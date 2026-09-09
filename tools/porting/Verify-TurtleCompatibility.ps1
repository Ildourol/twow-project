<#
.SYNOPSIS
    Verifies git diff, patch file, or worktree in Tortoise-WoW against Turtle-WoW compatibility invariants.
.DESCRIPTION
    Scans changes for violations of MAX_RACES=11, sTWDebuff removal,
    custom manager clobbering, entity-specific custom ID boundaries,
    and forbidden progressive columns.
    Standardized Exit Codes:
      0 = PASS
      1 = VALIDATION / COMPATIBILITY FAILURE
      2 = TOOL / ENVIRONMENT FAILURE
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$TargetRepo = "",

    [Parameter()]
    [string]$PatchFile = "",

    [Parameter()]
    [string]$WorktreePath = "",

    [Parameter()]
    [switch]$AsJson
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..") -ErrorAction SilentlyContinue
if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }

if ([string]::IsNullOrEmpty($TargetRepo) -and [string]::IsNullOrEmpty($PatchFile) -and [string]::IsNullOrEmpty($WorktreePath)) {
    $TargetRepo = Join-Path $ProjectRoot "tortoise-wow"
}

$ModulesDir = Join-Path $ProjectRoot "tools\modules"
if (-not (Test-Path $ModulesDir)) {
    $ModulesDir = Join-Path $ScriptDir "..\modules"
}

. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "CompatibilityChecker.ps1")

if (-not [string]::IsNullOrEmpty($PatchFile)) {
    if (-not (Test-Path $PatchFile)) {
        Write-Host "[ERROR] Patch file not found: $PatchFile" -ForegroundColor Red
        exit $script:EXIT_CODE_TOOL_FAILURE
    }
} elseif (-not [string]::IsNullOrEmpty($WorktreePath)) {
    if (-not (Test-Path $WorktreePath)) {
        Write-Host "[ERROR] Worktree path not found: $WorktreePath" -ForegroundColor Red
        exit $script:EXIT_CODE_TOOL_FAILURE
    }
} elseif (-not [string]::IsNullOrEmpty($TargetRepo)) {
    if (-not (Test-Path $TargetRepo)) {
        Write-Host "[ERROR] Target repository not found: $TargetRepo" -ForegroundColor Red
        exit $script:EXIT_CODE_TOOL_FAILURE
    }
}

if (-not $AsJson) {
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "  Turtle-WoW Compatibility Guard & Invariant Checker" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
}

$checkResult = Test-TurtleCompatibility -TargetRepo $TargetRepo -PatchFile $PatchFile -WorktreePath $WorktreePath

if ($AsJson) {
    $checkResult | ConvertTo-Json -Depth 5
    exit $checkResult.ExitCode
}

Write-Host "`n--- Verification Report ---" -ForegroundColor Cyan
if ($checkResult.Violations.Count -eq 0 -and $checkResult.Warnings.Count -eq 0) {
    Write-Host "[PASS] No compatibility invariant violations detected. Patch is clean!" -ForegroundColor Green
} else {
    if ($checkResult.Violations.Count -gt 0) {
        Write-Host "`n[FAIL] Found $($checkResult.Violations.Count) Critical Violations:" -ForegroundColor Red
        foreach ($v in $checkResult.Violations) {
            Write-Host "  * $v" -ForegroundColor Red
        }
    }
    if ($checkResult.Warnings.Count -gt 0) {
        Write-Host "`n[WARN] Found $($checkResult.Warnings.Count) Warnings:" -ForegroundColor Yellow
        foreach ($w in $checkResult.Warnings) {
            Write-Host "  * $w" -ForegroundColor Yellow
        }
    }
}

exit $checkResult.ExitCode