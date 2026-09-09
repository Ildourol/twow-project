# AiController.ps1: Deterministic-first AI orchestration, token budgeting, and caching

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")
. (Join-Path $ScriptDir "StateStore.ps1")

function Get-AiCacheKey {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("CandidateSha")][string]$DonorSha,
        [string]$TargetBaseSha = "",
        [Alias("PromptContext")][string]$BoundedContext = "",
        [string]$ToolVersion = "2.0.0",
        [string]$StageVersion = "1.0.0",
        [string]$ManifestVersion = "1.0.0"
    )

    $contextHash = Get-StringSha256 -inputStr $BoundedContext
    $composite = "$DonorSha|$TargetBaseSha|$ToolVersion|$StageVersion|$ManifestVersion|$contextHash"
    return (Get-StringSha256 -inputStr $composite)
}

function Test-AiEligibility {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Verdict,
        [string]$EffectiveMode = "Normal"
    )

    # Hard deterministic rule: Never call AI for deterministic conclusions
    if ($Verdict -eq "ALREADY_FIXED" -or $Verdict -eq "NOT_APPLICABLE" -or $Verdict -eq "TURTLE_INTENTIONAL_DIVERGENCE" -or $Verdict -eq "REJECTED") {
        return @{
            Eligible = $false
            Reason   = "Deterministic verdict [$Verdict] eliminates need for AI tokens."
        }
    }

    # Fast mode normally skips AI
    if ($EffectiveMode -eq "Fast" -and $Verdict -eq "BUG_PRESENT") {
        return @{
            Eligible = $false
            Reason   = "Fast mode operates on deterministic proof without AI call."
        }
    }

    return @{
        Eligible = $true
        Reason   = "Candidate requires adaptation or semantic synthesis."
    }
}

function Invoke-BoundedContextAssembly {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][Alias("CandidateSha")][string]$DonorSha,
        [string]$DonorRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core",
        [string]$TargetRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow",
        [int]$MaxContextLines = 200
    )

    $touchedFiles = git -C $DonorRepo diff-tree --no-commit-id --name-only -r $DonorSha
    $contextBlocks = [System.Collections.Generic.List[string]]::new()

    foreach ($tf in $touchedFiles) {
        $tgtPath = Join-Path $TargetRepo $tf
        if (Test-Path $tgtPath) {
            $lines = Get-Content $tgtPath -TotalCount $MaxContextLines
            [void]$contextBlocks.Add("// File: $tf (Bounded first $($lines.Count) lines)`n" + ($lines -join "`n"))
        }
    }

    return ($contextBlocks -join "`n`n")
}

function Query-AiAuditCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CacheKey,
        [string]$StateStorePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\state\state_store.json"
    )

    $store = Get-StateStore -Path $StateStorePath
    $cache = $store.ai_call_cache
    if ($cache -is [System.Collections.IDictionary] -and $cache.ContainsKey($CacheKey)) {
        return $cache[$CacheKey]
    } elseif ($null -ne $cache.$CacheKey) {
        return $cache.$CacheKey
    }
    return $null
}

function Store-AiAuditCache {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CacheKey,
        [Parameter(Mandatory=$true)]$AuditResult,
        [string]$StateStorePath = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tools\state\state_store.json"
    )

    $store = Get-StateStore -Path $StateStorePath
    if ($store.ai_call_cache -is [System.Collections.IDictionary]) {
        $store.ai_call_cache[$CacheKey] = $AuditResult
    } else {
        $store.ai_call_cache = @{ $CacheKey = $AuditResult }
    }
    Save-StateStore -Store $store -Path $StateStorePath
}


function Save-AiCache([string]$CacheKey, $Data) {
    Store-AiAuditCache -CacheKey $CacheKey -AuditResult $Data
}

function Get-AiCache([string]$CacheKey) {
    return Query-AiAuditCache -CacheKey $CacheKey
}

function Limit-ContextLines([string[]]$Lines, [int]$MaxLines = 200) {
    if ($Lines.Count -le $MaxLines) { return $Lines }
    return $Lines[0..($MaxLines - 1)]
}