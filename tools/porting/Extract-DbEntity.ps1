<#
.SYNOPSIS
    High-performance Database Entity Scalper, Diff Engine, and Dashboard Explorer for Turtle-WoW 1.18.1.
.DESCRIPTION
    Extracts, tokenizes, and compares entity rows across:
      1. Local Turtle-WoW base SQL (tortoise-wow/sql/base/tw_world_<table_name>.sql)
      2. Tortoise Database Viewer Dashboard & REST API (xian55/tortoise-db-viewer)
      3. Tortoise-DB-Viewer Vanilla Catalog (tortoise-db-viewer/scripts/data/vanilla-ids.json)
      4. Upstream Donor Reference (reference-upstreams/vmangos-core/db_latest/mysql-dump/mangos.sql)
    
    Key capabilities:
      - Field-by-field side-by-side comparison between host and donor/baseline.
      - Automatic progressive column stripping (patch, patch_min, patch_max, build).
      - Detection of custom Turtle-WoW columns (mount_display_id, sTWDebuff, etc.).
      - Instant generation of sanitized SQL migration patches into tools/queue/staging_sql/.
      - Direct entity lookup by ID or by search name with auto-table detection.
      - Instant launch of interactive 3D model, tooltip, and relations dashboard in browser.
.PARAMETER Table
    Table name or alias: item, creature, spell, quest, gameobject, loot, vendor, trainer, etc.
.PARAMETER Query
    Entity ID (entry number) or search string name (e.g. 19019, "Thunderfury", "Onyxia").
.PARAMETER Diff
    Show a detailed side-by-side field diff in the console.
.PARAMETER Export
    Auto-generate a clean, progressive-stripped SQL update in tools/queue/staging_sql/.
.PARAMETER OpenViewer
    Open the entity in the tortoise-db-viewer interactive dashboard in the default browser.
.PARAMETER Dashboard
    Alias for -OpenViewer.
.EXAMPLE
    task scalp item 19019 -Diff
    task scalp 19019 -Diff
    task scalp "Thunderfury" -Diff -Export
    task scalp creature "Onyxia" -Diff -OpenViewer
    task scalp changelog
#>
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Table = "",

    [Parameter(Position=1)]
    [string]$Query = "",

    [switch]$Diff,
    [switch]$Export,
    [switch]$OpenViewer,
    [switch]$Dashboard,
    [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
    [string]$ViewerRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-db-viewer",
    [string]$HistoricalDb = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\lights-hope-database-history\world_full_14_june_2021.sql",
    [string]$DonorDb = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core\db_latest\mysql-dump\mangos.sql",
    [string]$OutputDir = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\queue\staging_sql",
    [int]$PatchVersion = 10
)

$ErrorActionPreference = "Stop"
$bt = [char]96
if ($Dashboard) { $OpenViewer = $true }

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "    Tortoise-WoW Database Scalper & Dashboard Explorer Engine                  " -ForegroundColor Cyan
Write-Host "    Powered by tortoise-db-viewer (https://github.com/Xian55/tortoise-db-viewer)" -ForegroundColor DarkCyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 0. Handle Special Commands (e.g. changelog)
if ($Table.ToLower() -eq "changelog" -or $Query.ToLower() -eq "changelog") {
    $cdnChangelogUrl = "https://raw.githubusercontent.com/xian55/tortoise-db-viewer/cdn-dev/data/changelog.json"
    $cdnVersionUrl = "https://raw.githubusercontent.com/xian55/tortoise-db-viewer/cdn-dev/data/version.json"
    Write-Host "`n[FETCHING] Live Database Changelog from Online CDN (cdn-dev)..." -ForegroundColor Yellow
    try {
        $v = Invoke-RestMethod -Uri $cdnVersionUrl -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($v) { Write-Host "DB Viewer Version: $($v.version) (Built: $($v.builtAt))`n" -ForegroundColor Green }
        $changes = Invoke-RestMethod -Uri $cdnChangelogUrl -TimeoutSec 10
        if ($changes) {
            $latest = $changes[0]
            if ($latest.counts) {
                Write-Host "Live Changelog Counts:" -ForegroundColor White
                Write-Host "  * Spawns Delta : $($latest.counts.spawns)" -ForegroundColor Cyan
                Write-Host "  * Added Items  : $($latest.counts.added.items)" -ForegroundColor Cyan
                Write-Host "  * Added Spells : $($latest.counts.added.spells)" -ForegroundColor Cyan
                Write-Host "  * Added NPCs   : $($latest.counts.added.npcs)" -ForegroundColor Cyan
            }
            if ($latest.spawns) {
                Write-Host "`nRecent Spawn / Object Changes in Online DB:" -ForegroundColor DarkGray
                $latest.spawns | Select-Object -First 6 | ForEach-Object {
                    Write-Host "  - [Map $($_.map)] $($_.name) (ID: $($_.id), Delta: $($_.delta))" -ForegroundColor DarkGray
                }
            }
        }
        $url = "https://xian55.github.io/tortoise-db-viewer/?changelog"
        Write-Host "`nOnline Changelog View: $url" -ForegroundColor Cyan
        if ($OpenViewer) { Start-Process $url }
    } catch {
        Write-Host "Failed to fetch online changelog: $($_.Exception.Message)" -ForegroundColor Red
    }
    return
}

# 1. Argument Normalization & Auto-Table Detection
$tableAliases = @("item", "items", "creature", "mob", "npc", "spell", "spells", "quest", "quests",
                  "gameobject", "go", "objects", "loot", "creature_loot", "item_loot", "go_loot",
                  "skinning", "fishing", "pickpocket", "vendor", "trainer")

$actualTable = $Table.ToLower().Trim()
$actualQuery = $Query.Trim()

if (-not $actualTable -and -not $actualQuery) {
    Write-Host "Usage: task scalp [table] <id_or_name> [-Diff] [-Export] [-OpenViewer]" -ForegroundColor Yellow
    Write-Host "       task scalp item 19019 -Diff" -ForegroundColor Yellow
    Write-Host "       task scalp 19019 -Diff" -ForegroundColor Yellow
    Write-Host "       task scalp `"Thunderfury`" -Diff" -ForegroundColor Yellow
    Write-Host "       task scalp changelog" -ForegroundColor Yellow
    return
}

if ($actualTable -and -not $actualQuery) {
    if ($tableAliases -contains $actualTable -or $actualTable -like "*_template" -or $actualTable -like "tw_world_*") {
        Write-Host "Error: Table '$actualTable' specified but no entry ID or search name provided." -ForegroundColor Red
        Write-Host "Usage: task scalp $actualTable <id_or_name> [-Diff] [-Export]" -ForegroundColor Yellow
        return
    } else {
        $actualQuery = $actualTable
        $actualTable = "auto"
    }
} elseif (-not $actualTable -and $actualQuery) {
    $actualTable = "auto"
}

$resolvedTable = switch -Regex ($actualTable) {
    '^(item|items)$'                 { "item_template" }
    '^(creature|mob|npc)$'           { "creature_template" }
    '^(spell|spells)$'               { "spell_template" }
    '^(quest|quests)$'               { "quest_template" }
    '^(gameobject|go|objects)$'      { "gameobject_template" }
    '^(loot|creature_loot)$'         { "creature_loot_template" }
    '^(item_loot)$'                  { "item_loot_template" }
    '^(go_loot|gameobject_loot)$'    { "gameobject_loot_template" }
    '^(skinning|skinning_loot)$'     { "skinning_loot_template" }
    '^(fishing|fishing_loot)$'       { "fishing_loot_template" }
    '^(pickpocket|pickpocketing)$'   { "pickpocketing_loot_template" }
    '^(vendor|npc_vendor)$'          { "npc_vendor_template" }
    '^(trainer|npc_trainer)$'        { "npc_trainer_template" }
    '^(auto)$'                       { "auto" }
    default                          { $actualTable -replace '^tw_world_', '' }
}

# 2. Tokenizer Helper
function Tokenize-SqlTuple([string]$rawTuple) {
    $trimmed = $rawTuple.Trim().TrimStart('(').TrimEnd('),; ' + "`r`n")
    $pattern = "\s*(?:'(?<str>(?:[^'\\]|\\.|'')*)'|(?<val>[^,]*))\s*(?:,|$)"
    $tokens = [System.Collections.Generic.List[string]]::new()
    
    $matches = [regex]::Matches($trimmed, $pattern)
    foreach ($m in $matches) {
        if ($m.Length -eq 0) { continue }
        if ($m.Groups['str'].Success) {
            $tokens.Add(($m.Groups['str'].Value -replace "\\'", "'" -replace "''", "'"))
        } else {
            $tokens.Add($m.Groups['val'].Value.Trim())
        }
    }
    return $tokens
}

# 3. Auto-Table Detection if table was not specified
$targetEntry = $null
$isNumeric = [int]::TryParse($actualQuery, [ref]$targetEntry)

if ($resolvedTable -eq "auto") {
    Write-Host "[1/5] Auto-detecting table for query '$actualQuery'..." -ForegroundColor Yellow
    $candidateTables = @("item_template", "creature_template", "spell_template", "quest_template", "gameobject_template")
    $detectedTable = $null

    if ($isNumeric) {
        foreach ($ct in $candidateTables) {
            $f = Join-Path $TortoiseRepo "sql\base\tw_world_$ct.sql"
            if (-not (Test-Path $f)) { $f = Join-Path $TortoiseRepo "sql\base\$ct.sql" }
            if (Test-Path $f) {
                $m = Select-String -Path $f -Pattern "\((?<!\d)$targetEntry,\s*" -List -ErrorAction SilentlyContinue
                if ($m) {
                    $detectedTable = $ct
                    break
                }
            }
        }
        if (-not $detectedTable) { $detectedTable = "item_template" }
    } else {
        foreach ($ct in $candidateTables) {
            $f = Join-Path $TortoiseRepo "sql\base\tw_world_$ct.sql"
            if (-not (Test-Path $f)) { $f = Join-Path $TortoiseRepo "sql\base\$ct.sql" }
            if (Test-Path $f) {
                $esc = [regex]::Escape($actualQuery)
                $m = Select-String -Path $f -Pattern "(?i)'[^']*?$esc[^']*?'" -List -ErrorAction SilentlyContinue
                if ($m) {
                    $detectedTable = $ct
                    break
                }
            }
        }
        if (-not $detectedTable) { $detectedTable = "item_template" }
    }
    $resolvedTable = $detectedTable
    Write-Host "      Auto-detected target table: " -NoNewline -ForegroundColor Gray
    Write-Host "$resolvedTable" -ForegroundColor Green
} else {
    Write-Host "[1/5] Target Table: " -NoNewline -ForegroundColor Gray
    Write-Host "$resolvedTable" -ForegroundColor Green
}

$turtleSqlFile = Join-Path $TortoiseRepo "sql\base\tw_world_$resolvedTable.sql"
if (-not (Test-Path $turtleSqlFile)) {
    $alt = Join-Path $TortoiseRepo "sql\base\$resolvedTable.sql"
    if (Test-Path $alt) { $turtleSqlFile = $alt }
}

if (Test-Path $turtleSqlFile) {
    Write-Host "      Base File   : " -NoNewline -ForegroundColor Gray
    Write-Host (Split-Path $turtleSqlFile -Leaf) -ForegroundColor DarkCyan
} else {
    Write-Host "      Base File   : Not found in sql/base/ (external or DBC entity)" -ForegroundColor Yellow
}

# 4. Catalog Schema Columns
$turtleCols = [System.Collections.Generic.List[string]]::new()
if (Test-Path $turtleSqlFile) {
    $headerLines = Get-Content $turtleSqlFile -TotalCount 250
    $inCreate = $false
    $targetPattern = 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(?:tw_world_)?' + $resolvedTable + '`?'
    foreach ($line in $headerLines) {
        if ($line -match $targetPattern) {
            $inCreate = $true
            continue
        }
        if ($inCreate) {
            if ($line -match '^\s*\)(\s*ENGINE|;)') { break }
            if ($line -match '^\s*`([a-zA-Z0-9_]+)`') {
                $turtleCols.Add(($matches[1] -replace '[^a-zA-Z0-9_]', '').ToLower())
            }
        }
    }
}
Write-Host "[2/5] Table Schema: " -NoNewline -ForegroundColor Gray
Write-Host "$($turtleCols.Count) columns cataloged" -ForegroundColor $(if ($turtleCols.Count -gt 0) { "DarkGreen" } else { "DarkGray" })

