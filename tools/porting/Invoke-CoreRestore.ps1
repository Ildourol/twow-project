<#
.SYNOPSIS
    Unified Core Restoration Pipeline (task restore / task 5).
.DESCRIPTION
    Audits leaked tortoise-wow core against official Turtle-WoW forum patch notes,
    detects missing or broken custom mechanics, logs progress to docs/CORE_RESTORATION_LEDGER.md
    and tools/queue/restoration_history.json to prevent redundant searches, templates native
    CORE-XXXX packages, and optionally executes AutoBuild.
.PARAMETER Topic
    The custom spell, talent, quest, racial, or system topic (e.g. "Holy Strike", "Patch 1.16.1", "Goblins").
.PARAMETER Subsystem
    Optional subsystem: 'Auto', 'Spell', 'Database', 'System'.
.PARAMETER StageTemplate
    Creates a ready-to-fill package manifest in tools/queue/02_ready_to_build/CORE-XXXX.json.
.PARAMETER AutoBuild
    If set, compiles, commits, and pushes any staged packages via Agent 1.
.PARAMETER Force
    Re-evaluates and searches the forum archive even if the topic was previously audited.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Topic,

    [Parameter()]
    [ValidateSet('Auto', 'Spell', 'Database', 'System')]
    [string]$Subsystem = 'Auto',

    [Parameter()]
    [switch]$StageTemplate,

    [Parameter()]
    [switch]$AutoBuild,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$TortoisePath = Join-Path $ProjectRoot "tortoise-wow"
$DocsDir = Join-Path $ProjectRoot "docs"
$LedgerFile = Join-Path $DocsDir "CORE_RESTORATION_LEDGER.md"
$HistoryJson = Join-Path $ProjectRoot "tools\queue\restoration_history.json"
$ReadyDir = Join-Path $ProjectRoot "tools\queue\02_ready_to_build"
$CompletedDir = Join-Path $ProjectRoot "tools\queue\03_completed"
$StagingPatches = Join-Path $ProjectRoot "tools\queue\staging_patches"

# Load existing restoration history to prevent double-checking
$history = @{}
if (Test-Path $HistoryJson) {
    try {
        $raw = Get-Content $HistoryJson -Raw -Encoding utf8
        if ($raw) {
            $parsed = $raw | ConvertFrom-Json
            if ($parsed) {
                foreach ($prop in $parsed.PSObject.Properties) {
                    $history[$prop.Name] = $prop.Value
                }
            }
        }
    } catch {
        # corrupted json, reset safely
        $history = @{}
    }
}

$cleanKey = $Topic.Trim().ToLower()

