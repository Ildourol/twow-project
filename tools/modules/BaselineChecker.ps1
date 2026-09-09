# BaselineChecker.ps1: Verifies and caches the unchanged target baseline health

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")
. (Join-Path $ScriptDir "StateStore.ps1")

function Get-BaselineStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [string]$TargetBaseSha = "",
        [string]$StateStorePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\state\state_store.json"
    )

    if ([string]::IsNullOrEmpty($TargetBaseSha)) {
        $TargetBaseSha = (git -C $TargetRepo rev-parse HEAD 2>$null)
        if ($TargetBaseSha) { $TargetBaseSha = $TargetBaseSha.Trim() }
    }

    $store = Get-StateStore -Path $StateStorePath
    $bCache = $store.baseline_cache
    if ($bCache -is [System.Collections.IDictionary] -and $bCache.ContainsKey($TargetBaseSha)) {
        return $bCache[$TargetBaseSha]
    } elseif ($null -ne $bCache.$TargetBaseSha) {
        return $bCache.$TargetBaseSha
    }

    return $null
}

function Invoke-TargetBaselineCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [string]$TargetBaseSha = "",
        [string]$StateStorePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\state\state_store.json",
        [switch]$Force
    )

    if ([string]::IsNullOrEmpty($TargetBaseSha)) {
        $TargetBaseSha = (git -C $TargetRepo rev-parse HEAD 2>$null)
        if ($TargetBaseSha) { $TargetBaseSha = $TargetBaseSha.Trim() }
    }

    if (-not $Force) {
        $cached = Get-BaselineStatus -TargetRepo $TargetRepo -TargetBaseSha $TargetBaseSha -StateStorePath $StateStorePath
        if ($null -ne $cached) {
            Write-Host "[BASELINE CACHE HIT] Target baseline for $TargetBaseSha already verified:" -ForegroundColor Green
            Write-Host "  Configure: $($cached.configure_status)" -ForegroundColor DarkGray
            Write-Host "  Compile  : $($cached.compile_status)" -ForegroundColor DarkGray
            Write-Host "  Link     : $($cached.link_status)" -ForegroundColor DarkGray
            return $cached
        }
    }

    Write-Host "Evaluating Target Baseline for $TargetBaseSha..." -ForegroundColor Cyan
    $cfg = Get-ProjectConfig
    $buildDir = Join-Path $TargetRepo "build"
    $cacheFile = Join-Path $buildDir "CMakeCache.txt"
    $cmakeExe = $cfg.build.cmake_executable

    $configurePass = (Test-Path $cacheFile)
    $compilePass = $false
    $linkPass = $false

    # Check existing binaries
    $mangosdBin = Join-Path $TargetRepo "bin\Release\mangosd.exe"
    $realmdBin  = Join-Path $TargetRepo "bin\Release\realmd.exe"
    if ((Test-Path $mangosdBin) -and (Test-Path $realmdBin)) {
        $compilePass = $true
        $linkPass = $true
    } elseif (Test-Path $cmakeExe) {
        Write-Host "Running baseline compilation check via CMake build Release..." -ForegroundColor Yellow
        $buildOut = cmd.exe /c """$cmakeExe"" --build ""$buildDir"" --config Release 2>&1"
        $compilePass = ($LASTEXITCODE -eq 0)
        $linkPass = ($LASTEXITCODE -eq 0 -and (Test-Path $mangosdBin) -and (Test-Path $realmdBin))
    }

    $baselineRecord = [ordered]@{
        target_base_sha      = $TargetBaseSha
        checked_at           = (Get-Date).ToString("o")
        configure_status     = if ($configurePass) { "PASS" } else { "FAIL" }
        compile_status       = if ($compilePass) { "PASS" } else { "FAIL" }
        link_status          = if ($linkPass) { "PASS" } else { "FAIL" }
        startup_status       = "PENDING_SMOKE"
        runtime_sanity_status= "UNTESTED"
        overall_health       = if ($compilePass -and $linkPass) { "HEALTHY" } else { "DEGRADED" }
    }

    # Save in state store cache
    $store = Get-StateStore -Path $StateStorePath
    if ($store.baseline_cache -is [System.Collections.IDictionary]) {
        $store.baseline_cache[$TargetBaseSha] = $baselineRecord
    } else {
        $store.baseline_cache = @{ $TargetBaseSha = $baselineRecord }
    }
    Save-StateStore -Store $store -Path $StateStorePath

    Write-Host "[BASELINE VERIFIED] Baseline overall health: $($baselineRecord.overall_health)" -ForegroundColor Green
    return $baselineRecord
}

function Classify-BaselineResult {
    param([bool]$CompilePass, [bool]$LinkPass, [bool]$StartupPass)
    if (-not $CompilePass) { return "COMPILE_FAIL" }
    if (-not $LinkPass) { return "LINK_FAIL" }
    if (-not $StartupPass) { return "STARTUP_FAIL" }
    return "HEALTHY"
}