# 4B. Catalog Schema Columns from Historical Reference DB (Brotalnia Choice 1 / VMaNGOS Choice 2)
$refCols = [System.Collections.Generic.List[string]]::new()
$activeRefDb = $null
if (Test-Path $HistoricalDb) {
    $activeRefDb = $HistoricalDb
} elseif (Test-Path $DonorDb) {
    $activeRefDb = $DonorDb
}

if ($activeRefDb) {
    $patternInsert = 'INSERT INTO `' + $resolvedTable + '` \((.*?)\) VALUES'
    $refMatch = Select-String -Path $activeRefDb -Pattern $patternInsert | Select-Object -First 1
    if ($refMatch) {
        $rawCols = ($refMatch.Matches[0].Groups[1].Value -split ',')
        foreach ($rc in $rawCols) {
            $refCols.Add(($rc -replace '[^a-zA-Z0-9_]', '').ToLower())
        }
    } else {
        $patternCreate = 'CREATE TABLE IF NOT EXISTS `' + $resolvedTable + '` \('
        $refCreate = Select-String -Path $activeRefDb -Pattern $patternCreate | Select-Object -First 1
        if ($refCreate) {
            $refLineNum = $refCreate.LineNumber
            $refCreateLines = Get-Content -Path $activeRefDb | Select-Object -Skip ($refLineNum - 1) -First 120
            $inRefCreate = $true
            foreach ($line in $refCreateLines) {
                if ($line -match '^\s*\)(\s*ENGINE|;)') { break }
                if ($line -match '^\s*`([a-zA-Z0-9_]+)`') {
                    $refCols.Add(($matches[1] -replace '[^a-zA-Z0-9_]', '').ToLower())
                }
            }
        }
    }
}
if ($refCols.Count -gt 0) {
    Write-Host "      Historic DB : $($refCols.Count) columns cataloged ($(Split-Path $activeRefDb -Leaf))" -ForegroundColor DarkGreen
}

