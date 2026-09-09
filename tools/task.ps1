<#
.SYNOPSIS
    Universal CLI Task Dispatcher for Tortoise-WoW Extended.
.DESCRIPTION
    Provides unified shorthand execution for all agents and pipeline commands:
      task 1                -> Agent 1: Build & commit all ready packages
      task 2 <sha/topic>    -> Agent 2: Forum & Bug Scout
      task 3 [table] [id]   -> Agent 3: Database & DBC Sentinel (Audit migrations OR scalp entity)
      task 4 <sha>          -> Agent 4: AI Context Assembler & C++ Semantic Adapter
      task 5 <topic>        -> Agent 5: Core Restorer & Patch Parity Auditor
      task 6 <id/query>     -> Agent 6: Online Database Oracle (xian55/tortoise-db-viewer)
      task scalp <tbl> <id> -> Scalp & Diff entity (item, creature, spell, quest, loot...)
      task port <sha>       -> Unified AI Pipeline on single SHA (Probe -> Forum -> DB -> C++)
      task port-batch <N>   -> Unified AI Pipeline on next N candidates
      task restore <topic>  -> Unified Core Restoration Pipeline (Forum -> Code Audit -> Cache -> Stage)
      task restore-batch <N>-> Batch Core Restoration on next N un-audited Turtle patch topics
      task status           -> Display live queue and git status
      task pdf              -> Regenerate COMMAND_REFERENCE.html & COMMAND_REFERENCE.pdf
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory = $true)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Argument = "",

    [Parameter(Position = 2)]
    [string]$SecondaryArgument = "",

    [Parameter()]
    [int]$Tier = 0,

    [Parameter()]
    [switch]$StageTemplate,

    [Parameter()]
    [switch]$AutoBuild,

    [Parameter()]
    [switch]$Diff,

    [Parameter()]
    [switch]$Export,

    [Parameter()]
    [switch]$OpenViewer
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PortingDir = Join-Path $ScriptDir "porting"
$QueueDir = Join-Path $ScriptDir "queue"
$TortoiseDir = Join-Path (Split-Path -Parent $ScriptDir) "tortoise-wow"

