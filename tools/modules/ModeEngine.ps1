# ModeEngine.ps1: Fast/Normal/Deep verification modes, automatic escalation, and DryRun planning

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "BugProver.ps1")
. (Join-Path $ScriptDir "RelationGraph.ps1")
. (Join-Path $ScriptDir "PriorityEngine.ps1")

function Resolve-VerificationMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RequestedMode,
        [hashtable]$CandidateContext = @{},
        [switch]$HasDatabaseMigration,
        [switch]$HasDependencies,
        [switch]$TouchesSecurityOrPackets
    )

    $req = $RequestedMode.Trim()
    if ($req -ne "Fast" -and $req -ne "Normal" -and $req -ne "Deep") {
        $req = "Normal"
    }

    $effective = $req
    $escalationReason = $null

    $subject = if ($CandidateContext.ContainsKey("Subject")) { $CandidateContext["Subject"] } else { "" }
    $confidence = if ($CandidateContext.ContainsKey("Confidence")) { [double]$CandidateContext["Confidence"] } else { 1.0 }
    $depCount = if ($CandidateContext.ContainsKey("DependencyCount")) { [int]$CandidateContext["DependencyCount"] } else { 0 }
    $subsystem = if ($CandidateContext.ContainsKey("Subsystem")) { $CandidateContext["Subsystem"] } else { "Core" }

    if ($HasDependencies.IsPresent -and $depCount -eq 0) { $depCount = 1 }
    if ($HasDatabaseMigration.IsPresent) { $subsystem = "Database" }
    if ($TouchesSecurityOrPackets.IsPresent) { $subsystem = "Security" }

    # Fast -> Normal Escalations
    if ($effective -eq "Fast") {
        if ($depCount -gt 0) {
            $effective = "Normal"
            $escalationReason = "AUTO_ESCALATE_FAST_TO_NORMAL: Multi-commit dependencies detected ($depCount)"
        } elseif ($subsystem -eq "Database" -or $HasDatabaseMigration.IsPresent) {
            $effective = "Normal"
            $escalationReason = "AUTO_ESCALATE_FAST_TO_NORMAL: Database migration detected"
        } elseif ($confidence -lt 0.85) {
            $effective = "Normal"
            $escalationReason = "AUTO_ESCALATE_FAST_TO_NORMAL: Bug existence confidence $confidence < 0.85"
        }
    }

    # Normal -> Deep Escalations
    if ($effective -eq "Normal") {
        if ($subject -match "(?i)crash|packet|opcode|thread|mutex|deadlock|leak|exploit|auth|crypto") {
            $effective = "Deep"
            $escalationReason = "AUTO_ESCALATE_NORMAL_TO_DEEP: Critical subsystem/security keyword in subject"
        } elseif ($subsystem -match "(?i)security|auth|network" -or $TouchesSecurityOrPackets.IsPresent) {
            $effective = "Deep"
            $escalationReason = "AUTO_ESCALATE_NORMAL_TO_DEEP: Critical subsystem classification ($subsystem)"
        }
    }

    # Guard: Never auto-downgrade
    $modeRank = @{ "Fast" = 1; "Normal" = 2; "Deep" = 3 }
    if ($modeRank[$effective] -lt $modeRank[$req]) {
        $effective = $req
    }

    return @{
        RequestedMode    = $req
        ResolvedMode     = $effective
        EffectiveMode    = $effective
        Escalated        = ($effective -ne $req)
        EscalationReason = $escalationReason
    }
}

function Invoke-CandidatePlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("CandidateSha")][string]$DonorSha,
        [string]$RequestedMode = "Normal",
        [switch]$DryRun
    )

    $cfg = Get-ProjectConfig
    $donorRepo = $cfg.repositories.vmangos_donor.path
    $targetRepo = $cfg.repositories.tortoise_wow.path

    # 1. Deterministic bug-existence proof
    $proof = Invoke-BugExistenceProof -DonorSha $DonorSha -DonorRepo $donorRepo -TargetRepo $targetRepo

    # 2. Candidate relations and dependencies
    $rel = Get-CandidateRelations -DonorSha $DonorSha -DonorRepo $donorRepo
    $deps = Get-CandidateDependencies -DonorSha $DonorSha -DonorRepo $donorRepo

    # 3. Mode resolution and escalation
    $context = @{
        Subject         = $proof.Evidence.subject
        Confidence      = $proof.Confidence
        DependencyCount = $deps.Dependencies.Count
        Subsystem       = "Core"
    }
    $modeResult = Resolve-VerificationMode -RequestedMode $RequestedMode -CandidateContext $context

    # 4. Priority score calculation
    $scoreResult = Get-CandidatePriorityScore -DonorSha $DonorSha -Subject $proof.Evidence.subject -Verdict $proof.Verdict -EvidenceConfidence $proof.Confidence -DependencyCount $deps.Dependencies.Count

    $plan = [ordered]@{
        CandidateId      = $proof.Evidence.donor_short_sha
        Subject          = $proof.Evidence.subject
        Verdict          = $proof.Verdict
        Confidence       = $proof.Confidence
        RequestedMode    = $modeResult.RequestedMode
        EffectiveMode    = $modeResult.EffectiveMode
        Escalated        = $modeResult.Escalated
        EscalationReason = $modeResult.EscalationReason
        PriorityScore    = $scoreResult.TotalScore
        Dependencies     = @($deps.Dependencies | ForEach-Object { $_.Sha })
        Relations        = @($rel.Relations | ForEach-Object { "$($_.Type): $($_.Target)" })
        ExpectedBuildProfile = if ($proof.Evidence.touched_files -match "\.sql$") { "sql-only" } else { "world" }
        ExpectedAiUsage  = if ($proof.Verdict -eq "BUG_PRESENT" -or $proof.Verdict -eq "UNCERTAIN") { "ADVISORY_ONLY" } else { "NONE" }
        IsDryRun         = [bool]$DryRun
    }

    if ($DryRun) {
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "  PLAN / DRY-RUN REPORT: Candidate $($plan.CandidateId)" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "Subject           : $($plan.Subject)" -ForegroundColor Yellow
        Write-Host "Bug Verdict       : [$($plan.Verdict)] (Confidence: $($plan.Confidence))" -ForegroundColor $(if ($plan.Verdict -eq "BUG_PRESENT") { "Green" } else { "Yellow" })
        Write-Host "Requested Mode    : $($plan.RequestedMode)" -ForegroundColor Gray
                $escStr = if ($plan.Escalated) { " [ESCALATED: $($plan.EscalationReason)]" } else { "" }
        Write-Host "Effective Mode    : $($plan.EffectiveMode)$escStr" -ForegroundColor Cyan
        Write-Host "Priority Score    : $($plan.PriorityScore)" -ForegroundColor Green
        $depStr = if ($plan.Dependencies.Count -gt 0) { $plan.Dependencies -join ", " } else { "None" }
        Write-Host "Dependencies      : $depStr" -ForegroundColor DarkGray
        Write-Host "Build Profile     : $($plan.ExpectedBuildProfile)" -ForegroundColor DarkGray
        Write-Host "AI Usage          : $($plan.ExpectedAiUsage)" -ForegroundColor DarkGray
        Write-Host "DryRun Mode       : No changes written to source, no worktrees created, no commits." -ForegroundColor Yellow
        Write-Host "================================================================================" -ForegroundColor Cyan
    }

    return $plan
}

