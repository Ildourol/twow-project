# DbAuditor.ps1: Robust SQL migration auditor, schema catalog, and provenance tracker

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")

$script:CompatibilityManifestPath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\config\turtle-compatibility.json"

function Build-SchemaCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TortoiseRepo
    )

    $cachePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\config\schema_catalog.json"
    if (Test-Path $cachePath) {
        $raw = [System.IO.File]::ReadAllText($cachePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
        $cachedCatalog = @{}
        foreach ($prop in $raw.PSObject.Properties) {
            $cachedCatalog[$prop.Name] = [System.Collections.Generic.HashSet[string]]::new([string[]]$prop.Value, [System.StringComparer]::OrdinalIgnoreCase)
        }
        return $cachedCatalog
    }

    $schemaCatalog = @{}

    $parseCreateTable = {
        param([string]$sqlContent)
        $pattern = '(?is)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`?\w+`?\.)?`?(\w+)`?\s*\((.*?)\n\)\s*(?:ENGINE|;)'
        $matches = [regex]::Matches($sqlContent, $pattern)
        foreach ($m in $matches) {
            $rawTableName = $m.Groups[1].Value.ToLower()
            $cleanTableName = $rawTableName -replace '^tw_world_', '' -replace '^tw_char_', ''
            $body = $m.Groups[2].Value

            if (-not $schemaCatalog.ContainsKey($cleanTableName)) {
                $schemaCatalog[$cleanTableName] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            }

            $colPattern = '(?m)^\s*`?([a-zA-Z_0-9]+)`?\s+(?:tinyint|smallint|mediumint|int|bigint|float|double|decimal|varchar|char|text|mediumtext|longtext|blob|mediumblob|longblob|datetime|timestamp|date|enum)'
            $colMatches = [regex]::Matches($body, $colPattern)
            foreach ($cm in $colMatches) {
                $colName = $cm.Groups[1].Value.ToLower()
                [void]$schemaCatalog[$cleanTableName].Add($colName)
            }
        }
    }

    $createDbFile = Join-Path $TortoiseRepo "sql\create_databases.sql"
    if (Test-Path $createDbFile) {
        $content = [System.IO.File]::ReadAllText($createDbFile, [System.Text.Encoding]::UTF8)
        & $parseCreateTable -sqlContent $content
    }

    $baseDir = Join-Path $TortoiseRepo "sql\base"
    if (Test-Path $baseDir) {
        $baseFiles = Get-ChildItem -Path $baseDir -Filter "*.sql"
        foreach ($bf in $baseFiles) {
            $content = Get-Content $bf.FullName -TotalCount 350 | Out-String
            & $parseCreateTable -sqlContent $content
        }
    }

    return $schemaCatalog
}

