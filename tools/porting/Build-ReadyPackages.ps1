<#
.SYNOPSIS
    Agent 1 (Builder & Committer): Verifies, compiles, and commits ready packages.
.DESCRIPTION
    Operates exclusively inside isolated Git worktrees, never on user working tree.
    Validates package freshness (rejects stale packages), enforces compatibility invariants,
    selects patch-aware build profiles, compiles via MSVC, creates candidate branch,
    and records provenance into canonical state store.
#>
[CmdletBinding()]
param(
    [switch]$SkipPush,
    [switch]$UseWorktree = $true,
    [string]$SpecificPackage = "",
    [switch]$SkipBuild,
    [switch]$FastBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path (Split-Path -Parent $ScriptDir) "tools\modules"
if (-not (Test-Path $ModulesDir)) { $ModulesDir = Join-Path $ScriptDir "..\modules" }

. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "ProjectConfig.ps1")
. (Join-Path $ModulesDir "StructuredResult.ps1")
. (Join-Path $ModulesDir "EncodingHelper.ps1")
. (Join-Path $ModulesDir "StateStore.ps1")
. (Join-Path $ModulesDir "StateMachine.ps1")
. (Join-Path $ModulesDir "WorktreeManager.ps1")
. (Join-Path $ModulesDir "CompatibilityChecker.ps1")
. (Join-Path $ModulesDir "BuildEngine.ps1")
. (Join-Path $ModulesDir "SmokeTest.ps1")

$cfg = Get-ProjectConfig
$ProjectRoot = $cfg.repositories.twow_project.path
$TortoisePath = $cfg.repositories.tortoise_wow.path
$ReadyDir = Join-Path $ProjectRoot "tools\queue\02_ready_to_build"
$CompletedDir = Join-Path $ProjectRoot "tools\queue\03_completed"
$RejectedDir = Join-Path $ProjectRoot "tools\queue\04_rejected"

$packagesToBuild = @()
if (-not [string]::IsNullOrEmpty($SpecificPackage)) {
    $cand = Join-Path $ReadyDir "$SpecificPackage.json"
    if (Test-Path $cand) { $packagesToBuild = @(Get-Item $cand) }
} else {
    $packagesToBuild = Get-ChildItem -Path $ReadyDir -Filter "*.json" -ErrorAction SilentlyContinue | Sort-Object Name
}

if ($packagesToBuild.Count -eq 0) {
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "[QUEUE STATUS: IDLE - NOTHING TO BUILD]" -ForegroundColor Yellow
    Write-Host "No packages waiting in tools/queue/02_ready_to_build/." -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    exit $script:EXIT_CODE_PASS
}

$wtStatus = if ($UseWorktree) { "ENABLED" } else { "DISABLED" }
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Agent 1: Building $($packagesToBuild.Count) Ready Package(s)" -ForegroundColor Cyan
Write-Host "  Worktree Isolation: $wtStatus" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

$runId = New-RunId

