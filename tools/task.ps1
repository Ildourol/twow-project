<#
.SYNOPSIS
    Standalone CLI Task Dispatcher for Module-playerbots.
.DESCRIPTION
    Provides unified, isolated execution for PlayerBots upstream auditing,
    synchronization, porting, verification, and ledger management.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "status",

    [Parameter(Position = 1)]
    [string]$Argument = "",

    [Parameter(Position = 2)]
    [string]$SecondaryArgument = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs = @(),

    [Parameter()]
    [ValidateSet("Fast", "Normal", "Deep")]
    [string]$Mode = "Normal",

    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [switch]$Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
if (-not (Test-Path (Join-Path $ProjectRoot "state"))) {
    $ProjectRoot = $ScriptDir
}

$StateDir = Join-Path $ProjectRoot "state"
$ReportsDir = Join-Path $ProjectRoot "reports"
$CommitAuditsDir = Join-Path $ReportsDir "commit-audits"
$VerificationDir = Join-Path $ReportsDir "verification"

$SourcesJsonPath = Join-Path $StateDir "sources.json"
$WatermarksJsonPath = Join-Path $StateDir "source-watermarks.json"
$LedgerJsonPath = Join-Path $StateDir "porting-ledger.json"

function Load-JsonFile([string]$path) {
    if (Test-Path $path) {
        return Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    return $null
}

function Save-JsonFile([string]$path, $data) {
    $json = $data | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($path, $json, [System.Text.Encoding]::UTF8)
}

$Sources = Load-JsonFile $SourcesJsonPath
$Watermarks = Load-JsonFile $WatermarksJsonPath
$Ledger = Load-JsonFile $LedgerJsonPath

function Get-GitOutput([string]$repoPath, [string[]]$gitArgs) {
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "git.exe"
    $pinfo.Arguments = "-C ""$repoPath"" " + ($gitArgs -join " ")
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true
    $proc = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $proc.StandardOutput.ReadToEnd()
    $stderr = $proc.StandardError.ReadToEnd()
    $proc.WaitForExit()
    return @{ ExitCode = $proc.ExitCode; Stdout = $stdout.Trim(); Stderr = $stderr.Trim() }
}

function Show-Status {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " MODULE-PLAYERBOTS -- SYSTEM STATUS" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $targetPath = $Sources.target.path
    $targetHead = (Get-GitOutput $targetPath @("rev-parse", "HEAD")).Stdout
    $targetBranch = (Get-GitOutput $targetPath @("branch", "--show-current")).Stdout
    $targetStatus = (Get-GitOutput $targetPath @("status", "--short")).Stdout
    $targetClean = if ([string]::IsNullOrWhiteSpace($targetStatus)) { "CLEAN" } else { "DIRTY (uncommitted changes present)" }

    Write-Host " TARGET REPOSITORY:" -ForegroundColor Green
    Write-Host "   Path:         $targetPath"
    Write-Host "   Branch:       $targetBranch (expected: $($Sources.target.branch))"
    Write-Host "   HEAD:         $targetHead"
    Write-Host "   Worktree:     $targetClean"
    Write-Host "   Expansion:    STRICT VANILLA / CLASSIC (TBC & WotLK strictly prohibited)" -ForegroundColor Green
    Write-Host ""

    $cmangosPath = $Sources.upstreams.cmangos.path
    $cmangosHead = (Get-GitOutput $cmangosPath @("rev-parse", "HEAD")).Stdout
    $cmangosWm = $Watermarks.watermarks.cmangos.current_watermark
    $cmangosUnscanned = (Get-GitOutput $cmangosPath @("rev-list", "--count", "$cmangosWm..$cmangosHead")).Stdout

    Write-Host " UPSTREAM: CMaNGOS PlayerBots ($($Sources.upstreams.cmangos.status)):" -ForegroundColor Yellow
    Write-Host "   Path:         $cmangosPath"
    Write-Host "   Branch:       $($Sources.upstreams.cmangos.branch)"
    Write-Host "   HEAD:         $cmangosHead"
    Write-Host "   Watermark:    $cmangosWm"
    Write-Host "   Unscanned:    $cmangosUnscanned commits"
    Write-Host ""

    $vmangosPath = $Sources.upstreams.vmangos.path
    $vmangosHead = (Get-GitOutput $vmangosPath @("rev-parse", "HEAD")).Stdout
    $vmangosWm = $Watermarks.watermarks.vmangos.current_watermark
    $vmangosUnscanned = (Get-GitOutput $vmangosPath @("rev-list", "--count", "$vmangosWm..$vmangosHead", "--", "src/game/PlayerBots")).Stdout

    Write-Host " UPSTREAM: vMaNGOS PlayerBots Core ($($Sources.upstreams.vmangos.status)):" -ForegroundColor Yellow
    Write-Host "   Path:         $vmangosPath"
    Write-Host "   Branch:       $($Sources.upstreams.vmangos.branch)"
    Write-Host "   HEAD:         $vmangosHead"
    Write-Host "   Watermark:    $vmangosWm"
    Write-Host "   Unscanned:    $vmangosUnscanned commits"
    Write-Host ""

    Write-Host " PORTING LEDGER METRICS:" -ForegroundColor Magenta
    Write-Host "   Total Audited:     $($Ledger.metrics.total_audited)"
    Write-Host "   Pending Ports:     $($Ledger.metrics.pending)"
    Write-Host "   Selected:          $($Ledger.metrics.selected)"
    Write-Host "   Ported / Verified: $($Ledger.metrics.ported) / $($Ledger.metrics.verified)"
    Write-Host "   Pushed:            $($Ledger.metrics.pushed)"
    Write-Host "   Already Present:   $($Ledger.metrics.already_present)"
    Write-Host "   Rejected:          $($Ledger.metrics.rejected)"
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Invoke-ScanSource([string]$sourceKey, [string]$scanMode) {
    Write-Host "`n>>> Scanning $sourceKey in $scanMode mode..." -ForegroundColor Cyan
    $upstream = $Sources.upstreams.$sourceKey
    $repoPath = $upstream.path
    $wm = $Watermarks.watermarks.$sourceKey.current_watermark
    $head = (Get-GitOutput $repoPath @("rev-parse", "HEAD")).Stdout

    $filterPath = if ($sourceKey -eq "vmangos") { @("src/game/PlayerBots") } else { @() }
    $revListArgs = @("log", "$wm..$head", "--format=%H|%an|%ad|%s", "--date=short")
    if ($filterPath.Count -gt 0) {
        $revListArgs += "--"
        $revListArgs += $filterPath
    }

    $logRes = Get-GitOutput $repoPath $revListArgs
    if ([string]::IsNullOrWhiteSpace($logRes.Stdout)) {
        Write-Host "No new commits found since watermark $wm." -ForegroundColor Green
        return
    }

    $rawLines = $logRes.Stdout -split "`n"
    Write-Host "Found $($rawLines.Count) candidate commits." -ForegroundColor Yellow

    foreach ($rawLine in $rawLines) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $parts = $line.Split('|')
        $sha = $parts[0]
        $author = $parts[1]
        $date = $parts[2]
        $subject = $parts[3]

        $status = "PENDING"
        $priority = "P2"
        $reason = "Awaiting manual/AI audit"

        # ADR-008: Strict Vanilla / Classic Mandate - check TBC/WotLK FIRST to prevent any post-Vanilla port
        if ($subject -match "(?i)\b(tbc|wotlk|wrath|burning\s*crusade|outland|northrend|arena\s*team|flying\s*mount|deathknight|dk|malchezaar|illidan|arthas|resilience|jewelcrafting|socket)\b") {
            $status = "EXPANSION_INCOMPATIBLE"
            $priority = "P3"
            $reason = "Strict Vanilla Mandate (ADR-008): Post-Vanilla TBC/WotLK content is strictly prohibited"
        } elseif ($subject -match "(?i)\b(crash|corruption|uaf|lifetime|null\s*pointer|segfault|assert)\b") {
            $status = "CRITICAL"
            $priority = "P0"
            $reason = "Stability/crash fix detected from keywords"
        } elseif ($subject -match "(?i)\b(fix|heal|threat|combat|stance|path|movement|travel|resurrect|cure|dispel)\b") {
            $status = "RECOMMENDED"
            $priority = "P1"
            $reason = "AI correctness / gameplay fix"
        }

        $color = "Gray"
        if ($status -eq "CRITICAL") { $color = "Red" }
        elseif ($status -eq "RECOMMENDED") { $color = "Green" }
        elseif ($status -eq "EXPANSION_INCOMPATIBLE") { $color = "DarkGray" }

        Write-Host "  [$priority] $sha ($date): $subject -> $status" -ForegroundColor $color

        if (-not $Ledger.entries.$sha) {
            $Ledger.entries | Add-Member -NotePropertyName $sha -NotePropertyValue @{
                source = $sourceKey
                sha = $sha
                author = $author
                date = $date
                subject = $subject
                priority = $priority
                status = $status
                triage_reason = $reason
                audit_mode = $scanMode
                audited_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            } -Force
            $Ledger.metrics.total_audited++
            if ($status -eq "CRITICAL" -or $status -eq "RECOMMENDED") {
                $Ledger.metrics.selected++
            } elseif ($status -eq "EXPANSION_INCOMPATIBLE") {
                $Ledger.metrics.rejected++
            } else {
                $Ledger.metrics.pending++
            }
        }
    }

    $Watermarks.watermarks.$sourceKey.last_scan_date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $Watermarks.watermarks.$sourceKey.last_scanned_head = $head
    Save-JsonFile $WatermarksJsonPath $Watermarks
    Save-JsonFile $LedgerJsonPath $Ledger
    Write-Host "Audit completed and ledger updated." -ForegroundColor Green
}

function Invoke-VerifyQuick {
    Write-Host "=== VERIFY QUICK: Compiling target modules.lib ===" -ForegroundColor Cyan
    $cmake = $Sources.target.build_configuration.cmake_executable
    $buildDir = Join-Path $Sources.target.path "build"
    & $cmake --build $buildDir --target modules --config Release --parallel 4
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PASS: modules.lib compiled successfully." -ForegroundColor Green
    } else {
        Write-Host "FAIL: modules.lib compilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}

function Invoke-VerifyFull {
    Write-Host "=== VERIFY FULL: Compiling and linking mangosd.exe ===" -ForegroundColor Cyan
    $cmake = $Sources.target.build_configuration.cmake_executable
    $buildDir = Join-Path $Sources.target.path "build"
    & $cmake --build $buildDir --target mangosd --config Release --parallel 4
    if ($LASTEXITCODE -eq 0) {
        Write-Host "PASS: mangosd.exe built and linked successfully." -ForegroundColor Green
    } else {
        Write-Host "FAIL: mangosd.exe build failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
}

switch ($Command.ToLower()) {
    "status" {
        Show-Status
    }
    "scan" {
        $src = if ($Argument) { $Argument.ToLower() } else { "all" }
        $scanMode = if ($SecondaryArgument) { $SecondaryArgument } else { $Mode }
        if ($src -eq "cmangos" -or $src -eq "all") { Invoke-ScanSource "cmangos" $scanMode }
        if ($src -eq "vmangos" -or $src -eq "all") { Invoke-ScanSource "vmangos" $scanMode }
    }
    "verify-quick" {
        Invoke-VerifyQuick
    }
    "verify-full" {
        Invoke-VerifyFull
    }
    "roadmap" {
        Get-Content (Join-Path $ProjectRoot "ROADMAP.md")
    }
    "ledger" {
        $filterSrc = $Argument.ToLower()
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " PORTING LEDGER SUMMARY" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        $entries = $Ledger.entries.PSObject.Properties
        foreach ($prop in $entries) {
            $e = $prop.Value
            if ($filterSrc -and $e.source -ne $filterSrc) { continue }
            $color = "Yellow"
            if ($e.status -eq "CRITICAL") { $color = "Red" }
            elseif ($e.status -eq "RECOMMENDED" -or $e.status -eq "PORTED") { $color = "Green" }
            elseif ($e.status -eq "EXPANSION_INCOMPATIBLE" -or $e.status -eq "REJECTED") { $color = "DarkGray" }
            Write-Host "[$($e.source)] $($e.sha.Substring(0,8)) ($($e.date)) [$($e.priority)] $($e.status): $($e.subject)" -ForegroundColor $color
        }
    }
    "widen-scope" {
        Write-Host "[PROHIBITED] Widening the scan scope into historical donor backlogs is STRICTLY PROHIBITED." -ForegroundColor Red
        Write-Host "Per ADR-006 and AGENTS.md Section 2.5, this action risks scope explosion, regression hazards, and TBC/WotLK contamination." -ForegroundColor Yellow
        Write-Host "MANDATORY DOUBLE-CONFIRMATION GATE: To proceed, you must provide explicit secondary confirmation." -ForegroundColor Cyan
    }
    "commit-policy" {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " COMMIT & PUSH POLICY (ADR-007 / AGENTS.md 2.6)" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " 1. Batch Auditing: PERMITTED (audit up to 50 candidates in batch)." -ForegroundColor Green
        Write-Host " 2. Batch Commits:  STRICTLY PROHIBITED." -ForegroundColor Red
        Write-Host " 3. Granularity:    1 Upstream Donor Commit = 1 Target Commit = 1 Remote Push." -ForegroundColor Yellow
        Write-Host " 4. Target Branch:  mantech-turtle on tortoise-wow-extended." -ForegroundColor Yellow
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    "vanilla-mandate" {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " STRICT VANILLA / CLASSIC MANDATE (ADR-008 / AGENTS.md 2.7)" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " 1. Target Lineage:  Strictly Vanilla (Classic 1.12.1 / Turtle WoW 1.18.1 Classic+)." -ForegroundColor Green
        Write-Host " 2. TBC & WotLK:     STRICTLY PROHIBITED. Zero tolerance for post-Vanilla code." -ForegroundColor Red
        Write-Host " 3. Permitted Scope: ONLY Vanilla and Classic-related changes/fixes." -ForegroundColor Yellow
        Write-Host " 4. Rejection Rule:  Any post-Vanilla commit is auto-tagged EXPANSION_INCOMPATIBLE (P3)." -ForegroundColor DarkGray
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    default {
        Write-Host "Available commands: status, scan, verify-quick, verify-full, roadmap, ledger, commit-policy, vanilla-mandate." -ForegroundColor Yellow
        Write-Host "Notice: Strict Vanilla/Classic only (no TBC/WotLK). Audits in batch; commits commit-by-commit." -ForegroundColor Cyan
    }
}
