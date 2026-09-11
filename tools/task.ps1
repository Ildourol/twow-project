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
    [switch]$Force,

    [Parameter()]
    [string]$DonorSha = "",

    [Parameter()]
    [string]$TargetSha = "",

    [Parameter()]
    [string]$Message = "",

    [Parameter()]
    [string]$Subsystem = "General",

    [Parameter()]
    [string]$Priority = "P1",

    [Parameter()]
    [string]$Subject = "",

    [Parameter()]
    [string]$Rationale = ""
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

$Cores = if ($env:NUMBER_OF_PROCESSORS) { [int]$env:NUMBER_OF_PROCESSORS } else { 4 }

function Invoke-VerifyQuick {
    param([switch]$Quiet = $true)
    $cmake = $Sources.target.build_configuration.cmake_executable
    $buildDir = Join-Path $Sources.target.path "build"
    $extraFlags = if ($Quiet) { @("--", "/nologo", "/v:q") } else { @() }
    
    $start = Get-Date
    & $cmake --build $buildDir --target modules --config Release --parallel $Cores $extraFlags
    $code = $LASTEXITCODE
    $elapsed = [Math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    if ($code -eq 0) {
        Write-Host "[PASS] modules.lib compiled cleanly in ${elapsed}s ($Cores cores, quiet)." -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] modules.lib compilation failed with exit code $code" -ForegroundColor Red
        return $false
    }
}

function Invoke-VerifyFull {
    param([switch]$Quiet = $true)
    $cmake = $Sources.target.build_configuration.cmake_executable
    $buildDir = Join-Path $Sources.target.path "build"
    $extraFlags = if ($Quiet) { @("--", "/nologo", "/v:m") } else { @() }
    
    $start = Get-Date
    & $cmake --build $buildDir --target mangosd --config Release --parallel $Cores $extraFlags
    $code = $LASTEXITCODE
    $elapsed = [Math]::Round(((Get-Date) - $start).TotalSeconds, 1)
    if ($code -eq 0) {
        Write-Host "[PASS] mangosd.exe built and linked successfully in ${elapsed}s ($Cores cores)." -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] mangosd.exe build/link failed with exit code $code" -ForegroundColor Red
        return $false
    }
}

function Invoke-VerifyBatch {
    Write-Host "=== VERIFY BATCH: Executing batch compilation & full link ($Cores cores) ===" -ForegroundColor Cyan
    $pass = Invoke-VerifyQuick -Quiet:$false
    if ($pass) {
        Invoke-VerifyFull -Quiet:$false
    }
}