# 5. Resolve Entity Entry ID and Name
$entityName = ""
if (-not $isNumeric) {
    Write-Host "[3/5] Query is text search: '$actualQuery'. Searching local base SQL..." -ForegroundColor Yellow
    $foundEntries = [System.Collections.Generic.List[PSObject]]::new()

    if (Test-Path $turtleSqlFile) {
        $content = Get-Content $turtleSqlFile -Raw
        $escapedQuery = [regex]::Escape($actualQuery)
        $namePattern = "(?i)\((\d+),[^)]*?'([^']*?$escapedQuery[^']*?)'"
        $matches = [regex]::Matches($content, $namePattern)
        foreach ($m in $matches) {
            $eId = [int]$m.Groups[1].Value
            $eName = $m.Groups[2].Value
            if (-not ($foundEntries | Where-Object { $_.Entry -eq $eId })) {
                $foundEntries.Add([pscustomobject]@{ Entry = $eId; Name = $eName })
            }
        }
    }

    if ($foundEntries.Count -eq 0) {
        Write-Host "      No local entities matching '$actualQuery' found in $resolvedTable." -ForegroundColor Yellow
        $targetEntry = 0
        $entityName = $actualQuery
    } elseif ($foundEntries.Count -eq 1) {
        $targetEntry = $foundEntries[0].Entry
        $entityName = $foundEntries[0].Name
        Write-Host "      Exact match found: " -NoNewline -ForegroundColor Gray
        Write-Host "[$targetEntry] $entityName" -ForegroundColor Green
    } else {
        Write-Host "      Multiple matches found ($($foundEntries.Count) entities):" -ForegroundColor Yellow
        foreach ($fe in ($foundEntries | Select-Object -First 8)) {
            Write-Host "        - [$($fe.Entry)] $($fe.Name)" -ForegroundColor Cyan
        }
        if ($foundEntries.Count -gt 8) {
            Write-Host "        ... and $($foundEntries.Count - 8) more." -ForegroundColor Gray
        }
        $targetEntry = $foundEntries[0].Entry
        $entityName = $foundEntries[0].Name
        Write-Host "      Proceeding with primary match: " -NoNewline -ForegroundColor Gray
        Write-Host "[$targetEntry] $entityName" -ForegroundColor Green
    }
} else {
    Write-Host "[3/5] Target Entry ID: " -NoNewline -ForegroundColor Gray
    Write-Host "$targetEntry" -ForegroundColor Green
}

# Turtle Invariant Check
if ($targetEntry -ge 300000) {
    Write-Host "      [!] INVARIANT ALERT: Entry $targetEntry >= 300000 is reserved for Turtle-WoW custom content!" -ForegroundColor Yellow
} elseif ($resolvedTable -like "*spell*" -and $targetEntry -ge 40000) {
    Write-Host "      [!] INVARIANT ALERT: Spell $targetEntry >= 40000 is reserved for Turtle-WoW custom spells!" -ForegroundColor Yellow
}

# 6. Extract Entity from Local Base SQL
Write-Host "[4/5] Scalping entity across datasets..." -ForegroundColor Gray

