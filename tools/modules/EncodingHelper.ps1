# EncodingHelper.ps1: Safe patch encoding, byte-level I/O, path safety

function Write-Utf8NoBomText([string]$filePath, [string]$content) {
    $parent = Split-Path -Parent $filePath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($filePath, $content, $encoding)
}

function Read-Utf8Text([string]$filePath) {
    if (-not (Test-Path $filePath)) { return $null }
    $encoding = [System.Text.UTF8Encoding]::new($false)
    return [System.IO.File]::ReadAllText($filePath, $encoding)
}

function Export-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$Sha,
        [Parameter(Mandatory=$true)][string]$DestinationPatchPath
    )

    $parent = Split-Path -Parent $DestinationPatchPath
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    # Run git format-patch with redirection via cmd to preserve raw bytes without PowerShell encoding filters
    $cmd = "git -C ""$RepoPath"" format-patch -1 --stdout ""$Sha"" > ""$DestinationPatchPath"""
    cmd.exe /c $cmd
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $DestinationPatchPath)) {
        throw "Failed to safely export patch for SHA $Sha from repo $RepoPath (ExitCode: $LASTEXITCODE)"
    }

    # Check that file is not empty
    $fi = Get-Item $DestinationPatchPath
    if ($fi.Length -eq 0) {
        throw "Exported patch is 0 bytes for SHA $Sha"
    }

    return $DestinationPatchPath
}

function Test-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$PatchPath
    )

    if (-not (Test-Path $PatchPath)) {
        return @{
            AppliesCleanly = $false
            ExitCode = 2
            Output = "Patch file not found: $PatchPath"
        }
    }

    $out = cmd.exe /c "git -C ""$RepoPath"" apply --check ""$PatchPath"" 2>&1"
    $code = $LASTEXITCODE

    return @{
        AppliesCleanly = ($code -eq 0)
        ExitCode = $code
        Output = ($out -join "`n")
    }
}

function Apply-GitPatchSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepoPath,
        [Parameter(Mandatory=$true)][string]$PatchPath,
        [switch]$IgnoreWhitespace
    )

    if (-not (Test-Path $PatchPath)) {
        throw "Patch file not found: $PatchPath"
    }

    $extraArgs = if ($IgnoreWhitespace) { "--ignore-whitespace" } else { "" }
    $out = cmd.exe /c "git -C ""$RepoPath"" apply $extraArgs ""$PatchPath"" 2>&1"
    $code = $LASTEXITCODE

    return @{
        Success = ($code -eq 0)
        ExitCode = $code
        Output = ($out -join "`n")
    }
}
function Save-Utf8NoBom([string]$FilePath, [string]$Content) {
    Write-Utf8NoBomText -filePath $FilePath -content $Content
}

function Normalize-LineEndings([string]$Text) {
    return [regex]::Replace($Text, "\r\n|\n|\r", "
")
}