function Invoke-DatabaseMigrationAudit {
    [CmdletBinding()]
    param(
        [string[]]$TargetMigrations = @(),
        [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
    )

    if (-not (Test-Path $TortoiseRepo)) {
        return @{
            ExitCode = $script:EXIT_CODE_TOOL_FAILURE
            Status = "TOOL_FAILURE"
            Error = "Target repository not found: $TortoiseRepo"
            Results = @()
        }
    }

    $schemaCatalog = Build-SchemaCatalog -TortoiseRepo $TortoiseRepo
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
                } else {
                    return @{
                        ExitCode = $script:EXIT_CODE_TOOL_FAILURE
                        Status = "TOOL_FAILURE"
                        Error = "Specified migration file not found: $tm"
                        Results = @()
                    }
                }
            }
        }
    } else {
        if (Test-Path $migrationDir) {
            $filesToAudit = Get-ChildItem -Path $migrationDir -Filter "*.sql" | Sort-Object Name
        }
    }

    $forbiddenColumns = @("patch", "build", "min_patch", "max_patch", "patch_min", "patch_max")
    $auditResults = [System.Collections.Generic.List[object]]::new()
    $totalViolations = 0
    $totalWarnings = 0

    foreach ($file in $filesToAudit) {
        $fname = $file.Name
        $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $fileIssues = [System.Collections.Generic.List[string]]::new()
        $fileWarnings = [System.Collections.Generic.List[string]]::new()
        $tablesReferenced = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        # Clean comments cleanly
        $cleanSql = [regex]::Replace($text, '(?m)--.*$', '')
        $cleanSql = [regex]::Replace($cleanSql, '(?s)/\*.*?\*/', '')

        # 1. Forbidden progressive columns
        foreach ($col in $forbiddenColumns) {
            $backtickCol = "`"$col`""
            $regexCol = "\b$col\s*="
            if ($cleanSql -match $regexCol -or $cleanSql.IndexOf($backtickCol, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $fileIssues.Add("FORBIDDEN COLUMN: Progressive column '$col' detected in migration statements.")
            }
        }

        # 2. Syntax: Unbalanced single quotes
        $singleQuotes = ([regex]::Matches($cleanSql, "'")).Count
        $escapedSingleQuotes = ([regex]::Matches($cleanSql, "\\'")).Count + ([regex]::Matches($cleanSql, "''")).Count * 2
        $netSingleQuotes = $singleQuotes - $escapedSingleQuotes
        if ($netSingleQuotes % 2 -ne 0) {
            $fileIssues.Add("SYNTAX ERROR: Unbalanced single quotes detected.")
        }

        # 3. Entity-specific custom ID collision protection
        # Spell template protection: >= 40000
        $spellPattern = '(?m)^\s*(?:DELETE\s+FROM|UPDATE)\s+`?spell_template`?\s+WHERE.*?(?:entry|id)\s*(?:=|IN\s*\()\s*([4-9]\d{4,})'
        $sm = [regex]::Match($cleanSql, $spellPattern)
        if ($sm.Success) {
            $cid = [int]$sm.Groups[1].Value
            if ($cid -ge 40000 -and $cid -lt 1000000) {
                $fileIssues.Add("CUSTOM SPELL CLOBBER: Deletion or modification of Turtle custom spell entry $cid (>= 40000)!")
            }
        }

        # World template tables: creature_template, item_template, quest_template, gameobject_template (>= 300000)
        foreach ($tbl in @("creature_template", "item_template", "quest_template", "gameobject_template")) {
            $pattern = "(?m)^\s*(?:DELETE\s+FROM|UPDATE)\s+`?$tbl`?\s+WHERE.*?(?:entry|id)\s*(?:=|IN\s*\()\s*([3-9]\d{5,})"
            $m = [regex]::Match($cleanSql, $pattern)
            if ($m.Success) {
                $cid = $m.Groups[1].Value
                $fileIssues.Add("CUSTOM TEMPLATE CLOBBER: Modification/deletion of Turtle custom $tbl entry $cid (>= 300000)!")
            }
        }

        # 4. Table existence check against catalog (anchored at statement start)
        $tableMatches = [regex]::Matches($cleanSql, '(?m)^\s*(?:INSERT\s+INTO|REPLACE\s+INTO|UPDATE|DELETE\s+FROM)\s+`?([a-zA-Z0-9_]+)`?')
        foreach ($tm in $tableMatches) {
            $rawTbl = $tm.Groups[1].Value.ToLower()
            $cleanTbl = $rawTbl -replace '^tw_world_', ''
            [void]$tablesReferenced.Add($cleanTbl)
            if ($schemaCatalog.Keys.Count -gt 0 -and -not $schemaCatalog.ContainsKey($cleanTbl)) {
                $fileIssues.Add("UNKNOWN TABLE: Table '$cleanTbl' does not exist in Turtle-WoW schema catalog.")
            }
        }

        # 5. Insert column existence check
        $insertMatches = [regex]::Matches($cleanSql, '(?m)^\s*(?:INSERT|REPLACE)\s+INTO\s+`?(\w+)`?\s*\((.*?)\)\s*VALUES')
        foreach ($im in $insertMatches) {
            $tblName = ($im.Groups[1].Value -replace '^tw_world_', '').ToLower()
            $colBlock = $im.Groups[2].Value
            $cols = $colBlock -split ',' | ForEach-Object { $_.Trim().Trim('`') }
            if ($schemaCatalog.ContainsKey($tblName)) {
                $validCols = $schemaCatalog[$tblName]
                foreach ($c in $cols) {
                    $cleanCol = $c.Trim().ToLower()
                    if (-not $validCols.Contains($cleanCol)) {
                        $fileIssues.Add("UNKNOWN COLUMN: Column '$c' in INSERT/REPLACE does not exist in table '$tblName'.")
                    }
                }
            }
        }

        $status = if ($fileIssues.Count -gt 0) { "FAIL" } elseif ($fileWarnings.Count -gt 0) { "WARN" } else { "PASS" }
        if ($status -eq "FAIL") { $totalViolations += $fileIssues.Count }
        if ($status -eq "WARN") { $totalWarnings += $fileWarnings.Count }

        [void]$auditResults.Add([PSCustomObject]@{
            Filename = $fname
            Status   = $status
            Tables   = ($tablesReferenced -join ", ")
            Issues   = @($fileIssues)
            Warnings = @($fileWarnings)
        })
    }

    $overallExitCode = if ($totalViolations -gt 0) { $script:EXIT_CODE_VALIDATION_FAILURE } else { $script:EXIT_CODE_PASS }
    $overallStatus = if ($totalViolations -gt 0) { "FAIL" } else { "PASS" }

    return @{
        ExitCode       = $overallExitCode
        Status         = $overallStatus
        TotalFiles     = $filesToAudit.Count
        FailCount      = @($auditResults | Where-Object { $_.Status -eq "FAIL" }).Count
        PassCount      = @($auditResults | Where-Object { $_.Status -eq "PASS" }).Count
        WarnCount      = @($auditResults | Where-Object { $_.Status -eq "WARN" }).Count
        Results        = $auditResults
        CatalogedTables= $schemaCatalog.Keys.Count
    }
}

function New-EntityProvenanceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SourceRepo,
        [Parameter(Mandatory=$true)][string]$SourceRevision,
        [Parameter()][string]$SourceDb = "vmangos_world",
        [Parameter(Mandatory=$true)][string]$SourceTable,
        [Parameter(Mandatory=$true)][string]$SourceEntityId,
        [Parameter(Mandatory=$true)][string]$TargetTable,
        [Parameter(Mandatory=$true)][string]$TargetEntityId,
        [Parameter()][string]$TargetRevision = "",
        [Parameter()][string]$OriginalTargetValue = "",
        [Parameter()][string]$ProposedValue = "",
        [Parameter()][string]$Evidence = "",
        [Parameter()][double]$Confidence = 1.0,
        [Parameter()][string]$MigrationFile = ""
    )

    return [ordered]@{
        source_repository     = $SourceRepo
        source_revision       = $SourceRevision
        source_database       = $SourceDb
        source_table          = $SourceTable
        source_entity_id      = $SourceEntityId
        target_table          = $TargetTable
        target_entity_id      = $TargetEntityId
        target_revision       = $TargetRevision
        original_target_value = $OriginalTargetValue
        proposed_value        = $ProposedValue
        evidence              = $Evidence
        confidence            = $Confidence
        migration_file        = $MigrationFile
        created_at            = (Get-Date).ToString("o")
    }
}

function Audit-MigrationContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$SqlContent,
        [string]$FilePath = "inline.sql",
        [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
    )

    $schemaCatalog = Build-SchemaCatalog -TortoiseRepo $TortoiseRepo
    $forbiddenColumns = @("patch", "build", "min_patch", "max_patch", "patch_min", "patch_max")
    $fileIssues = [System.Collections.Generic.List[string]]::new()

    $cleanSql = [regex]::Replace($SqlContent, '(?m)--.*$', '')
    $cleanSql = [regex]::Replace($cleanSql, '(?s)/\*.*?\*/', '')

    # 1. Forbidden progressive columns
    foreach ($col in $forbiddenColumns) {
        $backtickCol = "`"$col`""
        $regexCol = "(?i)\b$col\s*="
        if ($cleanSql -match $regexCol -or $cleanSql.IndexOf($backtickCol, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $cleanSql -match "(?i)\bADD\s+(?:COLUMN\s+)?`?$col`?\b") {
            $fileIssues.Add("Forbidden progressive versioning column '$col' detected.")
        }
    }

    # 2. Entity-specific custom ID collision protection
    # Spell template protection: >= 40000
    $spellPattern = '(?m)^\s*(?:INSERT\s+INTO|REPLACE\s+INTO|DELETE\s+FROM|UPDATE)\s+`?spell_template`?.*?(?:VALUES\s*\(\s*|WHERE.*?(?:entry|id)\s*(?:=|IN\s*\()\s*)([4-9]\d{4,})'
    $sm = [regex]::Match($cleanSql, $spellPattern)
    if ($sm.Success) {
        $cid = [int]$sm.Groups[1].Value
        if ($cid -ge 40000 -and $cid -lt 1000000) {
            $fileIssues.Add("Custom ID boundary collision: Deletion/modification of Turtle custom spell entry $cid (>= 40000)!")
        }
    }

    # World template tables: creature_template, item_template, quest_template, gameobject_template (>= 300000)
    foreach ($tbl in @("creature_template", "item_template", "quest_template", "gameobject_template")) {
        $pattern = "(?m)^\s*(?:INSERT\s+INTO|REPLACE\s+INTO|DELETE\s+FROM|UPDATE)\s+`?$tbl`?.*?(?:VALUES\s*\(\s*|WHERE.*?(?:entry|id)\s*(?:=|IN\s*\()\s*)([3-9]\d{5,})"
        $m = [regex]::Match($cleanSql, $pattern)
        if ($m.Success) {
            $cid = $m.Groups[1].Value
            $fileIssues.Add("Custom ID boundary collision: Modification/deletion of Turtle custom $tbl entry $cid (>= 300000)!")
        }
    }

    $exitCode = if ($fileIssues.Count -gt 0) { 1 } else { 0 }
    return @{
        ExitCode   = $exitCode
        Violations = @($fileIssues)
        Status     = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }
    }
}
