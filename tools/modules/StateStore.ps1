# StateStore.ps1: Canonical machine-readable state store for twow-project

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "StateMachine.ps1")

$script:DefaultStateStorePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\state\state_store.json"

function New-RunId {
    $now = Get-Date
    $rnd = [System.IO.Path]::GetRandomFileName().Substring(0, 4).ToUpper()
    return "RUN-$($now.ToString('yyyyMMdd-HHmmss'))-$rnd"
}

function Get-StateStore {
    [CmdletBinding()]
    param(
        [string]$Path = $script:DefaultStateStorePath
    )

    if (Test-Path $Path) {
        $raw = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        $store = $raw | ConvertFrom-Json
        return $store
    }

    # Initialize new empty store structure
    return [ordered]@{
        schema_version = "1.0.0"
        tool_version   = "2.0.0"
        last_updated   = (Get-Date).ToString("o")
        baseline_cache = @{}
        runs           = @{}
        candidates     = @{}
        ai_call_cache  = @{}
    }
}

function Save-StateStore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$Store,
        [string]$Path = $script:DefaultStateStorePath
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if ($Store -is [System.Collections.IDictionary]) {
        $Store["last_updated"] = (Get-Date).ToString("o")
    } elseif ($null -ne $Store.last_updated) {
        $Store.last_updated = (Get-Date).ToString("o")
    }

    $json = $Store | ConvertTo-Json -Depth 12
    $tempFile = "$Path.tmp." + [System.Guid]::NewGuid().ToString("N")
    [System.IO.File]::WriteAllText($tempFile, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -Path $tempFile -Destination $Path -Force
}

function Register-Candidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateId,
        [Parameter(Mandatory=$true)][string]$DonorSha,
        [Parameter()][string]$DonorFullSha = "",
        [Parameter()][string]$Subject = "",
        [Parameter()][int]$Tier = 5,
        [Parameter()][string]$Subsystem = "Core",
        [Parameter()][string]$TargetBaseSha = "",
        [string]$Path = $script:DefaultStateStorePath
    )

    $store = Get-StateStore -Path $Path

    # Handle hashtable or PSCustomObject
    $candidates = $store.candidates
    $existing = if ($candidates -is [System.Collections.IDictionary]) { $candidates[$CandidateId] } else { $candidates.$CandidateId }

    if ($null -eq $existing) {
        $candidateObj = [ordered]@{
            candidate_id      = $CandidateId
            donor_sha         = $DonorSha
            donor_full_sha    = $DonorFullSha
            subject           = $Subject
            tier              = $Tier
            subsystem         = $Subsystem
            current_state     = "DISCOVERED"
            target_base_sha   = $TargetBaseSha
            reference_shas    = @{}
            confidence        = 1.0
            risk_score        = 0.0
            verdict           = "PENDING"
            reason_codes      = @()
            evidence          = @{}
            dependencies      = @()
            relations         = @{}
            patch_file        = ""
            patch_sha256      = ""
            sql_file          = ""
            db_migrations     = @()
            db_provenance     = @()
            reproduction_plan = @{}
            build_profile     = "world"
            compile_status    = "UNTESTED"
            link_status       = "UNTESTED"
            startup_status    = "UNTESTED"
            runtime_status    = "UNTESTED"
            ai_calls          = @()
            worktree_path     = ""
            candidate_branch  = ""
            is_stale          = $false
            human_approval    = "NOT_REQUIRED"
            created_at        = (Get-Date).ToString("o")
            history           = @(
                @{
                    from_state  = $null
                    to_state    = "DISCOVERED"
                    timestamp   = (Get-Date).ToString("o")
                    reason_code = "INITIAL_DISCOVERY"
                }
            )
        }

        if ($candidates -is [System.Collections.IDictionary]) {
            $candidates[$CandidateId] = $candidateObj
        } else {
            $store.candidates = [ordered]@{}
            $store.candidates[$CandidateId] = $candidateObj
        }

        Save-StateStore -Store $store -Path $Path
        return $candidateObj
    }

    return $existing
}

function Update-CandidateState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateId,
        [Parameter(Mandatory=$true)][string]$ToState,
        [Parameter()][string]$ReasonCode = "",
        [Parameter()][double]$Confidence = -1.0,
        [Parameter()][hashtable]$Evidence = $null,
        [Parameter()][string]$Verdict = "",
        [string]$Path = $script:DefaultStateStorePath
    )

    $store = Get-StateStore -Path $Path
    $candidates = $store.candidates
    $c = if ($candidates -is [System.Collections.IDictionary]) { $candidates[$CandidateId] } else { $candidates.$CandidateId }
    if ($null -eq $c) {
        throw "Candidate '$CandidateId' not found in state store"
    }

    $fromState = $c.current_state
    Assert-StateTransition -FromState $fromState -ToState $ToState

    $c.current_state = $ToState
    if ($Confidence -ge 0.0) { $c.confidence = $Confidence }
    if (-not [string]::IsNullOrEmpty($Verdict)) { $c.verdict = $Verdict }
    if ($null -ne $Evidence) {
        foreach ($k in $Evidence.Keys) {
            $c.evidence[$k] = $Evidence[$k]
        }
    }

    $historyEntry = @{
        from_state  = $fromState
        to_state    = $ToState
        timestamp   = (Get-Date).ToString("o")
        reason_code = $ReasonCode
    }

    $historyList = [System.Collections.ArrayList]::new(@($c.history))
    [void]$historyList.Add($historyEntry)
    $c.history = $historyList

    Save-StateStore -Store $store -Path $Path
    return $c
}

function Record-Run {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RunId,
        [Parameter(Mandatory=$true)][string]$Operation,
        [Parameter()][string]$CandidateId = "",
        [Parameter()][string]$Mode = "Normal",
        [Parameter()][string]$Status = "SUCCESS",
        [Parameter()][hashtable]$Details = @{},
        [string]$Path = $script:DefaultStateStorePath
    )

    $store = Get-StateStore -Path $Path
    $runs = $store.runs

    $runEntry = @{
        run_id       = $RunId
        operation    = $Operation
        candidate_id = $CandidateId
        mode         = $Mode
        status       = $Status
        timestamp    = (Get-Date).ToString("o")
        details      = $Details
    }

    if ($runs -is [System.Collections.IDictionary]) {
        $runs[$RunId] = $runEntry
    } else {
        $runs = @{}
        $runs[$RunId] = $runEntry
        $store.runs = $runs
    }

    Save-StateStore -Store $store -Path $Path
}

function Get-PipelineSummary {
    [CmdletBinding()]
    param(
        [string]$Path = $script:DefaultStateStorePath
    )

    $store = Get-StateStore -Path $Path
    $candidates = $store.candidates
    $counts = @{}
    foreach ($st in $script:CANONICAL_STATES) {
        $counts[$st] = 0
    }

    $total = 0
    if ($candidates) {
        $keys = if ($candidates -is [System.Collections.IDictionary]) { $candidates.Keys } else { $candidates.PSObject.Properties.Name }
        foreach ($k in $keys) {
            $c = if ($candidates -is [System.Collections.IDictionary]) { $candidates[$k] } else { $candidates.$k }
            $st = $c.current_state
            if ($counts.ContainsKey($st)) {
                $counts[$st]++
            } else {
                $counts[$st] = 1
            }
            $total++
        }
    }

    return [PSCustomObject]@{
        TotalCandidates = $total
        StateCounts = $counts
        TotalRuns = if ($store.runs) { ($store.runs.Keys).Count } else { 0 }
        LastUpdated = $store.last_updated
    }
}