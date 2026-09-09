<#
.SYNOPSIS
    Automates Agent 1 (Builder & Committer) to build, verify, commit, and push all ready packages.
.DESCRIPTION
    Scans tools/queue/02_ready_to_build/ for PORT-XXXX.json and CORE-XXXX.json packages.
    For each package:
      1. Applies patch and SQL
      2. Runs Verify-TurtleCompatibility.ps1
      3. Compiles via MSVC 2022 Release (Exit Code 0 gate)
      4. Staged git commit with standardized attribution
      5. Pushes to extended main
      6. Moves package and patch to 03_completed/
      7. Updates COMMITS_UPLOADED.md, BACKPORT_HISTORY.md, docs/commits/, and ROADMAP.md
#>
[CmdletBinding()]
param(
    [switch]$SkipPush
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$TortoisePath = Join-Path $ProjectRoot "tortoise-wow"
$ReadyDir = Join-Path $ProjectRoot "tools\queue\02_ready_to_build"
$CompletedDir = Join-Path $ProjectRoot "tools\queue\03_completed"
$CMakeExe = "C:\vcpkg\downloads\tools\cmake-4.4.2-windows\cmake-4.4.2-windows-x86_64\bin\cmake.exe"

$readyPackages = Get-ChildItem -Path $ReadyDir -Filter "*.json" | Sort-Object Name
if ($readyPackages.Count -eq 0) {
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "[QUEUE STATUS: IDLE - NOTHING TO COMMIT]" -ForegroundColor Yellow
    Write-Host "No packages found in tools/queue/02_ready_to_build/." -ForegroundColor Yellow
    Write-Host "================================================================================" -ForegroundColor Cyan
    return
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Agent 1: Building $($readyPackages.Count) Ready Package(s)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

foreach ($pkg in $readyPackages) {
    $meta = Get-Content $pkg.FullName -Raw | ConvertFrom-Json
    $pkgId = [System.IO.Path]::GetFileNameWithoutExtension($pkg.Name)
    $title = $meta.title
    $sha = $meta.donor_sha
    $subsystem = $meta.subsystem
    $patchPath = Join-Path $ProjectRoot $meta.patch_file
    $commitMsg = $meta.commit_msg

    Write-Host "`n>>> Processing Package: $pkgId ($sha) - $title" -ForegroundColor Cyan

    if ($meta.status -eq "AWAITING_CODE" -or $meta.status -eq "AWAITING_AI_ADAPTATION") {
        Write-Host "[WAITING] Package $pkgId has status '$($meta.status)' and is awaiting code authoring/adaptation. Skipping." -ForegroundColor Yellow
        continue
    }

    # 1. Apply patch
    if (Test-Path $patchPath) {
        Write-Host "Applying patch: $patchPath" -ForegroundColor DarkGray
        $applyOut = & git -C $TortoisePath apply --ignore-whitespace $patchPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to apply patch $patchPath. Aborting."
            return
        }
    }

    # 2. Apply SQL if present
    if ($meta.sql_file -and (Test-Path (Join-Path $ProjectRoot $meta.sql_file))) {
        $sqlSource = Join-Path $ProjectRoot $meta.sql_file
        $sqlDestDir = Join-Path $TortoisePath "sql\database_updates\world"
        Copy-Item $sqlSource $sqlDestDir -Force
        Write-Host "Copied SQL migration to $sqlDestDir" -ForegroundColor DarkGray
    }

    # 3. Pre-build compatibility verification
    $compatScript = Join-Path $ScriptDir "Verify-TurtleCompatibility.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $compatScript -TargetRepo $TortoisePath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compatibility invariant verification failed for $pkgId. Rolling back."
        git -C $TortoisePath checkout .
        return
    }

    # 4. Compile gate
    Write-Host "Compiling server via MSVC 2022 (Release)..." -ForegroundColor Yellow
    $buildDir = Join-Path $TortoisePath "build"
    & $CMakeExe --build $buildDir --config Release
    if ($LASTEXITCODE -ne 0) {
        Write-Error "MSVC 2022 Compilation gate failed with exit code $LASTEXITCODE. Rolling back."
        git -C $TortoisePath checkout .
        return
    }

    # 5. Git Commit & Push
    git -C $TortoisePath add src/ sql/ CMakeLists.txt
    git -C $TortoisePath commit -m $commitMsg
    $shortHash = (git -C $TortoisePath rev-parse --short HEAD).Trim()
    $fullHash  = (git -C $TortoisePath rev-parse HEAD).Trim()

    if (-not $SkipPush) {
        Write-Host "Pushing $shortHash to extended main..." -ForegroundColor Yellow
        git -C $TortoisePath push extended main
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to push to extended main."
            return
        }
    }

    # 6. Move manifest and patch to completed archive
    Move-Item $pkg.FullName $CompletedDir -Force
    if (Test-Path $patchPath) {
        $patchesArch = Join-Path $CompletedDir "patches"
        if (-not (Test-Path $patchesArch)) { New-Item -ItemType Directory -Path $patchesArch -Force | Out-Null }
        Move-Item $patchPath $patchesArch -Force
    }

    Write-Host "[SUCCESS] $pkgId committed ($shortHash) and pushed to extended main!" -ForegroundColor Green
}

# 7. Update Commit Dossiers Archive
Write-Host "`nUpdating commit dossiers archive..." -ForegroundColor Yellow
$dossierScript = Join-Path $ScriptDir "Generate-CommitDossiers.ps1"
& powershell.exe -ExecutionPolicy Bypass -File $dossierScript

Write-Host "`nAll packages processed successfully." -ForegroundColor Green
