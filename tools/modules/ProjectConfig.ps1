# ProjectConfig.ps1: Canonical Configuration and Build Discovery

$script:ConfigFilePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\config\twow-project.json"

function Get-ProjectConfig {
    [CmdletBinding()]
    param(
        [string]$Path = $script:ConfigFilePath
    )

    if (-not (Test-Path $Path)) {
        throw "Canonical project configuration file not found at: $Path"
    }

    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $config = $raw | ConvertFrom-Json

    # Dynamic auto-discovery for CMake executable if not found at specified path
    $cmakePath = $config.build.cmake_executable
    if (-not (Test-Path $cmakePath)) {
        $found = Get-Command cmake -ErrorAction SilentlyContinue
        if ($found) {
            $config.build.cmake_executable = $found.Source
        }
    }

    return $config
}

function Get-RepoGitInfo([string]$repoPath) {
    if (-not (Test-Path $repoPath)) {
        return @{
            Exists = $false
            Path = $repoPath
            Branch = ""
            HeadSha = ""
            Remotes = @{}
            IsClean = $false
        }
    }

    $headSha = (git -C $repoPath rev-parse HEAD 2>$null)
    if ($headSha) { $headSha = $headSha.Trim() } else { $headSha = "" }

    $branch = (git -C $repoPath rev-parse --abbrev-ref HEAD 2>$null)
    if ($branch) { $branch = $branch.Trim() } else { $branch = "" }

    $statusOut = git -C $repoPath status --porcelain 2>$null
    $isClean = [string]::IsNullOrWhiteSpace($statusOut)

    $remotesOut = git -C $repoPath remote -v 2>$null
    $remotes = @{}
    if ($remotesOut) {
        foreach ($r in $remotesOut) {
            if ($r -match '^(\w+)\s+(.+?)\s+\((fetch|push)\)') {
                $remotes[$Matches[1]] = $Matches[2]
            }
        }
    }

    return @{
        Exists = $true
        Path = $repoPath
        Branch = $branch
        HeadSha = $headSha
        Remotes = $remotes
        IsClean = $isClean
        HasGit = (Test-Path (Join-Path $repoPath ".git"))
    }
}

function Test-ProjectConfig {
    [CmdletBinding()]
    param()

    $config = Get-ProjectConfig
    $results = [ordered]@{}
    $errors = @()

    # Repositories check
    $repos = @(
        @{ Name = "twow_project"; Path = $config.repositories.twow_project.path },
        @{ Name = "tortoise_wow"; Path = $config.repositories.tortoise_wow.path },
        @{ Name = "vmangos_donor"; Path = $config.repositories.vmangos_donor.path },
        @{ Name = "client_data"; Path = $config.repositories.client_data.path }
    )

    foreach ($r in $repos) {
        $info = Get-RepoGitInfo -repoPath $r.Path
        $results[$r.Name] = $info
        if (-not $info.Exists) {
            $errors += "Repository '$($r.Name)' path not found: $($r.Path)"
        }
    }

    # CMake check
    $cmakeExe = $config.build.cmake_executable
    $cmakeExists = Test-Path $cmakeExe
    $cmakeVersion = ""
    if ($cmakeExists) {
        $cmakeVersion = (& $cmakeExe --version | Select-Object -First 1)
    } else {
        $errors += "CMake executable not found at: $cmakeExe"
    }

    $results["cmake"] = @{
        Path = $cmakeExe
        Exists = $cmakeExists
        Version = $cmakeVersion
    }

    # Inspect tortoise build tree CMakeCache.txt if present
    $cacheFile = Join-Path $config.repositories.tortoise_wow.path "build\CMakeCache.txt"
    $cacheExists = Test-Path $cacheFile
    $cacheInfo = @{}
    if ($cacheExists) {
        $content = Get-Content $cacheFile -Raw
        $cacheInfo["Generator"] = if ($content -match 'CMAKE_GENERATOR:INTERNAL=(.*)') { $Matches[1].Trim() } else { "Unknown" }
        $cacheInfo["Platform"] = if ($content -match 'CMAKE_GENERATOR_PLATFORM:INTERNAL=(.*)') { $Matches[1].Trim() } else { "Unknown" }
        $cacheInfo["BuildType"] = if ($content -match 'CMAKE_BUILD_TYPE:STRING=(.*)') { $Matches[1].Trim() } else { "Unknown" }
        $cacheInfo["HomeDir"] = if ($content -match 'CMAKE_HOME_DIRECTORY:INTERNAL=(.*)') { $Matches[1].Trim() } else { "Unknown" }
        $cacheInfo["Modules"] = if ($content -match 'MODULES:STRING=(.*)') { $Matches[1].Trim() } else { "Unknown" }
    }
    $results["build_cache"] = @{
        Path = $cacheFile
        Exists = $cacheExists
        Info = $cacheInfo
    }

    return @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        Details = $results
    }
}

function Get-BuildInfo {
    [CmdletBinding()]
    param()

    $check = Test-ProjectConfig
    $cfg = Get-ProjectConfig
    return [PSCustomObject]@{
        CMakePath      = $cfg.build.cmake_executable
        CMakeVersion   = $check.Details["cmake"].Version
        Generator      = $cfg.build.generator
        Architecture   = $cfg.build.architecture
        DefaultConfig  = $cfg.build.default_configuration
        InstallPrefix  = $cfg.build.install_prefix
        Compiler       = $cfg.build.compiler
        ModuleMode     = $cfg.build.module_mode
        BuildCache     = $check.Details["build_cache"].Info
    }
}