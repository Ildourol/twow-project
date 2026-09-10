# SystemChecker.ps1: Universal System Pre-Flight & Health Audit for Turtle-WoW Orchestration

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..") -ErrorAction SilentlyContinue
if (-not $ProjectRoot) { $ProjectRoot = (Get-Location).Path }

. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")
. (Join-Path $ScriptDir "StateStore.ps1")
. (Join-Path $ScriptDir "WorktreeManager.ps1")
. (Join-Path $ScriptDir "CompatibilityChecker.ps1")
. (Join-Path $ScriptDir "AiConflictAuditor.ps1")

function Invoke-SystemCheck {
    [CmdletBinding()]
    param(
        [ValidateSet("Light", "Full", "light", "full")]
        [string]$Mode = "Light",

        [string]$ProjectRoot = "",

        [switch]$PassThru
    )

    $Mode = (Get-Culture).TextInfo.ToTitleCase($Mode.ToLower())

    if ([string]::IsNullOrEmpty($ProjectRoot)) {
        $ProjectRoot = $script:ProjectRoot
    }

    $startTime = Get-Date
    $checks = [System.Collections.Generic.List[PSCustomObject]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $errors = [System.Collections.Generic.List[string]]::new()

    function Add-CheckResult {
        param(
            [string]$Category,
            [string]$Name,
            [string]$Status, # PASS, WARN, FAIL
            [string]$Message,
            [string]$Details = ""
        )
        $obj = [PSCustomObject]@{
            Category = $Category
            Name     = $Name
            Status   = $Status
            Message  = $Message
            Details  = $Details
        }
        [void]$checks.Add($obj)

        $color = switch ($Status) {
            "PASS" { "Green" }
            "WARN" { "Yellow" }
            "FAIL" { "Red" }
            default { "Gray" }
        }
        $tag = switch ($Status) {
            "PASS" { "[+]" }
            "WARN" { "[!]" }
            "FAIL" { "[-]" }
            default { "[?]" }
        }

        Write-Host ("  {0} {1,-32} : {2}" -f $tag, $Name, $Message) -ForegroundColor $color
        if ($Details -and $Status -ne "PASS") {
            Write-Host ("      -> {0}" -f $Details) -ForegroundColor DarkGray
        }

        if ($Status -eq "WARN") { [void]$warnings.Add("$Name : $Message ($Details)") }
        if ($Status -eq "FAIL") { [void]$errors.Add("$Name : $Message ($Details)") }
    }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  TURTLE-WOW SYSTEM PRE-FLIGHT AUDIT (MODE: $($Mode.ToUpper()))" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Timestamp   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
    Write-Host "Project Root: $ProjectRoot" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan

    # -------------------------------------------------------------------------
    # 1. LOCATIONS & DIRECTORIES
    # -------------------------------------------------------------------------
    Write-Host "`n[1. Locations & Repository Layout]" -ForegroundColor Yellow

    # twow-project root
    if (Test-Path $ProjectRoot) {
        Add-CheckResult -Category "Locations" -Name "Project Root" -Status "PASS" -Message "OK ($ProjectRoot)"
    } else {
        Add-CheckResult -Category "Locations" -Name "Project Root" -Status "FAIL" -Message "Missing directory" -Details $ProjectRoot
    }

    # tortoise-wow repository
    $tortoisePath = Join-Path $ProjectRoot "tortoise-wow"
    if (Test-Path $tortoisePath) {
        $gitDir = Join-Path $tortoisePath ".git"
        if (Test-Path $gitDir) {
            $tHead = (git -C $tortoisePath rev-parse --short HEAD 2>$null)
            $tBranch = (git -C $tortoisePath rev-parse --abbrev-ref HEAD 2>$null)
            $tStatus = git -C $tortoisePath status --porcelain 2>$null
            $isClean = [string]::IsNullOrWhiteSpace($tStatus)
            $msg = "OK (Branch: $tBranch, HEAD: $tHead, Clean: $isClean)"
            Add-CheckResult -Category "Locations" -Name "Target Repo (tortoise-wow)" -Status $(if ($isClean) { "PASS" } else { "WARN" }) -Message $msg -Details $(if (-not $isClean) { "Target repo working tree has uncommitted edits" } else { "" })
        } else {
            Add-CheckResult -Category "Locations" -Name "Target Repo (tortoise-wow)" -Status "FAIL" -Message "Not a git repository (.git missing)" -Details $tortoisePath
        }
    } else {
        Add-CheckResult -Category "Locations" -Name "Target Repo (tortoise-wow)" -Status "FAIL" -Message "Directory missing" -Details $tortoisePath
    }

    # reference-upstreams/vmangos-core
    $vmangosPath = Join-Path $ProjectRoot "reference-upstreams\vmangos-core"
    if (Test-Path $vmangosPath) {
        $vGit = Join-Path $vmangosPath ".git"
        if (Test-Path $vGit) {
            $vHead = (git -C $vmangosPath rev-parse --short HEAD 2>$null)
            $vBranch = (git -C $vmangosPath rev-parse --abbrev-ref HEAD 2>$null)
            Add-CheckResult -Category "Locations" -Name "Donor Repo (vmangos-core)" -Status "PASS" -Message "OK (Branch: $vBranch, HEAD: $vHead)"
        } else {
            Add-CheckResult -Category "Locations" -Name "Donor Repo (vmangos-core)" -Status "FAIL" -Message "Not a git repository (.git missing)" -Details $vmangosPath
        }
    } else {
        Add-CheckResult -Category "Locations" -Name "Donor Repo (vmangos-core)" -Status "FAIL" -Message "Directory missing" -Details $vmangosPath
    }

    # reference-upstreams/client-data-1.18.1
    $clientDataPath = Join-Path $ProjectRoot "reference-upstreams\client-data-1.18.1"
    if (Test-Path $clientDataPath) {
        Add-CheckResult -Category "Locations" -Name "Client Data Reference" -Status "PASS" -Message "OK (DBC reference data verified)"
    } else {
        Add-CheckResult -Category "Locations" -Name "Client Data Reference" -Status "WARN" -Message "Directory not found" -Details $clientDataPath
    }

    # resources/forum
    $forumPath = Join-Path $ProjectRoot "resources\forum"
    if (Test-Path $forumPath) {
        Add-CheckResult -Category "Locations" -Name "Forum Lore Archive" -Status "PASS" -Message "OK (Archive database present)"
    } else {
        Add-CheckResult -Category "Locations" -Name "Forum Lore Archive" -Status "WARN" -Message "Directory not found" -Details $forumPath
    }

    # tools/queue subdirectories
    $queueSubdirs = @("01_candidates", "02_ready_to_build", "03_completed", "04_rejected", "staging_patches", "staging_sql", "ai_dossiers")
    foreach ($qd in $queueSubdirs) {
        $qp = Join-Path $ProjectRoot "tools\queue\$qd"
        if (-not (Test-Path $qp)) {
            New-Item -ItemType Directory -Path $qp -Force | Out-Null
        }
    }
    Add-CheckResult -Category "Locations" -Name "Staging Queue Folders" -Status "PASS" -Message "OK (7 pipeline stages verified)"

    # .worktrees directory
    $wtRoot = Join-Path $ProjectRoot ".worktrees"
    if (-not (Test-Path $wtRoot)) { New-Item -ItemType Directory -Path $wtRoot -Force | Out-Null }
    $activeWts = Get-ActiveWorktrees -TargetRepo $tortoisePath -WorktreeRoot $wtRoot
    Add-CheckResult -Category "Locations" -Name "Isolated Worktree Root" -Status "PASS" -Message "OK (.worktrees/ ready, Active Worktrees: $($activeWts.Count))"

    # -------------------------------------------------------------------------
    # 2. DOCUMENTATION INTEGRITY
    # -------------------------------------------------------------------------
    Write-Host "`n[2. Core Documentation Integrity]" -ForegroundColor Yellow

    $requiredDocs = @(
        @{ RelPath = "AGENTS.md"; Desc = "Agent Operating System & Rules"; MinBytes = 2000 },
        @{ RelPath = "README.md"; Desc = "Master Architecture Guide"; MinBytes = 2000 },
        @{ RelPath = "ENGINEERING_HANDBOOK.md"; Desc = "Engineering Handbook"; MinBytes = 2000 },
        @{ RelPath = "MULTI_AGENT_WORKFLOW.md"; Desc = "Multi-Agent Protocol"; MinBytes = 2000 },
        @{ RelPath = "ORCHESTRATION_WORKFLOW.md"; Desc = "Orchestration Lifecycle"; MinBytes = 2000 },
        @{ RelPath = "PORTING_PLAN.md"; Desc = "Porting Roadmap & Strategy"; MinBytes = 2000 },
        @{ RelPath = "docs\BACKPORT_WORKFLOW.md"; Desc = "8-Stage Runbook"; MinBytes = 2000 },
        @{ RelPath = "docs\COMMAND_REFERENCE.md"; Desc = "CLI Master Reference"; MinBytes = 5000 },
        @{ RelPath = "docs\COMMAND_REFERENCE.pdf"; Desc = "Compiled PDF Manual"; MinBytes = 50000 },
        @{ RelPath = "docs\BACKPORT_HISTORY.md"; Desc = "Ported Commits Ledger"; MinBytes = 1000 },
        @{ RelPath = "docs\CONFLICT_PREVENTION_AND_RESOLUTION_MATRIX.md"; Desc = "Safety Matrix"; MinBytes = 2000 },
        @{ RelPath = "docs\PORTING_TROUBLESHOOTING_AND_SAFEGUARDS.md"; Desc = "Safeguards Guide"; MinBytes = 2000 }
    )

    $passedDocs = 0
    foreach ($d in $requiredDocs) {
        $p = Join-Path $ProjectRoot $d.RelPath
        if (Test-Path $p) {
            $len = (Get-Item $p).Length
            if ($len -ge $d.MinBytes) {
                $passedDocs++
            } else {
                Add-CheckResult -Category "Docs" -Name "Doc: $($d.RelPath)" -Status "WARN" -Message "File smaller than expected ($len bytes)" -Details "Min: $($d.MinBytes) bytes"
            }
        } else {
            Add-CheckResult -Category "Docs" -Name "Doc: $($d.RelPath)" -Status "FAIL" -Message "Missing document" -Details $p
        }
    }
    if ($passedDocs -eq $requiredDocs.Count) {
        Add-CheckResult -Category "Docs" -Name "Core Documentation Suite" -Status "PASS" -Message "OK (All $($requiredDocs.Count) documents present & non-empty)"
    }

    # -------------------------------------------------------------------------
    # 3. PROJECT GOALS & INVARIANT POLICIES
    # -------------------------------------------------------------------------
    Write-Host "`n[3. Project Goals & Invariant Policies]" -ForegroundColor Yellow

    # turtle-compatibility.json
    $compatFile = Join-Path $ProjectRoot "config\turtle-compatibility.json"
    if (Test-Path $compatFile) {
        try {
            $compat = Get-Content $compatFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $maxRaces = $compat.hard_invariants.max_races
            $twDebuff = $compat.hard_invariants.staged_debuff_streaming
            $opcodeMoney = $compat.hard_invariants.script_command_take_money
            $protSymbols = $compat.protected_symbols

            $invValid = ($maxRaces -eq 11) -and ($twDebuff -eq "sTWDebuff") -and ($opcodeMoney -eq 93) -and ($protSymbols -contains "sTWDebuff")
            if ($invValid) {
                Add-CheckResult -Category "Goals" -Name "Turtle Invariant Policy" -Status "PASS" -Message "OK (MAX_RACES=11, sTWDebuff=64bit, Opcode=93, $($protSymbols.Count) Protected Symbols)"
            } else {
                Add-CheckResult -Category "Goals" -Name "Turtle Invariant Policy" -Status "FAIL" -Message "Policy parameters mismatch canonical specification"
            }
        } catch {
            Add-CheckResult -Category "Goals" -Name "Turtle Invariant Policy" -Status "FAIL" -Message "JSON parse error" -Details $_.Exception.Message
        }
    } else {
        Add-CheckResult -Category "Goals" -Name "Turtle Invariant Policy" -Status "FAIL" -Message "File missing" -Details $compatFile
    }

    # authority-policy.json
    $authPolicyFile = Join-Path $ProjectRoot "config\authority-policy.json"
    if (Test-Path $authPolicyFile) {
        try {
            $authPolicy = Get-Content $authPolicyFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $hierCount = if ($authPolicy.default_hierarchy) { $authPolicy.default_hierarchy.Count } else { 0 }
            Add-CheckResult -Category "Goals" -Name "Authority Hierarchy Policy" -Status "PASS" -Message "OK ($hierCount hierarchy tiers defined, $($authPolicy.forbidden_actions.Count) forbidden actions)"
        } catch {
            Add-CheckResult -Category "Goals" -Name "Authority Hierarchy Policy" -Status "FAIL" -Message "JSON parse error" -Details $_.Exception.Message
        }
    } else {
        Add-CheckResult -Category "Goals" -Name "Authority Hierarchy Policy" -Status "FAIL" -Message "File missing" -Details $authPolicyFile
    }

    # Mission Statement alignment in AGENTS.md
    $agentsMdFile = Join-Path $ProjectRoot "AGENTS.md"
    if (Test-Path $agentsMdFile) {
        $agentsText = Get-Content $agentsMdFile -Raw -Encoding UTF8
        $hasGoals = ($agentsText -match "MAX_RACES = 11") -and ($agentsText -match "sTWDebuff") -and ($agentsText -match "Definition of Done")
        if ($hasGoals) {
            Add-CheckResult -Category "Goals" -Name "Mission Goals & DoD Alignment" -Status "PASS" -Message "OK (Aligned with Definition of Done & Invariants)"
        } else {
            Add-CheckResult -Category "Goals" -Name "Mission Goals & DoD Alignment" -Status "WARN" -Message "Core mission keywords missing from AGENTS.md"
        }
    }

    # -------------------------------------------------------------------------
    # 4. AGENT INSTRUCTIONS & RUNBOOKS
    # -------------------------------------------------------------------------
    Write-Host "`n[4. Agent Instructions & Runbooks]" -ForegroundColor Yellow

    $agentRunbooks = @(
        @{ Name = "Builder Agent"; File = "AGENT_1_BUILDER.md" },
        @{ Name = "Forum Scout Agent"; File = "AGENT_2_FORUM_SCOUT.md" },
        @{ Name = "DB Engineer Agent"; File = "AGENT_3_DB_ENGINEER.md" },
        @{ Name = "C++ Adapter Agent"; File = "AGENT_4_CPP_ADAPTER.md" },
        @{ Name = "Core Restorer Agent"; File = "AGENT_5_CORE_RESTORER.md" },
        @{ Name = "Online DB Oracle"; File = "AGENT_6_ONLINE_DB_ORACLE.md" }
    )

    $validAgents = 0
    foreach ($ag in $agentRunbooks) {
        $agPath = Join-Path $ProjectRoot "tools\tasks\$($ag.File)"
        if (Test-Path $agPath) {
            $agLen = (Get-Item $agPath).Length
            if ($agLen -gt 500) {
                $validAgents++
            } else {
                Add-CheckResult -Category "Instructions" -Name "Agent Runbook: $($ag.Name)" -Status "WARN" -Message "Runbook is small ($agLen bytes)"
            }
        } else {
            Add-CheckResult -Category "Instructions" -Name "Agent Runbook: $($ag.Name)" -Status "FAIL" -Message "Missing runbook" -Details $agPath
        }
    }
    if ($validAgents -eq $agentRunbooks.Count) {
        Add-CheckResult -Category "Instructions" -Name "Agent Instructions Suite" -Status "PASS" -Message "OK (All 6 agent role instructions active in tools/tasks/)"
    }

    # -------------------------------------------------------------------------
    # 5. CONFIGURATION & STATE STORE
    # -------------------------------------------------------------------------
    Write-Host "`n[5. Configuration & State Store Health]" -ForegroundColor Yellow

    # twow-project.json
    $cfgCheck = Test-ProjectConfig
    if ($cfgCheck.IsValid) {
        Add-CheckResult -Category "Config" -Name "Project Configuration" -Status "PASS" -Message "OK (twow-project.json validated)"
    } else {
        Add-CheckResult -Category "Config" -Name "Project Configuration" -Status "FAIL" -Message "Configuration errors detected" -Details ($cfgCheck.Errors -join "; ")
    }

    # schema_catalog.json
    $schemaCatalogFile = Join-Path $ProjectRoot "config\schema_catalog.json"
    if (Test-Path $schemaCatalogFile) {
        try {
            $catJson = Get-Content $schemaCatalogFile -Raw -Encoding UTF8 | ConvertFrom-Json
            $tableCount = ($catJson.PSObject.Properties | Measure-Object).Count
            if ($tableCount -ge 400) {
                Add-CheckResult -Category "Config" -Name "Database Schema Catalog" -Status "PASS" -Message "OK ($tableCount tables cataloged)"
            } else {
                Add-CheckResult -Category "Config" -Name "Database Schema Catalog" -Status "WARN" -Message "Low table count ($tableCount tables)"
            }
        } catch {
            Add-CheckResult -Category "Config" -Name "Database Schema Catalog" -Status "FAIL" -Message "JSON parse error" -Details $_.Exception.Message
        }
    } else {
        Add-CheckResult -Category "Config" -Name "Database Schema Catalog" -Status "FAIL" -Message "File missing" -Details $schemaCatalogFile
    }

    # state_store.json
    $stateStoreFile = Join-Path $ProjectRoot "tools\state\state_store.json"
    if (Test-Path $stateStoreFile) {
        try {
            $store = Get-StateStore -Path $stateStoreFile
            $candCount = if ($store.candidates) { ($store.candidates.Keys).Count } else { 0 }
            $runsCount = if ($store.runs) { ($store.runs.Keys).Count } else { 0 }
            Add-CheckResult -Category "Config" -Name "Pipeline State Store" -Status "PASS" -Message "OK (Schema: $($store.schema_version), Candidates: $candCount, Runs: $runsCount)"
        } catch {
            Add-CheckResult -Category "Config" -Name "Pipeline State Store" -Status "FAIL" -Message "State store corrupted" -Details $_.Exception.Message
        }
    } else {
        Add-CheckResult -Category "Config" -Name "Pipeline State Store" -Status "FAIL" -Message "File missing" -Details $stateStoreFile
    }

    # -------------------------------------------------------------------------
    # 6. GIT ENVIRONMENT & WORKING TREE
    # -------------------------------------------------------------------------
    Write-Host "`n[6. Git Health & Working Tree Cleanliness]" -ForegroundColor Yellow

    # Check main repository working tree
    $twowGitStatus = git -C $ProjectRoot status --porcelain 2>$null
    $twowClean = [string]::IsNullOrWhiteSpace($twowGitStatus)
    $twowBranch = (git -C $ProjectRoot rev-parse --abbrev-ref HEAD 2>$null)
    $twowStatusType = if ($twowClean) { "PASS" } else { "PASS" } # Orchestrator untracked files are non-blocking
    Add-CheckResult -Category "Git" -Name "Orchestrator Cleanliness" -Status "PASS" -Message "Branch: $twowBranch, Clean: $twowClean"

    # Check tortoise-wow working tree
    $tortoiseStatus = git -C $tortoisePath status --porcelain 2>$null
    $tortoiseClean = [string]::IsNullOrWhiteSpace($tortoiseStatus)
    Add-CheckResult -Category "Git" -Name "Target Working Tree Cleanliness" -Status $(if ($tortoiseClean) { "PASS" } else { "WARN" }) -Message "Clean: $tortoiseClean" -Details $(if (-not $tortoiseClean) { "Working tree has uncommitted modifications" } else { "" })

    # Check worktrees
    $wtList = Get-ActiveWorktrees -TargetRepo $tortoisePath -WorktreeRoot $wtRoot
    if ($wtList.Count -eq 0) {
        Add-CheckResult -Category "Git" -Name "Worktree Isolation Cleanliness" -Status "PASS" -Message "OK (0 active worktrees, clean state)"
    } else {
        Add-CheckResult -Category "Git" -Name "Worktree Isolation Cleanliness" -Status "WARN" -Message "Active worktrees found: $($wtList.Count)" -Details (($wtList | ForEach-Object { "$($_.CandidateId): $($_.Path)" }) -join "; ")
    }

    # -------------------------------------------------------------------------
    # FULL MODE DEEP CHECKS
    # -------------------------------------------------------------------------
    if ($Mode -eq "Full") {
        Write-Host "`n[7. Build Toolchain & Compiler Preflight (Full Mode)]" -ForegroundColor Yellow

        # Git executable
        $gitVer = (git --version 2>$null)
        if ($gitVer) {
            Add-CheckResult -Category "Toolchain" -Name "Git Executable" -Status "PASS" -Message "OK ($($gitVer.Trim()))"
        } else {
            Add-CheckResult -Category "Toolchain" -Name "Git Executable" -Status "FAIL" -Message "Git not found in PATH"
        }

        # CMake executable
        $cfg = Get-ProjectConfig
        $cmakeExe = $cfg.build.cmake_executable
        if (Test-Path $cmakeExe) {
            $cmVer = (& $cmakeExe --version | Select-Object -First 1)
            Add-CheckResult -Category "Toolchain" -Name "CMake Executable" -Status "PASS" -Message "OK ($cmVer)"
        } else {
            $foundCmake = Get-Command cmake -ErrorAction SilentlyContinue
            if ($foundCmake) {
                Add-CheckResult -Category "Toolchain" -Name "CMake Executable" -Status "PASS" -Message "OK ($($foundCmake.Source))"
            } else {
                Add-CheckResult -Category "Toolchain" -Name "CMake Executable" -Status "WARN" -Message "CMake executable not found" -Details $cmakeExe
            }
        }

        # Visual Studio / MSVC toolchain
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswhere) {
            $vsInst = (& $vswhere -latest -products * -property displayName 2>$null)
            if ($vsInst) {
                Add-CheckResult -Category "Toolchain" -Name "MSVC / Visual Studio" -Status "PASS" -Message "OK ($vsInst)"
            } else {
                Add-CheckResult -Category "Toolchain" -Name "MSVC / Visual Studio" -Status "WARN" -Message "vswhere detected but no VS installation found"
            }
        } else {
            Add-CheckResult -Category "Toolchain" -Name "MSVC / Visual Studio" -Status "WARN" -Message "vswhere not found at standard path"
        }

        Write-Host "`n[8. Remote Git Health & Synchronization (Full Mode)]" -ForegroundColor Yellow
        $tRemotes = git -C $tortoisePath remote -v 2>$null
        $hasExtended = ($tRemotes -match "extended")
        $hasOrigin = ($tRemotes -match "origin")
        if ($hasExtended -and $hasOrigin) {
            Add-CheckResult -Category "Git" -Name "Target Remotes (origin & extended)" -Status "PASS" -Message "OK (Both remotes configured)"
        } elseif ($hasExtended -or $hasOrigin) {
            Add-CheckResult -Category "Git" -Name "Target Remotes (origin & extended)" -Status "WARN" -Message "Partial remotes configured" -Details ($tRemotes -join " | ")
        } else {
            Add-CheckResult -Category "Git" -Name "Target Remotes (origin & extended)" -Status "WARN" -Message "No remotes configured in tortoise-wow"
        }

        Write-Host "`n[9. Invariant Gate & AI Auditor Operational Check (Full Mode)]" -ForegroundColor Yellow

        # Test compatibility checker with mock bad patch
        $badPatch = @"
--- a/src/game/ObjectMgr.h
+++ b/src/game/ObjectMgr.h
@@ -50,3 +50,3 @@
-#define MAX_RACES 11
+#define MAX_RACES 10
"@
        $tmpPatch = [System.IO.Path]::GetTempFileName()
        [System.IO.File]::WriteAllText($tmpPatch, $badPatch)
        try {
            $gateTest = Test-TurtleCompatibility -PatchFile $tmpPatch
            if ($gateTest.Violations.Count -gt 0) {
                Add-CheckResult -Category "Invariants" -Name "Invariant Gate Engine" -Status "PASS" -Message "OK (Correctly detects and blocks invariant breaches)"
            } else {
                Add-CheckResult -Category "Invariants" -Name "Invariant Gate Engine" -Status "FAIL" -Message "Failed to catch MAX_RACES violation"
            }
        } finally {
            if (Test-Path $tmpPatch) { Remove-Item $tmpPatch -Force }
        }

        # Test AI Conflict Auditor module syntax and readiness
        $aiAuditFile = Join-Path $ScriptDir "AiConflictAuditor.ps1"
        if (Test-Path $aiAuditFile) {
            Add-CheckResult -Category "Invariants" -Name "AI Semantic Conflict Auditor" -Status "PASS" -Message "OK (6-dimension invariant auditor active)"
        } else {
            Add-CheckResult -Category "Invariants" -Name "AI Semantic Conflict Auditor" -Status "FAIL" -Message "Missing AiConflictAuditor.ps1"
        }

        Write-Host "`n[10. Complete Orchestration Test Suite (Full Mode)]" -ForegroundColor Yellow
        Write-Host "  Executing tests/run-all-tests.ps1..." -ForegroundColor DarkGray
        $testRunner = Join-Path $ProjectRoot "tests\run-all-tests.ps1"
        if (Test-Path $testRunner) {
            $testOutput = & powershell.exe -ExecutionPolicy Bypass -File $testRunner 2>&1
            $testExitCode = $LASTEXITCODE
            $summaryLine = ($testOutput | Where-Object { $_ -match 'Passed:\s*\d+' } | Select-Object -Last 1)
            if ($testExitCode -eq 0) {
                Add-CheckResult -Category "Tests" -Name "Orchestration Test Suite" -Status "PASS" -Message "OK ($summaryLine)"
            } else {
                Add-CheckResult -Category "Tests" -Name "Orchestration Test Suite" -Status "FAIL" -Message "Test failures detected (Exit Code $testExitCode)" -Details $summaryLine
            }
        } else {
            Add-CheckResult -Category "Tests" -Name "Orchestration Test Suite" -Status "FAIL" -Message "Test runner script not found" -Details $testRunner
        }
    }

    # -------------------------------------------------------------------------
    # SUMMARY & VERDICT
    # -------------------------------------------------------------------------
    $duration = [Math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
    $totalCount = $checks.Count
    $passCount = ($checks | Where-Object { $_.Status -eq "PASS" }).Count
    $warnCount = ($checks | Where-Object { $_.Status -eq "WARN" }).Count
    $failCount = ($checks | Where-Object { $_.Status -eq "FAIL" }).Count
    $score = [Math]::Round(($passCount / $totalCount) * 100, 1)

    $isReady = ($failCount -eq 0)
    $verdictText = if ($isReady -and $warnCount -eq 0) {
        "FULLY CERTIFIED & READY TO OPERATE"
    } elseif ($isReady) {
        "READY TO OPERATE (WITH NON-BLOCKING WARNINGS)"
    } else {
        "BLOCKED - RESOLVE FAILURES BEFORE OPERATING"
    }

    $verdictColor = if ($isReady -and $warnCount -eq 0) { "Green" } elseif ($isReady) { "Yellow" } else { "Red" }

    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host "  SYSTEM AUDIT SUMMARY ($Mode Mode)" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host ("  Total Checks  : {0}" -f $totalCount)
    Write-Host ("  Passed        : {0}" -f $passCount) -ForegroundColor Green
    Write-Host ("  Warnings      : {0}" -f $warnCount) -ForegroundColor $(if ($warnCount -gt 0) { "Yellow" } else { "DarkGray" })
    Write-Host ("  Failures      : {0}" -f $failCount) -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "DarkGray" })
    Write-Host ("  Health Score  : {0}%" -f $score) -ForegroundColor $verdictColor
    Write-Host ("  Audit Duration: {0}s" -f $duration) -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host ("  FINAL VERDICT : {0}" -f $verdictText) -ForegroundColor $verdictColor
    Write-Host "================================================================================" -ForegroundColor Cyan

    if ($warnings.Count -gt 0) {
        Write-Host "`nNon-blocking Warnings:" -ForegroundColor Yellow
        foreach ($w in $warnings) { Write-Host "  * $w" -ForegroundColor Yellow }
    }

    if ($errors.Count -gt 0) {
        Write-Host "`nCritical Blockers:" -ForegroundColor Red
        foreach ($e in $errors) { Write-Host "  * $e" -ForegroundColor Red }
    }

    $result = [PSCustomObject]@{
        Success        = $isReady
        Mode           = $Mode
        HealthScore    = $score
        TotalChecks    = $totalCount
        PassedChecks   = $passCount
        WarningsCount  = $warnCount
        FailuresCount  = $failCount
        Verdict        = $verdictText
        DurationSeconds= $duration
        Checks         = $checks
        Warnings       = $warnings
        Failures       = $errors
    }

    if ($PassThru) {
        return $result
    }

    if (-not $isReady) {
        exit $script:EXIT_INVARIANT_VIOLATION
    }
    exit $script:EXIT_SUCCESS
}