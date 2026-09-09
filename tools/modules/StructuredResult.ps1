# StructuredResult.ps1: Contract generator and validator for pipeline stages

$script:CURRENT_SCHEMA_VERSION = "1.0.0"
$script:CURRENT_TOOL_VERSION = "2.0.0"

function Get-FileSha256([string]$filePath) {
    if (-not (Test-Path $filePath)) { return "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    $hash = $sha.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
}

function Get-StringSha256([string]$inputStr) {
    if ([string]::IsNullOrEmpty($inputStr)) { return "" }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($inputStr)
    $hash = $sha.ComputeHash($bytes)
    return [System.BitConverter]::ToString($hash).Replace("-", "").ToLower()
}

function New-StageResult {
    [CmdletBinding()]
    param(
        [Parameter()][string]$RunId = "",
        [Parameter()][string]$CandidateId = "CANDIDATE-0000",
        [Parameter(Mandatory=$true)][string]$Stage,
        [Parameter()][Alias("CandidateSha")][string]$DonorSha = "",
        [Parameter()][string]$DonorFullSha = "",
        [Parameter()][string]$DonorRepo = "reference-upstreams/vmangos-core",
        [Parameter()][string]$TargetRepo = "tortoise-wow",
        [Parameter()][string]$TargetBaseSha = "",
        [Parameter()][hashtable]$ReferenceShas = @{},
        [Parameter()][string]$RequestedMode = "Normal",
        [Parameter()][string]$EffectiveMode = "Normal",
        [Parameter(Mandatory=$true)][string]$Status,
        [Parameter()][string]$Verdict = "PASS",
        [Parameter()][double]$Confidence = 1.0,
        [Parameter()][string[]]$ReasonCodes = @(),
        [Parameter()][hashtable]$Evidence = @{},
        [Parameter()][string[]]$Warnings = @(),
        [Parameter()][string[]]$Errors = @(),
        [Parameter()][hashtable]$InputHashes = @{},
        [Parameter()][hashtable]$OutputHashes = @{},
        [Parameter()][string]$ConfigHash = "",
        [Parameter()][string]$CompatibilityManifestVersion = "1.0.0",
        [Parameter()][datetime]$StartedAt = (Get-Date),
        [Parameter()][datetime]$CompletedAt = (Get-Date),
        [Parameter()][hashtable]$Details = @{}
    )

    if ([string]::IsNullOrEmpty($DonorFullSha) -and -not [string]::IsNullOrEmpty($DonorSha)) {
        $DonorFullSha = $DonorSha
    }

    $durationMs = [int](($CompletedAt - $StartedAt).TotalMilliseconds)
    if ($durationMs -lt 0) { $durationMs = 0 }

    $result = [ordered]@{
        schema_version                 = $script:CURRENT_SCHEMA_VERSION
        tool_version                   = $script:CURRENT_TOOL_VERSION
        run_id                         = $RunId
        candidate_id                   = $CandidateId
        candidate_sha                  = if ($DonorSha) { $DonorSha } else { $CandidateId }
        stage                          = $Stage
        donor_repository               = $DonorRepo
        donor_sha                      = $DonorSha
        donor_full_sha                 = $DonorFullSha
        target_repository              = $TargetRepo
        target_base_sha                = $TargetBaseSha
        reference_shas                 = $ReferenceShas
        requested_mode                 = $RequestedMode
        effective_mode                 = $EffectiveMode
        status                         = $Status
        verdict                        = $Verdict
        confidence                     = [Math]::Round([double]$Confidence, 4)
        reason_codes                   = @($ReasonCodes)
        evidence                       = $Evidence
        warnings                       = @($Warnings)
        errors                         = @($Errors)
        input_hashes                   = $InputHashes
        output_hashes                  = $OutputHashes
        configuration_hash             = $ConfigHash
        compatibility_manifest_version = $CompatibilityManifestVersion
        started_at                     = $StartedAt.ToString("o")
        completed_at                   = $CompletedAt.ToString("o")
        duration_ms                    = $durationMs
    }

    return $result
}

function Test-StageResultSchema {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$ResultObject
    )

    $requiredFields = @(
        "schema_version", "tool_version", "run_id", "candidate_id",
        "stage", "donor_repository", "donor_sha", "donor_full_sha",
        "target_repository", "target_base_sha", "requested_mode",
        "effective_mode", "status", "verdict", "confidence",
        "reason_codes", "started_at", "completed_at", "duration_ms"
    )

    $missing = @()
    foreach ($rf in $requiredFields) {
        if ($ResultObject -is [System.Collections.IDictionary]) {
            if (-not $ResultObject.Contains($rf) -or $null -eq $ResultObject[$rf]) {
                $missing += $rf
            }
        } elseif ($null -eq $ResultObject.$rf) {
            $missing += $rf
        }
    }

    if ($missing.Count -gt 0) {
        return @{
            IsValid = $false
            Valid   = $false
            Errors  = @("Missing required fields: $($missing -join ', ')")
        }
    }

    $validModes = @("Fast", "Normal", "Deep")
    $rm = if ($ResultObject -is [System.Collections.IDictionary]) { $ResultObject["requested_mode"] } else { $ResultObject.requested_mode }
    $em = if ($ResultObject -is [System.Collections.IDictionary]) { $ResultObject["effective_mode"] } else { $ResultObject.effective_mode }
    if ($validModes -notcontains $rm) {
        return @{ IsValid = $false; Valid = $false; Errors = @("Invalid requested_mode: $rm") }
    }
    if ($validModes -notcontains $em) {
        return @{ IsValid = $false; Valid = $false; Errors = @("Invalid effective_mode: $em") }
    }

    return @{
        IsValid = $true
        Valid   = $true
        Errors  = @()
    }
}

function Save-StageResultJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]$ResultObject,
        [Parameter(Mandatory=$true)][string]$FilePath
    )

    $validation = Test-StageResultSchema -ResultObject $ResultObject
    if (-not $validation.IsValid) {
        throw "StageResult schema validation failed: $($validation.Errors -join '; ')"
    }

    $parentDir = Split-Path -Parent $FilePath
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }

    $json = $ResultObject | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($FilePath, $json, [System.Text.UTF8Encoding]::new($false))
}