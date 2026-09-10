# WorktreeManager.ps1: Safe Git worktree isolation and lifecycle management

function Get-WorktreeRoot {
    param([string]$TargetRepo = "")
    if ($TargetRepo) {
        $root = Join-Path $TargetRepo ".worktrees"
    } else {
        $cfg = Get-ProjectConfig
        $root = Join-Path $cfg.repositories.twow_project.path ".worktrees"
    }
    if (-not (Test-Path $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return (Resolve-Path $root).Path
}

function New-CandidateWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [Parameter(Mandatory=$true)][string]$CandidateId,
        [Parameter()][string]$BaseSha = "",
        [Parameter()][string]$WorktreeRoot = ""
    )

    if (-not (Test-Path $TargetRepo)) {
        throw "Target repository not found: $TargetRepo"
    }

    if ([string]::IsNullOrEmpty($WorktreeRoot)) {
        $WorktreeRoot = Get-WorktreeRoot -TargetRepo $TargetRepo
    }

    if ([string]::IsNullOrEmpty($BaseSha)) {
        $BaseSha = (git -C $TargetRepo rev-parse HEAD).Trim()
    }

    $sanitizedId = $CandidateId -replace '[^\w\-]', '_'
    $worktreePath = Join-Path $WorktreeRoot $sanitizedId
    $branchName = "worktree/$sanitizedId"

    if (Test-Path $worktreePath) {
        Write-Host "Worktree directory already exists at $worktreePath. Checking registration..." -ForegroundColor DarkGray
        return @{
            WorktreePath = $worktreePath
            Branch = $branchName
            BaseSha = $BaseSha
            AlreadyExisted = $true
        }
    }

    # Clean up any stale branch with same name
    $branchExists = git -C $TargetRepo branch --list $branchName
    if ($branchExists) {
        cmd.exe /c "git -C ""$TargetRepo"" branch -D ""$branchName"" 2>&1" | Out-Null
    }

    # Create the git worktree based on BaseSha
    Write-Host "Creating isolated worktree at $worktreePath from $BaseSha..." -ForegroundColor DarkGray
    $cmd = "git -C ""$TargetRepo"" worktree add -b ""$branchName"" ""$worktreePath"" ""$BaseSha"""
    $out = cmd.exe /c "$cmd 2>&1"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create git worktree: $($out -join ' ')"
    }

    # Store metadata inside worktree
    $meta = [ordered]@{
        candidate_id   = $CandidateId
        target_repo    = $TargetRepo
        worktree_path  = $worktreePath
        branch         = $branchName
        target_base_sha = $BaseSha
        created_at     = (Get-Date).ToString("o")
    }
    $metaFile = Join-Path $worktreePath ".twow_worktree_meta.json"
    $json = $meta | ConvertTo-Json -Depth 4
    [System.IO.File]::WriteAllText($metaFile, $json, [System.Text.UTF8Encoding]::new($false))

    return @{
        WorktreePath   = $worktreePath
        Branch         = $branchName
        BaseSha        = $BaseSha
        AlreadyExisted = $false
    }
}

function Get-ActiveWorktrees {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [Parameter()][string]$WorktreeRoot = ""
    )

    if ([string]::IsNullOrEmpty($WorktreeRoot)) {
        $WorktreeRoot = Get-WorktreeRoot -TargetRepo $TargetRepo
    }

    $list = [System.Collections.Generic.List[object]]::new()
    $raw = git -C $TargetRepo worktree list --porcelain
    $current = @{}

    foreach ($line in $raw) {
        if ($line -match '^worktree\s+(.*)') {
            if ($current.ContainsKey("worktree")) {
                [void]$list.Add([PSCustomObject]$current)
                $current = @{}
            }
            $current["worktree"] = $Matches[1].Trim()
        } elseif ($line -match '^HEAD\s+(.*)') {
            $current["head"] = $Matches[1].Trim()
        } elseif ($line -match '^branch\s+(.*)') {
            $current["branch"] = $Matches[1].Trim()
        }
    }
    if ($current.ContainsKey("worktree")) {
        [void]$list.Add([PSCustomObject]$current)
    }

    # Filter only those managed within WorktreeRoot
    $managed = @()
    foreach ($w in $list) {
        $wp = $w.worktree.Replace('/', '\')
        if ($wp.StartsWith($WorktreeRoot, [System.StringComparison]::OrdinalIgnoreCase) -and $wp -ne $TargetRepo) {
            $metaFile = Join-Path $wp ".twow_worktree_meta.json"
            $cid = if (Test-Path $metaFile) {
                try { (Get-Content $metaFile -Raw | ConvertFrom-Json).candidate_id } catch { "UNKNOWN" }
            } else { "UNKNOWN" }

            $managed += [PSCustomObject]@{
                CandidateId  = $cid
                Path         = $wp
                Branch       = $w.branch
                Head         = $w.head
            }
        }
    }

    return $managed
}

