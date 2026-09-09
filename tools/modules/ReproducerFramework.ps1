# ReproducerFramework.ps1: Structured verification plans and reproducer metadata

function New-ReproductionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateId,
        [string]$Type = "FORMULA_ASSERTION",
        [string[]]$Steps = @(),
        [string]$ExpectedBefore = "",
        [string]$ExpectedAfter = "",
        [string]$AutomatedTest = "",
        [string]$RuntimeTest = "",
        [string]$TestEnvironment = "isolated_worktree"
    )

    return [ordered]@{
        candidate_id        = $CandidateId
        reproduction_type   = $Type
        reproduction_steps  = @($Steps)
        expected_before     = $ExpectedBefore
        expected_after      = $ExpectedAfter
        automated_test      = $AutomatedTest
        runtime_test        = $RuntimeTest
        test_environment    = $TestEnvironment
        test_result         = "PENDING"
        evidence            = [ordered]@{}
    }
}

function Format-ReproductionPlanMarkdown {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Plan)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("### Verification & Reproducer Plan: $($Plan.candidate_id)")
    [void]$sb.AppendLine("- **Type**: ``$($Plan.reproduction_type)``")
    [void]$sb.AppendLine("- **Environment**: ``$($Plan.test_environment)``")
    [void]$sb.AppendLine("- **Expected Before Fix**: $($Plan.expected_before)")
    [void]$sb.AppendLine("- **Expected After Fix**: $($Plan.expected_after)")
    if ($Plan.reproduction_steps.Count -gt 0) {
        [void]$sb.AppendLine("- **Steps**:")
        foreach ($s in $Plan.reproduction_steps) {
            [void]$sb.AppendLine("  1. $s")
        }
    }
    return $sb.ToString()
}

