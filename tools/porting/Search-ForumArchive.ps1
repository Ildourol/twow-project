<#
.SYNOPSIS
    Search and query the official Turtle-WoW forum archive for patches, changelogs, bug reports, and mechanics specifications.

.DESCRIPTION
    Searches across 22,155 forum threads in resources/forum/ to assist agents and developers during VMaNGOS-to-Tortoise porting.
    Supports title matching, full-text content searching, category filtering, official staff filtering, DB table mapping, and excerpt generation.

.PARAMETER Query
    Search keyword or regex pattern to search for.

.PARAMETER Category
    Filter by category: 'All', 'Patches', 'Changelogs', 'Combat', 'Spells', 'Quests', 'Bugs', 'Crashes', 'Itemization', 'Database'.

.PARAMETER DBTable
    Filter by target database table: 'quest_template', 'creature_template', 'item_template', 'gameobject_template', 'loot_template', 'creature_movement'.

.PARAMETER ContentSearch
    If set, searches file contents in addition to filenames.

.PARAMETER OfficialOnly
    If set, filters results to posts authored by official staff ([Turtle WoW Team], Torta, Pompa, etc.).

.PARAMETER Limit
    Maximum number of results to display (default: 20).

.PARAMETER Year
    Optional year filter (e.g. 2025, 2026).

.EXAMPLE
    .\tools\porting\Search-ForumArchive.ps1 -Query "parry haste"
    .\tools\porting\Search-ForumArchive.ps1 -Query "Holy Strike" -Category Spells
    .\tools\porting\Search-ForumArchive.ps1 -Query "Questioning Reethe" -DBTable quest_template
    .\tools\porting\Search-ForumArchive.ps1 -Query "Ornate Dagger" -DBTable item_template -ContentSearch
    .\tools\porting\Search-ForumArchive.ps1 -Category Crashes -Limit 10
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Query = "",

    [Parameter()]
    [ValidateSet('All', 'Patches', 'Changelogs', 'Combat', 'Spells', 'Quests', 'Bugs', 'Crashes', 'Itemization', 'Database')]
    [string]$Category = 'All',

    [Parameter()]
    [ValidateSet('None', 'quest_template', 'creature_template', 'item_template', 'gameobject_template', 'loot_template', 'creature_movement')]
    [string]$DBTable = 'None',

    [Parameter()]
    [switch]$ContentSearch,

    [Parameter()]
    [switch]$OfficialOnly,

    [Parameter()]
    [int]$Limit = 20,

    [Parameter()]
    [string]$Year = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$ForumDir = Join-Path $ProjectRoot "resources\forum"

if (-not (Test-Path $ForumDir)) {
    # Check if we are running in standalone repo
    $StandaloneForum = Join-Path $ProjectRoot "forum"
    if (Test-Path $StandaloneForum) {
        $ForumDir = $StandaloneForum
    } else {
        Write-Error "Forum archive not found at: $ForumDir"
        exit 1
    }
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " Turtle-WoW Forum Intelligence & Database Mining Search" -ForegroundColor Cyan
Write-Host " Archive: $ForumDir" -ForegroundColor DarkGray
Write-Host " Category: $Category | DBTable: $DBTable | Query: '$Query' | ContentSearch: $ContentSearch" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# Step 1: Filter files based on Year, Category, and DBTable
$FileFilter = if ($Year) { "$Year*.txt" } else { "*.txt" }
$CandidateFiles = Get-ChildItem -Path $ForumDir -Filter $FileFilter -File

# Apply DBTable mapping if specified
if ($DBTable -ne 'None') {
    switch ($DBTable) {
        'quest_template'       { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'quest|escort|chain|turnin|giver' } }
        'creature_template'    { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'mob|creature|boss|npc|respawn|elite|stat' } }
        'item_template'        { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'item|weapon|armor|stat|squish|gear|trinket|set' } }
        'gameobject_template'  { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'chest|door|node|ore|herb|flower|trap|object' } }
        'loot_template'        { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'loot|drop|chance|skinning|pickpocket' } }
        'creature_movement'    { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'waypoint|patrol|escort|path|speed|stuck|reverse' } }
    }
}

