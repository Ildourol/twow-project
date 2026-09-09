<#
.SYNOPSIS
    High-performance Database Entity Scalper and Diff Engine for Turtle-WoW 1.18.1.
.DESCRIPTION
    Extracts, tokenizes, and compares entity rows across:
      1. Local Turtle-WoW base SQL (tortoise-wow/sql/base/tw_world_<table_name>.sql)
      2. Classic Reference DB (reference-upstreams/lights-hope-database-history/world_full_14_june_2021.sql)
      3. Upstream VMaNGOS migrations
      4. Online DB Viewer (xian55/tortoise-db-viewer)
    
    Key capabilities:
      - Field-by-field side-by-side comparison between donor and host.
      - Automatic progressive column stripping (patch, patch_min, patch_max, build).
      - Detection of custom Turtle-WoW columns (mount_display_id, sTWDebuff, etc.).
      - Instant generation of sanitized SQL migration patches into tools/queue/staging_sql/.
      - Direct entity lookup by ID or by search name.
.PARAMETER Table
    Table name or alias: item, creature, spell, quest, gameobject, loot, creature_loot, etc.
.PARAMETER Query
    Entity ID (entry number) or search string name (e.g. 19019 or "Thunderfury").
.PARAMETER Diff
    Show a detailed side-by-side field diff in the console.
.PARAMETER Export
    Auto-generate a clean, progressive-stripped SQL update in tools/queue/staging_sql/.
.PARAMETER OpenViewer
    Open the entity in the online tortoise-db-viewer in the default browser.
.PARAMETER PatchVersion
    Target progressive patch version in reference DB (default: 10 for 1.12.1 final).
.EXAMPLE
    task scalp item 19019 -Diff
.EXAMPLE
    task scalp creature "Onyxia" -Diff -Export
.EXAMPLE
    task scalp creature_loot 10184
#>
[CmdletBinding()]
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$Table,

    [Parameter(Position=1, Mandatory=$true)]
    [string]$Query,

    [switch]$Diff,
    [switch]$Export,
    [switch]$OpenViewer,
    [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
    [string]$ReferenceDb = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\lights-hope-database-history\world_full_14_june_2021.sql",
    [string]$OutputDir = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\queue\staging_sql",
    [int]$PatchVersion = 10
)

$ErrorActionPreference = "Stop"
$bt = [char]96

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "       Tortoise-WoW Database Scalper & Entity Extraction Engine                " -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# -----------------------------------------------------------------------------
# 1. Resolve Table Name and Target Base File
# -----------------------------------------------------------------------------
$tableNormalized = $Table.ToLower().Trim()
$resolvedTable = switch -Regex ($tableNormalized) {
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
    default                          { $tableNormalized -replace '^tw_world_', '' }
}

$turtleSqlFile = Join-Path $TortoiseRepo "sql\base\tw_world_$resolvedTable.sql"
if (-not (Test-Path $turtleSqlFile)) {
    $alt = Join-Path $TortoiseRepo "sql\base\$resolvedTable.sql"
    if (Test-Path $alt) { $turtleSqlFile = $alt }
}