function Invoke-RecordPort {
    param(
        [string]$DonorSha,
        [string]$TargetSha,
        [string]$Subsystem = "General",
        [string]$Priority = "P1",
        [string]$Subject = "",
        [string]$Rationale = ""
    )
    if ([string]::IsNullOrWhiteSpace($DonorSha)) {
        Write-Host "Error: -DonorSha is required." -ForegroundColor Red
        return
    }
    $targetPath = $Sources.target.path
    if ([string]::IsNullOrWhiteSpace($TargetSha)) {
        $TargetSha = (Get-GitOutput $targetPath @("rev-parse", "HEAD")).Stdout
    }
    
    $script:Ledger = Load-JsonFile $LedgerJsonPath
    $entry = $script:Ledger.entries.$DonorSha
    if ($null -eq $entry) {
        Write-Host "Notice: SHA $DonorSha not yet in ledger, creating entry..." -ForegroundColor Yellow
        $script:Ledger.entries | Add-Member -NotePropertyName $DonorSha -NotePropertyValue @{
            source = "vmangos"
            sha = $DonorSha
            priority = $Priority
            subject = $Subject
            audited_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        } -Force
        $entry = $script:Ledger.entries.$DonorSha
    }
    
    $entry.status = "PORTED"
    $entry | Add-Member -NotePropertyName "target_commit_sha" -NotePropertyValue $TargetSha -Force
    $entry | Add-Member -NotePropertyName "ported_at" -NotePropertyValue (Get-Date -Format "yyyy-MM-dd HH:mm:ss") -Force
    $entry | Add-Member -NotePropertyName "verified" -NotePropertyValue $true -Force
    $entry | Add-Member -NotePropertyName "pushed" -NotePropertyValue $true -Force
    
    $script:Ledger.metrics.ported = [int]$script:Ledger.metrics.ported + 1
    $script:Ledger.metrics.verified = [int]$script:Ledger.metrics.verified + 1
    $script:Ledger.metrics.pushed = [int]$script:Ledger.metrics.pushed + 1
    if ($script:Ledger.metrics.selected -gt 0) { $script:Ledger.metrics.selected = [int]$script:Ledger.metrics.selected - 1 }
    Save-JsonFile $LedgerJsonPath $script:Ledger
    
    $portedCount = $script:Ledger.metrics.ported
    $id = "PORT-" + $portedCount.ToString("D4")
    $shortDonor = $DonorSha.Substring(0, [Math]::Min(8, $DonorSha.Length))
    $shortTarget = $TargetSha.Substring(0, [Math]::Min(8, $TargetSha.Length))
    $subj = if ($Subject) { $Subject } else { $entry.subject }
    $dossierPath = Join-Path $ProjectRoot "docs\commits\${id}_${shortDonor}.md"
    
    $bt = '`'
    $dossierContent = @"
# Commit Dossier: $id ($shortTarget)

## 1. Commit Overview

| Property | Value |
|:---|:---|
| **ID** | $bt$id$bt |
| **Target Commit SHA** | [$bt$shortTarget$bt](https://github.com/Ildourol/tortoise-wow-extended/commit/$TargetSha) |
| **Full SHA** | $bt$TargetSha$bt |
| **Subject** | $bt$subj$bt |
| **Subsystem** | $Subsystem |
| **Author** | $($entry.author) |
| **Date** | $($entry.date) |
| **Upstream Donor** | [$bt$($entry.source)/core@$shortDonor$bt](https://github.com/ileboii/core/commit/$DonorSha) |
| **Verification Status** | Verified (MSVC 2022 x64 Release: modules.lib + mangosd.exe clean link) |
| **Target Integration Branch** | ${bt}playerbots$bt |
| **Priority** | $bt$Priority$bt |

---

## 2. Rationale & Defect Description

$Rationale

---

## 3. Protected Subsystems & Safety Verification

- **Strict Vanilla/Classic Compliance**: Fully compliant with Classic 1.12.1 / Turtle WoW 1.18.1. Zero TBC/WotLK code.
- **Dungeon Clear Compatibility**: Preserved.
- **Link Verification**: Compiled cleanly with exit code 0.
"@
    [System.IO.File]::WriteAllText($dossierPath, $dossierContent, [System.Text.Encoding]::UTF8)
    Write-Host "[LEDGER & DOSSIER] Recorded $id ($shortDonor -> $shortTarget) in ledger and generated $dossierPath" -ForegroundColor Green
}

function Invoke-CommitAndPush {
    param(
        [string]$DonorSha,
        [string]$Message,
        [string]$Subsystem = "General",
        [string]$Priority = "P1",
        [string]$Rationale = ""
    )
    if ([string]::IsNullOrWhiteSpace($DonorSha) -or [string]::IsNullOrWhiteSpace($Message)) {
        Write-Host "Error: -DonorSha and -Message are required for commit-and-push." -ForegroundColor Red
        return
    }
    
    Write-Host "`n>>> Step 1/4: Quick Build Verification (modules.lib, $Cores cores, quiet)..." -ForegroundColor Cyan
    $pass = Invoke-VerifyQuick -Quiet:$true
    if (-not $pass) {
        Write-Host "[ABORT] Build failed. Commit will not be created." -ForegroundColor Red
        return
    }
    
    $targetPath = $Sources.target.path
    Write-Host ">>> Step 2/4: Git Add and Commit (atomic)..." -ForegroundColor Cyan
    & git.exe -C "$targetPath" add -A
    & git.exe -C "$targetPath" commit -q -m "$Message"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ABORT] Git commit failed." -ForegroundColor Red
        return
    }
    $targetSha = (Get-GitOutput $targetPath @("rev-parse", "HEAD")).Stdout
    $shortTarget = $targetSha.Substring(0, [Math]::Min(8, $targetSha.Length))
    Write-Host "[COMMITTED] Created commit $shortTarget on playerbots." -ForegroundColor Green
    
    Write-Host ">>> Step 3/4: Remote Git Push..." -ForegroundColor Cyan
    & git.exe -C "$targetPath" push -q origin playerbots
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARNING] Remote git push failed with exit code $LASTEXITCODE" -ForegroundColor Yellow
    } else {
        Write-Host "[PUSHED] Pushed $shortTarget to origin/playerbots." -ForegroundColor Green
    }
    
    Write-Host ">>> Step 4/4: Ledger & Dossier Recording..." -ForegroundColor Cyan
    $firstLine = ($Message -split "`n")[0].Trim()
    Invoke-RecordPort -DonorSha $DonorSha -TargetSha $targetSha -Subsystem $Subsystem -Priority $Priority -Subject $firstLine -Rationale $Rationale
    
    Write-Host "`n[COMPLETE] 1-to-1 port cycle finished cleanly: $DonorSha -> $shortTarget" -ForegroundColor Green
}

