# CompatibilityChecker.ps1: Centralized Turtle-WoW Invariant and Safety Checker

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")

$script:ManifestPath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\config\turtle-compatibility.json"

function Get-TurtleManifest {
    param([string]$Path = $script:ManifestPath)
    if (Test-Path $Path) {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        return ($raw | ConvertFrom-Json)
    }
    return $null
}

function Test-TurtleCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)][Alias("PatchContent")][string]$DiffText = "",
        [Parameter(Mandatory=$false)][string]$PatchFile = "",
        [Parameter(Mandatory=$false)][string]$TargetRepo = "",
        [Parameter(Mandatory=$false)][string]$WorktreePath = ""
    )

    $manifest = Get-TurtleManifest
    $violations = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $reasonCodes = [System.Collections.Generic.List[string]]::new()

    # 1. Resolve Diff text
    if ([string]::IsNullOrWhiteSpace($DiffText)) {
        if (-not [string]::IsNullOrWhiteSpace($PatchFile)) {
            if (-not (Test-Path $PatchFile)) {
                return @{
                    ExitCode    = $script:EXIT_CODE_TOOL_FAILURE
                    Status      = "TOOL_FAILURE"
                    Violations  = @("Patch file not found: $PatchFile")
                    Warnings    = @()
                    ReasonCodes = @("PATCH_FILE_NOT_FOUND")
                }
            }
            $DiffText = [System.IO.File]::ReadAllText($PatchFile, [System.Text.Encoding]::UTF8)
        } elseif (-not [string]::IsNullOrWhiteSpace($WorktreePath)) {
            if (-not (Test-Path $WorktreePath)) {
                return @{
                    ExitCode    = $script:EXIT_CODE_TOOL_FAILURE
                    Status      = "TOOL_FAILURE"
                    Violations  = @("Worktree path not found: $WorktreePath")
                    Warnings    = @()
                    ReasonCodes = @("WORKTREE_PATH_NOT_FOUND")
                }
            }
            $DiffText = git -C $WorktreePath diff HEAD 2>$null
            if ([string]::IsNullOrWhiteSpace($DiffText)) {
                $DiffText = git -C $WorktreePath diff 2>$null
            }
        } elseif (-not [string]::IsNullOrWhiteSpace($TargetRepo)) {
            if (-not (Test-Path $TargetRepo)) {
                return @{
                    ExitCode    = $script:EXIT_CODE_TOOL_FAILURE
                    Status      = "TOOL_FAILURE"
                    Violations  = @("Target repo not found: $TargetRepo")
                    Warnings    = @()
                    ReasonCodes = @("TARGET_REPO_NOT_FOUND")
                }
            }
            $DiffText = git -C $TargetRepo diff HEAD 2>$null
            if ([string]::IsNullOrWhiteSpace($DiffText)) {
                $DiffText = git -C $TargetRepo diff 2>$null
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($DiffText)) {
        return @{
            ExitCode    = $script:EXIT_CODE_PASS
            Status      = "PASS"
            Violations  = @()
            Warnings    = @("No active diff detected; tree or patch is clean.")
            ReasonCodes = @("NO_DIFF")
        }
    }

    # 2. Inspect line-by-line additions and removals
    $lines = $DiffText -split "\r?\n"
    $currentFile = ""
    $bt = [char]96

    foreach ($line in $lines) {
        if ($line -match "^\+\+\+ b/(.*)") {
            $currentFile = $Matches[1]
            continue
        }

        # Added lines (+)
        if ($line -match "^\+([^\+].*)") {
            $added = $Matches[1]

            # Invariant 1: Race limit loops (< 8 or < 9 or [9])
            if ($added -match "for\s*\(.*<\s*(9|8)\s*;\s*\+\+.*race" -or $added -match "\[\s*9\s*\]\s*;\s*//.*race") {
                $violations.Add("${currentFile} - Hardcoded race limit detected ($added). In Tortoise-WoW, MAX_RACES is 11.")
                if (-not $reasonCodes.Contains("MAX_RACES_VIOLATION")) { [void]$reasonCodes.Add("MAX_RACES_VIOLATION") }
            }

            # Invariant 2: MAX_RACES reassignment or macro definition
            if ($added -match "MAX_RACES\s*(?:=|\s)\s*(8|9|10)\b" -or $added -match "#define\s+MAX_RACES\s+(8|9|10)\b") {
                $violations.Add("${currentFile} - MAX_RACES reassigned to $($Matches[1]). Must remain 11.")
                if (-not $reasonCodes.Contains("MAX_RACES_VIOLATION")) { [void]$reasonCodes.Add("MAX_RACES_VIOLATION") }
            }

            # Invariant 3: SCRIPT_COMMAND_TAKE_MONEY protection
            if ($added -match "SCRIPT_COMMAND_TAKE_MONEY\s*=\s*(?!93\b)\d+") {
                $violations.Add("${currentFile} - SCRIPT_COMMAND_TAKE_MONEY changed from 93. Violates client packet contract.")
                if (-not $reasonCodes.Contains("TAKE_MONEY_COMMAND_VIOLATION")) { [void]$reasonCodes.Add("TAKE_MONEY_COMMAND_VIOLATION") }
            }

            # Invariant 4: Architectural divergence check
            if ($manifest -and $manifest.architectural_divergences) {
                foreach ($ad in $manifest.architectural_divergences) {
                    if ($added -match $ad.pattern) {
                        $violations.Add("${currentFile} - Forbidden architectural pattern: $($ad.reason)")
                        if (-not $reasonCodes.Contains("ARCHITECTURAL_DIVERGENCE")) { [void]$reasonCodes.Add("ARCHITECTURAL_DIVERGENCE") }
                    }
                }
            }

            # Invariant 5: Forbidden progressive SQL columns
            if ($currentFile -like "*.sql") {
                foreach ($col in @("patch", "build", "min_patch", "max_patch", "patch_min", "patch_max")) {
                    $btCol = [string]::Concat($bt, $col, $bt)
                    if ($added -match "\b$col\b\s*=" -or $added.IndexOf($btCol, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                        $violations.Add("${currentFile} - Forbidden progressive column $col in SQL: $added")
                        if (-not $reasonCodes.Contains("FORBIDDEN_SQL_COLUMN")) { [void]$reasonCodes.Add("FORBIDDEN_SQL_COLUMN") }
                    }
                }

                # Invariant 6: Custom Entity ID clobbering (Entity-Specific ID guards)
                if ($currentFile -like "*spell_template*" -or $added -match "spell_template") {
                    if ($added -match "(?i)(?:DELETE\s+FROM|UPDATE)\s+`?spell_template`?.*?(?:entry|id)\s*(?:=|IN\s*\()\s*([4-9]\d{4,})") {
                        $cid = [int]$Matches[1]
                        if ($cid -ge 40000 -and $cid -lt 1000000) {
                            $violations.Add("${currentFile} - Clobbering Turtle-WoW custom spell entry $cid (>= 40000) detected!")
                            if (-not $reasonCodes.Contains("CUSTOM_SPELL_CLOBBER")) { [void]$reasonCodes.Add("CUSTOM_SPELL_CLOBBER") }
                        }
                    }
                }

                foreach ($tbl in @("creature_template", "quest_template", "gameobject_template", "item_template")) {
                    if ($currentFile -like "*$tbl*" -or $added -match $tbl) {
                        if ($added -match "(?i)(?:DELETE\s+FROM|UPDATE)\s+`?$tbl`?.*?(?:entry|id)\s*(?:=|IN\s*\()\s*([3-9]\d{5,})") {
                            $cid = $Matches[1]
                            $violations.Add("${currentFile} - Clobbering Turtle-WoW custom $tbl entry $cid (>= 300000) detected!")
                            if (-not $reasonCodes.Contains("CUSTOM_ENTITY_CLOBBER")) { [void]$reasonCodes.Add("CUSTOM_ENTITY_CLOBBER") }
                        }
                    }
                }
            }
        }

        # Removed lines (-)
        if ($line -match "^-([^-].*)") {
            $removed = $Matches[1]

            # Invariant 7: sTWDebuff removal
            if ($removed -match "sTWDebuff") {
                $violations.Add("${currentFile} - CRITICAL: Removal of $removed breaks Turtle debuff streaming!")
                if (-not $reasonCodes.Contains("STWDEBUFF_REMOVAL")) { [void]$reasonCodes.Add("STWDEBUFF_REMOVAL") }
            }

            # Invariant 8: SCRIPT_COMMAND_TAKE_MONEY deletion
            if ($removed -match "SCRIPT_COMMAND_TAKE_MONEY") {
                $violations.Add("${currentFile} - CRITICAL: Removal of SCRIPT_COMMAND_TAKE_MONEY breaks client protocol!")
                if (-not $reasonCodes.Contains("TAKE_MONEY_COMMAND_VIOLATION")) { [void]$reasonCodes.Add("TAKE_MONEY_COMMAND_VIOLATION") }
            }

            # Invariant 9: Custom manager hook removal
            if ($removed -match "sLFTMgr\." -or $removed -match "sTransmogMgr\." -or $removed -match "sCustomMerchantMgr\.") {
                $warnings.Add("${currentFile} - WARNING: Removal of custom Turtle manager hook: $removed")
                if (-not $reasonCodes.Contains("CUSTOM_MANAGER_MODIFIED")) { [void]$reasonCodes.Add("CUSTOM_MANAGER_MODIFIED") }
            }
        }
    }

    $hasViolations = ($violations.Count -gt 0)
    $status = if ($hasViolations) { "FAIL" } else { "PASS" }
    $exitCode = if ($hasViolations) { $script:EXIT_CODE_VALIDATION_FAILURE } else { $script:EXIT_CODE_PASS }

    return @{
        ExitCode    = $exitCode
        Status      = $status
        Violations  = @($violations)
        Warnings    = @($warnings)
        ReasonCodes = @($reasonCodes)
    }
}

function Test-PatchCompatibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("PatchContent")][string]$DiffText
    )
    return Test-TurtleCompatibility -DiffText $DiffText
}
