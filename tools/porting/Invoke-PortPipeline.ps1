<#
.SYNOPSIS
    Unified Port Pipeline: Bug Proof -> Triage -> Compatibility -> Build/Worktree Staging
.DESCRIPTION
    Evidence-driven pipeline supporting Fast, Normal, and Deep verification modes,
    automatic escalation, DryRun planning, run IDs, and structured state tracking.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$DonorSha = @(),

    [Parameter()]
    [int]$BatchCount = 0,

    [Parameter()]
    [int]$Tier = 0,

    [Parameter()]
    [string]$Subsystem = "",

    [Parameter()]
    [ValidateSet("Fast", "Normal", "Deep")]
    [string]$Mode = "Normal",

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [int]$MaxCandidates = 50,

    [Parameter()]
    [int]$MaxParallel = 1,

    [Parameter()]
    [switch]$AutoBuild,

    [Parameter()]
    [switch]$AutoCommit,

    [Parameter()]
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesDir = Join-Path (Split-Path -Parent $ScriptDir) "tools\modules"
if (-not (Test-Path $ModulesDir)) { $ModulesDir = Join-Path $ScriptDir "..\modules" }

. (Join-Path $ModulesDir "ExitCodes.ps1")
. (Join-Path $ModulesDir "ProjectConfig.ps1")
. (Join-Path $ModulesDir "StructuredResult.ps1")
. (Join-Path $ModulesDir "EncodingHelper.ps1")
. (Join-Path $ModulesDir "StateStore.ps1")
. (Join-Path $ModulesDir "StateMachine.ps1")
. (Join-Path $ModulesDir "WorktreeManager.ps1")
. (Join-Path $ModulesDir "CompatibilityChecker.ps1")
. (Join-Path $ModulesDir "BugProver.ps1")
. (Join-Path $ModulesDir "RelationGraph.ps1")
. (Join-Path $ModulesDir "PriorityEngine.ps1")
. (Join-Path $ModulesDir "ModeEngine.ps1")
. (Join-Path $ModulesDir "AiController.ps1")

$cfg = Get-ProjectConfig
$ProjectRoot = $cfg.repositories.twow_project.path
$VmangosRepo = $cfg.repositories.vmangos_donor.path
$TortoiseRepo = $cfg.repositories.tortoise_wow.path
$QueueDir = Join-Path $ProjectRoot "tools\queue"
$ReadyDir = Join-Path $QueueDir "02_ready_to_build"
$CompletedDir = Join-Path $QueueDir "03_completed"
$RejectedDir = Join-Path $QueueDir "04_rejected"
$StagingPatches = Join-Path $QueueDir "staging_patches"
$StagingSql = Join-Path $QueueDir "staging_sql"

# 1. Resolve candidates
$shasToProcess = [System.Collections.Generic.List[string]]::new()

if ($DonorSha.Count -gt 0) {
    foreach ($s in $DonorSha) { [void]$shasToProcess.Add($s.Trim()) }
} elseif ($BatchCount -gt 0) {
    $queueCsv = Join-Path $ScriptDir "CRUCIAL_COMMITS_QUEUE.csv"
    if (-not (Test-Path $queueCsv)) {
        Write-Host "[ERROR] Queue file not found: $queueCsv" -ForegroundColor Red
        exit $script:EXIT_CODE_TOOL_FAILURE
    }

    $store = Get-StateStore
    $processedShas = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if ($store.candidates) {
        foreach ($k in $store.candidates.Keys) {
            $c = $store.candidates[$k]
            [void]$processedShas.Add($c.donor_sha)
        }
    }

    $csvRows = Import-Csv -Path $queueCsv
    $count = 0
    foreach ($row in $csvRows) {
        $cSha = $row.ShortSha
        $cTier = [int]$row.Tier
        $cSub = $row.Subsystem

        if ($processedShas.Contains($cSha)) { continue }
        if ($Tier -gt 0 -and $cTier -ne $Tier) { continue }
        if (-not [string]::IsNullOrEmpty($Subsystem) -and $cSub -notlike "*$Subsystem*") { continue }

        [void]$shasToProcess.Add($cSha)
        $count++
        if ($count -ge $BatchCount -or $count -ge $MaxCandidates) { break }
    }
} else {
    Write-Host "Usage: task port <sha> [-Mode Fast|Normal|Deep] [-DryRun]" -ForegroundColor Yellow
    Write-Host "       task port-batch <N> [-Tier T] [-Subsystem S] [-Mode Fast|Normal|Deep] [-DryRun]" -ForegroundColor Yellow
    exit $script:EXIT_CODE_PASS
}