Write-Host "[1/5] Target Table: " -NoNewline -ForegroundColor Gray
Write-Host "$resolvedTable" -ForegroundColor Green
if (Test-Path $turtleSqlFile) {
    Write-Host "      Base File   : " -NoNewline -ForegroundColor Gray
    Write-Host (Split-Path $turtleSqlFile -Leaf) -ForegroundColor DarkCyan
} else {
    Write-Host "      Base File   : Not found in sql/base/ (will attempt generic search)" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 2. Tokenizer Helper
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# 3. Parse Schema Columns (Turtle and Reference)
# -----------------------------------------------------------------------------
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

$refCols = [System.Collections.Generic.List[string]]::new()
if (Test-Path $ReferenceDb) {
    $patternInsert = 'INSERT INTO `' + $resolvedTable + '` \((.*?)\) VALUES'
    $refMatch = Select-String -Path $ReferenceDb -Pattern $patternInsert | Select-Object -First 1
    if ($refMatch) {
        $rawCols = ($refMatch.Matches[0].Groups[1].Value -split ',')
        foreach ($rc in $rawCols) {
            $refCols.Add(($rc -replace '[^a-zA-Z0-9_]', '').ToLower())
        }
    } else {
        $patternCreate = 'CREATE TABLE IF NOT EXISTS `' + $resolvedTable + '` \('
        $refCreate = Select-String -Path $ReferenceDb -Pattern $patternCreate | Select-Object -First 1
        if ($refCreate) {
            $refLineNum = $refCreate.LineNumber
            $refCreateLines = Get-Content -Path $ReferenceDb | Select-Object -Skip ($refLineNum - 1) -First 120
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

Write-Host "[2/5] Columns Cataloged:" -ForegroundColor Gray
Write-Host "      Turtle Base : $($turtleCols.Count) columns" -ForegroundColor $(if ($turtleCols.Count -gt 0) { "DarkGreen" } else { "DarkGray" })
Write-Host "      Ref Database: $($refCols.Count) columns" -ForegroundColor $(if ($refCols.Count -gt 0) { "DarkGreen" } else { "DarkGray" })

# -----------------------------------------------------------------------------
# 4. Resolve Query (ID vs Name Search)
# -----------------------------------------------------------------------------
$targetEntry = $null
$isNumeric = [int]::TryParse($Query, [ref]$targetEntry)

if (-not $isNumeric) {
    Write-Host "[3/5] Query is text string: '$Query'. Searching entity names..." -ForegroundColor Yellow
    $foundEntries = [System.Collections.Generic.List[PSObject]]::new()

    # Search in Turtle base file
    if (Test-Path $turtleSqlFile) {
        $content = Get-Content $turtleSqlFile -Raw
        $escapedQuery = [regex]::Escape($Query)
        $namePattern = "(?i)\((\d+),[^)]*?'([^']*?$escapedQuery[^']*?)'"
        $matches = [regex]::Matches($content, $namePattern)
        foreach ($m in $matches) {
            $eId = [int]$m.Groups[1].Value
            $eName = $m.Groups[2].Value
            if (-not ($foundEntries | Where-Object { $_.Entry -eq $eId })) {
                $foundEntries.Add([pscustomobject]@{ Entry = $eId; Name = $eName; Source = "Turtle" })
            }
        }
    }

    if ($foundEntries.Count -eq 0) {
        Write-Host "      No entities matching '$Query' found in $resolvedTable." -ForegroundColor Red
        return
    } elseif ($foundEntries.Count -eq 1) {
        $targetEntry = $foundEntries[0].Entry
        Write-Host "      Exact match found: " -NoNewline -ForegroundColor Gray
        Write-Host "[$targetEntry] $($foundEntries[0].Name)" -ForegroundColor Green
    } else {
        Write-Host "      Multiple entities matched '$Query' ($($foundEntries.Count) found):" -ForegroundColor Yellow
        foreach ($fe in ($foundEntries | Select-Object -First 10)) {
            Write-Host "        - [$($fe.Entry)] $($fe.Name)" -ForegroundColor Cyan
        }
        if ($foundEntries.Count -gt 10) {
            Write-Host "        ... and $($foundEntries.Count - 10) more." -ForegroundColor Gray
        }
        $targetEntry = $foundEntries[0].Entry
        Write-Host "      Proceeding with first match: " -NoNewline -ForegroundColor Gray
        Write-Host "[$targetEntry] $($foundEntries[0].Name)" -ForegroundColor Green
    }
} else {
    Write-Host "[3/5] Target Entry ID: " -NoNewline -ForegroundColor Gray
    Write-Host "$targetEntry" -ForegroundColor Green
}

# Turtle Invariant Check
if ($targetEntry -ge 300000) {
    Write-Host "      [!] INVARIANT ALERT: Entry $targetEntry >= 300000 is reserved for Turtle-WoW custom content!" -ForegroundColor Yellow
}

# -----------------------------------------------------------------------------
# 5. Extract Entity Data from Sources
# -----------------------------------------------------------------------------
Write-Host "[4/5] Scalping Entity Data across Datasets..." -ForegroundColor Gray

# 5A. Scalp Turtle WoW Base
$turtleRows = @()
if (Test-Path $turtleSqlFile) {
    $tContent = Get-Content $turtleSqlFile -Raw
    $tMatches = [regex]::Matches($tContent, "\((?<!\d)$targetEntry,\s*(.*?)\)(?=\s*[,;]|\s*$)")
    foreach ($tm in $tMatches) {
        $turtleRows += $tm.Value
    }
}
Write-Host "      Turtle Base : $($turtleRows.Count) row(s) found" -ForegroundColor $(if ($turtleRows.Count -gt 0) { "Green" } else { "DarkGray" })

# 5B. Scalp Reference Database (Brotalnia 2021)
$refRows = @()
if (Test-Path $ReferenceDb) {
    $patternRef = "^\s*\($targetEntry,"
    $refLineMatches = Select-String -Path $ReferenceDb -Pattern $patternRef
    foreach ($rlm in $refLineMatches) {
        $refRows += $rlm.Line.Trim().TrimEnd(',;')
    }
}
Write-Host "      Ref Database: $($refRows.Count) row(s) found" -ForegroundColor $(if ($refRows.Count -gt 0) { "Green" } else { "DarkGray" })

if ($turtleRows.Count -eq 0 -and $refRows.Count -eq 0) {
    Write-Host "`n[ERROR] Entity $targetEntry was not found in either Turtle base or Reference database." -ForegroundColor Red
    return
}

# -----------------------------------------------------------------------------
# 6. Parse and Tokenize Best Matching Rows
# -----------------------------------------------------------------------------
$isSingleTemplate = $resolvedTable -like "*_template" -and $resolvedTable -notlike "*loot*"

$tTokens = if ($turtleRows.Count -gt 0) { Tokenize-SqlTuple $turtleRows[0] } else { @() }
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

# Map dictionaries: Column -> Value
$turtleDict = [ordered]@{}
for ($i = 0; $i -lt $turtleCols.Count; $i++) {
    $val = if ($i -lt $tTokens.Count) { $tTokens[$i] } else { "N/A" }
    $turtleDict[$turtleCols[$i]] = $val
}

$refDict = [ordered]@{}
for ($i = 0; $i -lt $refCols.Count; $i++) {
    $val = if ($i -lt $rTokens.Count) { $rTokens[$i] } else { "N/A" }
    $refDict[$refCols[$i]] = $val
}

# Display Entity Summary
$entityName = if ($turtleDict.Contains("name")) { $turtleDict["name"] } elseif ($refDict.Contains("name")) { $refDict["name"] } else { "Entity $targetEntry" }
Write-Host "`nEntity: " -NoNewline -ForegroundColor Cyan
Write-Host "[$targetEntry] $entityName" -ForegroundColor White

# -----------------------------------------------------------------------------
# 7. Side-by-Side Field Diff Display
# -----------------------------------------------------------------------------
if ($Diff -or (-not $Export -and -not $OpenViewer)) {
    Write-Host "`n[5/5] Side-by-Side Field Comparison:" -ForegroundColor Cyan
    Write-Host ("-" * 88) -ForegroundColor DarkGray
    Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f "COLUMN", "TURTLE BASE (HOST)", "REFERENCE DB (DONOR)") -ForegroundColor Yellow
    Write-Host ("-" * 88) -ForegroundColor DarkGray

    # Progressive columns to highlight as stripped
    $progressiveCols = @('patch', 'patch_min', 'patch_max', 'build', 'min_patch', 'max_patch')

    # All unique columns in union
    $allCols = [System.Collections.Generic.List[string]]::new()
    foreach ($c in $turtleCols) { $allCols.Add($c) }
    foreach ($c in $refCols) { if (-not $allCols.Contains($c)) { $allCols.Add($c) } }

    $diffCount = 0
    $matchCount = 0

    foreach ($col in $allCols) {
        $inTurtle = $turtleDict.Contains($col)
        $inRef = $refDict.Contains($col)
        $tVal = if ($inTurtle) { $turtleDict[$col] } else { "<absent>" }
        $rVal = if ($inRef) { $refDict[$col] } else { "<absent>" }

        $tTrunc = if ($tVal.Length -gt 24) { $tVal.Substring(0, 21) + "..." } else { $tVal }
        $rTrunc = if ($rVal.Length -gt 24) { $rVal.Substring(0, 21) + "..." } else { $rVal }

        if ($progressiveCols -contains $col) {
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, "[STRIPPED (PROGRESSIVE)]", $rTrunc) -ForegroundColor DarkGray
        } elseif (-not $inTurtle) {
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, "<absent in Turtle>", $rTrunc) -ForegroundColor DarkCyan
        } elseif (-not $inRef) {
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, "[TURTLE EXCLUSIVE]") -ForegroundColor Magenta
        } elseif ($tVal -eq $rVal) {
            $matchCount++
        } else {
            $diffCount++
            Write-Host ("{0,-28} | {1,-26} | {2,-26}" -f $col, $tTrunc, $rTrunc) -ForegroundColor Yellow
        }
    }

    Write-Host ("-" * 88) -ForegroundColor DarkGray
    Write-Host "Summary: $matchCount field(s) identical, $diffCount field(s) differing." -ForegroundColor $(if ($diffCount -gt 0) { "Yellow" } else { "Green" })
}

