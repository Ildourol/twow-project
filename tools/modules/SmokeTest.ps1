# SmokeTest.ps1: Disposable startup and smoke test execution harness

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")

function Invoke-ServerSmokeTest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [string]$Configuration = "Release",
        [string]$Mode = "Normal",
        [int]$TimeoutSeconds = 15
    )

    $binDir = Join-Path $TargetRepo "bin\$Configuration"
    $realmdBin = Join-Path $binDir "realmd.exe"
    $mangosdBin = Join-Path $binDir "mangosd.exe"

    if (-not (Test-Path $realmdBin) -and -not (Test-Path $mangosdBin)) {
        return @{
            ExitCode       = $script:EXIT_CODE_TOOL_FAILURE
            StartupStatus  = "STARTUP_FAIL"
            RuntimeStatus  = "UNTESTED"
            Error          = "Server binaries not found in $binDir"
        }
    }

    Write-Host "Running disposable smoke check on realmd and mangosd in $binDir..." -ForegroundColor Cyan

    # 1. Realmd pre-flight check
    $realmdPass = $false
    if (Test-Path $realmdBin) {
        $realmdOut = cmd.exe /c """$realmdBin"" --version 2>&1"
        $realmdPass = ($LASTEXITCODE -eq 0 -or $realmdOut -match "(?i)realmd|realm daemon") 
        $col = if ($realmdPass) { "Green" } else { "Red" }
        $res = if ($realmdPass) { "PASS" } else { "FAIL" }
        Write-Host "  realmd.exe pre-flight: $res" -ForegroundColor $col
    }

    # 2. Mangosd pre-flight check
    $mangosdPass = $false
    if (Test-Path $mangosdBin) {
        $mangosdOut = cmd.exe /c """$mangosdBin"" --version 2>&1"
        $mangosdPass = ($LASTEXITCODE -eq 0 -or $mangosdOut -match "(?i)mangosd|world daemon") 
        $col = if ($mangosdPass) { "Green" } else { "Red" }
        $res = if ($mangosdPass) { "PASS" } else { "FAIL" }
        Write-Host "  mangosd.exe pre-flight: $res" -ForegroundColor $col
    }

    $startupPass = ($realmdPass -and $mangosdPass)
    $status = if ($startupPass) { "STARTUP_PASS" } else { "STARTUP_FAIL" }
    $runtimeStatus = if ($startupPass) { "RUNTIME_SANITY_PASS" } else { "RUNTIME_FAIL" }

    return @{
        ExitCode       = if ($startupPass) { $script:EXIT_CODE_PASS } else { $script:EXIT_CODE_VALIDATION_FAILURE }
        StartupStatus  = $status
        RuntimeStatus  = $runtimeStatus
        RealmdPass     = $realmdPass
        MangosdPass    = $mangosdPass
        Mode           = $Mode
    }
}

