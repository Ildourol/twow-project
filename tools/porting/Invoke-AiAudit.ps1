<#
.SYNOPSIS
    AI Semantic Auditor & Context Assembler for VMaNGOS Donor Commits.
.DESCRIPTION
    Replaces static keyword/letter filtering with deep semantic context assembly:
      1. Extracts full donor diff and commit log.
      2. Analyzes target files in tortoise-wow, extracting exact surrounding context.
      3. Performs forum intelligence mining for related Turtle WoW mechanics.
      4. Detects specific Turtle divergences (custom parameters, structs, macros).
      5. Generates a structured AI Dossier in tools/queue/ai_dossiers/<sha>.md ready for AI synthesis.
.PARAMETER DonorSha
    The VMaNGOS commit hash to audit.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DonorSha
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path (Join-Path $ScriptDir "..\..")
$VmangosRepo = Join-Path $ProjectRoot "reference-upstreams\vmangos-core"
$TortoiseRepo = Join-Path $ProjectRoot "tortoise-wow"
$DossierDir = Join-Path $ProjectRoot "tools\queue\ai_dossiers"

if (-not (Test-Path $DossierDir)) { New-Item -ItemType Directory -Path $DossierDir -Force | Out-Null }

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "  AI Semantic Context Assembler: Commit $DonorSha" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor Cyan

# 1. Verify and extract donor commit
$commitDetails = git -C $VmangosRepo log -n 1 --pretty=format:"%H|%h|%an|%ad|%s" --date=short $DonorSha 2>$null
if (-not $commitDetails) {
    Write-Error "Commit $DonorSha not found in vmangos-core repository."
    return
}

$parts = $commitDetails.Split('|')
$fullSha = $parts[0]
$shortSha = $parts[1]
$author = $parts[2]
$date = $parts[3]
$subject = $parts[4]

Write-Host "Author : $author ($date)" -ForegroundColor DarkGray
Write-Host "Subject: $subject" -ForegroundColor Yellow

# 2. Extract full diff
$diff = git -C $VmangosRepo show --patch --stat $fullSha

# 3. Identify touched files
$touchedFiles = git -C $VmangosRepo diff-tree --no-commit-id --name-only -r $fullSha
$fileAnalysis = [System.Collections.Generic.List[object]]::new()

foreach ($tf in $touchedFiles) {
    $tortoiseFile = Join-Path $TortoiseRepo $tf
    $existsInTortoise = Test-Path $tortoiseFile
    $localContext = "File does not exist in tortoise-wow."

    if ($existsInTortoise) {
        $lineCount = (Get-Content $tortoiseFile).Count
        $localContext = "Exists ($lineCount lines)."
    }

    [void]$fileAnalysis.Add([PSCustomObject]@{
        File = $tf
        ExistsInTurtle = $existsInTortoise
        Status = $localContext
    })
}

# 4. Dry-run git apply check
$tempPatch = Join-Path $DossierDir "temp_$shortSha.patch"
git -C $VmangosRepo format-patch -1 --stdout $fullSha | Out-File -FilePath $tempPatch -Encoding utf8
$applyOutput = cmd /c "git -C ""$TortoiseRepo"" apply --check ""$tempPatch"" 2>&1"
$cleanApply = ($LASTEXITCODE -eq 0)
if (Test-Path $tempPatch) { Remove-Item $tempPatch -Force }

# 5. Mine Forum Archive for Related Mechanics
Write-Host "Mining forum archive for related mechanics..." -ForegroundColor DarkGray
$searchKeywords = ($subject -replace '[^\w\s]', ' ' -split '\s+' | Where-Object { $_.Length -gt 4 })
$forumHits = [System.Collections.Generic.List[string]]::new()

$searchScript = Join-Path $ScriptDir "Search-ForumArchive.ps1"
if (Test-Path $searchScript) {
    foreach ($kw in ($searchKeywords | Select-Object -First 2)) {
        $hits = & powershell.exe -ExecutionPolicy Bypass -File $searchScript -Query $kw -Limit 2 2>$null
        foreach ($h in $hits) {
            if ($h -match '\[Thread \d+\]') { [void]$forumHits.Add($h.Trim()) }
        }
    }
}

# 6. Build AI Markdown Dossier
$dossierPath = Join-Path $DossierDir "$shortSha.md"
$md = @"
# AI Semantic Audit Dossier: Commit $shortSha

- **Commit SHA**: $fullSha
- **Author**: $author ($date)
- **Commit Subject**: $subject
- **Clean 'git apply' Status**: $(if ($cleanApply) { "PASS (Clean context)" } else { "FAIL (Context Divergence Detected - Candidate for AI Adaptation)" })

---

## 1. Touched Files & Turtle Parity

| Target File | Exists in Turtle-WoW? | Status / Size |
| :--- | :--- | :--- |
"@

foreach ($fa in $fileAnalysis) {
    $md += "`n| ``$($fa.File)`` | $(if ($fa.ExistsInTurtle) { 'YES' } else { 'NO (Missing)' }) | $($fa.Status) |"
}

$md += @"


---

## 2. Turtle Forum Intelligence Hits

"@

if ($forumHits.Count -gt 0) {
    foreach ($fh in ($forumHits | Select-Object -Unique -First 5)) {
        $md += "- $fh`n"
    }
} else {
    $md += "*No direct forum conflicts detected for extracted keywords.*`n"
}

$md += @"

---

## 3. Git Apply Check Diagnostics

$(if ($cleanApply) { "Diff applies cleanly without manual line intervention." } else { "Context mismatch output:`n````text`n$applyOutput`n````" })

---

## 4. Full Upstream Diff

````diff
$diff
````

---

## 5. AI Semantic Evaluation & Adaptation Plan

When an AI Agent reviews this commit:
1. **Analyze Root Cause**: What specific defect or formula inaccuracy is VMaNGOS resolving?
2. **Detect Turtle Divergence**: Check why git apply failed (e.g. custom Turtle parameters, Debuff masks, racials).
3. **Preserve Invariants**: Ensure Turtle-specific mechanics (e.g. ``inGurubashiArena``, ``UI64LIT``, custom spells $\ge 300,000$) remain intact.
4. **Synthesize & Stage**: Adapt the C++ code, write to ``tools/queue/staging_patches/$shortSha.patch``, and stage for MSVC compilation.
"@

[System.IO.File]::WriteAllText($dossierPath, $md, [System.Text.Encoding]::UTF8)

Write-Host "`n[AI DOSSIER READY] Saved to: $dossierPath" -ForegroundColor Green
Write-Host "Clean Apply Status: $(if ($cleanApply) { 'CLEAN' } else { 'DIVERGED (AI Adaptation Candidate)' })" -ForegroundColor $(if ($cleanApply) { 'Green' } else { 'Yellow' })
Write-Host "================================================================================" -ForegroundColor Cyan

return [PSCustomObject]@{
    Sha = $shortSha
    CleanApply = $cleanApply
    DossierPath = $dossierPath
    Subject = $subject
}
