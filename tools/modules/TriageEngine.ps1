# TriageEngine.ps1: Deterministic crash dump, stack trace, and server log triage engine

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptDir "ExitCodes.ps1")
. (Join-Path $ScriptDir "ProjectConfig.ps1")

$script:LogCategories = @(
    "BUILD", "LINK", "DATABASE", "STARTUP", "AUTH", "NETWORK",
    "MOVEMENT", "SPELL", "SCRIPT", "PLAYERBOTS", "MAP", "VMAP",
    "MMAP", "CONFIGURATION", "ASSERT", "CRASH", "OTHER"
)

function Invoke-LogTriage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$LogPath
    )

    if (-not (Test-Path $LogPath)) {
        return @{ Error = "Log file not found: $LogPath"; ExitCode = $script:EXIT_CODE_TOOL_FAILURE }
    }

    $lines = Get-Content $LogPath
    $categorized = @{}
    foreach ($cat in $script:LogCategories) { $categorized[$cat] = [System.Collections.Generic.List[string]]::new() }

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $cat = "OTHER"
        if ($line -match "(?i)CRASH|EXCEPTION|SIGSEGV|ACCESS_VIOLATION") { $cat = "CRASH" }
        elseif ($line -match "(?i)ASSERT|Assertion failed") { $cat = "ASSERT" }
        elseif ($line -match "(?i)SQL|database|table|column|mysql") { $cat = "DATABASE" }
        elseif ($line -match "(?i)spell|aura|proc|effect") { $cat = "SPELL" }
        elseif ($line -match "(?i)movement|spline|chase|path") { $cat = "MOVEMENT" }
        elseif ($line -match "(?i)playerbot|botai") { $cat = "PLAYERBOTS" }
        elseif ($line -match "(?i)auth|session|logon|srp6") { $cat = "AUTH" }
        elseif ($line -match "(?i)packet|opcode|socket|network") { $cat = "NETWORK" }
        elseif ($line -match "(?i)vmap|mmap|navmesh") { $cat = "VMAP" }
        elseif ($line -match "(?i)map\s+\d+|instance|grid") { $cat = "MAP" }
        elseif ($line -match "(?i)script|eventai|scriptdev") { $cat = "SCRIPT" }
        elseif ($line -match "(?i)starting|initialized|shutdown") { $cat = "STARTUP" }

        [void]$categorized[$cat].Add($line.Trim())
    }

    $summary = [ordered]@{}
    foreach ($cat in $script:LogCategories) {
        if ($categorized[$cat].Count -gt 0) {
            $summary[$cat] = $categorized[$cat].Count
        }
    }

    return [ordered]@{
        LogFile   = $LogPath
        TotalLines= $lines.Count
        Summary   = $summary
        Entries   = $categorized
    }
}

function Invoke-CrashTriage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CrashPath,
        [string]$DonorRepo = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\reference-upstreams\vmangos-core"
    )

    if (-not (Test-Path $CrashPath)) {
        return @{ Error = "Crash file not found: $CrashPath"; ExitCode = $script:EXIT_CODE_TOOL_FAILURE }
    }

    $text = [System.IO.File]::ReadAllText($CrashPath, [System.Text.Encoding]::UTF8)

    # Extract exception code / fault
    $exception = if ($text -match "(?i)Exception\s+code:\s*([0-9a-fx]+)") { $Matches[1] } else { "UNKNOWN_EXCEPTION" }
    $module    = if ($text -match "(?i)Faulting\s+module:\s*([^\r\n]+)") { $Matches[1].Trim() } else { "mangosd.exe" }

    # Extract call stack frames / symbols
    $frameMatches = [regex]::Matches($text, "(?m)^\s*(?:[0-9a-fA-F``]+|\d+)\s+([a-zA-Z0-9_:]+)\s*(?:\+0x[0-9a-fA-F]+)?\s*(?:\[(.*?)\])?")
    $frames = [System.Collections.Generic.List[string]]::new()
    foreach ($fm in $frameMatches) {
        $sym = $fm.Groups[1].Value
        if ($sym -and $sym -notmatch "^\d+$") { [void]$frames.Add($sym) }
    }

    $topFrame = if ($frames.Count -gt 0) { $frames[0] } else { "Unknown" }

    # Search upstream donor commit history for relevant fixes mentioning topFrame
    $candidates = [System.Collections.Generic.List[object]]::new()
    if ($topFrame -ne "Unknown" -and (Test-Path $DonorRepo)) {
        $cleanSym = ($topFrame -split "::")[-1]
        $donorHits = git -C $DonorRepo log -n 5 --grep="$cleanSym" --pretty=format:"%h|%s" 2>$null
        if ($donorHits) {
            foreach ($dh in ($donorHits -split "`r?`n")) {
                if ([string]::IsNullOrWhiteSpace($dh)) { continue }
                $dhParts = $dh.Split('|')
                [void]$candidates.Add([PSCustomObject]@{
                    Sha     = $dhParts[0]
                    Subject = $dhParts[1]
                    Match   = $cleanSym
                })
            }
        }
    }

    return [ordered]@{
        CrashFile       = $CrashPath
        ExceptionCode   = $exception
        FaultingModule  = $module
        TopFrame        = $topFrame
        CallStackFrames = @($frames)
        RankedCandidates= @($candidates)
    }
}

