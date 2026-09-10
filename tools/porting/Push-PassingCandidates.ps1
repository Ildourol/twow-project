<#
.SYNOPSIS
    Pushes all verified, passing commits to a designated development branch on GitHub.
.DESCRIPTION
    Scans tools/queue/03_completed for certified candidate packages, checks out or creates
    the target dev branch off main, applies candidate patches cleanly via git am, and pushes
    to the configured remote (https://github.com/Ildourol/tortoise-wow-extended).
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$BranchName = "extended",

    [Parameter()]
    [string]$RemoteName = "origin",

    [Parameter()]
    [string]$BaseBranch = "main",

    [Parameter()]
    [switch]$NoPush
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $ToolsDir
$ModulesDir = Join-Path $ToolsDir "modules"

. (Join-Path $ModulesDir "ProjectConfig.ps1")

$cfg = Get-ProjectConfig
$TortoiseRepo = $cfg.repositories.tortoise_wow.path
$CompletedDir = Join-Path $ProjectRoot "tools\queue\03_completed"
$PatchesDir = Join-Path $CompletedDir "patches"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  PUSH PASSING CANDIDATES TO REMOTE: $RemoteName/$BranchName" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Gather all completed manifests and patches
$completedPackages = Get-ChildItem -Path $CompletedDir -Filter "*.json" | Where-Object { $_.Name -match '^[A-Z]+-\d+\.json$' } | Sort-Object Name
if ($completedPackages.Count -eq 0) {
    Write-Host "[WARNING] No completed packages found in $CompletedDir!" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($completedPackages.Count) verified packages to integrate." -ForegroundColor Green

# 2. Check git cleanliness on target repo
$status = git -C $TortoiseRepo status --porcelain
if (-not [string]::IsNullOrWhiteSpace($status)) {
    Write-Host "[ERROR] Target repository has uncommitted changes. Stash or commit before proceeding." -ForegroundColor Red
    exit 1
}

$origBranch = (git -C $TortoiseRepo rev-parse --abbrev-ref HEAD).Trim()

try {
    # 3. Checkout or create the dev branch
    $localBranches = (git -C $TortoiseRepo branch --list $BranchName)
    $remoteBranchExists = -not [string]::IsNullOrWhiteSpace((git -C $TortoiseRepo branch -r --list "$RemoteName/$BranchName"))

    if ([string]::IsNullOrWhiteSpace($localBranches)) {
        if ($remoteBranchExists) {
            Write-Host "Checking out branch '$BranchName' tracking '$RemoteName/$BranchName'..." -ForegroundColor Cyan
            git -C $TortoiseRepo checkout -b $BranchName "$RemoteName/$BranchName" 2>&1 | Out-Null
        } else {
            Write-Host "Creating branch '$BranchName' from '$BaseBranch'..." -ForegroundColor Cyan
            git -C $TortoiseRepo checkout -b $BranchName $BaseBranch 2>&1 | Out-Null
        }
    } else {
        Write-Host "Checking out existing branch '$BranchName'..." -ForegroundColor Cyan
        git -C $TortoiseRepo checkout $BranchName 2>&1 | Out-Null
        if ($remoteBranchExists) {
            Write-Host "Fetching latest updates from '$RemoteName/$BranchName'..." -ForegroundColor DarkGray
            git -C $TortoiseRepo pull --ff-only $RemoteName $BranchName 2>&1 | Out-Null
        }
    }

    # 4. Apply clean patches
    $appliedCount = 0
    $skippedCount = 0

    foreach ($pkg in $completedPackages) {
        $meta = Get-Content $pkg.FullName -Raw | ConvertFrom-Json
        $donorSha = $meta.donor_sha
        $patchPath = Join-Path $PatchesDir "$donorSha.patch"

        if (-not (Test-Path $patchPath)) {
            Write-Host "  * [$($meta.candidate_id)] Patch file not found: $patchPath (Skipping)" -ForegroundColor Yellow
            continue
        }

        # Check if already applied (by donor sha in commit message, or exact subject/title)
        $title = if ($meta.evidence.subject) { $meta.evidence.subject.Trim() } elseif ($meta.title) { $meta.title.Trim() } else { "" }
        $alreadyInLog = git -C $TortoiseRepo log -n 100 --grep="$donorSha" --oneline
        if ([string]::IsNullOrWhiteSpace($alreadyInLog) -and -not [string]::IsNullOrWhiteSpace($title)) {
            $alreadyInLog = git -C $TortoiseRepo log -n 100 --fixed-strings --grep="$title" --oneline
        }
        if (-not [string]::IsNullOrWhiteSpace($alreadyInLog)) {
            Write-Host "  * [$($meta.candidate_id)] Already present in $BranchName (Skipped)" -ForegroundColor DarkGray
            $skippedCount++
            continue
        }

        Write-Host "  * [$($meta.candidate_id)] Applying: $($meta.evidence.subject)..." -ForegroundColor Cyan
        $amOut = git -C $TortoiseRepo am -3 --ignore-whitespace $patchPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [WARNING] git am conflict; aborting am for this patch..." -ForegroundColor Yellow
            git -C $TortoiseRepo am --abort 2>&1 | Out-Null
        } else {
            $appliedCount++
        }
    }

    Write-Host "`nSummary: $appliedCount applied, $skippedCount previously applied." -ForegroundColor Green

    # 5. Push to GitHub if requested
    if (-not $NoPush) {
        $unpushed = git -C $TortoiseRepo cherry "$RemoteName/$BranchName" $BranchName 2>$null
        if ([string]::IsNullOrWhiteSpace($unpushed) -and $remoteBranchExists -and $appliedCount -eq 0) {
            Write-Host "`n[INFO] Remote '$RemoteName/$BranchName' is already fully up to date with all verified commits." -ForegroundColor Green
        } else {
            Write-Host "`nPushing branch '$BranchName' to remote '$RemoteName'..." -ForegroundColor Cyan
            $pushOut = git -C $TortoiseRepo push -u $RemoteName $BranchName 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Push failed:`n$pushOut" -ForegroundColor Red
            } else {
                Write-Host "[SUCCESS] Pushed successfully to: https://github.com/Ildourol/tortoise-wow-extended/tree/$BranchName" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "[INFO] -NoPush specified; commits committed locally to $BranchName." -ForegroundColor Yellow
    }
}
finally {
    # Return to original branch
    if ($origBranch -and $origBranch -ne "HEAD") {
        git -C $TortoiseRepo checkout $origBranch 2>&1 | Out-Null
    }
}