switch ($Command.ToLower()) {
    "1" {
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Build-ReadyPackages.ps1")
    }
    "2" {
        if (-not $Argument) { Write-Host "Usage: task 2 <sha_or_topic>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Search-ForumArchive.ps1") -Query $Argument
    }
    "3" {
        $tableAliases = @('item', 'items', 'creature', 'mob', 'npc', 'spell', 'spells', 'quest', 'quests', 'gameobject', 'go', 'loot', 'creature_loot', 'item_loot', 'go_loot', 'skinning', 'fishing', 'vendor', 'trainer')
        if ($Argument -and ($tableAliases -contains $Argument.ToLower() -or $Argument -like "*_template" -or $SecondaryArgument)) {
            $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"), "-Table", $Argument)
            if ($SecondaryArgument) { $cmdArgs += @("-Query", $SecondaryArgument) }
            if ($Diff) { $cmdArgs += "-Diff" }
            if ($Export) { $cmdArgs += "-Export" }
            if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
            & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
        } else {
            $params = @{}
            if ($Argument) { $params["TargetMigrations"] = @($Argument) }
            & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Audit-DatabaseMigrations.ps1") @params
        }
    }
    "scalp" {
        if (-not $Argument) {
            Write-Host "Usage: task scalp <table_or_alias> <entry_or_name> [-Diff] [-Export] [-OpenViewer]" -ForegroundColor Yellow
            return
        }
        $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"), "-Table", $Argument)
        if ($SecondaryArgument) { $cmdArgs += @("-Query", $SecondaryArgument) }
        if ($Diff) { $cmdArgs += "-Diff" }
        if ($Export) { $cmdArgs += "-Export" }
        if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "extract" {
        if (-not $Argument) {
            Write-Host "Usage: task extract <table_or_alias> <entry_or_name> [-Diff] [-Export] [-OpenViewer]" -ForegroundColor Yellow
            return
        }
        $cmdArgs = @((Join-Path $PortingDir "Extract-DbEntity.ps1"), "-Table", $Argument)
        if ($SecondaryArgument) { $cmdArgs += @("-Query", $SecondaryArgument) }
        if ($Diff) { $cmdArgs += "-Diff" }
        if ($Export) { $cmdArgs += "-Export" }
        if ($OpenViewer) { $cmdArgs += "-OpenViewer" }
        & powershell.exe -ExecutionPolicy Bypass -File @cmdArgs
    }
    "4" {
        if (-not $Argument) { Write-Host "Usage: task 4 <sha>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-AiAudit.ps1") -DonorSha $Argument
    }
    "5" {
        if (-not $Argument) { Write-Host "Usage: task 5 <topic_or_patch> [-StageTemplate] [-AutoBuild]" -ForegroundColor Yellow; return }
        $params = @{ Topic = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestore.ps1") @params
    }
    "restore" {
        if (-not $Argument) { Write-Host "Usage: task restore <topic_or_patch> [-StageTemplate] [-AutoBuild]" -ForegroundColor Yellow; return }
        $params = @{ Topic = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestore.ps1") @params
    }
    "restore-batch" {
        $params = @{}
        if ($Argument) { $params["BatchInput"] = $Argument }
        if ($StageTemplate) { $params["StageTemplate"] = $true }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-CoreRestoreBatch.ps1") @params
    }
    "6" {
        $params = @{}
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "db-viewer" {
        $params = @{}
        if ($Argument) { $params["Query"] = $Argument }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Query-OnlineDbViewer.ps1") @params
    }
    "port" {
        if (-not $Argument) { Write-Host "Usage: task port <sha> [-AutoBuild]" -ForegroundColor Yellow; return }
        $params = @{ DonorSha = @($Argument) }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-PortPipeline.ps1") @params
    }
    "port-batch" {
        $count = if ($Argument) { [int]$Argument } else { 10 }
        $params = @{ BatchCount = $count }
        if ($Tier -gt 0) { $params["Tier"] = $Tier }
        if ($AutoBuild) { $params["AutoBuild"] = $true }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-PortPipeline.ps1") @params
    }
    "ai-audit" {
        if (-not $Argument) { Write-Host "Usage: task ai-audit <sha>" -ForegroundColor Yellow; return }
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Invoke-AiAudit.ps1") -DonorSha $Argument
    }
    "pdf" {
        & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $PortingDir "Export-CommandReferencePdf.ps1")
    }
    "status" {
        Write-Host "================================================================================" -ForegroundColor Cyan
        Write-Host "  Tortoise-WoW Extended: Live Pipeline & Queue Status" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
        $c01 = @(Get-ChildItem -Path (Join-Path $QueueDir "01_candidates") -Filter "*.json" -ErrorAction SilentlyContinue).Count
        $c02 = @(Get-ChildItem -Path (Join-Path $QueueDir "02_ready_to_build") -Filter "*.json" -ErrorAction SilentlyContinue).Count
        $c03 = @(Get-ChildItem -Path (Join-Path $QueueDir "03_completed") -Filter "*.json" -ErrorAction SilentlyContinue).Count
        $c04 = @(Get-ChildItem -Path (Join-Path $QueueDir "04_rejected") -Filter "*.json" -ErrorAction SilentlyContinue).Count
        $cPatch = @(Get-ChildItem -Path (Join-Path $QueueDir "staging_patches") -Filter "*.patch" -ErrorAction SilentlyContinue).Count

        Write-Host "01_candidates     : $c01 items pending triage" -ForegroundColor $(if ($c01 -gt 0) { 'Yellow' } else { 'DarkGray' })
        Write-Host "02_ready_to_build : $c02 packages waiting for task 1" -ForegroundColor $(if ($c02 -gt 0) { 'Green' } else { 'DarkGray' })
        Write-Host "staging_patches   : $cPatch unbuilt patches" -ForegroundColor $(if ($cPatch -gt 0) { 'Yellow' } else { 'DarkGray' })
        Write-Host "03_completed      : $c03 packages committed & uploaded" -ForegroundColor Green
        Write-Host "04_rejected       : $c04 declined/incompatible candidates" -ForegroundColor DarkGray
        Write-Host ""
        $head = git -C $TortoiseDir log -n 1 --oneline
        Write-Host "Current Git HEAD  : $head" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor Cyan
    }
    default {
        Write-Host "Unknown task command '$Command'." -ForegroundColor Red
        Write-Host "Available: task 1, task 2 <sha>, task 3 [table] [id], task 4 <sha>, task 5 <topic>, task 6 <id>, task scalp <tbl> <id>, task port <sha>, task port-batch <N>, task restore <topic>, task status" -ForegroundColor Yellow
    }
}
