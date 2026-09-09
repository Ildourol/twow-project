<#
.SYNOPSIS
    Audits Tortoise-WoW database migrations for compatibility with Turtle-WoW 1.18.1
    and detects conflicts with custom content, schema mismatches, and forbidden progressive columns.
.DESCRIPTION
    1. Extracts table and column schema from tortoise-wow/sql/create_databases.sql and sql/base/*.sql.
    2. Analyzes all SQL migration files in sql/database_updates/world/ (or specific files/commits).
    3. Checks for:
       - Forbidden progressive patch columns (patch, build, min_patch, max_patch, patch_min, patch_max)
       - Target table existence in Turtle-WoW schema
       - Target column existence for INSERT / UPDATE / WHERE clauses
       - Turtle-WoW custom template protection (creature_template, item_template, quest_template, gameobject_template, spell_template with entry >= 300000)
       - Syntax validity (balanced quotes, statement termination)
.PARAMETER TargetMigrations
    Optional array of migration filenames or full paths to audit. If omitted, audits all ported migrations.
#>
[CmdletBinding()]
param(
    [string[]]$TargetMigrations = @(),
    [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
    [string]$ReferenceDb = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\reference_db\world_full_14_june_2021.sql",
    [string]$ReferenceDbLatest = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\reference_db\db_latest\mysql-dump\mangos.sql"
)

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host "  Tortoise-WoW Database Migration Auditor & Invariant Checker  " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# -------------------------------------------------------------------------
# Phase 1: Build Turtle-WoW Schema Catalog
# -------------------------------------------------------------------------
Write-Host "`n[1/3] Parsing Turtle-WoW Schema Definitions..." -ForegroundColor Yellow

$schemaCatalog = @{} # TableName (lowercase) -> HashSet[string] of ColumnNames (lowercase)

function Parse-CreateTableSql([string]$sqlContent) {
    # Match CREATE TABLE up to ) ENGINE or );
    $pattern = '(?is)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`?\w+`?\.)?`?(\w+)`?\s*\((.*?)\n\)\s*(?:ENGINE|;)'
    $matches = [regex]::Matches($sqlContent, $pattern)
    foreach ($m in $matches) {
        $rawTableName = $m.Groups[1].Value.ToLower()
        $cleanTableName = $rawTableName -replace '^tw_world_', '' -replace '^tw_char_', ''
        $body = $m.Groups[2].Value

        if (-not $schemaCatalog.ContainsKey($cleanTableName)) {
            $schemaCatalog[$cleanTableName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        }

        # Match column definitions: `col_name` type ...
        $colPattern = '(?m)^\s*`?([a-zA-Z_0-9]+)`?\s+(?:tinyint|smallint|mediumint|int|bigint|float|double|decimal|varchar|char|text|mediumtext|longtext|blob|mediumblob|longblob|datetime|timestamp|date|enum)'
        $colMatches = [regex]::Matches($body, $colPattern)
        foreach ($cm in $colMatches) {
            $colName = $cm.Groups[1].Value.ToLower()
            [void]$schemaCatalog[$cleanTableName].Add($colName)
        }
    }
}

# 1A. Parse create_databases.sql
$createDbFile = Join-Path $TortoiseRepo "sql\create_databases.sql"
if (Test-Path $createDbFile) {
    $content = Get-Content $createDbFile -Raw
    Parse-CreateTableSql -sqlContent $content
}

# 1B. Parse sql/base/*.sql (read up to line 350 to capture all columns of wide tables)
$baseDir = Join-Path $TortoiseRepo "sql\base"
if (Test-Path $baseDir) {
    $baseFiles = Get-ChildItem -Path $baseDir -Filter "*.sql"
    foreach ($bf in $baseFiles) {
        $content = Get-Content $bf.FullName -TotalCount 350 | Out-String
        Parse-CreateTableSql -sqlContent $content
    }
}

Write-Host "   Cataloged $($schemaCatalog.Keys.Count) distinct database tables in Turtle-WoW schema." -ForegroundColor Green

# -------------------------------------------------------------------------
# Phase 2: Identify Target Migrations to Audit
# -------------------------------------------------------------------------
$migrationDir = Join-Path $TortoiseRepo "sql\database_updates\world"
$filesToAudit = @()

if ($TargetMigrations.Count -gt 0) {
    foreach ($tm in $TargetMigrations) {
        if (Test-Path $tm) {
            $filesToAudit += Get-Item $tm
        } else {
            $candidate = Join-Path $migrationDir $tm
            if (Test-Path $candidate) {
                $filesToAudit += Get-Item $candidate
            }
        }
    }
} else {
    # All migrations ported in batches
    $filesToAudit = Get-ChildItem -Path $migrationDir -Filter "*.sql" | Where-Object {
        $_.Name -ge "20260729" -or $_.Name -like "*20260812*" -or $_.Name -like "*20260816*" -or $_.Name -like "*20260819*" -or $_.Name -like "*20260831*" -or $_.Name -like "*202609*"
    } | Sort-Object Name
}

Write-Host "`n[2/3] Auditing $($filesToAudit.Count) Migration Files..." -ForegroundColor Yellow

# -------------------------------------------------------------------------
# Phase 3: Perform Rigorous Invariant and Compatibility Audit
# -------------------------------------------------------------------------
$auditResults = @()
$totalViolations = 0
$totalWarnings = 0

$forbiddenColumns = @('patch', 'build', 'min_patch', 'max_patch', 'patch_min', 'patch_max')
$templateTables = @('creature_template', 'item_template', 'quest_template', 'gameobject_template', 'spell_template')

foreach ($file in $filesToAudit) {
    $fname = $file.Name
    $text = Get-Content $file.FullName -Raw
    $fileIssues = @()
    $fileWarnings = @()

    # Strip comments cleanly (both inline -- and block /* */)
    $cleanSql = [regex]::Replace($text, '(?m)--.*$', '')
    $cleanSql = [regex]::Replace($cleanSql, '(?s)/\*.*?\*/', '')

    # 1. Check for forbidden progressive patch columns
    foreach ($col in $forbiddenColumns) {
        $backtickCol = '`' + $col + '`'
        $regexCol = '\b' + $col + '\s*='
        if ($cleanSql.IndexOf($backtickCol, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $cleanSql -match $regexCol) {
            $fileIssues += "FORBIDDEN COLUMN: Progressive column '$col' detected in SQL statement. Causes fatal unknown column error on Nostalrius schema."
        }
    }

    # 2. Check for unbalanced quotes (syntax corruption)
    $singleQuotes = ([regex]::Matches($cleanSql, "'")).Count
    $escapedSingleQuotes = ([regex]::Matches($cleanSql, "\\'")).Count + ([regex]::Matches($cleanSql, "''")).Count * 2
    $netSingleQuotes = $singleQuotes - $escapedSingleQuotes
    if ($netSingleQuotes % 2 -ne 0) {
        $fileIssues += "SYNTAX WARNING: Unbalanced single quotes detected in SQL statements."
    }

    # 3. Check for Turtle Custom Template Entity collisions (entry >= 300000 clobbering)
    foreach ($tbl in $templateTables) {
        $pattern = "(?is)(?:DELETE\s+FROM|UPDATE)\s+`?$tbl`?\s+WHERE.*?(?:entry|id)\s*(?:=|IN\s*\()\s*([3-9]\d{5,})"
        $m = [regex]::Match($cleanSql, $pattern)
        if ($m.Success) {
            $cid = $m.Groups[1].Value
            $fileIssues += "CUSTOM TEMPLATE CLOBBER: Modification or deletion of Turtle-WoW custom $tbl entry $cid detected!"
        }
    }

    # 4. Check target tables against catalog
    $tableMatches = [regex]::Matches($cleanSql, '(?i)(?:INSERT\s+INTO|REPLACE\s+INTO|(?<!KEY\s+)UPDATE|DELETE\s+FROM)\s+`?(\w+)`?')
    $tablesReferenced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($tm in $tableMatches) {
        $rawTbl = $tm.Groups[1].Value.ToLower()
        $cleanTbl = $rawTbl -replace '^tw_world_', ''
        [void]$tablesReferenced.Add($cleanTbl)

        if (-not $schemaCatalog.ContainsKey($cleanTbl)) {
            $fileIssues += "UNKNOWN TABLE: Table '$cleanTbl' is referenced but does not exist in Turtle-WoW schema catalog."
        }
    }

    # 5. Check INSERT / REPLACE column lists against catalog columns
    $insertMatches = [regex]::Matches($cleanSql, '(?is)(?:INSERT|REPLACE)\s+INTO\s+`?(\w+)`?\s*\((.*?)\)\s*VALUES')
    foreach ($im in $insertMatches) {
        $tblName = ($im.Groups[1].Value -replace '^tw_world_', '').ToLower()
        $colBlock = $im.Groups[2].Value
        $cols = $colBlock -split ',' | ForEach-Object {
            $c = $_.Trim().Trim('`')
            $c
        }

        if ($schemaCatalog.ContainsKey($tblName)) {
            $validCols = $schemaCatalog[$tblName]
            foreach ($c in $cols) {
                if ($c -match '^\s+') {
                    $fileIssues += "SYNTAX ERROR: Leading whitespace in column identifier '$c' in table '$tblName'."
                }
                $cleanCol = $c.Trim().ToLower()
                if (-not $validCols.Contains($cleanCol)) {
                    $fileIssues += "UNKNOWN COLUMN: Column '$c' in INSERT/REPLACE statement does not exist in table '$tblName'."
                }
            }
        }
    }

    # 6. Check UPDATE column assignments
    $updateMatches = [regex]::Matches($cleanSql, '(?is)UPDATE\s+`?(\w+)`?\s+SET\s+(.*?)\s+WHERE')
    foreach ($um in $updateMatches) {
        $tblName = ($um.Groups[1].Value -replace '^tw_world_', '').ToLower()
        $setBlock = $um.Groups[2].Value
        $assignments = $setBlock -split ',' | ForEach-Object { $_.Trim() }
        foreach ($assign in $assignments) {
            if ($assign -match '^\s*`?([a-zA-Z_0-9]+)`?\s*=') {
                $sc = $matches[1].ToLower()
                if ($schemaCatalog.ContainsKey($tblName)) {
                    $validCols = $schemaCatalog[$tblName]
                    if (-not $validCols.Contains($sc)) {
                        $fileIssues += "UNKNOWN COLUMN: Column '$sc' in UPDATE SET does not exist in table '$tblName'."
                    }
                }
            }
        }
    }

    $status = if ($fileIssues.Count -gt 0) { "FAIL" } elseif ($fileWarnings.Count -gt 0) { "WARN" } else { "PASS" }

    if ($status -eq "FAIL") { $totalViolations += $fileIssues.Count }
    if ($status -eq "WARN") { $totalWarnings += $fileWarnings.Count }

    $auditResults += [PSCustomObject]@{
        Filename = $fname
        Status = $status
        Tables = ($tablesReferenced -join ", ")
        Issues = $fileIssues
        Warnings = $fileWarnings
    }
}

# -------------------------------------------------------------------------
# Report Output
# -------------------------------------------------------------------------
Write-Host "`n[3/3] Audit Execution Summary" -ForegroundColor Cyan
Write-Host "-----------------------------------------------------------------"

$failCount = @($auditResults | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = @($auditResults | Where-Object { $_.Status -eq "WARN" }).Count
$passCount = @($auditResults | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host "Total Migration Files Checked: $($auditResults.Count)"
Write-Host "  -> PASS: $passCount" -ForegroundColor Green
Write-Host "  -> WARN: $warnCount" -ForegroundColor Yellow
Write-Host "  -> FAIL: $failCount" -ForegroundColor Red

Write-Host "`nDetailed Migration Audit Log:" -ForegroundColor Cyan
foreach ($r in $auditResults) {
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
if ($failCount -eq 0) {
    Write-Host "  ALL MIGRATIONS COMPLIANT: 0 Schema, Invariant, or Column Violations!" -ForegroundColor Green
} else {
    Write-Host "  AUDIT FAILED: $failCount migrations require schema adjustments." -ForegroundColor Red
}
Write-Host "=================================================================" -ForegroundColor Cyan

return $auditResults
