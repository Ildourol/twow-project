<#
.SYNOPSIS
    Universal Orchestration Test Runner for twow-project.
.DESCRIPTION
    Executes the complete 38-test orchestration suite specified in Section 47.
    Provides standard Pester DSL execution (Describe, It, Should) with zero external
    module dependencies, ensuring 100% portability across PowerShell versions and CI runners.
#>
[CmdletBinding()]
param(
    [string]$OutputFile = "",
    [string]$OutputFormat = "NUnitXml"
)

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:CurrentDescribe = ""
$script:Failures = [System.Collections.Generic.List[string]]::new()

function Describe {
    param([string]$Name, [scriptblock]$Fixture)
    $script:CurrentDescribe = $Name
    Write-Host "`nDescribing $Name" -ForegroundColor Cyan
    & $Fixture
}

function It {
    param([string]$Name, [scriptblock]$Test)
    try {
        & $Test
        Write-Host " [+] $Name" -ForegroundColor Green
        $script:TestsPassed++
    } catch {
        Write-Host " [-] $Name" -ForegroundColor Red
        Write-Host "     $($_.Exception.Message)" -ForegroundColor DarkRed
        $script:TestsFailed++
        [void]$script:Failures.Add("$($script:CurrentDescribe) -> $Name : $($_.Exception.Message)")
    }
}

function Should {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]$Actual,
        [Parameter(Position=0)][string]$Op1,
        [Parameter(Position=1)][object]$Op2,
        [Parameter(Position=2)][object]$Op3
    )

    $isNot = ($Op1 -eq "Not" -or $Op1 -eq "-Not")
    $actualOp = if ($isNot) { [string]$Op2 } else { $Op1 }
    $expected = if ($isNot) { $Op3 } else { $Op2 }

    if ($actualOp -and $actualOp.StartsWith("-")) { $actualOp = $actualOp.Substring(1) }

    if ($expected -is [string]) {
        if ($expected -eq "True" -or $expected -eq "true") { $expected = $true }
        elseif ($expected -eq "False" -or $expected -eq "false") { $expected = $false }
    }

    switch ($actualOp) {
        "Be" {
            $matched = if ($null -eq $Actual -and $null -eq $expected) {
                $true
            } elseif ($null -eq $Actual -or $null -eq $expected) {
                $false
            } elseif ($Actual -is [bool] -or $expected -is [bool]) {
                [bool]$Actual -eq [bool]$expected
            } elseif ($Actual -is [int] -or $expected -is [int] -or $Actual -is [long] -or $expected -is [long]) {
                [int64]$Actual -eq [int64]$expected
            } else {
                $Actual.ToString() -eq $expected.ToString()
            }

            if ($isNot) {
                if ($matched) { throw "Expected value not to be '$expected', but got '$Actual'." }
            } else {
                if (-not $matched) { throw "Expected '$expected', but got '$Actual'." }
            }
        }
        "BeGreaterThan" {
            $matched = ([int64]$Actual -gt [int64]$expected)
            if ($isNot) {
                if ($matched) { throw "Expected $Actual not to be greater than $expected." }
            } else {
                if (-not $matched) { throw "Expected $Actual to be greater than $expected." }
            }
        }
        "Match" {
            $matched = ($Actual -match $expected)
            if ($isNot) {
                if ($matched) { throw "Expected value not to match '$expected', but got '$Actual'." }
            } else {
                if (-not $matched) { throw "Expected '$Actual' to match pattern '$expected'." }
            }
        }
        "Throw" {
            $threw = $false
            if ($Actual -is [scriptblock]) {
                try { & $Actual } catch { $threw = $true }
            }
            if ($isNot) {
                if ($threw) { throw "Expected scriptblock not to throw, but an exception was thrown." }
            } else {
                if (-not $threw) { throw "Expected scriptblock to throw an exception, but none was thrown." }
            }
        }
        "BeNullOrEmpty" {
            $isNullOrEmpty = if ($null -eq $Actual) { $true } elseif ($Actual -is [string]) { [string]::IsNullOrEmpty($Actual) } elseif ($Actual -is [System.Collections.ICollection]) { $Actual.Count -eq 0 } else { $false }
            if ($isNot) {
                if ($isNullOrEmpty) { throw "Expected value not to be null or empty, but it was." }
            } else {
                if (-not $isNullOrEmpty) { throw "Expected value to be null or empty, but got '$Actual'." }
            }
        }
        default {
            throw "Unknown assertion operator: $actualOp"
        }
    }
}

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AllTestsFile = Join-Path $ScriptDir "AllTests.Tests.ps1"

if (-not (Test-Path $AllTestsFile)) {
    Write-Error "Test suite file not found: $AllTestsFile"
    exit 2
}

. $AllTestsFile

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  TWOW ORCHESTRATION TEST SUMMARY" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Passed: $script:TestsPassed | Failed: $script:TestsFailed | Total: $($script:TestsPassed + $script:TestsFailed)" -ForegroundColor $(if ($script:TestsFailed -eq 0) { "Green" } else { "Red" })

if ($script:TestsFailed -gt 0) {
    Write-Host "`nFailures detected:" -ForegroundColor Red
    foreach ($f in $script:Failures) {
        Write-Host "  * $f" -ForegroundColor Red
    }
    exit 1
}

exit 0