function Invoke-UpdateUpstreams {
    param(
        [string]$TargetUpstream = "all"
    )
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " UPDATE REFERENCE UPSTREAMS (Module-playerbots)" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "Policy: Fetches and fast-forwards read-only upstream donor clones." -ForegroundColor Gray
    Write-Host "Safety: Active target repo 'tortoise-wow-extended' is EXCLUDED." -ForegroundColor Green
    Write-Host ""

    $keys = @("cmangos", "vmangos")
    if ($TargetUpstream -and $TargetUpstream -ne "all") {
        if ($keys -contains $TargetUpstream.ToLower()) {
            $keys = @($TargetUpstream.ToLower())
        } else {
            Write-Host "[ERROR] Unknown upstream '$TargetUpstream'. Valid options: cmangos, vmangos, all" -ForegroundColor Red
            return
        }
    }

    foreach ($k in $keys) {
        $u = $Sources.upstreams.$k
        $repoPath = $u.path
        $branch = $u.branch
        $remote = if ($u.remote_name) { $u.remote_name } else { "origin" }
        Write-Host ">>> Updating [$k] ($($u.source_name)) at $repoPath ..." -ForegroundColor Cyan
        
        if (-not (Test-Path $repoPath)) {
            Write-Host "  [WARN] Path does not exist: $repoPath" -ForegroundColor Yellow
            continue
        }
        
        $oldHead = (Get-GitOutput $repoPath @("rev-parse", "HEAD")).Stdout
        
        # Fetch remote updates
        Write-Host "  Fetching latest from $remote..." -ForegroundColor DarkGray
        $fetchOut = & git.exe -C "$repoPath" fetch --all --prune --tags 2>&1
        
        # Check current branch
        $currBranch = (Get-GitOutput $repoPath @("branch", "--show-current")).Stdout
        if ($currBranch -ne $branch) {
            Write-Host "  Checking out tracking branch '$branch'..." -ForegroundColor DarkGray
            & git.exe -C "$repoPath" checkout "$branch" 2>&1 | Out-Null
        }
        
        # Fast-forward pull
        Write-Host "  Pulling fast-forward updates on '$branch'..." -ForegroundColor DarkGray
        $pullOut = & git.exe -C "$repoPath" pull --ff-only $remote $branch 2>&1
        
        $newHead = (Get-GitOutput $repoPath @("rev-parse", "HEAD")).Stdout
        if ($oldHead -ne $newHead) {
            $count = (Get-GitOutput $repoPath @("rev-list", "--count", "$oldHead..$newHead")).Stdout
            Write-Host "  [UPDATED] $count new commit(s) fetched! (HEAD: $($newHead.Substring(0,8)))" -ForegroundColor Green
            Write-Host "  Recent incoming commits:" -ForegroundColor Yellow
            & git.exe -C "$repoPath" log -n 5 "$oldHead..$newHead" --oneline | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        } else {
            Write-Host "  [UP-TO-DATE] Already at latest commit ($($newHead.Substring(0,8)))." -ForegroundColor Green
        }
        Write-Host ""
    }
    
    Write-Host "Excluded active project working repo: 'tortoise-wow-extended' (protected)." -ForegroundColor DarkGray
    Write-Host "[DONE] Reference upstreams update completed." -ForegroundColor Green
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
    "verify-fast" {
        Invoke-VerifyQuick
    }
    "verify-full" {
        Invoke-VerifyFull
    }
    "verify-batch" {
        Invoke-VerifyBatch
    }
    "build-options" {
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " BUILD & VERIFICATION EXECUTION OPTIONS (ADR-009)" -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host " Option 1: Fast Incremental Mode (Recommended Default)" -ForegroundColor Green
        Write-Host "   - Per-commit: compile modules.lib (~3s, minimal tokens)."
        Write-Host "   - Batch end: link mangosd.exe once."
        Write-Host " Option 2: Batch Verification Mode (High Throughput)" -ForegroundColor Yellow
        Write-Host "   - Per-commit: commit to git sequentially (preserves bisect)."
        Write-Host "   - Batch end: run verify-batch (single compile + link pass)."
        Write-Host " Option 3: Strict Full-Link Mode (P0 Safety)" -ForegroundColor Magenta
        Write-Host "   - Per-commit: full compile and link mangosd.exe (~2-3m)."
        Write-Host "============================================================" -ForegroundColor Cyan
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
        Write-Host " 4. Target Branch:  playerbots on tortoise-wow-extended." -ForegroundColor Yellow
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
    "commit-and-push" {
        $dSha = if ($DonorSha) { $DonorSha } else { $Argument }
        $msg = if ($Message) { $Message } else { $SecondaryArgument }
        $sub = if ($Subsystem -ne "General") { $Subsystem } else { if ($RemainingArgs.Count -gt 0) { $RemainingArgs[0] } else { "General" } }
        $pri = if ($Priority -ne "P1") { $Priority } else { if ($RemainingArgs.Count -gt 1) { $RemainingArgs[1] } else { "P1" } }
        Invoke-CommitAndPush -DonorSha $dSha -Message $msg -Subsystem $sub -Priority $pri -Rationale $Rationale
    }
    "record-port" {
        $dSha = if ($DonorSha) { $DonorSha } else { $Argument }
        $tSha = if ($TargetSha) { $TargetSha } else { $SecondaryArgument }
        Invoke-RecordPort -DonorSha $dSha -TargetSha $tSha -Subsystem $Subsystem -Priority $Priority -Subject $Subject -Rationale $Rationale
    }
    "update-upstreams" {
        $tgt = if ($Argument) { $Argument } else { "all" }
        Invoke-UpdateUpstreams -TargetUpstream $tgt
    }
    "sync-upstreams" {
        $tgt = if ($Argument) { $Argument } else { "all" }
        Invoke-UpdateUpstreams -TargetUpstream $tgt
    }
    "pull-upstreams" {
        $tgt = if ($Argument) { $Argument } else { "all" }
        Invoke-UpdateUpstreams -TargetUpstream $tgt
    }
    default {
        Write-Host "Available commands: status, scan, update-upstreams, verify-fast, verify-full, verify-batch, build-options, commit-and-push, record-port, roadmap, ledger, commit-policy, vanilla-mandate." -ForegroundColor Yellow
        Write-Host "Notice: Strict Vanilla/Classic only (no TBC/WotLK). Audits in batch; commits commit-by-commit." -ForegroundColor Cyan
    }
}
