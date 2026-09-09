# PriorityEngine.ps1: Structured multi-factor scoring and candidate ranking engine

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")

function Get-CandidatePriorityScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$DonorSha,
        [Parameter()][string]$Subject = "",
        [Parameter()][int]$Tier = 5,
        [Parameter()][string]$Subsystem = "Core",
        [Parameter()][string]$Verdict = "BUG_PRESENT",
        [Parameter()][double]$EvidenceConfidence = 1.0,
        [Parameter()][int]$LinesChanged = 10,
        [Parameter()][int]$FilesChanged = 1,
        [Parameter()][bool]$TouchesSql = $false,
        [Parameter()][bool]$TouchesCustomTurtle = $false,
        [Parameter()][int]$DependencyCount = 0
    )

    # Hard zero gate: If already fixed or not applicable or intentional divergence
    if ($Verdict -eq "ALREADY_FIXED" -or $Verdict -eq "NOT_APPLICABLE" -or $Verdict -eq "TURTLE_INTENTIONAL_DIVERGENCE" -or $Verdict -eq "REJECTED") {
        return [ordered]@{
            TotalScore          = 0.0
            RecommendedMode     = "Fast"
            ReasonCodes         = @("ZERO_APPLICABILITY_$Verdict")
            Factors             = @{
                Impact               = 0.0
                TurtleApplicability  = 0.0
                EvidenceConfidence   = $EvidenceConfidence
                RegressionRisk       = 0.0
                Testability          = 0.0
                DependencyComplexity = 0.0
                DBRisk               = 0.0
                RuntimeRisk          = 0.0
                SecurityRisk         = 0.0
                SubsystemCriticality = 0.0
                PatchSize            = 0.0
                HistoricalStability  = 0.0
            }
        }
    }

    $reasonCodes = [System.Collections.Generic.List[string]]::new()

    # 1. Impact (based on Tier 1 to 5: Tier 1 = 1.0, Tier 2 = 0.8, Tier 3 = 0.6, Tier 4 = 0.4, Tier 5 = 0.2)
    $impact = switch ($Tier) {
        1 { 1.0 }
        2 { 0.8 }
        3 { 0.6 }
        4 { 0.4 }
        default { 0.3 }
    }
    if ($Subject -match "(?i)crash|exploit|deadlock|leak|segfault|overflow") {
        $impact = 1.0
        [void]$reasonCodes.Add("HIGH_IMPACT_CRASH_OR_SECURITY")
    }

    # 2. Turtle Applicability (0.0 to 1.0)
    $applicability = 1.0
    if ($TouchesCustomTurtle) {
        $applicability = 0.5
        [void]$reasonCodes.Add("TOUCHES_CUSTOM_TURTLE_SYSTEMS")
    }

    # 3. Subsystem Criticality
    $subCriticality = switch -Regex ($Subsystem) {
        "(?i)crash|security|auth" { 1.0 }
        "(?i)combat|spell"        { 0.85 }
        "(?i)movement|pathing"    { 0.75 }
        "(?i)database|db"         { 0.70 }
        "(?i)quest|gameobject"    { 0.50 }
        default                   { 0.40 }
    }

    # 4. Security Risk (0.0 to 1.0)
    $securityRisk = if ($Subject -match "(?i)security|auth|exploit|packet|overflow|credential") { 0.9 } else { 0.1 }

    # 5. Regression Risk (0.0 to 1.0)
    $regressionRisk = 0.1
    if ($LinesChanged -gt 200) { $regressionRisk += 0.3 }
    if ($FilesChanged -gt 5)   { $regressionRisk += 0.3 }
    if ($TouchesCustomTurtle)  { $regressionRisk += 0.3 }
    if ($regressionRisk -gt 1.0) { $regressionRisk = 1.0 }

    # 6. Testability (0.0 to 1.0)
    $testability = 0.8
    if ($TouchesSql) { $testability = 0.9 } # DB migrations are very testable
    if ($Subject -match "(?i)random|race condition|intermittent") { $testability = 0.4 }

    # 7. Dependency Complexity (0.0 to 1.0)
    $depComplexity = [Math]::Min(1.0, $DependencyCount * 0.25)

    # 8. DB Risk
    $dbRisk = if ($TouchesSql) { 0.5 } else { 0.0 }

    # 9. Patch Size (1.0 = compact, 0.0 = huge)
    $patchSize = if ($LinesChanged -le 20) { 1.0 } elseif ($LinesChanged -le 100) { 0.7 } else { 0.3 }

    # Calculate weighted total score (0 to 100)
    $raw = (
        ($impact * 30.0) +
        ($applicability * 25.0) +
        ($subCriticality * 15.0) +
        ($EvidenceConfidence * 10.0) +
        ($testability * 10.0) +
        ($patchSize * 10.0) -
        ($regressionRisk * 15.0) -
        ($depComplexity * 10.0)
    )
    $totalScore = [Math]::Round([Math]::Max(0.0, [Math]::Min(100.0, $raw)), 2)

    # Recommended verification mode
    $recMode = "Normal"
    if ($securityRisk -ge 0.8 -or $subCriticality -ge 0.9 -or $regressionRisk -ge 0.7 -or $Subject -match "(?i)packet|thread|mutex|race|deadlock") {
        $recMode = "Deep"
        [void]$reasonCodes.Add("AUTO_ESCALATE_DEEP_HIGH_RISK")
    } elseif ($totalScore -lt 40.0 -and $LinesChanged -le 15 -and -not $TouchesSql -and $depComplexity -eq 0) {
        $recMode = "Fast"
        [void]$reasonCodes.Add("LOW_RISK_FAST_ELIGIBLE")
    }

    return [ordered]@{
        TotalScore      = $totalScore
        RecommendedMode = $recMode
        ReasonCodes     = @($reasonCodes)
        Factors         = [ordered]@{
            Impact               = [Math]::Round($impact, 2)
            TurtleApplicability  = [Math]::Round($applicability, 2)
            EvidenceConfidence   = [Math]::Round($EvidenceConfidence, 2)
            SubsystemCriticality = [Math]::Round($subCriticality, 2)
            SecurityRisk         = [Math]::Round($securityRisk, 2)
            RegressionRisk       = [Math]::Round($regressionRisk, 2)
            Testability          = [Math]::Round($testability, 2)
            DependencyComplexity = [Math]::Round($depComplexity, 2)
            DBRisk               = [Math]::Round($dbRisk, 2)
            PatchSize            = [Math]::Round($patchSize, 2)
        }
    }
}