$turtleRows = @()
if (Test-Path $turtleSqlFile) {
    $tContent = Get-Content $turtleSqlFile -Raw
    $tMatches = [regex]::Matches($tContent, "\((?<!\d)$targetEntry,\s*(.*?)\)(?=\s*[,;]|\s*$)")
    foreach ($tm in $tMatches) {
        $turtleRows += $tm.Value
    }
}
Write-Host "      Turtle Base : $($turtleRows.Count) row(s) found" -ForegroundColor $(if ($turtleRows.Count -gt 0) { "Green" } else { "DarkGray" })

$tTokens = if ($turtleRows.Count -gt 0) { Tokenize-SqlTuple $turtleRows[0] } else { @() }
$turtleDict = [ordered]@{}
for ($i = 0; $i -lt $turtleCols.Count; $i++) {
    $val = if ($i -lt $tTokens.Count) { $tTokens[$i] } else { "N/A" }
    $turtleDict[$turtleCols[$i]] = $val
}

if (-not $entityName -and $turtleDict.Contains("name")) {
    $entityName = $turtleDict["name"]
}

# 6B. Extract Entity from Historical Reference DB (Brotalnia Choice 1 / VMaNGOS Choice 2)
$refRows = @()
$refDbName = ""
if ($activeRefDb) {
    $refDbName = Split-Path $activeRefDb -Leaf
    $patternRef = "^\s*\($targetEntry,"
    $refLineMatches = Select-String -Path $activeRefDb -Pattern $patternRef
    foreach ($rlm in $refLineMatches) {
        $refRows += $rlm.Line.Trim().TrimEnd(',;')
    }
    # If not found in Brotalnia, try DonorDb as backup
    if ($refRows.Count -eq 0 -and $activeRefDb -ne $DonorDb -and (Test-Path $DonorDb)) {
        $refLineMatchesDonor = Select-String -Path $DonorDb -Pattern $patternRef
        foreach ($rlm in $refLineMatchesDonor) {
            $refRows += $rlm.Line.Trim().TrimEnd(',;')
        }
        if ($refRows.Count -gt 0) {
            $refDbName = Split-Path $DonorDb -Leaf
        }
    }
}
Write-Host "      Historic DB : $($refRows.Count) row(s) found $(if ($refDbName) { "($refDbName)" })" -ForegroundColor $(if ($refRows.Count -gt 0) { "Green" } else { "DarkGray" })

$isSingleTemplate = $resolvedTable -like "*_template" -and $resolvedTable -notlike "*loot*"
$rTokens = @()
if ($refRows.Count -gt 0) {
    $validRefRows = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
    foreach ($rr in $refRows) {
        $toks = Tokenize-SqlTuple $rr
        if ($refCols.Count -gt 0) {
            if ($toks.Count -ge ($refCols.Count - 5)) {
                $validRefRows.Add($toks)
            }
        } else {
            $validRefRows.Add($toks)
        }
    }

    $hasPatchCol = $refCols.Contains("patch")
    if ($hasPatchCol -and $isSingleTemplate -and $validRefRows.Count -gt 0) {
        $patchIdx = $refCols.IndexOf("patch")
        $bestRow = $null
        $bestPatch = -1
        foreach ($candTokens in $validRefRows) {
            if ($patchIdx -lt $candTokens.Count) {
                $pVal = 0
                if ([int]::TryParse($candTokens[$patchIdx], [ref]$pVal)) {
                    if ($pVal -eq $PatchVersion) {
                        $bestRow = $candTokens
                        $bestPatch = $pVal
                        break
                    } elseif ($pVal -le $PatchVersion -and $pVal -gt $bestPatch) {
                        $bestRow = $candTokens
                        $bestPatch = $pVal
                    }
                }
            }
        }
        $rTokens = if ($bestRow) { $bestRow } else { $validRefRows[0] }
    } elseif ($validRefRows.Count -gt 0) {
        $rTokens = $validRefRows[0]
    }
}

$refDict = [ordered]@{}
for ($i = 0; $i -lt $refCols.Count; $i++) {
    $val = if ($i -lt $rTokens.Count) { $rTokens[$i] } else { "N/A" }
    $refDict[$refCols[$i]] = $val
}

if (-not $entityName -and $refDict.Contains("name") -and $refDict["name"] -ne "N/A") {
    $entityName = $refDict["name"]
}