# -----------------------------------------------------------------------------
# 8. Export Sanitized SQL Migration Patch
# -----------------------------------------------------------------------------
if ($Export) {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $cleanName = ($entityName -replace '[^a-zA-Z0-9_]', '_').Trim('_')
    $sqlFileName = "{0}_{1}_{2}_sanitized.sql" -f $resolvedTable, $targetEntry, $cleanName
    $sqlFilePath = Join-Path $OutputDir $sqlFileName

    # Generate sanitized SQL row aligned to Turtle's exact schema
    # Use Ref DB values where available, fallback to Turtle Base values, strip progressive columns
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

        # Format SQL value
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

    $sqlHeader = @"
-- ============================================================================
-- FILE: $sqlFileName
-- ENTITY: [$targetEntry] $entityName
-- TABLE: $resolvedTable
-- GENERATED BY: Tortoise-WoW Database Scalper
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

# -----------------------------------------------------------------------------
# 9. Online DB Viewer Integration
# -----------------------------------------------------------------------------
if ($OpenViewer) {
    $viewerParam = switch -Regex ($resolvedTable) {
        'item'        { "item" }
        'creature'    { "npc" }
        'spell'       { "spell" }
        'quest'       { "quest" }
        'gameobject'  { "object" }
        default       { "search" }
    }
    $url = "https://xian55.github.io/tortoise-db-viewer/?$viewerParam=$targetEntry"
    Write-Host "`n[BROWSER] Launching Online DB Viewer: $url" -ForegroundColor Cyan
    Start-Process $url
}

Write-Host "`n[COMPLETED] Scalping operation finished successfully." -ForegroundColor Green
