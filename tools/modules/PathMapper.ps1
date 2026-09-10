# PathMapper.ps1: Intelligent file path mapping between VMaNGOS donor repository and Tortoise-WoW target repository

$script:TargetFileIndexCache = $null
$script:TargetRepoCachedPath = $null

function Initialize-TargetPathIndex([string]$TargetRepo) {
    if ($script:TargetFileIndexCache -and $script:TargetRepoCachedPath -eq $TargetRepo) {
        return $script:TargetFileIndexCache
    }

    $index = @{
        ExactSet     = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        BasenameMap  = @{}
    }

    $files = git -C $TargetRepo ls-files 2>$null
    if ($files) {
        foreach ($f in $files) {
            $normalized = $f.Replace('\', '/')
            [void]$index.ExactSet.Add($normalized)
            $base = [System.IO.Path]::GetFileName($normalized)
            if (-not $index.BasenameMap.ContainsKey($base)) {
                $index.BasenameMap[$base] = [System.Collections.Generic.List[string]]::new()
            }
            $index.BasenameMap[$base].Add($normalized)
        }
    }

    $script:TargetFileIndexCache = $index
    $script:TargetRepoCachedPath = $TargetRepo
    return $index
}

function Clear-TargetPathIndexCache {
    $script:TargetFileIndexCache = $null
    $script:TargetRepoCachedPath = $null
}

function Get-MappedTargetPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$DonorFilePath,
        [Parameter(Mandatory=$true)][string]$TargetRepo
    )

    $donorNorm = $DonorFilePath.Replace('\', '/').TrimStart('/')
    $index = Initialize-TargetPathIndex -TargetRepo $TargetRepo

    # 1. Exact match in target
    if ($index.ExactSet.Contains($donorNorm)) {
        return $donorNorm
    }

    # 2. Rule-based static transformations
    # Rule 2a: Scripts in eastern_kingdoms/kalimdor dungeon subdirectories -> src/scripts/dungeons/
    if ($donorNorm -match '^src/scripts/(?:eastern_kingdoms|kalimdor)/[^/]+/([^/]+)/(.+)$') {
        $dungeonName = $Matches[1]
        $fileName = $Matches[2]
        $candidate = "src/scripts/dungeons/$dungeonName/$fileName"
        if ($index.ExactSet.Contains($candidate)) {
            return $candidate
        }
    }

    # Rule 2b: Scripts in eastern_kingdoms/kalimdor zone subdirectories -> src/scripts/world/
    if ($donorNorm -match '^src/scripts/(?:eastern_kingdoms|kalimdor)/([^/]+)/(.+)$') {
        $zoneName = $Matches[1]
        $fileName = $Matches[2]
        $candidateZone = "src/scripts/world/$zoneName/$fileName"
        if ($index.ExactSet.Contains($candidateZone)) {
            return $candidateZone
        }
        $candidateFlat = "src/scripts/world/$fileName"
        if ($index.ExactSet.Contains($candidateFlat)) {
            return $candidateFlat
        }
    }

    # Rule 2c: cmake/find -> cmake/
    if ($donorNorm -match '^cmake/find/(.+)$') {
        $candidate = "cmake/$($Matches[1])"
        if ($index.ExactSet.Contains($candidate)) {
            return $candidate
        }
    }

    # Rule 2d: cmake/platform -> cmake/
    if ($donorNorm -match '^cmake/platform/(.+)$') {
        $candidate = "cmake/$($Matches[1])"
        if ($index.ExactSet.Contains($candidate)) {
            return $candidate
        }
    }

    # Rule 2e: contrib/<tool> -> tools/<tool>
    if ($donorNorm -match '^contrib/([^/]+)/(.+)$') {
        $tool = $Matches[1]
        $sub = $Matches[2]
        $candidate = "tools/$tool/$sub"
        if ($index.ExactSet.Contains($candidate)) {
            return $candidate
        }
    }

    # 3. Dynamic Basename Disambiguation Fallback
    $baseName = [System.IO.Path]::GetFileName($donorNorm)
    if ($index.BasenameMap.ContainsKey($baseName)) {
        $matchesList = $index.BasenameMap[$baseName]
        if ($matchesList.Count -eq 1) {
            return $matchesList[0]
        }

        # If multiple, prefer the one with highest path similarity (matching directory tokens)
        $donorParts = $donorNorm -split '/'
        $bestMatch = $null
        $bestScore = -1
        foreach ($cand in $matchesList) {
            $candParts = $cand -split '/'
            $score = 0
            foreach ($p in $donorParts) {
                if ($candParts -contains $p) { $score++ }
            }
            if ($score -gt $bestScore) {
                $bestScore = $score
                $bestMatch = $cand
            }
        }
        if ($bestMatch -and $bestScore -ge 2) {
            return $bestMatch
        }
    }

    # Return original donor path if no mapping could be determined
    return $donorNorm
}

function Convert-PatchPaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$PatchContent,
        [Parameter(Mandatory=$true)][string]$TargetRepo
    )

    $lines = $PatchContent -split "`r?`n"
    $newLines = [System.Collections.Generic.List[string]]::new($lines.Count)
    $pathMapCache = @{}
    $hasChanges = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '^diff --git a/(.+?) b/(.+?)$') {
            $fileA = $Matches[1]
            $fileB = $Matches[2]

            if (-not $pathMapCache.ContainsKey($fileA)) {
                $pathMapCache[$fileA] = Get-MappedTargetPath -DonorFilePath $fileA -TargetRepo $TargetRepo
            }
            if (-not $pathMapCache.ContainsKey($fileB)) {
                $pathMapCache[$fileB] = Get-MappedTargetPath -DonorFilePath $fileB -TargetRepo $TargetRepo
            }

            $mappedA = $pathMapCache[$fileA]
            $mappedB = $pathMapCache[$fileB]

            if ($mappedA -ne $fileA -or $mappedB -ne $fileB) {
                $hasChanges = $true
                $line = "diff --git a/$mappedA b/$mappedB"
            }
        }
        elseif ($line -match '^--- (?:a/)?(.+?)$') {
            $file = $Matches[1]
            if ($file -ne "/dev/null") {
                if (-not $pathMapCache.ContainsKey($file)) {
                    $pathMapCache[$file] = Get-MappedTargetPath -DonorFilePath $file -TargetRepo $TargetRepo
                }
                $mapped = $pathMapCache[$file]
                if ($mapped -ne $file) {
                    $hasChanges = $true
                    $line = "--- a/$mapped"
                }
            }
        }
        elseif ($line -match '^\+\+\+ (?:b/)?(.+?)$') {
            $file = $Matches[1]
            if ($file -ne "/dev/null") {
                if (-not $pathMapCache.ContainsKey($file)) {
                    $pathMapCache[$file] = Get-MappedTargetPath -DonorFilePath $file -TargetRepo $TargetRepo
                }
                $mapped = $pathMapCache[$file]
                if ($mapped -ne $file) {
                    $hasChanges = $true
                    $line = "+++ b/$mapped"
                }
            }
        }

        [void]$newLines.Add($line)
    }

    return @{
        HasChanges   = $hasChanges
        PatchContent = ($newLines -join "`n")
    }
}