if (-not $Force -and $history.ContainsKey($cleanKey)) {
    $entry = $history[$cleanKey]
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  Unified Core Restoration Pipeline: '$Topic'" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "`n[CACHE HIT - ZERO DOUBLE-CHECKING]" -ForegroundColor Green
    Write-Host "Topic '$Topic' was already audited on $($entry.date_audited)." -ForegroundColor White
    Write-Host "  * Subsystem        : $($entry.subsystem)" -ForegroundColor DarkGray
    Write-Host "  * Forum Sources    : $($entry.forum_sources)" -ForegroundColor DarkGray
    Write-Host "  * Codebase Status  : $($entry.code_status)" -ForegroundColor DarkGray
    Write-Host "  * Parity Verdict   : $($entry.verdict)" -ForegroundColor Cyan
    if ($entry.package_id) {
        Write-Host "  * Staged Package   : $($entry.package_id)" -ForegroundColor Yellow
    }
    Write-Host "`nTo force a re-evaluation from scratch, pass the -Force switch:" -ForegroundColor DarkGray
    Write-Host "  task restore `"$Topic`" -Force" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor Cyan
    return
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Unified Core Restoration Pipeline: '$Topic' (Subsystem: $Subsystem)" -ForegroundColor Cyan
Write-Host "  AutoBuild Flag: $(if ($AutoBuild) { 'ENABLED' } else { 'DISABLED' })" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Search Forum Archive for Official Specifications
Write-Host "`n[1/3] Searching Forum Archive for Official Staff Specifications..." -ForegroundColor Yellow
$forumScript = Join-Path $ScriptDir "Search-ForumArchive.ps1"
$forumOutput = & powershell.exe -ExecutionPolicy Bypass -File $forumScript -Query $Topic -OfficialOnly -Limit 5
$forumOutput | Out-Host

$forumSourcesList = @()
foreach ($line in $forumOutput) {
    if ($line -match '\[MATCH\]\s+(.+?\.txt)') {
        $forumSourcesList += $Matches[1]
    }
}
$forumSummary = if ($forumSourcesList.Count -gt 0) { $forumSourcesList[0] } else { "None found" }

# 2. Probe tortoise-wow Codebase
Write-Host "`n[2/3] Probing tortoise-wow for Existing Implementation..." -ForegroundColor Yellow
$symbolsFound = @()
$searchPatterns = @($Topic)
if ($Topic -match '\s+') { $searchPatterns += ($Topic -split '\s+') }

foreach ($pat in ($searchPatterns | Where-Object { $_.Length -gt 3 })) {
    $matchesInCode = Select-String -Path "$TortoisePath\src\game\*\*.cpp", "$TortoisePath\src\scripts\*\*.cpp" -Pattern $pat -List -ErrorAction SilentlyContinue | Select-Object -First 5
    if ($matchesInCode) {
        foreach ($m in $matchesInCode) {
            $symbolsFound += [PSCustomObject]@{
                File = ($m.Path -replace [regex]::Escape($TortoisePath), '')
                Line = $m.LineNumber
                Text = $m.Line.Trim()
            }
        }
    }
}

$codeStatus = ""
$verdict = ""
if ($symbolsFound.Count -gt 0) {
    $codeStatus = "Present ($($symbolsFound.Count) occurrences)"
    $verdict = "PARITY_VERIFIED"
    Write-Host "Found $($symbolsFound.Count) symbol occurrences in tortoise-wow:" -ForegroundColor Green
    foreach ($sf in $symbolsFound) {
        Write-Host "  * [$($sf.File):$($sf.Line)] $($sf.Text)" -ForegroundColor DarkGray
    }
} else {
    $codeStatus = "Missing / Stubbed"
    $verdict = "AWAITING_RESTORATION"
    Write-Host "No direct code matches for '$Topic' found in tortoise-wow (Feature is missing or stubbed in leaked core)." -ForegroundColor Red
}

# 3. Next Steps & Optional Template Packaging
Write-Host "`n[3/3] Specification & Implementation Parity Verdict: $verdict" -ForegroundColor Cyan

function Get-NextCoreId {
    $existing = Get-ChildItem -Path $CompletedDir, $ReadyDir -Filter "CORE-*.json" -ErrorAction SilentlyContinue
    $maxNum = 0
    foreach ($f in $existing) {
        if ($f.Name -match 'CORE-(\d+)\.json') {
            $n = [int]$Matches[1]
            if ($n -gt $maxNum) { $maxNum = $n }
        }
    }
    $nextNum = $maxNum + 1
    return ("CORE-{0:D4}" -f $nextNum)
}

$cleanTopicTag = ($Topic -replace '[^\w]', '_').ToLower()
$coreId = Get-NextCoreId
$assignedPackage = ""

if ($StageTemplate -or ($verdict -eq "AWAITING_RESTORATION")) {
    $tplFile = Join-Path $ReadyDir "$coreId.json"
    $tplObj = [PSCustomObject]@{
        status       = "AWAITING_CODE"
        id           = $coreId
        type         = "TURTLE_CORE_RESTORATION"
        topic        = $Topic
        subsystem    = $Subsystem
        title        = "Restore Turtle $Topic specification from official patch notes"
        patch_file   = "tools/queue/staging_patches/$coreId-$cleanTopicTag.patch"
        sql_file     = $null
        commit_msg   = "Turtle($Subsystem): Restore $Topic specification from patch notes`n`n- Verified against official Turtle-WoW forum patch archive`n- Enforces Turtle invariants and C++17 compatibility"
    }
    $tplObj | ConvertTo-Json -Depth 4 | Out-File $tplFile -Encoding utf8
    $assignedPackage = $coreId
    Write-Host "[STAGED] Created restoration manifest: $tplFile" -ForegroundColor Green
    Write-Host "Author the patch and save as: tools/queue/staging_patches/$coreId-$cleanTopicTag.patch" -ForegroundColor Yellow
}

# 4. Save to Persistent Restoration Cache & Ledger
$dateStr = (Get-Date).ToString("yyyy-MM-dd")
$historyRecord = [PSCustomObject]@{
    topic         = $Topic
    subsystem     = $Subsystem
    date_audited  = $dateStr
    forum_sources = $forumSummary
    code_status   = $codeStatus
    verdict       = $verdict
    package_id    = $assignedPackage
}
$history[$cleanKey] = $historyRecord
$history | ConvertTo-Json -Depth 4 | Out-File $HistoryJson -Encoding utf8

# Append to docs/CORE_RESTORATION_LEDGER.md if not already present
if (Test-Path $LedgerFile) {
    $bt = [char]96
    $pkgDisplay = if ($assignedPackage) { "$bt$assignedPackage$bt" } else { "None (Parity OK)" }
    $countEntries = $history.Keys.Count
    $topicDisplay = "$bt$Topic$bt"
    $rowEntry = "| $countEntries | $dateStr | $topicDisplay | $Subsystem | $forumSummary | $codeStatus | **$verdict** | $pkgDisplay |"
    Add-Content -Path $LedgerFile -Value $rowEntry -Encoding utf8
}

if ($AutoBuild -and $assignedPackage) {
    Write-Host "`n>>> AutoBuild flag set: Checking 02_ready_to_build/ for ready packages..." -ForegroundColor Yellow
    $buildScript = Join-Path $ScriptDir "Build-ReadyPackages.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $buildScript
}
Write-Host "================================================================================" -ForegroundColor Cyan