# 7. Query Tortoise Database Viewer (REST API + Local Catalogs)
$apiPrefix = switch -Regex ($resolvedTable) {
    'item'        { "i" }
    'creature'    { "n" }
    'spell'       { "s" }
    'quest'       { "q" }
    default       { "" }
}

$viewerData = $null
$viewerUrl = ""
if ($apiPrefix -and $targetEntry -gt 0) {
    $apiUrl = "https://api.tortoiseclothing.org/$apiPrefix/$targetEntry"
    try {
        $viewerData = Invoke-RestMethod -Uri $apiUrl -TimeoutSec 5 -ErrorAction SilentlyContinue
        if ($viewerData) {
            Write-Host "      DB Viewer   : Official Turtle DB record retrieved" -ForegroundColor Green
            if (-not $entityName -and $viewerData.name) { $entityName = $viewerData.name }
            if (-not $entityName -and $viewerData.title) { $entityName = $viewerData.title }
            $viewerUrl = $viewerData.link
        }
    } catch {
        Write-Host "      DB Viewer   : API offline/skipped (falling back to local catalog)" -ForegroundColor DarkGray
    }
}

if (-not $viewerUrl) {
    $viewerParam = switch -Regex ($resolvedTable) {
        'item'        { "item" }
        'creature'    { "npc" }
        'spell'       { "spell" }
        'quest'       { "quest" }
        'gameobject'  { "object" }
        default       { "search" }
    }
    $viewerUrl = if ($targetEntry -gt 0) { "https://xian55.github.io/tortoise-db-viewer/?$viewerParam=$targetEntry" } else { "https://xian55.github.io/tortoise-db-viewer/?search=$([System.Uri]::EscapeDataString($actualQuery))" }
}

$vanillaCatalogPath = Join-Path $ViewerRepo "scripts\data\vanilla-ids.json"
$isVanilla = $false
$isEditedVanilla = $false

