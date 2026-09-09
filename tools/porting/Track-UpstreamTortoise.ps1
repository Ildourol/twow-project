<#
.SYNOPSIS
    Monitors and tracks upstream commits from the official Penqle/tortoise-wow repository.
.DESCRIPTION
    Fetches the latest commits from origin (https://github.com/Penqle/tortoise-wow),
    compares them against the current branch (extended), audits for potential ID or
    subsystem collisions (such as SCRIPT_COMMAND IDs and database migrations),
    and updates the upstream tracking registry.
.PARAMETER Branch
    Upstream branch to monitor (default: 'main'). Can also be '1181dev'.
.PARAMETER SkipFetch
    Switch to skip fetching remote origin.
#>
[CmdletBinding()]
param(
    [string]$Branch = "main",
    [switch]$SkipFetch
)

$TortoisePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow"
$TrackerCsv = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\porting\UPSTREAM_TRACKER.csv"
$SyncDoc = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\UPSTREAM_SYNC.md"

if (!(Test-Path $TortoisePath)) {
    Write-Error "Tortoise-WoW repository not found at $TortoisePath"
    return
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Official Upstream Monitor: Penqle/tortoise-wow" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

if (!$SkipFetch) {
    Write-Host "Fetching latest updates from origin ($Branch)..." -ForegroundColor Yellow
    git -C $TortoisePath fetch origin $Branch 2>$null
}

# Check divergence
$behindCount = (git -C $TortoisePath rev-list --count HEAD..origin/$Branch).Trim()
$aheadCount = (git -C $TortoisePath rev-list --count origin/$Branch..HEAD).Trim()

Write-Host "Branch Status vs origin/$Branch :" -ForegroundColor Cyan
Write-Host "  Ahead by  : $aheadCount commit(s)" -ForegroundColor Green
Write-Host "  Behind by : $behindCount commit(s)" -ForegroundColor $(if ($behindCount -eq "0") { "Green" } else { "Red" })

if ($behindCount -eq "0") {
    Write-Host "`n[UP TO DATE] No unmerged commits from origin/$Branch." -ForegroundColor Green
    return
}

Write-Host "`nIncoming Unmerged Commits from origin/$Branch :" -ForegroundColor Yellow
$rawCommits = git -C $TortoisePath log HEAD..origin/$Branch --pretty=format:"%H|%h|%ad|%an|%s" --date=short

$results = @()
foreach ($line in $rawCommits) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line.Split('|')
    $fullSha  = $parts[0]
    $shortSha = $parts[1]
    $date     = $parts[2]
    $author   = $parts[3]
    $subject  = $parts[4]

    # Inspect touched files for risk audit
    $files = git -C $TortoisePath diff-tree --no-commit-id --name-only -r $fullSha
    $risk = "LOW"
    $collisionWarning = ""

    if ($files -match "src/game/ScriptMgr\.h" -or $files -match "src/game/Maps/Map\.h") {
        $risk = "HIGH"
        $collisionWarning += "[ScriptCommand Check Required] "
    }
    if ($files -match "sql/database_updates/world/") {
        # Check if migration touches command 93 or other custom scripts
        $diff = git -C $TortoisePath show $fullSha -- "sql/database_updates/world/*"
        if ($diff -match "\b93\b|\b94\b") {
            $risk = "CRITICAL"
            $collisionWarning += "[Command ID 93/94 Collision] "
        } else {
            if ($risk -eq "LOW") { $risk = "MEDIUM" }
            $collisionWarning += "[DB Migration] "
        }
    }
    if ($files -match "src/game/Objects/Player\." -or $files -match "src/game/Spells/Spell\.") {
        if ($risk -eq "LOW") { $risk = "MEDIUM" }
    }

    $results += [PSCustomObject]@{
        ShortSha  = $shortSha
        Date      = $date
        Author    = $author
        Risk      = $risk
        Alert     = $collisionWarning.Trim()
        Subject   = $subject
    }
}

$results | Format-Table ShortSha, Date, Risk, Alert, Subject -AutoSize

# Export to tracker CSV
$csvEntries = $results | Select-Object ShortSha, Date, Author, Risk, Alert, Subject
$csvEntries | Export-Csv -Path $TrackerCsv -NoTypeInformation -Force
Write-Host "Upstream tracker updated at: $TrackerCsv" -ForegroundColor Green
