<#
.SYNOPSIS
    Unified Port Pipeline: Runs Probe -> Forum Triage -> DB Check -> C++ Staging in a single automated step.
.DESCRIPTION
    Replaces manual switching between task 2, task 3, and task 4.
    Can run on a single SHA or automatically pull the next N pending candidates from CRUCIAL_COMMITS_QUEUE.csv.
.PARAMETER DonorSha
    Optional single SHA or list of SHAs to process.
.PARAMETER BatchCount
    Optional number of candidates to pull from the pending queue.
.PARAMETER Tier
    Optional tier filter (1 to 5) when pulling from the queue.
.PARAMETER AutoBuild
    If set, automatically invokes Agent 1 (task 1 / Build-ReadyPackages.ps1) after staging completes!
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$DonorSha = @(),

    [Parameter()]
    [int]$BatchCount = 0,

    [Parameter()]
    [int]$Tier = 0,

    [Parameter()]
    [switch]$AutoBuild
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$VmangosRepo = Join-Path $ProjectRoot "reference-upstreams\vmangos-core"
$TortoiseRepo = Join-Path $ProjectRoot "tortoise-wow"
$QueueDir = Join-Path $ProjectRoot "tools\queue"
$ReadyDir = Join-Path $QueueDir "02_ready_to_build"
$CompletedDir = Join-Path $QueueDir "03_completed"
$RejectedDir = Join-Path $QueueDir "04_rejected"
$StagingPatches = Join-Path $QueueDir "staging_patches"
$StagingSql = Join-Path $QueueDir "staging_sql"

