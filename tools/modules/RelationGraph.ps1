# RelationGraph.ps1: Dependency, duplicate, and supersession relationship engine

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")

function Get-CommitPatchId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$Sha
    )

    $patchOut = git -C $RepoPath format-patch -1 --stdout $Sha 2>$null
    if (-not $patchOut) { return "" }
    $pidOut = $patchOut | git -C $RepoPath patch-id 2>$null
    if ($pidOut -match '^([0-9a-f]{40})\s+') {
        return $Matches[1]
    }
    return ""
}

function Get-CandidateRelations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("CandidateSha")][string]$DonorSha,
        [string]$DonorRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core"
    )

    if (-not (Test-Path $DonorRepo)) {
        return @{ Error = "Donor repository not found: $DonorRepo"; Relations = @() }
    }

    $meta = git -C $DonorRepo log -n 1 --pretty=format:"%H|%h|%s|%b" $DonorSha 2>$null
    if (-not $meta) {
        return @{ Error = "Donor SHA $DonorSha not found"; Relations = @() }
    }

    $parts = $meta.Split('|')
    $fullSha = $parts[0]
    $shortSha = $parts[1]
    $subject = $parts[2]
    $body = if ($parts.Count -gt 3) { $parts[3] } else { "" }

    $relations = [System.Collections.Generic.List[object]]::new()

    # 1. Revert detection
    if ($subject -match '(?i)Revert\s+"(.*)"' -or $subject -match '(?i)revert\s+([0-9a-f]{7,40})') {
        $revertedRef = $Matches[1]
        [void]$relations.Add([PSCustomObject]@{
            Type        = "REVERTS"
            Target      = $revertedRef
            Description = "Commit explicitly reverts an earlier commit/change"
            Confidence  = 0.95
        })
    }

    # 2. Check if a later commit reverts THIS commit
    $revertedBy = git -C $DonorRepo log --grep="$shortSha" --pretty=format:"%h|%s" 2>$null
    if ($revertedBy) {
        foreach ($rb in ($revertedBy -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($rb)) { continue }
            $rbParts = $rb.Split('|')
            $rbSha = $rbParts[0]
            $rbSub = $rbParts[1]
            if ($rbSha -ne $shortSha) {
                if ($rbSub -match "(?i)revert") {
                    [void]$relations.Add([PSCustomObject]@{
                        Type        = "SUPERSEDED_BY"
                        Target      = $rbSha
                        Description = "Later commit $rbSha reverts or supersedes this commit ($rbSub)"
                        Confidence  = 0.95
                    })
                } else {
                    [void]$relations.Add([PSCustomObject]@{
                        Type        = "FOLLOW_UP_TO"
                        Target      = $rbSha
                        Description = "Referenced in follow-up commit $rbSha ($rbSub)"
                        Confidence  = 0.85
                    })
                }
            }
        }
    }

    # 3. Message cross-references (e.g. "follow-up to", "fixes #", "supersedes")
    if ($body -match '(?i)follow[- ]up\s+to\s+([0-9a-f]{7,40})') {
        [void]$relations.Add([PSCustomObject]@{
            Type        = "FOLLOW_UP_TO"
            Target      = $Matches[1]
            Description = "Commit body explicitly notes follow-up relationship"
            Confidence  = 0.90
        })
    }

    # 4. Touched files and line overlap search across nearby commits
    $touchedFiles = git -C $DonorRepo diff-tree --no-commit-id --name-only -r $fullSha
    $nearbyCommits = git -C $DonorRepo log -n 10 --pretty=format:"%h|%s" "$fullSha~5..$fullSha" 2>$null
    if ($nearbyCommits) {
        foreach ($nc in ($nearbyCommits -split "`r?`n")) {
            if ([string]::IsNullOrWhiteSpace($nc)) { continue }
            $ncSha = $nc.Split('|')[0]
            if ($ncSha -ne $shortSha) {
                $ncFiles = git -C $DonorRepo diff-tree --no-commit-id --name-only -r $ncSha
                $overlap = @($touchedFiles | Where-Object { $ncFiles -contains $_ })
                if ($overlap.Count -gt 0) {
                    [void]$relations.Add([PSCustomObject]@{
                        Type        = "RELATED_TO"
                        Target      = $ncSha
                        Description = "Nearby commit touches overlapping files: $($overlap -join ', ')"
                        Confidence  = 0.70
                    })
                }
            }
        }
    }

    if ($relations.Count -eq 0) {
        [void]$relations.Add([PSCustomObject]@{
            Type        = "INDEPENDENT"
            Target      = $null
            Description = "No direct reverts, duplicates, or supersessions found in donor history"
            Confidence  = 0.80
        })
    }

    return @{
        Sha       = $shortSha
        candidate_sha = $shortSha
        superseded_by = @($relations | Where-Object { $_.Type -eq 'SUPERSEDED_BY' } | Select-Object -ExpandProperty Target)
        FullSha   = $fullSha
        Subject   = $subject
        Relations = $relations
    }
}

function Get-CandidateDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("CandidateSha")][string]$DonorSha,
        [string]$DonorRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core"
    )

    $parents = git -C $DonorRepo log -n 1 --pretty=format:"%P" $DonorSha 2>$null
    $parentList = if ($parents) { ($parents.Trim() -split '\s+') } else { @() }

    $deps = [System.Collections.Generic.List[object]]::new()
    foreach ($p in $parentList) {
        $pMeta = git -C $DonorRepo log -n 1 --pretty=format:"%h|%s" $p 2>$null
        if ($pMeta) {
            $pParts = $pMeta.Split('|')
            [void]$deps.Add([PSCustomObject]@{
                Sha         = $pParts[0]
                FullSha     = $p
                Subject     = $pParts[1]
                Type        = "PREREQUISITE_OF"
            })
        }
    }

    return @{
        Sha          = $DonorSha
        Dependencies = $deps
    }
}

