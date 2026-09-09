# StateMachine.ps1: Canonical Pipeline State Machine and Transition Guard

$script:CANONICAL_STATES = @(
    "DISCOVERED",
    "TRIAGED",
    "BUG_PROOF_PENDING",
    "BUG_PRESENT",
    "ALREADY_FIXED",
    "NOT_APPLICABLE",
    "TURTLE_INTENTIONAL_DIVERGENCE",
    "UNCERTAIN",
    "DEPENDENCY_PENDING",
    "DEPENDENCY_READY",
    "DB_CHECK_PENDING",
    "DB_CHECK_PASS",
    "DB_CHECK_FAIL",
    "ADAPTATION_REQUIRED",
    "PATCH_READY",
    "COMPILE_PENDING",
    "COMPILE_PASS",
    "COMPILE_FAIL",
    "STARTUP_PENDING",
    "STARTUP_PASS",
    "STARTUP_FAIL",
    "RUNTIME_PENDING",
    "RUNTIME_PASS",
    "RUNTIME_FAIL",
    "HUMAN_REVIEW_REQUIRED",
    "HUMAN_APPROVED",
    "HUMAN_REJECTED",
    "BLOCKED_BY_BASELINE",
    "NEEDS_REAUDIT",
    "COMPLETE",
    "REJECTED"
)

# Valid transitions map: FromState -> Allowed ToStates
$script:ALLOWED_TRANSITIONS = @{
    "DISCOVERED" = @("TRIAGED", "BUG_PROOF_PENDING", "ALREADY_FIXED", "NOT_APPLICABLE", "REJECTED")
    "TRIAGED" = @("BUG_PROOF_PENDING", "ALREADY_FIXED", "NOT_APPLICABLE", "TURTLE_INTENTIONAL_DIVERGENCE", "REJECTED")
    "BUG_PROOF_PENDING" = @("BUG_PRESENT", "ALREADY_FIXED", "NOT_APPLICABLE", "TURTLE_INTENTIONAL_DIVERGENCE", "UNCERTAIN")
    "BUG_PRESENT" = @("DEPENDENCY_PENDING", "DEPENDENCY_READY", "DB_CHECK_PENDING", "ADAPTATION_REQUIRED", "PATCH_READY", "NEEDS_REAUDIT")
    "ALREADY_FIXED" = @("NEEDS_REAUDIT")
    "NOT_APPLICABLE" = @("NEEDS_REAUDIT")
    "TURTLE_INTENTIONAL_DIVERGENCE" = @("HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "UNCERTAIN" = @("HUMAN_REVIEW_REQUIRED", "ADAPTATION_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "DEPENDENCY_PENDING" = @("DEPENDENCY_READY", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "DEPENDENCY_READY" = @("DB_CHECK_PENDING", "ADAPTATION_REQUIRED", "PATCH_READY", "NEEDS_REAUDIT")
    "DB_CHECK_PENDING" = @("DB_CHECK_PASS", "DB_CHECK_FAIL")
    "DB_CHECK_PASS" = @("ADAPTATION_REQUIRED", "PATCH_READY", "NEEDS_REAUDIT")
    "DB_CHECK_FAIL" = @("ADAPTATION_REQUIRED", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "ADAPTATION_REQUIRED" = @("PATCH_READY", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "PATCH_READY" = @("COMPILE_PENDING", "NEEDS_REAUDIT", "REJECTED")
    "COMPILE_PENDING" = @("COMPILE_PASS", "COMPILE_FAIL", "BLOCKED_BY_BASELINE")
    "COMPILE_PASS" = @("STARTUP_PENDING", "RUNTIME_PENDING", "COMPLETE", "HUMAN_REVIEW_REQUIRED", "NEEDS_REAUDIT")
    "COMPILE_FAIL" = @("BLOCKED_BY_BASELINE", "ADAPTATION_REQUIRED", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "STARTUP_PENDING" = @("STARTUP_PASS", "STARTUP_FAIL", "BLOCKED_BY_BASELINE")
    "STARTUP_PASS" = @("RUNTIME_PENDING", "COMPLETE", "HUMAN_REVIEW_REQUIRED", "NEEDS_REAUDIT")
    "STARTUP_FAIL" = @("BLOCKED_BY_BASELINE", "ADAPTATION_REQUIRED", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "RUNTIME_PENDING" = @("RUNTIME_PASS", "RUNTIME_FAIL")
    "RUNTIME_PASS" = @("COMPLETE", "HUMAN_REVIEW_REQUIRED", "NEEDS_REAUDIT")
    "RUNTIME_FAIL" = @("ADAPTATION_REQUIRED", "HUMAN_REVIEW_REQUIRED", "REJECTED", "NEEDS_REAUDIT")
    "HUMAN_REVIEW_REQUIRED" = @("HUMAN_APPROVED", "HUMAN_REJECTED", "NEEDS_REAUDIT")
    "HUMAN_APPROVED" = @("PATCH_READY", "COMPILE_PENDING", "STARTUP_PENDING", "COMPLETE", "NEEDS_REAUDIT")
    "HUMAN_REJECTED" = @("REJECTED", "NEEDS_REAUDIT")
    "BLOCKED_BY_BASELINE" = @("NEEDS_REAUDIT", "REJECTED")
    "NEEDS_REAUDIT" = @("BUG_PROOF_PENDING", "TRIAGED", "DISCOVERED", "REJECTED")
    "COMPLETE" = @("NEEDS_REAUDIT")
    "REJECTED" = @("NEEDS_REAUDIT")
}

function Test-StateTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FromState,
        [Parameter(Mandatory=$true)][string]$ToState
    )

    $FromState = $FromState.Trim().ToUpper()
    $ToState = $ToState.Trim().ToUpper()

    if ($script:CANONICAL_STATES -notcontains $FromState) {
        return @{
            Allowed = $false
            Error = "Unknown source state '$FromState'"
        }
    }
    if ($script:CANONICAL_STATES -notcontains $ToState) {
        return @{
            Allowed = $false
            Error = "Unknown destination state '$ToState'"
        }
    }

    if ($FromState -eq $ToState) {
        return @{ Allowed = $true; Error = $null }
    }

    $allowedList = $script:ALLOWED_TRANSITIONS[$FromState]
    if ($null -ne $allowedList -and $allowedList -contains $ToState) {
        return @{ Allowed = $true; Error = $null }
    }

    return @{
        Allowed = $false
        Error = "Illegal state transition from '$FromState' to '$ToState'. Valid next states: $($allowedList -join ', ')"
    }
}

function Assert-StateTransition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FromState,
        [Parameter(Mandatory=$true)][string]$ToState
    )

    $res = Test-StateTransition -FromState $FromState -ToState $ToState
    if (-not $res.Allowed) {
        throw "Invalid State Transition: $($res.Error)"
    }
}