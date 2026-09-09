# BuildEngine.ps1: Reproducible build configuration, profile selector, and compiler execution

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")

function Select-BuildProfile {
    [CmdletBinding()]
    param(
        [string[]]$TouchedFiles = @()
    )

    if ($TouchedFiles.Count -eq 0) { return "world" }

    $hasCpp = $false
    $hasSql = $false
    $hasDocs = $false
    $hasAuth = $false
    $hasPlayerbots = $false

    foreach ($f in $TouchedFiles) {
        if ($f -like "*.md" -or $f -like "docs/*") { $hasDocs = $true }
        elseif ($f -like "*.sql" -or $f -like "sql/*") { $hasSql = $true }
        elseif ($f -like "*playerbot*" -or $f -like "*Playerbot*") { $hasPlayerbots = $true; $hasCpp = $true }
        elseif ($f -like "src/realmd/*" -or $f -like "src/shared/Auth/*") { $hasAuth = $true; $hasCpp = $true }
        elseif ($f -like "src/*" -or $f -like "dep/*" -or $f -like "CMakeLists.txt") { $hasCpp = $true }
    }

    if ($hasPlayerbots) { return "playerbots" }
    if ($hasCpp) {
        if ($hasAuth -and -not ($TouchedFiles | Where-Object { $_ -like "src/game/*" })) {
            return "auth"
        }
        return "world"
    }
    if ($hasSql) { return "sql-only" }
    if ($hasDocs) { return "docs-only" }

    return "world"
}

function Invoke-TargetBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [string]$Profile = "world",
        [string]$Configuration = "Release",
        [string]$BuildDir = ""
    )

    $cfg = Get-ProjectConfig
    $cmakeExe = $cfg.build.cmake_executable
    if (-not (Test-Path $cmakeExe)) {
        return @{
            ExitCode = $script:EXIT_CODE_TOOL_FAILURE
            Status = "TOOL_FAILURE"
            Error = "CMake executable not found at: $cmakeExe"
        }
    }

    if ([string]::IsNullOrEmpty($BuildDir)) {
        $BuildDir = Join-Path $TargetRepo "build"
    }

    if (-not (Test-Path $BuildDir)) {
        return @{
            ExitCode = $script:EXIT_CODE_TOOL_FAILURE
            Status = "TOOL_FAILURE"
            Error = "Build directory not found at: $BuildDir"
        }
    }

    # If sql-only or docs-only profile, skip C++ compilation
    if ($Profile -eq "sql-only" -or $Profile -eq "docs-only") {
        Write-Host "[BUILD PROFILE: $Profile] Skipping C++ compilation." -ForegroundColor Green
        return @{
            ExitCode    = $script:EXIT_CODE_PASS
            Status      = "COMPILE_PASS"
            LinkStatus  = "SKIPPED"
            Profile     = $Profile
            DurationMs  = 0
        }
    }

    # Target resolution based on profile
    $targetArg = switch ($Profile) {
        "auth"       { "--target realmd" }
        "world"      { "--target mangosd" }
        "playerbots" { "--target mangosd" }
        default      { "" }
    }

    Write-Host "Compiling profile [$Profile] ($Configuration) via CMake..." -ForegroundColor Yellow
    $start = Get-Date
    $cmd = """$cmakeExe"" --build ""$BuildDir"" --config $Configuration $targetArg"
    $buildOut = cmd.exe /c "$cmd 2>&1"
    $code = $LASTEXITCODE
    $durationMs = [int]((Get-Date) - $start).TotalMilliseconds

    # Check binaries exist
    $binDir = Join-Path $TargetRepo "bin\$Configuration"
    $mangosdBin = Join-Path $binDir "mangosd.exe"
    $realmdBin  = Join-Path $binDir "realmd.exe"

    $compilePass = ($code -eq 0)
    $linkPass = ($compilePass -and (Test-Path $mangosdBin))

    return @{
        ExitCode    = if ($compilePass) { $script:EXIT_CODE_PASS } else { $script:EXIT_CODE_VALIDATION_FAILURE }
        Status      = if ($compilePass) { "COMPILE_PASS" } else { "COMPILE_FAIL" }
        LinkStatus  = if ($linkPass) { "LINK_PASS" } else { "LINK_FAIL" }
        Profile     = $Profile
        Output      = ($buildOut -join "`n")
        DurationMs  = $durationMs
        Binaries    = @{
            mangosd = (Test-Path $mangosdBin)
            realmd  = (Test-Path $realmdBin)
        }
    }
}

