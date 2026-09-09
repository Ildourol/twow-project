# Standardized Exit Codes for twow-project toolchain
# 0 = PASS
# 1 = VALIDATION / COMPATIBILITY FAILURE
# 2 = TOOL / ENVIRONMENT FAILURE
# 3 = INTERNAL / SCHEMA FAILURE

$script:EXIT_CODE_PASS = 0
$script:EXIT_CODE_VALIDATION_FAILURE = 1
$script:EXIT_CODE_TOOL_FAILURE = 2
$script:EXIT_CODE_SCHEMA_FAILURE = 3

function Get-StandardExitCode([string]$type) {
    switch ($type.ToUpper()) {
        "PASS"                 { return 0 }
        "VALIDATION_FAILURE"   { return 1 }
        "COMPATIBILITY_FAILURE"{ return 1 }
        "TOOL_FAILURE"         { return 2 }
        "ENVIRONMENT_FAILURE"  { return 2 }
        "SCHEMA_FAILURE"       { return 3 }
        "INTERNAL_FAILURE"     { return 3 }
        default                { return 2 }
    }
}

function Get-ExitCode([string]$type) {
    return Get-StandardExitCode $type
}