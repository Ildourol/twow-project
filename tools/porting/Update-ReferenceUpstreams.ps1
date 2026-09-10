<#
.SYNOPSIS
    Updates all cloned reference upstreams for the twow-project workspace.
.DESCRIPTION
    Fetches and fast-forwards all upstream donor repositories in reference-upstreams/
    (vmangos-core, lights-hope-database-history, elysium-core, tortoise-db-viewer, client-data-1.18.1).
    Fetches upstream Penqle commits on tortoise-wow while strictly protecting the local
    active working branch (extended) from being overwritten or merged.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$TargetUpstream = "all",

    [Parameter()]
    [switch]$FetchOnly
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Split-Path -Parent $ScriptDir
$ProjectRoot = Split-Path -Parent $ToolsDir
$RefDir = Join-Path $ProjectRoot "reference-upstreams"
$TortoiseRepo = Join-Path $ProjectRoot "tortoise-wow"

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  UPDATE REFERENCE UPSTREAMS (twow-project)" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "Policy: Fast-forwards read-only reference repositories in reference-upstreams/." -ForegroundColor Gray
Write-Host "Safety: Active worktree 'tortoise-wow' (branch: extended) is strictly protected." -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $RefDir)) {
    Write-Host "[ERROR] reference-upstreams directory not found at $RefDir" -ForegroundColor Red
    exit 1
}

$refItems = Get-ChildItem -Path $RefDir | Where-Object {
    (Test-Path (Join-Path $_.FullName ".git")) -or (Test-Path (Join-Path $_.FullName ".git\HEAD"))
}

$updatedCount = 0
$upToDateCount = 0
$errorCount = 0

foreach ($item in $refItems) {
    $name = $item.Name
    if ($TargetUpstream -ne "all" -and $name -notmatch $TargetUpstream) {
        continue
    }

    $repoPath = $item.FullName
    Write-Host ">>> Checking [$name] at $repoPath ..." -ForegroundColor Cyan
    
    $oldHead = (& git.exe -C "$repoPath" rev-parse HEAD 2>$null)
    if (-not $oldHead) {
        Write-Host "  [WARN] Unable to resolve HEAD for $name" -ForegroundColor Yellow
        $errorCount++
        continue
    }

    $currBranch = (& git.exe -C "$repoPath" branch --show-current 2>$null)
    $remote = "origin"

    Write-Host "  Fetching latest references from $remote..." -ForegroundColor DarkGray
    & git.exe -C "$repoPath" fetch --all --prune --tags 2>&1 | Out-Null

    if ($FetchOnly) {
        Write-Host "  [FETCHED] Remote references refreshed." -ForegroundColor Green
        continue
    }

    # Pull fast-forward if branch is known and clean
    if ($currBranch) {
        Write-Host "  Pulling fast-forward updates on '$currBranch'..." -ForegroundColor DarkGray
        $pullOut = & git.exe -C "$repoPath" pull --ff-only $remote $currBranch 2>&1
        $pullExit = $LASTEXITCODE
    } else {
        $pullExit = 0
    }

    $newHead = (& git.exe -C "$repoPath" rev-parse HEAD 2>$null)
    if ($oldHead -ne $newHead) {
        $count = (& git.exe -C "$repoPath" rev-list --count "$oldHead..$newHead" 2>$null)
        Write-Host "  [UPDATED] $count new commit(s) integrated! (HEAD: $($newHead.Substring(0,8)))" -ForegroundColor Green
        Write-Host "  Recent incoming commits:" -ForegroundColor Yellow
        & git.exe -C "$repoPath" log -n 5 "$oldHead..$newHead" --oneline | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        $updatedCount++
    } else {
        Write-Host "  [UP-TO-DATE] Already at latest commit ($($newHead.Substring(0,8)))." -ForegroundColor Green
        $upToDateCount++
    }
    Write-Host ""
}

# Check tortoise-wow for upstream (Penqle) updates without touching the working branch
if (Test-Path (Join-Path $TortoiseRepo ".git")) {
    $hasUpstream = (& git.exe -C "$TortoiseRepo" remote 2>$null) -contains "upstream"
    if ($hasUpstream) {
        Write-Host ">>> Checking upstream (Penqle/tortoise-wow) in tortoise-wow ..." -ForegroundColor Cyan
        & git.exe -C "$TortoiseRepo" fetch upstream --tags --prune 2>&1 | Out-Null
        Write-Host "  [FETCHED] Fetched upstream/main and upstream tags." -ForegroundColor Green
        Write-Host "  [PROTECTED] Active branch 'extended' kept intact (working tree untouched)." -ForegroundColor DarkGray
        Write-Host ""
    }
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  SUMMARY: $updatedCount updated, $upToDateCount up-to-date, $errorCount errors." -ForegroundColor Cyan
Write-Host "  Active working branch 'extended' on tortoise-wow was preserved." -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan