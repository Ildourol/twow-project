<#
.SYNOPSIS
    Queries the Tortoise-WoW Online Database Viewer & REST API (task 6 / task db-viewer / task dashboard).
.DESCRIPTION
    Provides instant online database verification against https://xian55.github.io/tortoise-db-viewer/
    and live REST API (https://api.tortoiseclothing.org). Cross-references local SQL definitions with
    the online 1.18.1 client/server database, displays rich entity stats, drop tables, abilities,
    and supports opening the interactive web dashboard in the browser.
.PARAMETER Query
    The item name, spell name, creature name, quest name, or numeric ID to inspect.
.PARAMETER Type
    Optional entity type: 'Auto', 'Item', 'NPC', 'Spell', 'Quest', 'Object'.
.PARAMETER Changelog
    Fetches and displays live database deltas and spawn changes from the online CDN.
.PARAMETER OpenBrowser
    Automatically launches default browser directly to the online DB viewer page.
.EXAMPLE
    task 6 19019
    task 6 "Holy Strike" -Type Spell
    task 6 changelog
    task 6 19019 -OpenBrowser
    task dashboard
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query = "",

    [Parameter()]
    [ValidateSet('Auto', 'Item', 'NPC', 'Spell', 'Quest', 'Object')]
    [string]$Type = 'Auto',

    [Parameter()]
    [switch]$Changelog,

    [Parameter()]
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$BaseSqlDir = Join-Path $ProjectRoot "tortoise-wow\sql\base"
$LocalViewerDir = Join-Path $ProjectRoot "tortoise-db-viewer"

$BaseUrl = "https://xian55.github.io/tortoise-db-viewer/"
$ApiBase = "https://api.tortoiseclothing.org"
$CdnChangelogUrl = "https://raw.githubusercontent.com/xian55/tortoise-db-viewer/cdn-dev/data/changelog.json"
$CdnVersionUrl = "https://raw.githubusercontent.com/xian55/tortoise-db-viewer/cdn-dev/data/version.json"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Agent 6: Tortoise Database Oracle & Dashboard Explorer                        " -ForegroundColor Cyan
Write-Host "  Web Dashboard: $BaseUrl" -ForegroundColor DarkCyan
Write-Host "  Local Clone  : $LocalViewerDir" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# Mode 1: Fetch and display live changelog
if ($Changelog -or ($Query -eq "changelog")) {
    Write-Host "`n[FETCHING] Live Database Changelog from Online CDN (cdn-dev)..." -ForegroundColor Yellow
    try {
        $version = Invoke-RestMethod -Uri $CdnVersionUrl -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($version) {
            Write-Host "Online DB Version: $($version.version) (Built: $($version.builtAt))" -ForegroundColor Green
        }
        
        $changes = Invoke-RestMethod -Uri $CdnChangelogUrl -TimeoutSec 10
        if ($changes) {
            $latest = $changes[0]
            Write-Host "`nLive Database Changelog Summary:" -ForegroundColor White
            if ($latest.counts) {
                Write-Host "  * Spawns Delta : $($latest.counts.spawns)" -ForegroundColor Cyan
                Write-Host "  * Added Items  : $($latest.counts.added.items)" -ForegroundColor Cyan
                Write-Host "  * Added Spells : $($latest.counts.added.spells)" -ForegroundColor Cyan
                Write-Host "  * Added NPCs   : $($latest.counts.added.npcs)" -ForegroundColor Cyan
            }
            if ($latest.spawns) {
                Write-Host "`nSample Spawn / Gameobject Modifications in Online DB:" -ForegroundColor DarkGray
                $latest.spawns | Select-Object -First 8 | ForEach-Object {
                    Write-Host "  - [Map $($_.map)] $($_.name) (ID: $($_.id), Delta: $($_.delta))" -ForegroundColor DarkGray
                }
            }
        }
        Write-Host "`nOnline Changelog View: ${BaseUrl}?changelog" -ForegroundColor Cyan
        if ($OpenBrowser) {
            Start-Process "${BaseUrl}?changelog"
        }
    } catch {
        Write-Host "Failed to fetch online changelog: $($_.Exception.Message)" -ForegroundColor Red
    }
    return
}

# Mode 2: Empty query - open dashboard or show help
if ([string]::IsNullOrWhiteSpace($Query)) {
    if ($OpenBrowser) {
        Write-Host "`nLaunching default browser to Tortoise Database Dashboard: $BaseUrl" -ForegroundColor Cyan
        Start-Process $BaseUrl
        return
    }
    Write-Host "Usage: task 6 <id_or_name> [-Type Item|NPC|Spell|Quest|Object] [-OpenBrowser]" -ForegroundColor Yellow
    Write-Host "       task 6 changelog" -ForegroundColor Yellow
    Write-Host "       task dashboard       -> Launches interactive web dashboard" -ForegroundColor Yellow
    Write-Host "`nDirect Web Access: $BaseUrl" -ForegroundColor Cyan
    return
}

# Mode 3: Query entity by ID or name
$isNumeric = ($Query -match '^\d+$')
$targetUrl = ""
$apiEndpoint = ""

if ($isNumeric) {
    $numericId = [int]$Query
    switch ($Type.ToLower()) {
        'item'   { $targetUrl = "${BaseUrl}?item=$numericId";   $apiEndpoint = "$ApiBase/i/$numericId" }
        'npc'    { $targetUrl = "${BaseUrl}?npc=$numericId";    $apiEndpoint = "$ApiBase/n/$numericId" }
        'spell'  { $targetUrl = "${BaseUrl}?spell=$numericId";  $apiEndpoint = "$ApiBase/s/$numericId" }
        'quest'  { $targetUrl = "${BaseUrl}?quest=$numericId";  $apiEndpoint = "$ApiBase/q/$numericId" }
        'object' { $targetUrl = "${BaseUrl}?object=$numericId" }
        default  {
            # Try item first
            $targetUrl = "${BaseUrl}?item=$numericId"
            $apiEndpoint = "$ApiBase/i/$numericId"
        }
    }
} else {
    $encodedQuery = [System.Uri]::EscapeDataString($Query)
    $targetUrl = "${BaseUrl}?search=$encodedQuery"
}

Write-Host "`n[QUERY] Inspecting Entity: '$Query'" -ForegroundColor Yellow
Write-Host "  * Target URL : $targetUrl" -ForegroundColor Cyan

# Fetch JSON API if available
$apiRecord = $null
if ($apiEndpoint) {
    try {
        $apiRecord = Invoke-RestMethod -Uri $apiEndpoint -TimeoutSec 5 -ErrorAction SilentlyContinue
    } catch { }

    # If item returned 404, test NPC
    if (-not $apiRecord -and $isNumeric -and $Type -eq "Auto") {
        try {
            $apiRecord = Invoke-RestMethod -Uri "$ApiBase/n/$numericId" -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($apiRecord) {
                $targetUrl = "${BaseUrl}?npc=$numericId"
            }
        } catch { }
    }
    # If still not found, test spell
    if (-not $apiRecord -and $isNumeric -and $Type -eq "Auto") {
        try {
            $apiRecord = Invoke-RestMethod -Uri "$ApiBase/s/$numericId" -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($apiRecord) {
                $targetUrl = "${BaseUrl}?spell=$numericId"
            }
        } catch { }
    }
    # If still not found, test quest
    if (-not $apiRecord -and $isNumeric -and $Type -eq "Auto") {
        try {
            $apiRecord = Invoke-RestMethod -Uri "$ApiBase/q/$numericId" -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($apiRecord) {
                $targetUrl = "${BaseUrl}?quest=$numericId"
            }
        } catch { }
    }
}

if ($apiRecord) {
    Write-Host "`n[DATABASE VIEWER ENTITY RECORD]" -ForegroundColor Green
    if ($apiRecord.type -eq "item") {
        Write-Host "  Name         : $($apiRecord.name) [$($apiRecord.id)] ($($apiRecord.quality.name))" -ForegroundColor White
        Write-Host "  Type / Slot  : $($apiRecord.class.name) - $($apiRecord.subclass.name) ($($apiRecord.slot.name))" -ForegroundColor Gray
        Write-Host "  Item Level   : $($apiRecord.itemLevel) (Req Level: $($apiRecord.requiredLevel))" -ForegroundColor Gray
        if ($apiRecord.stats) {
            $stList = @()
            foreach ($p in $apiRecord.stats.PSObject.Properties) { $stList += "$($p.Name): $($p.Value)" }
            Write-Host "  Combat Stats : $($stList -join ', ')" -ForegroundColor Yellow
        }
        if ($apiRecord.price) {
            Write-Host "  Economy      : Buy: $($apiRecord.price.buy)c | Sell: $($apiRecord.price.sell)c" -ForegroundColor DarkGray
        }
        if ($apiRecord.sources.quests -and $apiRecord.sources.quests.Count -gt 0) {
            $q = $apiRecord.sources.quests[0]
            Write-Host "  Quest Reward : [$($q.quest.id)] $($q.quest.title)" -ForegroundColor Cyan
        }
    } elseif ($apiRecord.type -eq "npc") {
        Write-Host "  Name         : $($apiRecord.name) [$($apiRecord.id)] (Level $($apiRecord.level) $($apiRecord.rank))" -ForegroundColor White
        Write-Host "  Health       : $($apiRecord.health.min) - Armor: $($apiRecord.stats.armor)" -ForegroundColor Gray
        Write-Host "  Melee Damage : $($apiRecord.stats.damage.min) - $($apiRecord.stats.damage.max) (Speed: $($apiRecord.stats.attackSpeed)ms)" -ForegroundColor Yellow
        if ($apiRecord.drops -and $apiRecord.drops.Count -gt 0) {
            Write-Host "  Top Drops    :" -ForegroundColor Cyan
            foreach ($d in ($apiRecord.drops | Select-Object -First 4)) {
                $chanceFmt = "{0:N1}%" -f $d.chance
                Write-Host "    - [$($d.item.id)] $($d.item.name) ($chanceFmt chance)" -ForegroundColor DarkGray
            }
        }
    } elseif ($apiRecord.type -eq "spell") {
        Write-Host "  Spell Name   : $($apiRecord.name) [$($apiRecord.id)]" -ForegroundColor White
        Write-Host "  Attributes   : Skill: $($apiRecord.skill), Icon: $($apiRecord.icon)" -ForegroundColor Gray
        if ($apiRecord.description) {
            Write-Host "  Description  : $($apiRecord.description)" -ForegroundColor Yellow
        }
    } elseif ($apiRecord.type -eq "quest") {
        Write-Host "  Quest Title  : $($apiRecord.title) [$($apiRecord.id)]" -ForegroundColor White
        Write-Host "  Level        : Level $($apiRecord.level) (Min: $($apiRecord.minLevel)) - Zone: $($apiRecord.zone)" -ForegroundColor Gray
        Write-Host "  Rewards      : XP: $($apiRecord.rewards.xp), Money: $($apiRecord.rewards.money)c" -ForegroundColor Yellow
    }
}

# Cross-reference local SQL database in tortoise-wow/sql/base
Write-Host "`n[LOCAL BASE CROSS-REFERENCE] Searching local tortoise-wow SQL..." -ForegroundColor Yellow
$localMatches = @()
if (Test-Path $BaseSqlDir) {
    if ($isNumeric) {
        $pattern = "entry\s*=\s*$Query\b|\b$Query\b"
    } else {
        $pattern = [regex]::Escape($Query)
    }
    
    $searchFiles = Get-ChildItem -Path $BaseSqlDir -Filter "*.sql" -ErrorAction SilentlyContinue | Select-Object -First 10
    foreach ($f in $searchFiles) {
        $matches = Select-String -Path $f.FullName -Pattern $pattern -List -ErrorAction SilentlyContinue | Select-Object -First 3
        if ($matches) {
            foreach ($m in $matches) {
                $localMatches += [PSCustomObject]@{
                    File = $f.Name
                    Line = $m.LineNumber
                    Snippet = ($m.Line.Trim() -replace '\s+', ' ')
                }
            }
        }
    }
}

if ($localMatches.Count -gt 0) {
    Write-Host "Found local SQL matches in tortoise-wow:" -ForegroundColor Green
    foreach ($lm in $localMatches) {
        $display = if ($lm.Snippet.Length -gt 90) { $lm.Snippet.Substring(0, 90) + "..." } else { $lm.Snippet }
        Write-Host "  * [$($lm.File):$($lm.Line)] $display" -ForegroundColor DarkGray
    }
} else {
    Write-Host "No direct local base SQL match found (Entity may be defined in client DBC, migrations, or custom ID space >= 300000)." -ForegroundColor DarkGray
}

Write-Host "`n[CAPABILITIES & ACTIONS]" -ForegroundColor Green
Write-Host "  1. 3D Model, Drops & Interactive Tooltip : $targetUrl" -ForegroundColor White
Write-Host "  2. Entity Scalper & Diff Engine          : task scalp $Query -Diff" -ForegroundColor Gray
Write-Host "  3. Staged SQL Migration Export           : task scalp $Query -Export" -ForegroundColor Gray

if ($OpenBrowser) {
    Write-Host "`nLaunching browser to: $targetUrl" -ForegroundColor Cyan
    Start-Process $targetUrl
} else {
    Write-Host "`nTip: Run with -OpenBrowser to view the 3D model, tooltip, and relations interactively!" -ForegroundColor DarkGray
}
Write-Host "================================================================================" -ForegroundColor Cyan
