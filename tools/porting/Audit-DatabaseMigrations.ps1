<#
.SYNOPSIS
    Audits Tortoise-WoW database migrations for compatibility with Turtle-WoW 1.18.1
    and detects conflicts with custom content, schema mismatches, and forbidden progressive columns.
    Standardized Exit Codes: 0 = PASS, 1 = VALIDATION FAILURE, 2 = TOOL FAILURE
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string[]]$TargetMigrations = @(),
    [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
    [switch]$AsJson
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path (Split-Path -Parent $ScriptDir) "tools\modules"
if (-not (Test-Path $ModulesDir)) {
    $ModulesDir = Join-Path $ScriptDir "..\modules"
}

. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "DbAuditor.ps1")

if (-not $AsJson) {
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  Tortoise-WoW Database Migration Auditor & Invariant Checker  " -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
}

$audit = Invoke-DatabaseMigrationAudit -TargetMigrations $TargetMigrations -TortoiseRepo $TortoiseRepo

if ($AsJson) {
    $audit | ConvertTo-Json -Depth 6
    exit $audit.ExitCode
}

Write-Host "`n[1/3] Cataloged $($audit.CatalogedTables) distinct database tables in Turtle-WoW schema." -ForegroundColor Green
Write-Host "[2/3] Audited $($audit.TotalFiles) Migration Files..." -ForegroundColor Yellow
Write-Host "`n[3/3] Audit Execution Summary" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------------------"
Write-Host "Total Migration Files Checked: $($audit.TotalFiles)"
Write-Host "  -> PASS: $($audit.PassCount)" -ForegroundColor Green
Write-Host "  -> WARN: $($audit.WarnCount)" -ForegroundColor Yellow
Write-Host "  -> FAIL: $($audit.FailCount)" -ForegroundColor Red

Write-Host "`nDetailed Migration Audit Log:" -ForegroundColor Cyan
foreach ($r in $audit.Results) {
    $color = switch ($r.Status) { "PASS" { "Green" } "WARN" { "Yellow" } "FAIL" { "Red" } }
    Write-Host "[$($r.Status)] $($r.Filename) (Tables: $($r.Tables))" -ForegroundColor $color
    foreach ($iss in $r.Issues) {
        Write-Host "     [ERROR] $iss" -ForegroundColor Red
    }
    foreach ($w in $r.Warnings) {
        Write-Host "     [WARN]  $w" -ForegroundColor Yellow
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
if ($audit.FailCount -eq 0) {
    Write-Host "  ALL MIGRATIONS COMPLIANT: 0 Schema, Invariant, or Column Violations!" -ForegroundColor Green
} else {
    Write-Host "  AUDIT FAILED: $($audit.FailCount) migrations require schema adjustments." -ForegroundColor Red
}
Write-Host "=================================================================" -ForegroundColor Cyan

exit $audit.ExitCode

