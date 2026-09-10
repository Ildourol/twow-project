# EncodingHelper.ps1: Safe patch encoding, byte-level I/O, path safety

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (Test-Path (Join-Path $ScriptDir "PathMapper.ps1")) {
    . (Join-Path $ScriptDir "PathMapper.ps1")
}

function Write-Utf8NoBomText([string]$filePath, [string]$content) {
    $parent = Split-Path -Parent $filePath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($filePath, $content, $encoding)
}

function Read-Utf8Text([string]$filePath) {
    if (-not (Test-Path $filePath)) { return $null }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    return [System.IO.File]::ReadAllText($filePath, $encoding)
}

function Export-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$Sha,
        [Parameter(Mandatory=$true)][string]$DestinationPatchPath,
        [string]$TargetRepo = ""
    )

    $parent = Split-Path -Parent $DestinationPatchPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    # Run git format-patch with redirection via cmd to preserve raw bytes without PowerShell encoding filters
    $cmd = "git -C ""$RepoPath"" format-patch -1 --stdout ""$Sha"" > ""$DestinationPatchPath"""
    cmd.exe /c $cmd
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $DestinationPatchPath)) {
        throw "Failed to safely export patch for SHA $Sha from repo $RepoPath (ExitCode: $LASTEXITCODE)"
    }

    # Check that file is not empty
    $fi = Get-Item $DestinationPatchPath
    if ($fi.Length -eq 0) {
        throw "Exported patch is 0 bytes for SHA $Sha"
    }

    # Apply smart path mapping if target repository is supplied
    if ($TargetRepo -and (Test-Path $TargetRepo) -and (Get-Command "Convert-PatchPaths" -ErrorAction SilentlyContinue)) {
        $raw = [System.IO.File]::ReadAllText($DestinationPatchPath, [System.Text.Encoding]::UTF8)
        $mapped = Convert-PatchPaths -PatchContent $raw -TargetRepo $TargetRepo
        if ($mapped.HasChanges) {
            Write-Utf8NoBomText -filePath $DestinationPatchPath -content $mapped.PatchContent
        }
    }

    return $DestinationPatchPath
}

function Test-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$PatchPath
    )

    if (-not (Test-Path $PatchPath)) {
        return @{
            AppliesCleanly = $false
            ExitCode = 2
            Output = "Patch file not found: $PatchPath"
        }
    }

    $out = cmd.exe /c "git -C ""$RepoPath"" apply --check ""$PatchPath"" 2>&1"
    $code = $LASTEXITCODE

    # Smart Path Mapping Fallback: if raw patch failed, try with path remapping
    if ($code -ne 0 -and (Get-Command "Convert-PatchPaths" -ErrorAction SilentlyContinue)) {
        $raw = [System.IO.File]::ReadAllText($PatchPath, [System.Text.Encoding]::UTF8)
        $mapped = Convert-PatchPaths -PatchContent $raw -TargetRepo $RepoPath
        if ($mapped.HasChanges) {
            $tmpMapped = [System.IO.Path]::GetTempFileName()
            try {
                Write-Utf8NoBomText -filePath $tmpMapped -content $mapped.PatchContent
                $mappedOut = cmd.exe /c "git -C ""$RepoPath"" apply --check ""$tmpMapped"" 2>&1"
                if ($LASTEXITCODE -eq 0) {
                    return @{
                        AppliesCleanly = $true
                        ExitCode = 0
                        Output = ($mappedOut -join "`n")
                        WasRemapped = $true
                    }
                }
            } finally {
                if (Test-Path $tmpMapped) { Remove-Item $tmpMapped -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    return @{
        AppliesCleanly = ($code -eq 0)
        ExitCode = $code
        Output = ($out -join "`n")
        WasRemapped = $false
    }
}

function Apply-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$PatchPath,
        [switch]$IgnoreWhitespace
    )

    if (-not (Test-Path $PatchPath)) {
        throw "Patch file not found: $PatchPath"
    }

    $extraArgs = if ($IgnoreWhitespace) { "--ignore-whitespace" } else { "" }
    $out = cmd.exe /c "git -C ""$RepoPath"" apply $extraArgs ""$PatchPath"" 2>&1"
    $code = $LASTEXITCODE

    # Smart Path Mapping Fallback: if raw patch failed, attempt applying converted patch
    if ($code -ne 0 -and (Get-Command "Convert-PatchPaths" -ErrorAction SilentlyContinue)) {
        $raw = [System.IO.File]::ReadAllText($PatchPath, [System.Text.Encoding]::UTF8)
        $mapped = Convert-PatchPaths -PatchContent $raw -TargetRepo $RepoPath
        if ($mapped.HasChanges) {
            $tmpMapped = [System.IO.Path]::GetTempFileName()
            try {
                Write-Utf8NoBomText -filePath $tmpMapped -content $mapped.PatchContent
                $mappedOut = cmd.exe /c "git -C ""$RepoPath"" apply $extraArgs ""$tmpMapped"" 2>&1"
                $code = $LASTEXITCODE
                if ($code -eq 0) {
                    Write-Utf8NoBomText -filePath $PatchPath -content $mapped.PatchContent
                    return @{
                        Success = $true
                        ExitCode = 0
                        Output = ($mappedOut -join "`n")
                        WasRemapped = $true
                    }
                }
            } finally {
                if (Test-Path $tmpMapped) { Remove-Item $tmpMapped -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    return @{
        Success = ($code -eq 0)
        ExitCode = $code
        Output = ($out -join "`n")
        WasRemapped = $false
    }
}
function Save-Utf8NoBom([string]$FilePath, [string]$Content) {
    Write-Utf8NoBomText -filePath $FilePath -content $Content
}

function Normalize-LineEndings([string]$Text) {
    return [regex]::Replace($Text, "\r\n|\n|\r", "
")
}