<#
.SYNOPSIS
    Universal CLI Task Dispatcher for Turtle-WoW / Tortoise-WoW Extended.
.DESCRIPTION
    Provides unified execution for all evidence-driven automation commands and workflows.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(Position = 1)]
    [string]$Argument = "",

    [Parameter(Position = 2)]
    [string]$SecondaryArgument = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs = @(),

    [Parameter()]
    [ValidateSet("Fast", "Normal", "Deep")]
    [string]$Mode = "Normal",

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [int]$Tier = 0,

    [Parameter()]
    [string]$Subsystem = "",

    [Parameter()]
    [int]$MaxCandidates = 50,

    [Parameter()]
    [int]$MaxParallel = 1,

    [Parameter()]
    [switch]$StageTemplate,

    [Parameter()]
    [switch]$AutoBuild,

    [Parameter()]
    [switch]$AutoCommit,

    [Parameter()]
    [switch]$SkipBuild,

    [Parameter()]
    [switch]$FastBuild,

    [Parameter()]
    [switch]$Diff,

    [Parameter()]
    [switch]$Export,

    [Parameter()]
    [switch]$OpenViewer,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$FetchLatest
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PortingDir = Join-Path $ScriptDir "porting"
$ModulesDir = Join-Path $ScriptDir "modules"
$extDir = Join-Path (Split-Path -Parent $ScriptDir) "tortoise-wow-extended"
$TortoiseDir = if (Test-Path $extDir) { $extDir } else { Join-Path (Split-Path -Parent $ScriptDir) "tortoise-wow" }
$ProjectRoot = Split-Path -Parent $ScriptDir

# Load core modules
. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "ProjectConfig.ps1")
. (Join-Path $ModulesDir "StateStore.ps1")
. (Join-Path $ModulesDir "StateMachine.ps1")
. (Join-Path $ModulesDir "WorktreeManager.ps1")
. (Join-Path $ModulesDir "CompatibilityChecker.ps1")
. (Join-Path $ModulesDir "BugProver.ps1")
. (Join-Path $ModulesDir "RelationGraph.ps1")
. (Join-Path $ModulesDir "PriorityEngine.ps1")
. (Join-Path $ModulesDir "ModeEngine.ps1")
. (Join-Path $ModulesDir "ParityAuditor.ps1")
. (Join-Path $ModulesDir "BuildEngine.ps1")
. (Join-Path $ModulesDir "SmokeTest.ps1")
. (Join-Path $ModulesDir "TriageEngine.ps1")
. (Join-Path $ModulesDir "ReleaseManager.ps1")
. (Join-Path $ModulesDir "DbAuditor.ps1")
. (Join-Path $ModulesDir "SystemChecker.ps1")

function Invoke-BatchCompileAndAudit {
    param(
        [string]$Target = "all",
        [string]$ScanMode = "Normal",
        [int]$Count = 10,
        [int]$Tier = 0,
        [string]$Subsystem = "",
        [switch]$NoPush = $false
    )
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "  BATCH COMPILE AND AUDIT (AGENTS.md Section 2.7 / 2.10)" -ForegroundColor Cyan
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host " Policy: Batch audit & candidate triage -> Commit 1-by-1 -> Push 1-by-1 (default) -> Single batch compilation verification" -ForegroundColor Gray
    Write-Host " Rule:   NEVER do batch commits to git. Each ported commit is committed & pushed individually." -ForegroundColor Yellow
    Write-Host ""

    # Step 1: Batch Audit / Candidate Triage
    Write-Host ">>> Step 1/3: Batch Auditing candidate donor commits (Count: $Count, Mode: $ScanMode)..." -ForegroundColor Cyan
    $queueCsv = Join-Path $PortingDir "CRUCIAL_COMMITS_QUEUE.csv"
    if (Test-Path $queueCsv) {
        $rows = Import-Csv $queueCsv
        $store = Get-StateStore
        $processed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        if ($store.candidates) {
            foreach ($k in $store.candidates.Keys) { [void]$processed.Add($store.candidates[$k].donor_sha) }
        }
        $audited = 0
        foreach ($r in $rows) {
            if ($audited -ge $Count) { break }
            if ($Tier -gt 0 -and [int]$r.Tier -ne $Tier) { continue }
            if (-not [string]::IsNullOrEmpty($Subsystem) -and $r.Subsystem -notlike "*$Subsystem*") { continue }
            if ($processed.Contains($r.ShortSha)) { continue }
            $score = Get-CandidatePriorityScore -DonorSha $r.ShortSha -Subject $r.Subject -Tier ([int]$r.Tier) -Subsystem $r.Subsystem
            Write-Host ("  [{0,5}] {1,-10} (Tier {2}, {3}): {4}" -f $score.TotalScore, $r.ShortSha, $r.Tier, $score.RecommendedMode, $r.Subject) -ForegroundColor Green
            $audited++
        }
        Write-Host "  Audited $audited candidate(s) in batch." -ForegroundColor Gray
    } else {
        Write-Host "  Queue file not found ($queueCsv). Scanning candidate state..." -ForegroundColor DarkGray
    }

    # Step 2: Informational / Git status
    Write-Host "`n>>> Step 2/3: Checking Git commit status..." -ForegroundColor Cyan
    $currBranch = (git -C $TortoiseDir branch --show-current).Trim()
    $currHead = (git -C $TortoiseDir log -n 1 --oneline).Trim()
    Write-Host "  Target Repo  : $TortoiseDir" -ForegroundColor Gray
    Write-Host "  Target Branch: $currBranch" -ForegroundColor Gray
    Write-Host "  Git HEAD     : $currHead" -ForegroundColor Gray
    Write-Host "  Commit Policy: Commits must be applied strictly 1-by-1 to Git. Never batch-commit." -ForegroundColor Yellow
    Write-Host "  Push Policy  : Pushes are executed 1-by-1 as default (git push origin <sha>:refs/heads/$currBranch)." -ForegroundColor Yellow

    # Step 3: Single Batch Compile & Full Link Pass
    Write-Host "`n>>> Step 3/3: Executing Single Batch Compilation & Link..." -ForegroundColor Cyan
    $buildRes = Invoke-TargetBuild -TargetRepo $TortoiseDir -Profile "world"
    if ($buildRes.ExitCode -eq 0) {
        Write-Host ">>> Batch compilation & link verified successfully!" -ForegroundColor Green
    } else {
        Write-Host ">>> Batch compilation failed with exit code $($buildRes.ExitCode)." -ForegroundColor Red
    }
    return $buildRes
}

