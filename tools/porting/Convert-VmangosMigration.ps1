<#
.SYNOPSIS
    Converts a VMaNGOS SQL migration into a Tortoise-WoW database update.
.DESCRIPTION
    Extracts raw SQL queries from a VMaNGOS migration stored procedure,
    validates target tables in Tortoise-WoW, and formats the output file
    into tortoise-wow/sql/database_updates/world/.
.PARAMETER SourceMigration
    Path to the VMaNGOS migration file.
.PARAMETER OutputDir
    Destination directory (default: tortoise-wow/sql/database_updates/world).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceMigration,
    [string]$OutputDir = "C:\Users\Admin\AntigravityProfiles\Projects\twow project\tortoise-wow\sql\database_updates\world"
)

if (!(Test-Path $SourceMigration)) {
    Write-Error "Source migration file not found: $SourceMigration"
    return
}

$filename = Split-Path $SourceMigration -Leaf
$migrationId = ($filename -split '_')[0]
$targetPath = Join-Path $OutputDir $filename

Write-Host "Converting VMaNGOS Migration: $filename" -ForegroundColor Cyan

$content = Get-Content -Path $SourceMigration -Raw

# 1. Strip VMaNGOS stored procedure wrapper
if ($content -match '(?s)INSERT INTO `migrations` VALUES \(''\d+''\);\s*-- Add your query below\.(.*?)(?:-- End of migration\.|END IF;\s*END\?\?)') {
    $payload = $matches[1].Trim()
} else {
    # If no standard wrapper found, take content as-is
    $payload = $content.Trim()
}

# 2. Schema compatibility adaptations:
# Remove patch_min, patch_max from gameobject_loot_template lines
$payload = [regex]::Replace($payload, '(?m)(INSERT INTO `gameobject_loot_template`\s*\([^)]*?), `patch_min`, `patch_max`(\)[^;]*?),\s*\d+,\s*\d+(\);)', '$1$2$3')

# Remove patch_min, patch_max from gameobject lines
$payload = [regex]::Replace($payload, '(?m)(INSERT INTO `gameobject`\s*\([^)]*?), `patch_min`, `patch_max`(\)[^;]*?),\s*\d+,\s*\d+(\);)', '$1$2$3')

# Remove patch and icon from gameobject_template
$payload = [regex]::Replace($payload, '(?m)(INSERT INTO `gameobject_template`\s*\([^)]*?)`patch`,\s*', '$1')
$payload = [regex]::Replace($payload, '(?m)(INSERT INTO `gameobject_template`\s*\([^)]*?)`icon`,\s*', '$1')

$header = @"
-- ====================================================================
-- FILE: $filename
-- BACKPORTED FROM VMANGOS: $migrationId
-- GENERATED: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- ====================================================================

"@

$finalContent = $header + $payload + "`n"

if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Set-Content -Path $targetPath -Value $finalContent -Encoding utf8
Write-Host "Migration successfully converted and saved to:" -ForegroundColor Green
Write-Host "  $targetPath" -ForegroundColor Green
