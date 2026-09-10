# BugProver.ps1: Deterministic bug-existence proving engine for donor candidates

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..") -ErrorAction SilentlyContinue
if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")
. (Join-Path $ScriptDir "CompatibilityChecker.ps1")
if (Test-Path (Join-Path $ScriptDir "PathMapper.ps1")) { . (Join-Path $ScriptDir "PathMapper.ps1") }
if (Test-Path (Join-Path $ScriptDir "EncodingHelper.ps1")) { . (Join-Path $ScriptDir "EncodingHelper.ps1") }

function Invoke-BugExistenceProof {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$DonorSha,
        [string]$DonorRepo = "",
        [string]$TargetRepo = ""
    )

    $cfg = Get-ProjectConfig
    if ([string]::IsNullOrEmpty($DonorRepo)) {
        $DonorRepo = if ($cfg -and $cfg.repositories.vmangos_donor.path) { $cfg.repositories.vmangos_donor.path } else { Join-Path $ProjectRoot "reference-upstreams\vmangos-core" }
    }
    if ([string]::IsNullOrEmpty($TargetRepo)) {
        $TargetRepo = if ($cfg -and $cfg.repositories.tortoise_wow.path) { $cfg.repositories.tortoise_wow.path } else { Join-Path $ProjectRoot "tortoise-wow" }
    }

    if (-not (Test-Path $DonorRepo)) {
        return @{
            Verdict = "UNCERTAIN"
            Confidence = 0.0
            Reason = "Donor repository not found: $DonorRepo"
            Evidence = @{}
            ExitCode = $script:EXIT_CODE_TOOL_FAILURE
        }
    }
    if (-not (Test-Path $TargetRepo)) {
        return @{
            Verdict = "UNCERTAIN"
            Confidence = 0.0
            Reason = "Target repository not found: $TargetRepo"
            Evidence = @{}
            ExitCode = $script:EXIT_CODE_TOOL_FAILURE
        }
    }

    # 1. Read donor commit details
    $commitMeta = git -C $DonorRepo log -n 1 --pretty=format:"%H|%h|%s|%an|%ad" --date=short $DonorSha 2>$null
    if (-not $commitMeta) {
        return @{
            Verdict = "NOT_APPLICABLE"
            Confidence = 1.0
            Reason = "Donor SHA $DonorSha not found in $DonorRepo"
            Evidence = @{}
            ExitCode = $script:EXIT_CODE_PASS
        }
    }

    $parts = $commitMeta.Split('|')
    $fullSha  = $parts[0]
    $shortSha = $parts[1]
    $subject  = $parts[2]
    $author   = $parts[3]
    $date     = $parts[4]

    $touchedFiles = git -C $DonorRepo diff-tree --no-commit-id --name-only -r $fullSha
    $donorDiff    = git -C $DonorRepo show $fullSha

    $evidence = [ordered]@{
        donor_short_sha     = $shortSha
        donor_full_sha      = $fullSha
        subject             = $subject
        author              = $author
        date                = $date
        touched_files       = @($touchedFiles)
        existing_files      = @()
        missing_files       = @()
        buggy_patterns_found= @()
        fixed_patterns_found= @()
        commit_already_found= $false
        divergence_found    = $null
    }

    # 2. Check if target commit history already references this donor SHA
    $targetLogMatch = git -C $TargetRepo log -n 5 --grep="vmangos/core@$shortSha" --pretty=format:"%h %s" 2>$null
    if (-not [string]::IsNullOrWhiteSpace($targetLogMatch)) {
        $evidence.commit_already_found = $true
        return @{
            Verdict     = "ALREADY_FIXED"
            Confidence  = 1.0
            Reason      = "Target repository commit log explicitly references donor commit: $targetLogMatch"
            Evidence    = $evidence
            ExitCode    = $script:EXIT_CODE_PASS
        }
    }

    # 3. Check for architectural divergence in subject or diff
    $manifest = Get-TurtleManifest
    if ($manifest -and $manifest.architectural_divergences) {
        foreach ($ad in $manifest.architectural_divergences) {
            if ($donorDiff -match $ad.pattern -or $subject -match $ad.pattern) {
                $evidence.divergence_found = $ad.reason
                return @{
                    Verdict     = "TURTLE_INTENTIONAL_DIVERGENCE"
                    Confidence  = 0.95
                    Reason      = "Architectural divergence detected: $($ad.reason)"
                    Evidence    = $evidence
                    ExitCode    = $script:EXIT_CODE_PASS
                }
            }
        }
    }

    # 4. Check file existence in target (with Smart Path Mapping)
    $existing = [System.Collections.Generic.List[string]]::new()
    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($tf in $touchedFiles) {
        if ([string]::IsNullOrWhiteSpace($tf)) { continue }
        $tgtPath = Join-Path $TargetRepo $tf
        if (Test-Path $tgtPath) {
            [void]$existing.Add($tf)
        } else {
            # Try smart path mapping
            $mappedTf = if (Get-Command "Get-MappedTargetPath" -ErrorAction SilentlyContinue) {
                Get-MappedTargetPath -DonorFilePath $tf -TargetRepo $TargetRepo
            } else { $tf }

            $mappedTgtPath = Join-Path $TargetRepo $mappedTf
            if ($mappedTf -ne $tf -and (Test-Path $mappedTgtPath)) {
                [void]$existing.Add($mappedTf)
            } else {
                [void]$missing.Add($tf)
            }
        }
    }
    $evidence.existing_files = @($existing)
    $evidence.missing_files  = @($missing)

    if ($existing.Count -eq 0 -and $missing.Count -gt 0) {
        return @{
            Verdict     = "NOT_APPLICABLE"
            Confidence  = 0.98
            Reason      = "All modified files do not exist in target repository."
            Evidence    = $evidence
            ExitCode    = $script:EXIT_CODE_PASS
        }
    }

    # 5. Inspect hunk diffs: determine whether buggy pattern or fix pattern exists in target files
    $diffLines = $donorDiff -split "`r?`n"
    $removedHunkLines = [System.Collections.Generic.List[string]]::new()
    $addedHunkLines   = [System.Collections.Generic.List[string]]::new()

    foreach ($dl in $diffLines) {
        if ($dl -match "^-([^-].*)") {
            $trimmed = $Matches[1].Trim()
            if ($trimmed.Length -ge 10 -and -not $trimmed.StartsWith("//") -and -not $trimmed.StartsWith("/*")) {
                [void]$removedHunkLines.Add($trimmed)
            }
        } elseif ($dl -match "^\+([^\+].*)") {
            $trimmed = $Matches[1].Trim()
            if ($trimmed.Length -ge 10 -and -not $trimmed.StartsWith("//") -and -not $trimmed.StartsWith("/*")) {
                [void]$addedHunkLines.Add($trimmed)
            }
        }
    }

    $buggyFound = [System.Collections.Generic.List[string]]::new()
    $fixedFound = [System.Collections.Generic.List[string]]::new()

    foreach ($ef in $existing) {
        $tgtFilePath = Join-Path $TargetRepo $ef
        $tgtContent = [System.IO.File]::ReadAllText($tgtFilePath, [System.Text.Encoding]::UTF8)

        foreach ($rh in $removedHunkLines) {
            if ($tgtContent.Contains($rh)) {
                [void]$buggyFound.Add("$ef : $rh")
            }
        }
        foreach ($ah in $addedHunkLines) {
            if ($tgtContent.Contains($ah)) {
                [void]$fixedFound.Add("$ef : $ah")
            }
        }
    }

    $evidence.buggy_patterns_found = @($buggyFound)
    $evidence.fixed_patterns_found = @($fixedFound)

    if ($fixedFound.Count -gt 0 -and $buggyFound.Count -eq 0) {
        return @{
            Verdict     = "ALREADY_FIXED"
            Confidence  = 0.90
            Reason      = "Target code contains upstream fix patterns and none of the removed buggy patterns."
            Evidence    = $evidence
            ExitCode    = $script:EXIT_CODE_PASS
        }
    }

    if ($buggyFound.Count -gt 0) {
        return @{
            Verdict     = "BUG_PRESENT"
            Confidence  = 0.92
            Reason      = "Exact buggy code pattern from donor commit is present in target source files."
            Evidence    = $evidence
            ExitCode    = $script:EXIT_CODE_PASS
        }
    }

    # If neither exact match was found, check patch applicability via git apply --check (with Smart Path Mapping)
    $tmpPatch = Join-Path $TargetRepo ".git\temp_prove_$shortSha.patch"
    cmd.exe /c "git -C ""$DonorRepo"" format-patch -1 --stdout $fullSha > ""$tmpPatch"""
    $applies = $false
    if (Test-Path $tmpPatch) {
        $testRes = Test-GitPatchSafely -RepoPath $TargetRepo -PatchPath $tmpPatch
        $applies = [bool]$testRes.AppliesCleanly
        Remove-Item $tmpPatch -Force -ErrorAction SilentlyContinue
    }

    if ($applies) {
        return @{
            Verdict     = "BUG_PRESENT"
            Confidence  = 0.75
            Reason      = "Patch applies cleanly to target context lines without conflicts; candidate requires runtime/compile verification."
            Evidence    = $evidence
            ExitCode    = $script:EXIT_CODE_PASS
        }
    }

    return @{
        Verdict     = "UNCERTAIN"
        Confidence  = 0.40
        Reason      = "Target source has diverged from donor context; manual or AI semantic evaluation required."
        Evidence    = $evidence
        ExitCode    = $script:EXIT_CODE_PASS
    }
}