switch ($Category) {
    'Patches'     { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'Patch\s|Patch-|_Patch' } }
    'Changelogs'  { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'Changelog|\d{4}\s*—\s*[A-Z]' } }
    'Combat'      { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'combat|pvp|damage|parry|crit|armor|threat|haste|weapon' } }
    'Spells'      { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'spell|aura|talent|buff|debuff|proc|totem|blessing' } }
    'Quests'      { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'quest|escort|turnin|giver|chain' } }
    'Bugs'        { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'bug|issue|broken|error|wrong|fail|not working' } }
    'Crashes'     { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'crash|freeze|disconnect|error\s*132|exception' } }
    'Itemization' { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'item|loot|drop|gear|tier|itemization|squish' } }
    'Database'    { $CandidateFiles = $CandidateFiles | Where-Object { $_.Name -match 'item|loot|quest|creature|vendor|template|stats' } }
    Default       { }
}

$Results = [System.Collections.Generic.List[PSCustomObject]]::new()
$Count = 0

foreach ($file in $CandidateFiles) {
    $TitleMatch = $false
    $ContentMatch = $false
    $Snippet = ""
    $Author = ""
    $DateStr = ""

    # Check filename first
    if ([string]::IsNullOrWhiteSpace($Query) -or ($file.Name -match [regex]::Escape($Query))) {
        $TitleMatch = $true
    }

    # If content search is enabled or official filter is needed, read header lines
    if ($ContentSearch -or $OfficialOnly -or (-not $TitleMatch)) {
        try {
            $lines = Get-Content -Path $file.FullName -TotalCount 200 -ErrorAction SilentlyContinue
            if ($lines) {
                # Extract metadata from header
                foreach ($line in ($lines | Select-Object -First 10)) {
                    if ($line -match '^(Posted|by)\s*:\s*(.+)$' -or $line -match '^by\s+([^\-]+)\s*-\s*(.+)$') {
                        $Author = $Matches[1]
                        $DateStr = $Matches[2]
                    }
                    if ($line -match '\[Turtle WoW Team\]|Torta|Pompa|Junkernaut') {
                        $Author = "Turtle WoW Staff ($Author)"
                    }
                }

                if ($OfficialOnly -and ($Author -notmatch 'Turtle WoW Team|Torta|Pompa|Junkernaut')) {
                    continue
                }

                if ($ContentSearch -and -not [string]::IsNullOrWhiteSpace($Query)) {
                    $matchLine = $lines | Where-Object { $_ -match [regex]::Escape($Query) } | Select-Object -First 1
                    if ($matchLine) {
                        $ContentMatch = $true
                        $Snippet = $matchLine.Trim()
                        if ($Snippet.Length -gt 160) { $Snippet = $Snippet.Substring(0, 157) + "..." }
                    }
                }
            }
        } catch {
            continue
        }
    }

    # Decide if match qualifies
    if ($TitleMatch -or $ContentMatch) {
        $cleanTitle = $file.Name -replace '^\d{4}-\d{2}-\d{2}-\d{2}-\d{2}-\d{2}_', '' -replace '\.txt$', ''
        $dateFromFilename = if ($file.Name -match '^(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { "Unknown" }

        $Results.Add([PSCustomObject]@{
            Date = $dateFromFilename
            Title = $cleanTitle
            Snippet = $Snippet
            File = $file.FullName
        })

        $Count++
        if ($Count -ge $Limit) { break }
    }
}

Write-Host "Found $($Results.Count) matches (limit: $Limit):" -ForegroundColor Green
Write-Host ""

$Index = 1
foreach ($r in $Results) {
    Write-Host "[$Index] [$($r.Date)] $($r.Title)" -ForegroundColor Yellow
    Write-Host "    Path: file:///$($r.File -replace '\\', '/')" -ForegroundColor DarkGray
    if ($r.Snippet) {
        Write-Host "    Excerpt: $($r.Snippet)" -ForegroundColor Gray
    }
    Write-Host ""
    $Index++
}

if ($Results.Count -eq 0) {
    Write-Host "No matching threads found. Try broadening the search query or changing category." -ForegroundColor Yellow
}