foreach ($pkg in $packagesToBuild) {
    $meta = Get-Content $pkg.FullName -Raw | ConvertFrom-Json
    $pkgId = [System.IO.Path]::GetFileNameWithoutExtension($pkg.Name)
    $donorSha = $meta.donor_sha
    $title = $meta.title
    if ([string]::IsNullOrEmpty($title) -and $meta.evidence -and $meta.evidence.subject) {
        $title = $meta.evidence.subject
    }
    $commitMsg = $meta.commit_msg
    if ([string]::IsNullOrEmpty($commitMsg)) {
        $sub = if ($meta.subsystem) { $meta.subsystem } elseif ($meta.evidence -and $meta.evidence.subsystem) { $meta.evidence.subsystem } else { "Core" }
        $commitMsg = "Port($sub): $title (vmangos/core@$donorSha)"
    }

    Write-Host "`n>>> Processing Package: $pkgId ($donorSha) - $title" -ForegroundColor Cyan

    # Stale Package Invalidation Check
    $currentHead = (git -C $TortoisePath rev-parse HEAD).Trim()
    if ($meta.target_base_sha -and $meta.target_base_sha -ne $currentHead) {
        Write-Host "  [STALE PACKAGE DETECTED] Recorded base $($meta.target_base_sha) != current HEAD $currentHead." -ForegroundColor Yellow
        Write-Host "  Moving package to NEEDS_REAUDIT state." -ForegroundColor Yellow
        Update-CandidateState -CandidateId $donorSha -ToState "NEEDS_REAUDIT" -ReasonCode "TARGET_BASE_CHANGED" | Out-Null
        continue
    }

    $patchRelPath = $meta.patch_file
    $patchFullPath = if ($patchRelPath) { Join-Path $ProjectRoot $patchRelPath } else { "" }
    if (-not $patchFullPath -or -not (Test-Path $patchFullPath)) {
        $fallbackPatch = Join-Path $ProjectRoot "tools\queue\staging_patches\$donorSha.patch"
        if (Test-Path $fallbackPatch) { $patchFullPath = $fallbackPatch }
    }

    # Worktree Isolation: Create isolated workspace for build
    $worktree = $null
    $activeRepo = $TortoisePath

    if ($UseWorktree) {
        try {
            $worktree = New-CandidateWorktree -TargetRepo $TortoisePath -CandidateId $pkgId -BaseSha $currentHead
            $activeRepo = $worktree.WorktreePath
            Write-Host "  Operating in isolated worktree: $activeRepo" -ForegroundColor DarkGray
        } catch {
            Write-Host "  [ERROR] Failed to create candidate worktree: $_" -ForegroundColor Red
            continue
        }
    }

    try {
        # 1. Apply Patch safely
        if ($patchFullPath -and (Test-Path $patchFullPath)) {
            $applyRes = Apply-GitPatchSafely -RepoPath $activeRepo -PatchPath $patchFullPath -IgnoreWhitespace
            if (-not $applyRes.Success) {
                Write-Host "  [FAIL] Failed to apply patch in worktree: $($applyRes.Output)" -ForegroundColor Red
                Update-CandidateState -CandidateId $donorSha -ToState "REJECTED" -ReasonCode "PATCH_APPLY_FAILED" | Out-Null
                Move-Item $pkg.FullName $RejectedDir -Force
                continue
            }
        }

        # 2. Apply SQL migration if present
        if ($meta.sql_file) {
            $sqlSrc = Join-Path $ProjectRoot $meta.sql_file
            if (Test-Path $sqlSrc) {
                $sqlDestDir = Join-Path $activeRepo "sql\database_updates\world"
                Copy-Item $sqlSrc $sqlDestDir -Force
                Write-Host "  Copied SQL migration to $sqlDestDir" -ForegroundColor DarkGray
            }
        }

        # 3. Verify Turtle Compatibility Invariants
        $compatRes = Test-TurtleCompatibility -WorktreePath $activeRepo
        if ($compatRes.ExitCode -ne 0) {
            $compMsg = $compatRes.Violations -join ", "
            Write-Host "  [FAIL] Compatibility invariant violated in worktree: $compMsg" -ForegroundColor Red
            Update-CandidateState -CandidateId $donorSha -ToState "REJECTED" -ReasonCode "COMPATIBILITY_VIOLATION" | Out-Null
            Move-Item $pkg.FullName $RejectedDir -Force
            continue
        }

        # 4. Build Profile Selection and Compilation Gate
        $touched = git -C $activeRepo diff --name-only HEAD
        $profile = Select-BuildProfile -TouchedFiles @($touched)
        Write-Host "  Selected build profile: $profile" -ForegroundColor DarkGray

        if (-not $SkipBuild) {
            # Link CMake build directory into worktree if needed
            $wtBuildDir = Join-Path $activeRepo "build"
            if (-not (Test-Path $wtBuildDir)) {
                $wtBuildDir = Join-Path $TortoisePath "build"
            }

            $buildRes = Invoke-TargetBuild -TargetRepo $activeRepo -Profile $profile -BuildDir $wtBuildDir -FastBuild:$FastBuild
            if ($buildRes.ExitCode -ne 0) {
                Write-Host "  [FAIL] Build gate failed for profile $profile!" -ForegroundColor Red
                Update-CandidateState -CandidateId $donorSha -ToState "COMPILE_FAIL" -ReasonCode "MSVC_BUILD_FAILED" | Out-Null
                Move-Item $pkg.FullName $RejectedDir -Force
                continue
            }
            Write-Host "  [PASS] Compilation and linking successful!" -ForegroundColor Green
        } else {
            Write-Host "  [SKIP-BUILD] Compilation skipped by user switch (-SkipBuild)." -ForegroundColor Yellow
        }

        # 5. Git Commit to Candidate Branch (Never direct to main)
        git -C $activeRepo add -A
        git -C $activeRepo reset --quiet -- .twow_worktree_meta.json 2>&1 | Out-Null
        git -C $activeRepo commit -m $commitMsg 2>&1 | Out-Null
        $commitSha = (git -C $activeRepo rev-parse --short HEAD).Trim()

        # Move package to completed archive
        Move-Item $pkg.FullName $CompletedDir -Force
        if ($patchFullPath -and (Test-Path $patchFullPath)) {
            $patchesArch = Join-Path $CompletedDir "patches"
            if (-not (Test-Path $patchesArch)) { New-Item -ItemType Directory -Path $patchesArch -Force | Out-Null }
            Move-Item $patchFullPath $patchesArch -Force
        }

        Update-CandidateState -CandidateId $donorSha -ToState "COMPLETE" -ReasonCode "COMMITTED_IN_WORKTREE" -Verdict "VERIFIED" | Out-Null
        Write-Host "  [SUCCESS] $pkgId committed ($commitSha) in candidate branch $($worktree.Branch)!" -ForegroundColor Green

    } finally {
        if ($UseWorktree -and $worktree) {
            Write-Host "  Preserving disposable worktree at $($worktree.WorktreePath) for candidate PR review." -ForegroundColor DarkGray
        }
    }
}

Record-Run -RunId $runId -Operation "BUILD_PACKAGES" -Status "COMPLETED" -Details @{ PackagesProcessed = $packagesToBuild.Count }
Write-Host "`nAll packages processed." -ForegroundColor Green