function Remove-CandidateWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [Parameter(Mandatory=$true)][string]$WorktreePath,
        [Parameter()][switch]$Force
    )

    $WorktreeRoot = Get-WorktreeRoot -TargetRepo $TargetRepo
    $wp = (Resolve-Path $WorktreePath -ErrorAction SilentlyContinue)
    if ($wp) { $wp = $wp.Path } else { $wp = $WorktreePath }

    # Absolute safety guard: MUST be inside WorktreeRoot and NOT TargetRepo!
    if ((-not $wp.Contains(".worktrees") -and -not $wp.StartsWith($WorktreeRoot, [System.StringComparison]::OrdinalIgnoreCase)) -or $wp -eq $TargetRepo -or $wp -eq "C:\" -or $wp -eq "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow") {
        throw "SAFETY VIOLATION: Refusing to remove path outside managed worktree root: $wp"
    }

    Write-Host "Removing worktree: $wp" -ForegroundColor DarkGray
    $cmd = "git -C ""$TargetRepo"" worktree remove --force ""$wp"""
    cmd.exe /c "$cmd 2>&1" | Out-Null

    if (Test-Path $wp) {
        Remove-Item -Path $wp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Remove-IsolatedWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$WorktreePath,
        [string]$TargetRepo = "",
        [switch]$Force
    )
    if ([string]::IsNullOrEmpty($TargetRepo)) {
        $cfg = Get-ProjectConfig
        $TargetRepo = if ($cfg -and $cfg.repositories.tortoise_wow.path) { $cfg.repositories.tortoise_wow.path } else { Join-Path $ProjectRoot "tortoise-wow" }
    }
    Remove-CandidateWorktree -TargetRepo $TargetRepo -WorktreePath $WorktreePath -Force:$Force
}

function Invoke-SafeWorktreeCleanup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$TargetRepo,
        [Parameter()][string]$WorktreeRoot = "",
        [switch]$DryRun,
        [int]$MaxRetainedFailed = 3
    )

    if ([string]::IsNullOrEmpty($WorktreeRoot)) {
        $WorktreeRoot = Get-WorktreeRoot -TargetRepo $TargetRepo
    }

    $active = Get-ActiveWorktrees -TargetRepo $TargetRepo -WorktreeRoot $WorktreeRoot
    Write-Host "Discovered $($active.Count) active managed worktrees in $WorktreeRoot" -ForegroundColor Cyan

    $removed = @()
    foreach ($w in $active) {
        Write-Host "  -> Candidate: $($w.CandidateId) | Path: $($w.Path)" -ForegroundColor $(if ($DryRun) { 'Yellow' } else { 'DarkGray' })
        if (-not $DryRun) {
            Remove-CandidateWorktree -TargetRepo $TargetRepo -WorktreePath $w.Path -Force
            $removed += $w.CandidateId
        } else {
            $removed += "[DryRun] $($w.CandidateId)"
        }
    }

    # Prune git worktree administrative records
    if (-not $DryRun) {
        cmd.exe /c "git -C ""$TargetRepo"" worktree prune 2>&1" | Out-Null
    }

    return $removed
}