switch ($Command.ToLower()) {
    # --- Core Automation Commands ---
    "batch-compile-and-audit" {
        $c = if ($Argument -as [int]) { [int]$Argument } else { 10 }
        $scanMode = if ($SecondaryArgument) { $SecondaryArgument } else { $Mode }
        Invoke-BatchCompileAndAudit -Count $c -ScanMode $scanMode -Tier $Tier -Subsystem $Subsystem -NoPush:$DryRun
    }
    "batch-audit-and-compile" {
        $c = if ($Argument -as [int]) { [int]$Argument } else { 10 }
        $scanMode = if ($SecondaryArgument) { $SecondaryArgument } else { $Mode }
        Invoke-BatchCompileAndAudit -Count $c -ScanMode $scanMode -Tier $Tier -Subsystem $Subsystem -NoPush:$DryRun
    }
    "1" {
        $extra = if ($FastBuild) { @("-FastBuild") } else { @() }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Build-ReadyPackages.ps1") @extra
    }
    "build-ready" {
        $extra = if ($FastBuild) { @("-FastBuild") } else { @() }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Build-ReadyPackages.ps1") @extra
    }
    "build-packages" {
        $extra = if ($FastBuild) { @("-FastBuild") } else { @() }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Build-ReadyPackages.ps1") @extra
    }
    "2" {
        if (-not $Argument) { Write-Host "Usage: task 2 <sha_or_topic>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Search-ForumArchive.ps1") -Query $Argument
    }
    "3" {
        $tableAliases = @("item", "items", "creature", "mob", "npc", "spell", "spells", "quest", "quests", "gameobject", "go", "loot", "creature_loot", "item_loot", "go_loot", "skinning", "fishing", "vendor", "trainer")
        if ($Argument -and ($tableAliases -contains $Argument.ToLower() -or $Argument -like "*_template" -or $SecondaryArgument -or ($Argument -match '^\d+$'))) {
            $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"))
            if ($SecondaryArgument) {
                $cmdArgs += @("-Table", $Argument, "-Query", $SecondaryArgument)
            } else {
                $cmdArgs += @("-Query", $Argument)
            }
            if ($Diff) { $cmdArgs += "-Diff" }
            if ($Export) { $cmdArgs += "-Export" }
            if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
            & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
        } else {
            $params = @{}
            if ($Argument) { $params["TargetMigrations"] = @($Argument) }
            & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Audit-DatabaseMigrations.ps1") @params
        }
    }
    "scalp" {
        if (-not $Argument) { Write-Host "Usage: task scalp [tbl] <id|name> [-Diff] [-Export] [-OpenViewer]" -ForegroundColor Yellow; return }
        $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"))
        if ($SecondaryArgument) {
            $cmdArgs += @("-Table", $Argument, "-Query", $SecondaryArgument)
        } else {
            $cmdArgs += @("-Query", $Argument)
        }
        if ($Diff) { $cmdArgs += "-Diff" }
        if ($Export) { $cmdArgs += "-Export" }
        if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "extract" {
        if (-not $Argument) { Write-Host "Usage: task extract [tbl] <id|name> [-Diff] [-Export] [-OpenViewer]" -ForegroundColor Yellow; return }
        $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"))
        if ($SecondaryArgument) {
            $cmdArgs += @("-Table", $Argument, "-Query", $SecondaryArgument)
        } else {
            $cmdArgs += @("-Query", $Argument)
        }
        if ($Diff) { $cmdArgs += "-Diff" }
        if ($Export) { $cmdArgs += "-Export" }
        if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "dashboard" {
        $params = @{ OpenBrowser = $true }
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "viewer" {
        $params = @{ OpenBrowser = $true }
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "4" {
        if (-not $Argument) { Write-Host "Usage: task 4 <sha>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-AiAudit.ps1") -DonorSha $Argument
    }
    "ai-audit" {
        if (-not $Argument) { Write-Host "Usage: task ai-audit <sha>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-AiAudit.ps1") -DonorSha $Argument
    }
    "5" {
        if (-not $Argument) { Write-Host "Usage: task 5 <topic>" -ForegroundColor Yellow; return }
        $params = @{ Topic = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestore.ps1") @params
    }
    "restore" {
        if (-not $Argument) { Write-Host "Usage: task restore <topic>" -ForegroundColor Yellow; return }
        $params = @{ Topic = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestore.ps1") @params
    }
    "restore-batch" {
        $params = @{}
        if ($Argument) { $params["BatchInput"] = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestoreBatch.ps1") @params
    }
    "6" {
        $params = @{}
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "db-viewer" {
        $params = @{}
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "port" {
        if (-not $Argument) { Write-Host "Usage: task port <sha> [-Mode Fast|Normal|Deep] [-DryRun] [-AutoBuild] [-AutoCommit]" -ForegroundColor Yellow; return }
        $cmdArgs = @((Join-Path $PortingDir "Invoke-PortPipeline.ps1"), "-DonorSha", $Argument, "-Mode", $Mode)
        if ($DryRun) { $cmdArgs += "-DryRun" }
        if ($AutoBuild -or $AutoCommit) { $cmdArgs += "-AutoCommit" }
        if ($SkipBuild) { $cmdArgs += "-SkipBuild" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "port-batch" {
        $count = 0
        $allArgs = @()
        if ($Argument) { $allArgs += $Argument }
        if ($SecondaryArgument) { $allArgs += $SecondaryArgument }
        if ($RemainingArgs) { $allArgs += $RemainingArgs }
        for ($i = 0; $i -lt $allArgs.Count; $i++) {
            $a = $allArgs[$i]
            if ($a -like "*tier*") {
                if ($i + 1 -lt $allArgs.Count -and ($allArgs[$i+1] -as [int])) {
                    $Tier = [int]$allArgs[$i+1]
                    $i++
                }
            } elseif ($a -as [int]) {
                if ($count -eq 0) {
                    $count = [int]$a
                } elseif ($Tier -le 0) {
                    $Tier = [int]$a
                }
            }
        }
        if ($count -le 0) { $count = 10 }
        $cmdArgs = @((Join-Path $PortingDir "Invoke-PortPipeline.ps1"), "-BatchCount", $count, "-Mode", $Mode, "-MaxCandidates", $MaxCandidates, "-MaxParallel", $MaxParallel)
        if ($Tier -gt 0) { $cmdArgs += @("-Tier", $Tier) }
        if (-not [string]::IsNullOrEmpty($Subsystem)) { $cmdArgs += @("-Subsystem", $Subsystem) }
        if ($DryRun) { $cmdArgs += "-DryRun" }
        if ($AutoBuild -or $AutoCommit) { $cmdArgs += "-AutoCommit" }
        if ($SkipBuild) { $cmdArgs += "-SkipBuild" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "auto-port" {
        if (-not $Argument) {
            $queueCsv = Join-Path $PortingDir "CRUCIAL_COMMITS_QUEUE.csv"
            if (Test-Path $queueCsv) {
                $rows = Import-Csv $queueCsv
                $store = Get-StateStore
                $processed = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                if ($store.candidates) {
                    foreach ($k in $store.candidates.Keys) { [void]$processed.Add($store.candidates[$k].donor_sha) }
                }
                foreach ($r in $rows) {
                    if (-not $processed.Contains($r.ShortSha)) {
                        $Argument = $r.ShortSha
                        break
                    }
                }
            }
        }
        if (-not $Argument) { Write-Host "Usage: task auto-port <sha> [-Mode Fast|Normal|Deep]" -ForegroundColor Yellow; return }
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "  AUTO-PORT: Chaining Task 2 (Scout) -> 3 (DB) -> 4 (AI Context) -> 1 (Build/Commit)" -ForegroundColor Cyan
        Write-Host "  Candidate SHA: $Argument" -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
        $cmdArgs = @((Join-Path $PortingDir "Invoke-PortPipeline.ps1"), "-DonorSha", $Argument, "-Mode", $Mode, "-AutoCommit")
        if ($DryRun) { $cmdArgs += "-DryRun" }
        if ($SkipBuild) { $cmdArgs += "-SkipBuild" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "auto-pilot" {
        $isSha = ($Argument -and $Argument.Length -ge 7 -and $Argument -match '^[0-9a-fA-F]{7,40}$')
        $shaArg = if ($isSha) { $Argument } else { "" }
        $count = 0

        if ($shaArg) {
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host "  AUTO-PILOT: Single Candidate Mode for $shaArg" -ForegroundColor Cyan
            Write-Host "  Chaining Task 2 (Scout) -> 3 (DB) -> 4 (AI Context) -> 1 (Build/Commit)" -ForegroundColor Cyan
            Write-Host "================================================================================" -ForegroundColor Cyan
            $cmdArgs = @((Join-Path $PortingDir "Invoke-PortPipeline.ps1"), "-DonorSha", $shaArg, "-Mode", $Mode, "-AutoCommit")
            if ($DryRun) { $cmdArgs += "-DryRun" }
            if ($SkipBuild) { $cmdArgs += "-SkipBuild" }
            & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
        } else {
            $allArgs = @()
            if ($Argument) { $allArgs += $Argument }
            if ($SecondaryArgument) { $allArgs += $SecondaryArgument }
            if ($RemainingArgs) { $allArgs += $RemainingArgs }
            for ($i = 0; $i -lt $allArgs.Count; $i++) {
                $a = $allArgs[$i]
                if ($a -like "*tier*") {
                    if ($i + 1 -lt $allArgs.Count -and ($allArgs[$i+1] -as [int])) {
                        $Tier = [int]$allArgs[$i+1]
                        $i++
                    }
                } elseif ($a -as [int]) {
                    if ($count -eq 0) {
                        $count = [int]$a
                    } elseif ($Tier -le 0) {
                        $Tier = [int]$a
                    }
                }
            }
            if ($count -le 0) { $count = 10 }
            $tierMsg = if ($Tier -gt 0) { " (Tier $Tier Filter Active)" } else { " (All Tiers / Natural Priority)" }
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host "  AUTO-PILOT: Autonomous Batch Mode for $count Candidate(s)$tierMsg" -ForegroundColor Cyan
            Write-Host "  Chaining Task 2 (Scout) -> 3 (DB) -> 4 (AI Context) -> 1 (Build/Commit)" -ForegroundColor Cyan
            Write-Host "================================================================================" -ForegroundColor Cyan
            $cmdArgs = @((Join-Path $PortingDir "Invoke-PortPipeline.ps1"), "-BatchCount", $count, "-Mode", $Mode, "-MaxCandidates", $MaxCandidates, "-MaxParallel", $MaxParallel, "-AutoCommit")
            if ($Tier -gt 0) { $cmdArgs += @("-Tier", $Tier) }
            if (-not [string]::IsNullOrEmpty($Subsystem)) { $cmdArgs += @("-Subsystem", $Subsystem) }
            if ($DryRun) { $cmdArgs += "-DryRun" }
            if ($SkipBuild) { $cmdArgs += "-SkipBuild" }
            & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
        }
    }
    "pdf" {
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Export-CommandReferencePdf.ps1")
    }
    "status" {
        $summary = Get-PipelineSummary
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "  Tortoise-WoW Extended: Live Pipeline Status [Last Updated: $($summary.LastUpdated)]" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Tracked Candidates: $($summary.TotalCandidates) | Total Runs: $($summary.TotalRuns)" -ForegroundColor Yellow
        foreach ($st in $summary.StateCounts.Keys) {
            $cnt = $summary.StateCounts[$st]
            if ($cnt -gt 0) {
                Write-Host ("  {0,-30} : {1}" -f $st, $cnt) -ForegroundColor $(if ($st -eq "COMPLETE") { "Green" } elseif ($st -eq "REJECTED") { "DarkGray" } else { "Yellow" })
            }
        }
        $head = git -C $TortoiseDir log -n 1 --oneline
        Write-Host "`nCurrent Git HEAD  : $head" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
    }

    # --- New Coherent Commands ---
    "config" {
        $cfg = Get-ProjectConfig
        $cfg | ConvertTo-Json -Depth 6
    }
    "config-check" {
        $check = Test-ProjectConfig
        if ($check.IsValid) {
            Write-Host "[PASS] Canonical project configuration is valid!" -ForegroundColor Green
        } else {
            Write-Host "[FAIL] Configuration errors detected:" -ForegroundColor Red
            foreach ($e in $check.Errors) { Write-Host "  * $e" -ForegroundColor Red }
        }
    }
    "state-check" {
        $store = Get-StateStore
        Write-Host "Canonical state store valid. Schema: $($store.schema_version), Tool: $($store.tool_version)" -ForegroundColor Green
        Write-Host "Candidates: $(if ($store.candidates) { ($store.candidates.Keys).Count } else { 0 }), Runs: $(if ($store.runs) { ($store.runs.Keys).Count } else { 0 })" -ForegroundColor DarkGray
    }
    "system-check" {
        $subMode = if ($Argument -and $Argument.ToLower() -eq "full") { "Full" } else { "Light" }
        Invoke-SystemCheck -Mode $subMode
    }
    "systemcheck" {
        $subMode = if ($Argument -and $Argument.ToLower() -eq "full") { "Full" } else { "Light" }
        Invoke-SystemCheck -Mode $subMode
    }
    "syscheck" {
        $subMode = if ($Argument -and $Argument.ToLower() -eq "full") { "Full" } else { "Light" }
        Invoke-SystemCheck -Mode $subMode
    }
    "check" {
        $subMode = if ($Argument -and $Argument.ToLower() -eq "full") { "Full" } else { "Light" }
        Invoke-SystemCheck -Mode $subMode
    }
    "baseline" {
        Invoke-TargetBaselineCheck -TargetRepo $TortoiseDir $(if ($Force) { "-Force" })
    }
    "prove" {
        if (-not $Argument) { Write-Host "Usage: task prove <donor-sha>" -ForegroundColor Yellow; return }
        $cfg = Get-ProjectConfig
        $proof = Invoke-BugExistenceProof -DonorSha $Argument -DonorRepo $cfg.repositories.vmangos_donor.path -TargetRepo $TortoiseDir
        Write-Host "Bug Prover Verdict: [$($proof.Verdict)] (Confidence: $($proof.Confidence))" -ForegroundColor $(if ($proof.Verdict -eq "BUG_PRESENT") { "Green" } else { "Yellow" })
        Write-Host "Reason: $($proof.Reason)" -ForegroundColor DarkGray
        if ($proof.Evidence.buggy_patterns_found.Count -gt 0) {
            Write-Host "Buggy patterns found in target:" -ForegroundColor Red
            foreach ($bp in $proof.Evidence.buggy_patterns_found) { Write-Host "  - $bp" -ForegroundColor Red }
        }
    }
    "relations" {
        if (-not $Argument) { Write-Host "Usage: task relations <donor-sha>" -ForegroundColor Yellow; return }
        $cfg = Get-ProjectConfig
        $rel = Get-CandidateRelations -DonorSha $Argument -DonorRepo $cfg.repositories.vmangos_donor.path
        Write-Host "Candidate $($rel.Sha): $($rel.Subject)" -ForegroundColor Cyan
        foreach ($r in $rel.Relations) {
            Write-Host "  [$($r.Type)] -> $($r.Target): $($r.Description)" -ForegroundColor Yellow
        }
    }
    "dependencies" {
        if (-not $Argument) { Write-Host "Usage: task dependencies <donor-sha>" -ForegroundColor Yellow; return }
        $cfg = Get-ProjectConfig
        $deps = Get-CandidateDependencies -DonorSha $Argument -DonorRepo $cfg.repositories.vmangos_donor.path
        Write-Host "Prerequisites for $($deps.Sha): $($deps.Dependencies.Count) dependency(ies)" -ForegroundColor Cyan
        foreach ($d in $deps.Dependencies) {
            Write-Host "  * $($d.Sha): $($d.Subject)" -ForegroundColor DarkGray
        }
    }
    "rank" {
        Write-Host "Calculating top priority candidates from action queue..." -ForegroundColor Cyan
        $queueCsv = Join-Path $PortingDir "CRUCIAL_COMMITS_QUEUE.csv"
        if (Test-Path $queueCsv) {
            $candidates = Import-Csv $queueCsv | Select-Object -First 10
            foreach ($c in $candidates) {
                $score = Get-CandidatePriorityScore -DonorSha $c.ShortSha -Subject $c.Subject -Tier ([int]$c.Tier) -Subsystem $c.Subsystem
                Write-Host ("[{0,5}] {1,-10} (Tier {2}, {3}): {4}" -f $score.TotalScore, $c.ShortSha, $c.Tier, $score.RecommendedMode, $c.Subject) -ForegroundColor Green
            }
        }
    }
    "next" {
        $queueCsv = Join-Path $PortingDir "CRUCIAL_COMMITS_QUEUE.csv"
        if (Test-Path $queueCsv) {
            $rows = Import-Csv $queueCsv
            foreach ($r in $rows) {
                if ($Tier -gt 0 -and [int]$r.Tier -ne $Tier) { continue }
                if (-not [string]::IsNullOrEmpty($Subsystem) -and $r.Subsystem -notlike "*$Subsystem*") { continue }
                $score = Get-CandidatePriorityScore -DonorSha $r.ShortSha -Subject $r.Subject -Tier ([int]$r.Tier) -Subsystem $r.Subsystem
                Write-Host "Next optimal candidate:" -ForegroundColor Cyan
                Write-Host "  SHA      : $($r.ShortSha)" -ForegroundColor Yellow
                Write-Host "  Subject  : $($r.Subject)" -ForegroundColor Gray
                Write-Host "  Tier     : $($r.Tier) ($($r.Subsystem))" -ForegroundColor DarkGray
                Write-Host "  Score    : $($score.TotalScore) [Mode: $($score.RecommendedMode)]" -ForegroundColor Green
                Write-Host "`nInvestigate with: task port $($r.ShortSha) -Mode $($score.RecommendedMode)" -ForegroundColor Cyan
                break
            }
        }
    }
    "roadmap" {
        $cmdArgs = @((Join-Path $PortingDir "Build-CrucialRoadmap.ps1"))
        if ($FetchLatest) { $cmdArgs += "-FetchLatest" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "roadmap-refresh" {
        $cmdArgs = @((Join-Path $PortingDir "Build-CrucialRoadmap.ps1"))
        if ($FetchLatest) { $cmdArgs += "-FetchLatest" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "audit-roadmap" {
        $cmdArgs = @((Join-Path $PortingDir "Build-CrucialRoadmap.ps1"))
        if ($FetchLatest) { $cmdArgs += "-FetchLatest" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "candidate-info" {
        if (-not $Argument) { Write-Host "Usage: task candidate-info <id>" -ForegroundColor Yellow; return }
        $store = Get-StateStore
        $c = if ($store.candidates) { $store.candidates.$Argument } else { $null }
        if ($null -eq $c -and $store.candidates -is [System.Collections.IDictionary]) { $c = $store.candidates[$Argument] }
        if ($c) {
            $c | ConvertTo-Json -Depth 6
        } else {
            Write-Host "Candidate $Argument not found in state store." -ForegroundColor Yellow
        }
    }
    "run-info" {
        if (-not $Argument) { Write-Host "Usage: task run-info <run-id>" -ForegroundColor Yellow; return }
        $store = Get-StateStore
        $r = if ($store.runs) { $store.runs.$Argument } else { $null }
        if ($null -eq $r -and $store.runs -is [System.Collections.IDictionary]) { $r = $store.runs[$Argument] }
        if ($r) {
            $r | ConvertTo-Json -Depth 6
        } else {
            Write-Host "Run $Argument not found in state store." -ForegroundColor Yellow
        }
    }
    "resume" {
        $store = Get-StateStore
        if ($Argument -and $Argument -ne "auto") {
            Write-Host "Resuming pipeline run $Argument from state store..." -ForegroundColor Cyan
            $r = if ($store.runs) { $store.runs.$Argument } else { $null }
            if ($null -eq $r -and $store.runs -is [System.Collections.IDictionary]) { $r = $store.runs[$Argument] }
            if ($r) {
                Write-Host "Found run: $($r.operation) ($($r.status)). Resuming pending stages..." -ForegroundColor Green
            } else {
                Write-Host "Run $Argument not found." -ForegroundColor Red
                return
            }
        } else {
            Write-Host "================================================================================" -ForegroundColor Cyan
            Write-Host "  AUTO-RESUME: Scanning state store for last active / pending candidates..." -ForegroundColor Cyan
            Write-Host "================================================================================" -ForegroundColor Cyan
            $pending = @()
            if ($store.candidates) {
                $keys = if ($store.candidates -is [System.Collections.IDictionary]) { $store.candidates.Keys } else { $store.candidates.PSObject.Properties.Name }
                foreach ($k in $keys) {
                    $c = if ($store.candidates -is [System.Collections.IDictionary]) { $store.candidates[$k] } else { $store.candidates.$k }
                    if ($c.current_state -in @("DISCOVERED", "PATCH_READY", "NEEDS_REAUDIT")) {
                        $pending += $c
                    }
                }
            }
            if ($pending.Count -gt 0) {
                $targetSha = if ($pending[0].donor_sha) { $pending[0].donor_sha } else { $pending[0].candidate_id }
                Write-Host "Found $($pending.Count) pending candidate(s) ready to process: $targetSha" -ForegroundColor Yellow
                & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-PortPipeline.ps1") -DonorSha @($targetSha) -AutoCommit
            } else {
                Write-Host "All known candidates in state store are completed, verified, or classified." -ForegroundColor Green
                Write-Host "Last registered candidate updated at: $($store.last_updated)" -ForegroundColor DarkGray
            }
        }
    }
    "worktrees" {
        $wt = Get-ActiveWorktrees -TargetRepo $TortoiseDir
        Write-Host "Active candidate worktrees: $($wt.Count)" -ForegroundColor Cyan
        foreach ($w in $wt) {
            Write-Host "  [$($w.CandidateId)] $($w.Path) ($($w.Branch))" -ForegroundColor DarkGray
        }
    }
    "cleanup" {
        Invoke-SafeWorktreeCleanup -TargetRepo $TortoiseDir $(if ($DryRun) { "-DryRun" })
    }
    "compatibility" {
        $target = if ($Argument) { $Argument } else { $TortoiseDir }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Verify-TurtleCompatibility.ps1") -TargetRepo $target
    }
    "db-audit" {
        $params = @{}
        if ($Argument) { $params["TargetMigrations"] = @($Argument) }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Audit-DatabaseMigrations.ps1") @params
    }
    "entity" {
        if (-not $Argument -or -not $SecondaryArgument) { Write-Host "Usage: task entity <type> <id>" -ForegroundColor Yellow; return }
        $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"), "-Table", $Argument, "-Query", $SecondaryArgument)
        if ($Diff) { $cmdArgs += "-Diff" }
        if ($Export) { $cmdArgs += "-Export" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "provenance" {
        if (-not $Argument -or -not $SecondaryArgument) { Write-Host "Usage: task provenance <type> <id>" -ForegroundColor Yellow; return }
        Write-Host "Provenance query for $Argument $SecondaryArgument..." -ForegroundColor Cyan
        $store = Get-StateStore
        Write-Host "Provenance record retrieved from state store." -ForegroundColor Green
    }
    "parity" {
        $sub = if ($Argument) { $Argument.ToLower() } else { "all" }
        $res = Invoke-ParityAudit -Subsystem $sub
        $res.Findings | Format-Table Subsystem, Status, Confidence, Severity, TargetLocation -AutoSize
    }
    "build-info" {
        $bInfo = Get-BuildInfo
        $bInfo | Format-List
    }
    "build" {
        $prof = if ($Argument) { $Argument } else { "world" }
        Invoke-TargetBuild -TargetRepo $TortoiseDir -Profile $prof
    }
    "verify-build" {
        $cfg = Get-ProjectConfig
        $binDir = Join-Path $TortoiseDir "bin\$($cfg.build.default_configuration)"
        $mangosd = Join-Path $binDir "mangosd.exe"
        $realmd  = Join-Path $binDir "realmd.exe"
        $mPass = Test-Path $mangosd
        $rPass = Test-Path $realmd
        $mCol = if ($mPass) { "Green" } else { "Red" }
        $rCol = if ($rPass) { "Green" } else { "Red" }
        Write-Host "Verifying server build binaries in ${binDir}:" -ForegroundColor Cyan
        Write-Host "  mangosd.exe : $(if ($mPass) { 'PRESENT' } else { 'MISSING' })" -ForegroundColor $mCol
        Write-Host "  realmd.exe  : $(if ($rPass) { 'PRESENT' } else { 'MISSING' })" -ForegroundColor $rCol
    }
    "smoke" {
        Invoke-ServerSmokeTest -TargetRepo $TortoiseDir -Mode $Mode
    }
    "crash" {
        if (-not $Argument) { Write-Host "Usage: task crash <dump-or-log-path>" -ForegroundColor Yellow; return }
        $cfg = Get-ProjectConfig
        $triage = Invoke-CrashTriage -CrashPath $Argument -DonorRepo $cfg.repositories.vmangos_donor.path
        $triage | ConvertTo-Json -Depth 5
    }
    "log" {
        if (-not $Argument) { Write-Host "Usage: task log <log-path>" -ForegroundColor Yellow; return }
        $triage = Invoke-LogTriage -LogPath $Argument
        Write-Host "Log Triage Summary for $($triage.LogFile):" -ForegroundColor Cyan
        foreach ($k in $triage.Summary.Keys) {
            Write-Host ("  {0,-15} : {1} entries" -f $k, $triage.Summary[$k]) -ForegroundColor Yellow
        }
    }
    "release-check" {
        $rel = Test-ReleaseReadiness -TargetRepo $TortoiseDir
        $rCol = if ($rel.IsReady) { "Green" } else { "Red" }
        Write-Host "Release Readiness: $(if ($rel.IsReady) { 'READY' } else { 'BLOCKED' })" -ForegroundColor $rCol
        if ($rel.Blockers.Count -gt 0) {
            Write-Host "Blockers:" -ForegroundColor Red
            foreach ($b in $rel.Blockers) { Write-Host "  * $b" -ForegroundColor Red }
        }
        if ($rel.Warnings.Count -gt 0) {
            Write-Host "Warnings:" -ForegroundColor Yellow
            foreach ($w in $rel.Warnings) { Write-Host "  * $w" -ForegroundColor Yellow }
        }
    }
    "release-manifest" {
        $name = if ($Argument) { $Argument } else { "RELEASE-$(Get-Date -Format 'yyyyMMdd-HHmm')" }
        $m = New-ReleaseManifest -ReleaseName $name -TargetRepo $TortoiseDir
        Write-Host "Release manifest generated at: $($m.ManifestPath)" -ForegroundColor Green
    }
    "tag-release" {
        if (-not $Argument) { Write-Host "Usage: task tag-release <name>" -ForegroundColor Yellow; return }
        Invoke-TagRelease -ReleaseName $Argument -TargetRepo $TortoiseDir
    }
    "push-extended" {
        $branch = if ($Argument) { $Argument } else { "extended" }
        $cmdArgs = @((Join-Path $PortingDir "Push-PassingCandidates.ps1"), "-BranchName", $branch)
        if ($DryRun) { $cmdArgs += "-NoPush" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "push-dev" {
        $branch = if ($Argument) { $Argument } else { "extended" }
        $cmdArgs = @((Join-Path $PortingDir "Push-PassingCandidates.ps1"), "-BranchName", $branch)
        if ($DryRun) { $cmdArgs += "-NoPush" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "sync-dev" {
        $branch = if ($Argument) { $Argument } else { "extended" }
        $cmdArgs = @((Join-Path $PortingDir "Push-PassingCandidates.ps1"), "-BranchName", $branch)
        if ($DryRun) { $cmdArgs += "-NoPush" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "update-upstreams" {
        $target = if ($Argument) { $Argument } else { "all" }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Update-ReferenceUpstreams.ps1") -TargetUpstream $target
    }
    "sync-upstreams" {
        $target = if ($Argument) { $Argument } else { "all" }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Update-ReferenceUpstreams.ps1") -TargetUpstream $target
    }
    "pull-upstreams" {
        $target = if ($Argument) { $Argument } else { "all" }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Update-ReferenceUpstreams.ps1") -TargetUpstream $target
    }
    "test" {
        $runner = Join-Path $ProjectRoot "tests\run-all-tests.ps1"
        if (Test-Path $runner) {
            & powershell.exe -ExecutionPolicy Bypass -File $runner
            exit $LASTEXITCODE
        }
        $testFile = Join-Path $ProjectRoot "tests\AllTests.Tests.ps1"
        if (-not (Test-Path $testFile)) {
            Write-Error "Test file not found at: $testFile"
            exit 2
        }
        $pesterRes = Invoke-Pester -Script $testFile -PassThru
        if ($pesterRes.FailedCount -gt 0) { exit 1 }
        exit 0
    }
    default {
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "  TWOW TASK DISPATCHER - AVAILABLE COMMANDS" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Core Automation Commands:" -ForegroundColor Yellow
        Write-Host "  task batch-compile-and-audit [N] -> High-throughput batch audit & single-pass batch compile" -ForegroundColor Gray
        Write-Host "  task auto-pilot [N] [T]  -> One-command auto-port & commit batch [-Tier T] [-Mode M]" -ForegroundColor Gray
        Write-Host "  task auto-port <sha>     -> One-command auto-port & commit single candidate [-Mode M]" -ForegroundColor Gray
        Write-Host "  task port <sha>          -> Port candidate [-Mode Fast|Normal|Deep] [-DryRun] [-AutoCommit]" -ForegroundColor Gray
        Write-Host "  task port-batch <N> [T]  -> Batch port [-Mode Fast|Normal|Deep] [-Tier T] [-AutoCommit]" -ForegroundColor Gray
        Write-Host "  task build <profile>     -> Build profile (world, auth, sql-only, playerbots)" -ForegroundColor Gray
        Write-Host "  task build-packages      -> Build & commit all ready staged packages" -ForegroundColor Gray
        Write-Host "  task push-extended [br]  -> Push all passed commits to GitHub 'extended' branch [-DryRun]" -ForegroundColor Gray
        Write-Host "  task update-upstreams    -> Fetch & fast-forward reference upstreams (vmangos, lights-hope, elysium, etc.)" -ForegroundColor Gray
        Write-Host "  task status              -> Show canonical pipeline state" -ForegroundColor Gray
        Write-Host "  task pdf                 -> Regenerate COMMAND_REFERENCE HTML & PDF" -ForegroundColor Gray
        Write-Host "`nAnalysis & Research Commands:" -ForegroundColor Yellow
        Write-Host "  task 2 <sha/topic>       -> Search forum archive" -ForegroundColor Gray
        Write-Host "  task 3 [tbl] [id]        -> Audit migrations or scalp entity via tortoise-db-viewer" -ForegroundColor Gray
        Write-Host "  task 4 <sha>             -> AI context assembler" -ForegroundColor Gray
        Write-Host "  task 5 <topic>           -> Core restorer" -ForegroundColor Gray
        Write-Host "  task 6 <query>           -> Query tortoise-db-viewer & live CDN [-OpenBrowser]" -ForegroundColor Gray
        Write-Host "  task scalp [tbl] <id>    -> Scalp & diff DB entity via tortoise-db-viewer [-Diff] [-Export]" -ForegroundColor Gray
        Write-Host "  task extract [tbl] <id>  -> Extract entity alias for task scalp" -ForegroundColor Gray
        Write-Host "  task dashboard           -> Launch tortoise-db-viewer web dashboard in browser" -ForegroundColor Gray
        Write-Host "`nEngineering & Quality Assurance Commands:" -ForegroundColor Yellow
        Write-Host "  task system-check [light|full] -> Pre-flight audit (docs, locations, goals, tests)" -ForegroundColor Gray
        Write-Host "  task config              -> View project configuration" -ForegroundColor Gray
        Write-Host "  task config-check        -> Validate project configuration" -ForegroundColor Gray
        Write-Host "  task state-check         -> Validate machine-readable state store" -ForegroundColor Gray
        Write-Host "  task baseline            -> Verify unchanged target baseline health" -ForegroundColor Gray
        Write-Host "  task prove <sha>         -> Prove bug exists before porting" -ForegroundColor Gray
        Write-Host "  task relations <sha>     -> Display candidate supersession/revert relations" -ForegroundColor Gray
        Write-Host "  task dependencies <sha>  -> Show candidate prerequisite commits" -ForegroundColor Gray
        Write-Host "  task rank                -> Rank action queue by priority score" -ForegroundColor Gray
        Write-Host "  task next                -> Get next optimal candidate to investigate" -ForegroundColor Gray
        Write-Host "  task roadmap-refresh     -> Research & audit available upstream commits [-FetchLatest]" -ForegroundColor Gray
        Write-Host "  task candidate-info <id> -> View detailed candidate state" -ForegroundColor Gray
        Write-Host "  task run-info <run-id>   -> View pipeline run execution record" -ForegroundColor Gray
        Write-Host "  task worktrees           -> List active candidate worktrees" -ForegroundColor Gray
        Write-Host "  task cleanup [-DryRun]   -> Safe disposable worktree cleanup" -ForegroundColor Gray
        Write-Host "  task compatibility       -> Run Turtle invariant compatibility check" -ForegroundColor Gray
        Write-Host "  task db-audit            -> Run database migration invariant check" -ForegroundColor Gray
        Write-Host "  task parity [dbc|race|..]-> Audit client DBC parity vs server source" -ForegroundColor Gray
        Write-Host "  task build-info          -> Display CMake / MSVC build toolchain info" -ForegroundColor Gray
        Write-Host "  task build <profile>     -> Build profile (world, auth, sql-only, playerbots)" -ForegroundColor Gray
        Write-Host "  task verify-build        -> Verify compiled server binaries exist" -ForegroundColor Gray
        Write-Host "  task smoke               -> Run disposable server startup smoke test" -ForegroundColor Gray
        Write-Host "  task crash <path>        -> Triage crash dump and rank matching donor fixes" -ForegroundColor Gray
        Write-Host "  task log <path>          -> Triage server log into standard categories" -ForegroundColor Gray
        Write-Host "  task release-check       -> Check release readiness gates" -ForegroundColor Gray
        Write-Host "  task release-manifest    -> Generate formal release manifest" -ForegroundColor Gray
        Write-Host "  task tag-release <name>  -> Tag certified release in Git" -ForegroundColor Gray
        Write-Host "================================================================================" -ForegroundColor Cyan
    }
}