$runId = New-RunId
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  TWOW PORT PIPELINE [Run: $runId]" -ForegroundColor Cyan
Write-Host "  Candidates: $($shasToProcess.Count) | Mode: $Mode | DryRun: $([bool]$DryRun)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

function Get-NextPortId {
    $existing = Get-ChildItem -Path $CompletedDir, $ReadyDir -Filter "PORT-*.json" -ErrorAction SilentlyContinue
    $maxNum = 0
    if ($existing) {
        foreach ($f in $existing) {
            if ($f.Name -match 'PORT-(\d+)\.json') {
                $n = [int]$Matches[1]
                if ($n -gt $maxNum) { $maxNum = $n }
            }
        }
    }
    return ("PORT-{0:D4}" -f ($maxNum + 1))
}

$results = [System.Collections.Generic.List[object]]::new()

foreach ($sha in $shasToProcess) {
    Write-Host "`n>>> Processing Candidate: $sha" -ForegroundColor Cyan
    $startedAt = Get-Date

    # If DryRun requested, generate plan only and continue
    if ($DryRun) {
        $plan = Invoke-CandidatePlan -DonorSha $sha -RequestedMode $Mode -DryRun
        [void]$results.Add($plan)
        continue
    }

    # 1. Deterministic Bug-Existence Prover
    $proof = Invoke-BugExistenceProof -DonorSha $sha -DonorRepo $VmangosRepo -TargetRepo $TortoiseRepo
    Write-Host "  [1/4] Bug Verdict: [$($proof.Verdict)] (Confidence: $($proof.Confidence))" -ForegroundColor $(if ($proof.Verdict -eq "BUG_PRESENT") { "Green" } elseif ($proof.Verdict -eq "ALREADY_FIXED") { "DarkGray" } else { "Yellow" })

    # Register candidate in state store
    $targetBaseSha = (git -C $TortoiseRepo rev-parse HEAD).Trim()
    $cState = Register-Candidate -CandidateId $sha -DonorSha $sha -DonorFullSha $proof.Evidence.donor_full_sha -Subject $proof.Evidence.subject -TargetBaseSha $targetBaseSha

    if ($proof.Verdict -eq "ALREADY_FIXED") {
        Update-CandidateState -CandidateId $sha -ToState "ALREADY_FIXED" -ReasonCode "BUG_PROVER_ALREADY_FIXED" -Verdict "ALREADY_FIXED" -Evidence $proof.Evidence | Out-Null
        Write-Host "  Candidate already fixed in target; skipping." -ForegroundColor DarkGray
        continue
    }
    if ($proof.Verdict -eq "NOT_APPLICABLE") {
        Update-CandidateState -CandidateId $sha -ToState "NOT_APPLICABLE" -ReasonCode "BUG_PROVER_NOT_APPLICABLE" -Verdict "NOT_APPLICABLE" -Evidence $proof.Evidence | Out-Null
        Write-Host "  Candidate not applicable to Turtle architecture; skipping." -ForegroundColor DarkGray
        continue
    }
    if ($proof.Verdict -eq "TURTLE_INTENTIONAL_DIVERGENCE") {
        Update-CandidateState -CandidateId $sha -ToState "TURTLE_INTENTIONAL_DIVERGENCE" -ReasonCode "BUG_PROVER_TURTLE_DIVERGENCE" -Verdict "TURTLE_INTENTIONAL_DIVERGENCE" -Evidence $proof.Evidence | Out-Null
        Write-Host "  Candidate rejected due to intentional Turtle architecture divergence." -ForegroundColor Yellow
        continue
    }

    # 2. Dependency and Supersession Graph
    $rel = Get-CandidateRelations -DonorSha $sha -DonorRepo $VmangosRepo
    $deps = Get-CandidateDependencies -DonorSha $sha -DonorRepo $VmangosRepo
    Write-Host "  [2/4] Graph: $($deps.Dependencies.Count) prerequisite(s), $($rel.Relations.Count) relation(s)" -ForegroundColor DarkGray

    # 3. Mode Resolution & Escalation
    $context = @{
        Subject         = $proof.Evidence.subject
        Confidence      = $proof.Confidence
        DependencyCount = $deps.Dependencies.Count
        Subsystem       = "Core"
    }
    $modeRes = Resolve-VerificationMode -RequestedMode $Mode -CandidateContext $context
    if ($modeRes.Escalated) {
        Write-Host "  [ESCALATION] Mode escalated to $($modeRes.EffectiveMode): $($modeRes.EscalationReason)" -ForegroundColor Yellow
    }

    # 4. Safe Patch Export
    $patchFile = Join-Path $StagingPatches "$sha.patch"
    Export-GitPatchSafely -RepoPath $VmangosRepo -Sha $sha -DestinationPatchPath $patchFile | Out-Null

    # 5. Turtle Invariant Verification
    $compat = Test-TurtleCompatibility -PatchFile $patchFile
    if ($compat.ExitCode -ne 0) {
        $violMsg = $compat.Violations -join ", "
        Write-Host "  [FAIL] Hard Turtle compatibility invariant violated: $violMsg" -ForegroundColor Red
        Update-CandidateState -CandidateId $sha -ToState "REJECTED" -ReasonCode "COMPATIBILITY_VIOLATION" -Verdict "REJECTED" | Out-Null
        continue
    }

    # --- Task 2: Forum & Mechanics Intelligence Scout ---
    $searchScript = Join-Path $ScriptDir "Search-ForumArchive.ps1"
    if (Test-Path $searchScript) {
        $cleanSubj = ($proof.Evidence.subject -replace '[^\w\s]', ' ' -split '\s+' | Where-Object { $_.Length -gt 4 })
        $forumMatches = @()
        foreach ($kw in ($cleanSubj | Select-Object -First 2)) {
            $hits = & powershell.exe -ExecutionPolicy Bypass -File $searchScript -Query $kw -Limit 2 2>$null
            if ($hits) {
                foreach ($h in $hits) {
                    if ($h -match '\[Thread \d+\]') { $forumMatches += $h.Trim() }
                }
            }
        }
        if ($forumMatches.Count -gt 0) {
            Write-Host "  [Task 2 Scout] Discovered $($forumMatches.Count) related Turtle forum thread(s)" -ForegroundColor DarkGray
            $proof.Evidence["forum_threads"] = $forumMatches
        }
    }

    # --- Task 3: Database & Migration Safety Audit ---
    $touchedSql = git -C $VmangosRepo diff-tree --no-commit-id --name-only -r $sha 2>$null | Where-Object { $_ -like "*.sql" }
    $stagedSqlRel = $null
    if ($touchedSql) {
        Write-Host "  [Task 3 DB Audit] Candidate touches $($touchedSql.Count) database file(s)" -ForegroundColor Yellow
        $dbScript = Join-Path $ScriptDir "Audit-DatabaseMigrations.ps1"
        if (Test-Path $dbScript) {
            & powershell.exe -ExecutionPolicy Bypass -File $dbScript -TargetMigrations $touchedSql 2>&1 | Out-Null
        }
        $sqlStagingDir = Join-Path $ProjectRoot "tools\queue\staging_sql"
        if (-not (Test-Path $sqlStagingDir)) { New-Item -ItemType Directory -Path $sqlStagingDir -Force | Out-Null }
        foreach ($sqlRel in $touchedSql) {
            $sqlSrc = Join-Path $VmangosRepo $sqlRel
            if (Test-Path $sqlSrc) {
                $sqlDest = Join-Path $sqlStagingDir ([System.IO.Path]::GetFileName($sqlRel))
                Copy-Item $sqlSrc $sqlDest -Force
                $stagedSqlRel = "tools/queue/staging_sql/" + ([System.IO.Path]::GetFileName($sqlRel))
            }
        }
    }

    # --- Task 4: AI Context Assembly & Semantic Dossier ---
    $aiAuditScript = Join-Path $ScriptDir "Invoke-AiAudit.ps1"
    if (Test-Path $aiAuditScript) {
        Write-Host "  [Task 4 AI Context] Generating AI semantic audit dossier..." -ForegroundColor DarkGray
        & powershell.exe -ExecutionPolicy Bypass -File $aiAuditScript -DonorSha $sha 2>&1 | Out-Null
    }

    # 6. Assemble Staging Package in 02_ready_to_build/
    $portId = Get-NextPortId
    $pkgFile = Join-Path $ReadyDir "$portId.json"
    $commitSubject = $proof.Evidence.subject
    $subsystemName = if ($commitSubject -match '^(\w+):') { $Matches[1] } else { "Core" }

    $stageResult = New-StageResult -RunId $runId -CandidateId $portId -Stage "PORT_STAGING" -DonorSha $sha -DonorFullSha $proof.Evidence.donor_full_sha -DonorRepo "reference-upstreams/vmangos-core" -TargetRepo "tortoise-wow" -TargetBaseSha $targetBaseSha -RequestedMode $Mode -EffectiveMode $modeRes.EffectiveMode -Status "PATCH_READY" -Verdict "BUG_PRESENT" -Confidence $proof.Confidence -ReasonCodes @("BUG_PROVEN_DETERMINISTIC") -Evidence $proof.Evidence -StartedAt $startedAt -CompletedAt (Get-Date)

    $stageResult["patch_file"] = "tools/queue/staging_patches/$sha.patch"
    $stageResult["title"] = $commitSubject
    $stageResult["subsystem"] = $subsystemName
    $stageResult["commit_msg"] = "Port($subsystemName): $commitSubject (vmangos/core@$sha)"
    if ($stagedSqlRel) {
        $stageResult["sql_file"] = $stagedSqlRel
    }

    Save-StageResultJson -ResultObject $stageResult -FilePath $pkgFile
    Update-CandidateState -CandidateId $sha -ToState "PATCH_READY" -ReasonCode "PACKAGE_STAGED" -Verdict "BUG_PRESENT" | Out-Null
    Write-Host "  [PASS] Successfully staged candidate as $portId ($pkgFile)" -ForegroundColor Green
    [void]$results.Add($stageResult)
}

Record-Run -RunId $runId -Operation "PORT_PIPELINE" -Mode $Mode -Status "COMPLETED" -Details @{ CandidatesProcessed = $shasToProcess.Count; StagedCount = $results.Count }

if (($AutoBuild -or $AutoCommit) -and -not $DryRun) {
    Write-Host "`n[Build Engine] Auto-Pilot / AutoCommit enabled: Invoking Build-ReadyPackages..." -ForegroundColor Cyan
    $buildArgs = @((Join-Path $ScriptDir "Build-ReadyPackages.ps1"))
    if ($SkipBuild) { $buildArgs += "-SkipBuild" }
    & powershell.exe -ExecutionPolicy Bypass -File @buildArgs
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Pipeline run $runId completed. Staged $($results.Count) candidate(s)." -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