function Test-BugExistence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateSha,
        [string]$DonorRepo = "",
        [string]$TargetRepo = ""
    )

    $proof = Invoke-BugExistenceProof -DonorSha $CandidateSha -DonorRepo $DonorRepo -TargetRepo $TargetRepo
    return @{
        status     = if ($proof.ExitCode -eq 0) { "PASS" } else { "FAIL" }
        verdict    = $proof.Verdict
        confidence = $proof.Confidence
        evidence   = $proof.Evidence
        reason     = $proof.Reason
    }
}

function Classify-BugByDiff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$DiffText,
        [string]$TargetRepo = ""
    )

    if ([string]::IsNullOrEmpty($TargetRepo)) {
        $cfg = Get-ProjectConfig
        $TargetRepo = if ($cfg -and $cfg.repositories.tortoise_wow.path) { $cfg.repositories.tortoise_wow.path } else { Join-Path $ProjectRoot "tortoise-wow" }
    }

    if ($DiffText -match "MAX_RACES\s+1[01]|sTWDebuff|sTransmogMgr|sCustomMerchantMgr") {
        return "TURTLE_INTENTIONAL_DIVERGENCE"
    }

    $fileMatches = [regex]::Matches($DiffText, '(?m)^\+\+\+\s+b/(.*)$')
    foreach ($fm in $fileMatches) {
        $relPath = $fm.Groups[1].Value.Trim()
        $fullPath = Join-Path $TargetRepo $relPath
        if (-not (Test-Path $fullPath)) {
            return "NOT_APPLICABLE"
        }
    }

    return "BUG_PRESENT"
}