if (Test-Path $vanillaCatalogPath) {
    try {
        $vJson = [System.IO.File]::ReadAllText($vanillaCatalogPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($resolvedTable -like "*item*" -and $vJson.items) {
            $isVanilla = ($vJson.items -contains $targetEntry)
            if ($vJson.edited -and $vJson.edited.items) { $isEditedVanilla = ($vJson.edited.items -contains $targetEntry) }
        } elseif ($resolvedTable -like "*creature*" -and $vJson.creatures) {
            $isVanilla = ($vJson.creatures -contains $targetEntry)
            if ($vJson.edited -and $vJson.edited.creatures) { $isEditedVanilla = ($vJson.edited.creatures -contains $targetEntry) }
        } elseif ($resolvedTable -like "*quest*" -and $vJson.quests) {
            $isVanilla = ($vJson.quests -contains $targetEntry)
            if ($vJson.edited -and $vJson.edited.quests) { $isEditedVanilla = ($vJson.edited.quests -contains $targetEntry) }
        }
    } catch { }
}

# 8. Render Entity Card & Dashboard Summary
Write-Host ""
Write-Host ("=" * 80) -ForegroundColor Cyan
if (-not $entityName) { $entityName = "Entity $targetEntry" }

$provenanceBadge = if ($targetEntry -ge 300000 -or ($resolvedTable -like "*spell*" -and $targetEntry -ge 40000)) {
    "[TURTLE CUSTOM EXCLUSIVE]"
} elseif ($isEditedVanilla) {
    "[TURTLE MODIFIED VANILLA]"
} elseif ($isVanilla) {
    "[AUTHENTIC VANILLA 1.12]"
} else {
    "[EXPANDED RECORD]"
}

Write-Host "  ENTITY: " -NoNewline -ForegroundColor White
Write-Host "[$targetEntry] $entityName" -NoNewline -ForegroundColor Cyan
Write-Host " $provenanceBadge" -ForegroundColor $(if ($isEditedVanilla) { "Yellow" } elseif ($isVanilla) { "Green" } else { "Magenta" })
Write-Host ("=" * 80) -ForegroundColor Cyan

Write-Host "  * Online Dashboard   : " -NoNewline -ForegroundColor Gray
Write-Host "$viewerUrl" -ForegroundColor Cyan

if ($viewerData) {
    if ($viewerData.type -eq "item") {
        Write-Host "  * Item Classification: $($viewerData.quality.name) $($viewerData.subclass.name) ($($viewerData.slot.name))" -ForegroundColor White
        Write-Host "  * Item / Req Level   : iLvl $($viewerData.itemLevel), Req Level: $($viewerData.requiredLevel)" -ForegroundColor Gray
        if ($viewerData.stats) {
            $stList = @()
            foreach ($p in $viewerData.stats.PSObject.Properties) { $stList += "$($p.Name): $($p.Value)" }
            Write-Host "  * Stats & Combat     : $($stList -join ', ')" -ForegroundColor Yellow
        }
        if ($viewerData.price) {
            Write-Host "  * Economy (Buy/Sell) : Buy: $($viewerData.price.buy)c | Sell: $($viewerData.price.sell)c" -ForegroundColor DarkGray
        }
        if ($viewerData.sources.quests -and $viewerData.sources.quests.Count -gt 0) {
            $q = $viewerData.sources.quests[0]
            Write-Host "  * Quest Associated   : [$($q.quest.id)] $($q.quest.title) (Role: $($q.role))" -ForegroundColor Green
        }
    } elseif ($viewerData.type -eq "npc") {
        Write-Host "  * NPC Classification : Level $($viewerData.level) $($viewerData.rank) $($viewerData.creatureType)" -ForegroundColor White
        Write-Host "  * Health & Armor     : Health: $($viewerData.health.min), Armor: $($viewerData.stats.armor)" -ForegroundColor Gray
        Write-Host "  * Melee Damage       : $($viewerData.stats.damage.min) - $($viewerData.stats.damage.max) (Speed: $($viewerData.stats.attackSpeed)ms)" -ForegroundColor Yellow
        if ($viewerData.drops -and $viewerData.drops.Count -gt 0) {
            Write-Host "  * Notable Drops      :" -ForegroundColor Cyan
            foreach ($d in ($viewerData.drops | Select-Object -First 4)) {
                $chanceFmt = "{0:N1}%" -f $d.chance
                Write-Host "      - [$($d.item.id)] $($d.item.name) ($chanceFmt chance)" -ForegroundColor DarkGray
            }
        }
    } elseif ($viewerData.type -eq "spell") {
        Write-Host "  * Spell Attributes   : Skill: $($viewerData.skill), Icon: $($viewerData.icon)" -ForegroundColor White
        if ($viewerData.description) {
            Write-Host "  * Description        : $($viewerData.description)" -ForegroundColor Yellow
        }
    } elseif ($viewerData.type -eq "quest") {
        Write-Host "  * Quest Details      : Level $($viewerData.level) (Min: $($viewerData.minLevel)) - Zone: $($viewerData.zone)" -ForegroundColor White
        Write-Host "  * Rewards            : XP: $($viewerData.rewards.xp), Money: $($viewerData.rewards.money)c" -ForegroundColor Gray
    }
} elseif ($turtleDict.Count -gt 0) {
    Write-Host "  * Local SQL Base Data Cataloged ($($turtleDict.Count) fields)" -ForegroundColor DarkGray
}

# 9. Side-by-Side Field Diff Display
if ($Diff -or (-not $Export -and -not $OpenViewer)) {
    Write-Host "`n[5/5] Differential Schema & Value Inspection:" -ForegroundColor Cyan
    Write-Host ("-" * 88) -ForegroundColor DarkGray
    Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f "COLUMN", "TURTLE BASE (HOST)", "HISTORIC / DONOR (BASELINE)") -ForegroundColor Yellow
    Write-Host ("-" * 88) -ForegroundColor DarkGray

    $progressiveCols = @('patch', 'patch_min', 'patch_max', 'build', 'min_patch', 'max_patch')
    $diffCount = 0
    $matchCount = 0

    foreach ($col in $turtleCols) {
        $tVal = if ($turtleDict.Contains($col)) { $turtleDict[$col] } else { "<absent>" }
        
        $rVal = "<unmodified>"
        if ($refDict.Contains($col) -and $refDict[$col] -ne "N/A" -and $refDict[$col] -ne "<absent>") {
            $rVal = $refDict[$col]
        } elseif ($col -eq "name" -and $viewerData.name) {
            $rVal = $viewerData.name
        } elseif ($col -eq "itemlevel" -and $viewerData.itemLevel) {
            $rVal = "$($viewerData.itemLevel)"
        } elseif ($col -eq "requiredlevel" -and $viewerData.requiredLevel) {
            $rVal = "$($viewerData.requiredLevel)"
        } elseif ($col -eq "buyprice" -and $viewerData.price.buy) {
            $rVal = "$($viewerData.price.buy)"
        } elseif ($col -eq "sellprice" -and $viewerData.price.sell) {
            $rVal = "$($viewerData.price.sell)"
        } elseif ($progressiveCols -contains $col) {
            $rVal = "[STRIPPED (PROGRESSIVE)]"
        }

        $tTrunc = if ($tVal.Length -gt 24) { $tVal.Substring(0, 21) + "..." } else { $tVal }
        $rTrunc = if ($rVal.Length -gt 24) { $rVal.Substring(0, 21) + "..." } else { $rVal }

        if ($progressiveCols -contains $col) {
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, "[STRIPPED (PROGRESSIVE)]") -ForegroundColor DarkGray
        } elseif ($col -in @('mount_display_id', 'wrapped_gift', 'script_name', 'sTWDebuff')) {
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, "[TURTLE EXCLUSIVE]") -ForegroundColor Magenta
        } elseif ($rVal -ne "<unmodified>" -and $tVal -ne $rVal) {
            $diffCount++
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, $rTrunc) -ForegroundColor Yellow
        } else {
            $matchCount++
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, $(if ($rVal -ne "<unmodified>") { $rTrunc } else { $tTrunc })) -ForegroundColor DarkGray
        }
    }
    Write-Host ("-" * 88) -ForegroundColor DarkGray
    Write-Host "Parity Check: $matchCount field(s) verified, $diffCount field(s) differing." -ForegroundColor $(if ($diffCount -gt 0) { "Yellow" } else { "Green" })
}

