# ReleaseManager.ps1: Release checkpoints, manifest generation, and tag gating

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")
. (Join-Path $ScriptDir "BaselineChecker.ps1")
. (Join-Path $ScriptDir "CompatibilityChecker.ps1")
. (Join-Path $ScriptDir "DbAuditor.ps1")

function Test-ReleaseReadiness {
    [CmdletBinding()]
    param(
        [string]$TargetRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
    )

    $blockers = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    # 1. Target working tree clean check
    $gitInfo = Get-RepoGitInfo -repoPath $TargetRepo
    if (-not $gitInfo.IsClean) {
        [void]$blockers.Add("Target repository has uncommitted changes.")
    }

    # 2. Compatibility check on HEAD
    $compat = Test-TurtleCompatibility -TargetRepo $TargetRepo
    if ($compat.ExitCode -ne 0) {
        [void]$blockers.Add("Compatibility invariant violations on HEAD: $($compat.Violations -join ', ')")
    }

    # 3. Baseline compilation check
    $baseline = Get-BaselineStatus -TargetRepo $TargetRepo
    if ($null -eq $baseline -or $baseline.compile_status -ne "PASS") {
        [void]$warnings.Add("Target baseline compilation has not been explicitly verified.")
    }

    return [ordered]@{
        IsReady   = ($blockers.Count -eq 0)
        Blockers  = @($blockers)
        Warnings  = @($warnings)
        TargetSha = $gitInfo.HeadSha
        Branch    = $gitInfo.Branch
    }
}

function New-ReleaseManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ReleaseName,
        [string]$TargetRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
        [string]$OutputDir = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\docs\releases"
    )

    $cfg = Get-ProjectConfig
    $gitInfo = Get-RepoGitInfo -repoPath $TargetRepo
    $readiness = Test-ReleaseReadiness -TargetRepo $TargetRepo

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $manifest = [ordered]@{
        release_name                   = $ReleaseName
        target_sha                     = $gitInfo.HeadSha
        penqle_baseline_sha            = $cfg.repositories.tortoise_wow.baseline_sha
        donor_repository               = $cfg.repositories.vmangos_donor.path
        build_config                   = $cfg.build.default_configuration
        compiler                       = $cfg.build.compiler
        toolchain                      = $cfg.build.toolset
        compatibility_manifest_version = "1.0.0"
        is_ready                       = $readiness.IsReady
        blockers                       = $readiness.Blockers
        warnings                       = $readiness.Warnings
        created_at                     = (Get-Date).ToString("o")
    }

    $manifestPath = Join-Path $OutputDir "$ReleaseName.json"
    $json = $manifest | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($manifestPath, $json, [System.Text.UTF8Encoding]::new($false))

    return @{
        ManifestPath = $manifestPath
        Manifest     = $manifest
    }
}

function Invoke-TagRelease {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$ReleaseName,
        [string]$TargetRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
    )

    $check = Test-ReleaseReadiness -TargetRepo $TargetRepo
    if (-not $check.IsReady) {
        throw "RELEASE TAG REJECTED: Validation incomplete or blocked by: $($check.Blockers -join ', ')"
    }

    Write-Host "Tagging release $ReleaseName at $($check.TargetSha)..." -ForegroundColor Green
    git -C $TargetRepo tag -a "$ReleaseName" -m "Release $ReleaseName certified by twow-project" 2>&1 | Out-Null
    Write-Host "Successfully tagged release $ReleaseName." -ForegroundColor Green
}

