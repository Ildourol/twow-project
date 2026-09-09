<#
.SYNOPSIS
    Verifies git diff or modified files in Tortoise-WoW against Turtle-WoW compatibility invariants.
.DESCRIPTION
    Scans changes for violations of the 10-race system, sTWDebuff removal,
    custom manager clobbering, and forbidden pattern overwrites.
.PARAMETER TargetRepo
    Path to tortoise-wow repository.
#>
[CmdletBinding()]
param(
    [string]$TargetRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Turtle-WoW Compatibility Guard & Invariant Checker" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (!(Test-Path $TargetRepo)) {
    Write-Error "Target repository not found at $TargetRepo"
    return
}

# Get working tree or staged diff
$diff = git -C $TargetRepo diff HEAD
if ([string]::IsNullOrWhiteSpace($diff)) {
    # Check unstaged diff
    $diff = git -C $TargetRepo diff
}

if ([string]::IsNullOrWhiteSpace($diff)) {
    Write-Host "No active git diff detected in $TargetRepo. Working directory clean." -ForegroundColor Green
    Write-Host "Checking HEAD commit..." -ForegroundColor Yellow
    $diff = git -C $TargetRepo show HEAD
}

$violations = @()
$warnings = @()

$lines = $diff -split "`n"
$currentFile = ""

foreach ($line in $lines) {
    if ($line -match "^\+\+\+ b/(.*)") {
        $currentFile = $matches[1]
        continue
    }

    # Only inspect added (+) or removed (-) lines
    if ($line -match "^\+(.*)") {
        $added = $matches[1]

        # Check for hardcoded 8 or 9 race loops
        if ($added -match "for\s*\(.*<\s*(9|8)\s*;\s*\+\+.*race" -or $added -match "\[\s*9\s*\]\s*;\s*//.*race") {
            $violations += "[$currentFile] Hardcoded race limit detected ('$added'). In Tortoise-WoW, MAX_RACES is 11 (Goblins & High Elves)."
        }

        # Check for MAX_RACES assumption
        if ($added -match "MAX_RACES\s*=\s*9") {
            $violations += "[$currentFile] MAX_RACES reassignment to 9. Must remain 11."
        }
    }

    if ($line -match "^-(.*)") {
        $removed = $matches[1]

        # Check for removal of sTWDebuff calls
        if ($removed -match "sTWDebuff->(AddDebuff|RemoveDebuff|RegisterTarget)") {
            $violations += "[$currentFile] CRITICAL: Removal of '$removed'. This breaks Turtle-WoW dynamic debuff streaming!"
        }

        # Check for removal of custom manager hooks
        if ($removed -match "sLFTMgr\." -or $removed -match "sTransmogMgr\." -or $removed -match "sCustomMerchantMgr\.") {
            $warnings += "[$currentFile] WARNING: Removal of custom Turtle manager hook: '$removed'."
        }
    }
}

Write-Host "`n--- Verification Report ---" -ForegroundColor Cyan
if ($violations.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host "[PASS] No compatibility invariant violations detected. Patch is clean!" -ForegroundColor Green
} else {
    if ($violations.Count -gt 0) {
        Write-Host "`n[FAIL] Found $($violations.Count) Critical Violations:" -ForegroundColor Red
        foreach ($v in $violations) {
            Write-Host "  * $v" -ForegroundColor Red
        }
    }
    if ($warnings.Count -gt 0) {
        Write-Host "`n[WARN] Found $($warnings.Count) Warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) {
            Write-Host "  * $w" -ForegroundColor Yellow
        }
    }
}