# Ensure directories exist
foreach ($dir in @($ReadyDir, $CompletedDir, $RejectedDir, $StagingPatches, $StagingSql)) {
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

# 1. Resolve Target SHAs
$shasToProcess = [System.Collections.Generic.List[string]]::new()

if ($DonorSha.Count -gt 0) {
    foreach ($s in $DonorSha) { [void]$shasToProcess.Add($s.Trim()) }
} elseif ($BatchCount -gt 0) {
    $queueCsv = Join-Path $ScriptDir "CRUCIAL_COMMITS_QUEUE.csv"
    if (-not (Test-Path $queueCsv)) {
        Write-Error "Queue file not found: $queueCsv"
        return
    }

    # Load already-completed and rejected SHAs
    $processedShas = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    git -C $TortoiseRepo log --pretty=format:"%s %b" | ForEach-Object {
        if ($_ -match "vmangos/core@`?([0-9a-f]{7,40})`?") {
            [void]$processedShas.Add($Matches[1].Substring(0, [Math]::Min(9, $Matches[1].Length)))
        }
    }
    Get-ChildItem -Path $RejectedDir -Filter "*.json" | ForEach-Object {
        [void]$processedShas.Add([System.IO.Path]::GetFileNameWithoutExtension($_.Name))
    }

    $csvRows = Import-Csv -Path $queueCsv
    $count = 0
    foreach ($row in $csvRows) {
        $cSha = $row.ShortSha
        $cTier = [int]$row.Tier

        if ($processedShas.Contains($cSha)) { continue }
        if ($Tier -gt 0 -and $cTier -ne $Tier) { continue }

        [void]$shasToProcess.Add($cSha)
        $count++
        if ($count -ge $BatchCount) { break }
    }
} else {
    Write-Host "Usage: Invoke-PortPipeline.ps1 -DonorSha <sha> OR -BatchCount <N> [-Tier <T>] [-AutoBuild]" -ForegroundColor Yellow
    return
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  Unified Port Pipeline: Processing $($shasToProcess.Count) Candidate(s)" -ForegroundColor Cyan
Write-Host "  AutoBuild Flag: $(if ($AutoBuild) { 'ENABLED (will compile & push at end)' } else { 'DISABLED (staging only)' })" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# Determine next PORT ID
function Get-NextPortId {
    $existing = Get-ChildItem -Path $CompletedDir, $ReadyDir -Filter "PORT-*.json"
    $maxNum = 0
    foreach ($f in $existing) {
        if ($f.Name -match 'PORT-(\d+)\.json') {
            $n = [int]$Matches[1]
            if ($n -gt $maxNum) { $maxNum = $n }
        }
    }
    $nextNum = $maxNum + 1
    return ("PORT-{0:D4}" -f $nextNum)
}

$stagedCount = 0
$rejectedCount = 0

foreach ($sha in $shasToProcess) {
    Write-Host "`n>>> [Pipeline] Auditing Candidate: $sha" -ForegroundColor Cyan

    # 1. Run AI Semantic Context Assembler
    $aiScript = Join-Path $ScriptDir "Invoke-AiAudit.ps1"
    $aiRes = & powershell.exe -ExecutionPolicy Bypass -File $aiScript -DonorSha $sha
    $cleanApply = $aiRes.CleanApply
    $dossierPath = $aiRes.DossierPath
    $subject = $aiRes.Subject

    # 2. Extract patch
    $patchFile = Join-Path $StagingPatches "$sha.patch"
    git -C $VmangosRepo format-patch -1 --stdout $sha | Out-File -FilePath $patchFile -Encoding utf8

    # 3. Assemble Package in 02_ready_to_build/
    $portId = Get-NextPortId
    $commitSubject = (git -C $VmangosRepo show -s --pretty=format:"%s" $sha).Trim()
    $subsystem = "Core"
    if ($commitSubject -match "^(\w+):") { $subsystem = $Matches[1] }

    $pkgFile = Join-Path $ReadyDir "$portId.json"

    if ($cleanApply) {
        $pkgStatus = "READY_FOR_BUILD"
        Write-Host "[AI VERDICT: CLEAN APPLY] Staged $portId for direct compilation!" -ForegroundColor Green
    } else {
        $pkgStatus = "AWAITING_AI_ADAPTATION"
        Write-Host "[AI VERDICT: ADAPTATION CANDIDATE] Context divergence detected in Turtle code." -ForegroundColor Yellow
        Write-Host "AI Dossier available at: $dossierPath" -ForegroundColor DarkGray
        Write-Host "Staged $portId as AWAITING_AI_ADAPTATION." -ForegroundColor Yellow
    }

    $pkgObj = [PSCustomObject]@{
        status       = $pkgStatus
        id           = $portId
        donor_sha    = $sha
        subsystem    = $subsystem
        title        = ($commitSubject -replace '^(\w+):\s*', '')
        clean_apply  = $cleanApply
        ai_dossier   = "tools/queue/ai_dossiers/$sha.md"
        patch_file   = "tools/queue/staging_patches/$sha.patch"
        sql_file     = $null
        commit_msg   = "Port($subsystem): $($commitSubject -replace '^(\w+):\s*', '') (vmangos/core@$sha)"
    }

    $pkgObj | ConvertTo-Json -Depth 4 | Out-File $pkgFile -Encoding utf8
    $stagedCount++
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "  Pipeline Staging Summary: Staged: $stagedCount | Rejected: $rejectedCount" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

# 4. If AutoBuild is requested, trigger Agent 1 now
if ($AutoBuild -and $stagedCount -gt 0) {
    Write-Host "`n>>> AutoBuild flag set: Triggering Agent 1 (Build-ReadyPackages.ps1)..." -ForegroundColor Yellow
    $buildScript = Join-Path $ScriptDir "Build-ReadyPackages.ps1"
    & powershell.exe -ExecutionPolicy Bypass -File $buildScript
} elseif ($stagedCount -gt 0) {
    Write-Host "`nReady packages are waiting in tools/queue/02_ready_to_build/." -ForegroundColor Cyan
    Write-Host "Run 'task 1' or 'Build-ReadyPackages.ps1' when you are ready to compile and push!" -ForegroundColor Yellow
}
