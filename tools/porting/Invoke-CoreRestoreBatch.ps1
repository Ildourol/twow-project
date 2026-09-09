<#
.SYNOPSIS
    Batch Runner for Turtle-WoW Native Core Restoration (task restore-batch).
.DESCRIPTION
    Sequentially audits multiple Turtle-WoW custom mechanics, patch specifications, and class
    features against the official 22,155 forum archive and tortoise-wow codebase.
    Automatically skips topics that have already been audited in docs/CORE_RESTORATION_LEDGER.md.
.PARAMETER BatchCount
    Number of queued topics to audit in this batch run (default: 5).
.PARAMETER Topics
    Explicit array or comma-separated list of topics to audit.
.PARAMETER StageTemplate
    Generates package manifests in 02_ready_to_build/ for missing mechanics.
.PARAMETER AutoBuild
    Automatically triggers compilation and remote push for staged packages via Agent 1.
.EXAMPLE
    task restore-batch 5
    task restore-batch "Holy Strike,Moonfury,Blood Frenzy"
    task restore-batch 10 -AutoBuild
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [object]$BatchInput = 5,

    [Parameter()]
    [switch]$StageTemplate,

    [Parameter()]
    [switch]$AutoBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$HistoryJson = Join-Path $ProjectRoot "tools\queue\restoration_history.json"
$SingleRestoreScript = Join-Path $ScriptDir "Invoke-CoreRestore.ps1"

# Curated queue of core Turtle-WoW patch mechanics (ordered by architectural impact)
$defaultPriorityTopics = @(
    "Holy Strike",
    "Moonfury",
    "Blood Frenzy",
    "Goblins",
    "High Elves",
    "Survival Skill",
    "Gardening",
    "Karazhan Crypts",
    "Looking For Turtle",
    "Transmogrification",
    "MountManager",
    "DynamicVisibility",
    "CustomMerchantMgr",
    "Undermine Shipment",
    "Emerald Sanctum"
)

# Load existing restoration history to prevent double-checking
$auditedTopics = @{}
if (Test-Path $HistoryJson) {
    try {
        $raw = Get-Content $HistoryJson -Raw -Encoding utf8
        if ($raw) {
            $parsed = $raw | ConvertFrom-Json
            if ($parsed) {
                foreach ($prop in $parsed.PSObject.Properties) {
                    $auditedTopics[$prop.Name] = $true
                }
            }
        }
    } catch {
        $auditedTopics = @{}
    }
}

$topicsToProcess = @()

if ($BatchInput -is [int] -or "$BatchInput" -match '^\d+$') {
    $count = [int]$BatchInput
    # Filter priority queue for un-audited topics
    foreach ($top in $defaultPriorityTopics) {
        $key = $top.Trim().ToLower()
        if (-not $auditedTopics.ContainsKey($key)) {
            $topicsToProcess += $top
            if ($topicsToProcess.Count -ge $count) { break }
        }
    }
} elseif ($BatchInput -is [string]) {
    $split = "$BatchInput" -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    $topicsToProcess = @($split)
} elseif ($BatchInput -is [array]) {
    $topicsToProcess = @($BatchInput)
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Turtle-WoW Core Restoration: Batch Processor" -ForegroundColor Cyan
Write-Host "  Topics Queued : $($topicsToProcess.Count)" -ForegroundColor Yellow
Write-Host "  Previously Audited (Skipped): $($auditedTopics.Count)" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

if ($topicsToProcess.Count -eq 0) {
    Write-Host "`nAll default priority topics have already been audited!" -ForegroundColor Green
    Write-Host "Check docs/CORE_RESTORATION_LEDGER.md for full results." -ForegroundColor Cyan
    Write-Host "You can specify custom topics via: task restore-batch `"Topic1,Topic2`"" -ForegroundColor Yellow
    return
}

$processed = 0
foreach ($top in $topicsToProcess) {
    $processed++
    Write-Host "`n>>> Processing [$processed/$($topicsToProcess.Count)]: '$top'..." -ForegroundColor White
    $params = @{
        Topic = $top
    }
    if ($StageTemplate) { $params["StageTemplate"] = $true }
    # Do not pass AutoBuild to intermediate iterations; run AutoBuild once at the very end if requested
    & powershell.exe -ExecutionPolicy Bypass -File $SingleRestoreScript @params
}

if ($AutoBuild) {
    Write-Host "`n>>> Batch completed. Running Single-Writer Build Gate (task build-packages)..." -ForegroundColor Yellow
    $buildScript = Join-Path $ScriptDir "Build-ReadyPackages.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $buildScript
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Batch Core Restoration Completed ($processed topics evaluated)" -ForegroundColor Green
Write-Host "  Progress documented in docs/CORE_RESTORATION_LEDGER.md" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