# 10. Export Sanitized SQL Migration Patch
if ($Export) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $cleanName = ($entityName -replace '[^a-zA-Z0-9_]', '_').Trim('_')
    $sqlFileName = "{0}_{1}_{2}_sanitized.sql" -f $resolvedTable, $targetEntry, $cleanName
    $sqlFilePath = Join-Path $OutputDir $sqlFileName

    $outputCols = [System.Collections.Generic.List[string]]::new()
    $outputVals = [System.Collections.Generic.List[string]]::new()

    foreach ($col in $turtleCols) {
        if (@('patch', 'patch_min', 'patch_max', 'build') -contains $col) { continue }
        $outputCols.Add("$bt$col$bt")
        $valToUse = if ($refDict.Contains($col) -and $refDict[$col] -ne "N/A" -and $refDict[$col] -ne "<absent>") {
            $refDict[$col]
        } elseif ($turtleDict.Contains($col)) {
            $turtleDict[$col]
        } else {
            "0"
        }

        if ($valToUse -eq "NULL" -or $valToUse -eq "") {
            $outputVals.Add("''")
        } elseif ($valToUse -match '^-?\d+(\.\d+)?$') {
            $outputVals.Add($valToUse)
        } else {
            $escaped = $valToUse -replace "'", "''"
            $outputVals.Add("'$escaped'")
        }
    }

    $colListStr = $outputCols -join ", "
    $valListStr = $outputVals -join ", "

    $sourceTag = if ($refDbName) { "Brotalnia Historic DB ($refDbName) / tortoise-db-viewer" } else { "tortoise-db-viewer (https://github.com/Xian55/tortoise-db-viewer)" }
    $sqlHeader = @"
-- ============================================================================
-- FILE: $sqlFileName
-- ENTITY: [$targetEntry] $entityName
-- TABLE: $resolvedTable
-- GENERATED BY: Tortoise-WoW Database Scalper Engine
-- SOURCE: $sourceTag
-- DATE: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- SANITIZATION: Progressive columns stripped (patch, patch_min, patch_max)
-- ============================================================================

"@
    $sqlBody = "REPLACE INTO $bt$resolvedTable$bt ($colListStr)`nVALUES ($valListStr);`n"
    $fullSql = $sqlHeader + $sqlBody
    Set-Content -Path $sqlFilePath -Value $fullSql -Encoding utf8
    Write-Host "`n[EXPORT SUCCESS] Sanitized SQL Migration staged at:" -ForegroundColor Green
    Write-Host "  $sqlFilePath" -ForegroundColor Cyan
}

# 11. Launch Interactive Browser Dashboard
if ($OpenViewer) {
    Write-Host "`n[BROWSER] Launching Tortoise Database Dashboard: $viewerUrl" -ForegroundColor Cyan
    Start-Process $viewerUrl
}

Write-Host "`n[COMPLETED] Database operation finished successfully." -ForegroundColor Green
