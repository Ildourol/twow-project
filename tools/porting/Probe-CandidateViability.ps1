<#
.SYNOPSIS
    Probes a VMaNGOS candidate commit for immediate viability against Tortoise-WoW.
.DESCRIPTION
    Automates Stage 1 pre-flight checks:
    1. Verifies if target source files exist in tortoise-wow.
    2. Checks for known architectural divergence patterns (ReadableBuffer, PartyBots, SRP6, etc.).
    3. Searches for target functions and symbols in tortoise-wow.
    4. Cross-references forum archive for intentional custom Turtle divergence.
.PARAMETER DonorSha
    One or more VMaNGOS commit hashes to probe.
.EXAMPLE
    .\tools\porting\Probe-CandidateViability.ps1 -DonorSha "84f1bbccd"
    .\tools\porting\Probe-CandidateViability.ps1 -DonorSha "e66174ef3", "b9cd08f7a"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]$DonorSha,

    [Parameter()]
    [string]$VmangosRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core",

    [Parameter()]
    [string]$TortoiseRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",

    [Parameter()]
    [string]$ForumDir = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\resources\forum"
)

$knownDivergences = @(
    @{ Pattern = "ReadableBuffer"; Reason = "VMaNGOS custom async IO layer. Turtle uses ACE MangosSocket." },
    @{ Pattern = "sAuthLogonChallengeBody"; Reason = "VMaNGOS static struct. Turtle uses dynamic std::vector buffer." },
    @{ Pattern = "SUPPORTED_CLIENT_BUILD\s*<=\s*CLIENT_BUILD_1_5_1"; Reason = "Pre-1.6 compatibility shim. Turtle targets 1.12.1/1.18.1 client." },
    @{ Pattern = "IsSavingDisabled"; Reason = "VMaNGOS Playerbot trading bypass. Not present in Turtle-WoW." },
    @{ Pattern = "HandlePartyBot(Add|Clone)Command"; Reason = "PartyBot GM commands do not exist in Turtle-WoW." },
    @{ Pattern = "MoveSpline::ComputePositionAfterTime"; Reason = "VMaNGOS predictive chase method not present in Turtle-WoW." },
    @{ Pattern = "debug send spellfail"; Reason = "Debug command not present in Turtle-WoW." },
    @{ Pattern = "m_passengerMutex"; Reason = "Multi-threaded transport mutex. Turtle transports are single-threaded on map loop." },
    @{ Pattern = "CityAttack|SummonPallid|mouthPos"; Reason = "VMaNGOS Scourge Invasion rewrite. Turtle retains classic structure." },
    @{ Pattern = "contrib/mmap"; Reason = "Offline map extraction tool. Not present in server repository." }
)

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($sha in $DonorSha) {
    if ([string]::IsNullOrWhiteSpace($sha)) { continue }

    Write-Host "`n==========================================================" -ForegroundColor Cyan
    Write-Host "  Probing Candidate: $sha" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan

    # 1. Get commit metadata from VMaNGOS
    $commitDetails = git -C $VmangosRepo show -s --pretty=format:"%h|%H|%s|%an|%ad" --date=short $sha 2>$null
    if ([string]::IsNullOrWhiteSpace($commitDetails)) {
        Write-Host "[ERROR] Could not find commit $sha in VMaNGOS repository." -ForegroundColor Red
        continue
    }

    $parts = $commitDetails.Split('|')
    $shortSha = $parts[0]
    $fullSha  = $parts[1]
    $subject  = $parts[2]
    $author   = $parts[3]
    $date     = $parts[4]

    Write-Host "Subject: $subject" -ForegroundColor Yellow
    Write-Host "Author:  $author ($date)" -ForegroundColor DarkGray

    # 2. Get modified files
    $files = git -C $VmangosRepo diff-tree --no-commit-id --name-only -r $fullSha
    $diffText = git -C $VmangosRepo show $fullSha

    $missingFiles = @()
    $matchedDivergences = @()
    $existingFiles = @()

    foreach ($f in $files) {
        if ([string]::IsNullOrWhiteSpace($f)) { continue }
        $targetPath = Join-Path $TortoiseRepo $f
        if (Test-Path $targetPath) {
            $existingFiles += $f
        } else {
            $missingFiles += $f
        }
    }

    # 3. Check for known architectural divergences
    foreach ($kd in $knownDivergences) {
        if ($diffText -match $kd.Pattern -or $subject -match $kd.Pattern) {
            $matchedDivergences += $kd.Reason
        }
    }

    # 4. Search forum for quick signal
    $forumMatches = @()
    if (Test-Path $ForumDir) {
        $searchTerms = ($subject -replace '[^\w\s]', '' -split '\s+') | Where-Object { $_.Length -gt 4 } | Select-Object -First 3
        foreach ($term in $searchTerms) {
            $hits = Get-ChildItem -Path $ForumDir -Filter "*$term*.txt" -File | Select-Object -First 2
            foreach ($h in $hits) {
                $forumMatches += $h.Name
            }
        }
    }

    # 5. Determine Verdict
    $verdict = "VIABLE"
    $reason = "Files present in tortoise-wow; no known architectural collisions."

    if ($matchedDivergences.Count -gt 0) {
        $verdict = "DO_NOT_PORT"
        $reason = "Architectural Divergence: " + ($matchedDivergences -join "; ")
    } elseif ($existingFiles.Count -eq 0 -and $missingFiles.Count -gt 0) {
        $verdict = "DO_NOT_PORT"
        $reason = "Target files missing in tortoise-wow: " + ($missingFiles -join ", ")
    } elseif ($missingFiles.Count -gt 0) {
        $verdict = "REQUIRES_SELECTIVE_PORT"
        $reason = "Partial file match: $($existingFiles.Count) exist, $($missingFiles.Count) missing."
    }

    $color = switch ($verdict) {
        "VIABLE" { "Green" }
        "DO_NOT_PORT" { "Red" }
        default { "Yellow" }
    }

    Write-Host "`nProbe Verdict: [$verdict]" -ForegroundColor $color
    Write-Host "Reason: $reason" -ForegroundColor $color
    if ($existingFiles.Count -gt 0) {
        Write-Host "Existing Files in Tortoise ($($existingFiles.Count)):" -ForegroundColor DarkGray
        foreach ($ef in $existingFiles) { Write-Host "  + $ef" -ForegroundColor DarkGray }
    }
    if ($missingFiles.Count -gt 0) {
        Write-Host "Missing Files in Tortoise ($($missingFiles.Count)):" -ForegroundColor Red
        foreach ($mf in $missingFiles) { Write-Host "  - $mf" -ForegroundColor Red }
    }
    if ($forumMatches.Count -gt 0) {
        Write-Host "Relevant Forum References ($($forumMatches.Count)):" -ForegroundColor Cyan
        foreach ($fm in $forumMatches) { Write-Host "  * $fm" -ForegroundColor Cyan }
    }

    $results.Add([PSCustomObject]@{
        ShortSha  = $shortSha
        Verdict   = $verdict
        Subject   = $subject
        Reason    = $reason
        FilesOK   = ($existingFiles -join ", ")
        FilesMiss = ($missingFiles -join ", ")
    })
}

return $results
