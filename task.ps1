<#
.SYNOPSIS
    Root wrapper for Module-playerbots CLI Dispatcher.
#>
param(
    [Parameter(Position = 0)]
    [string]$Command = "status",

    [Parameter(Position = 1)]
    [string]$Argument = "",

    [Parameter(Position = 2)]
    [string]$SecondaryArgument = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs = @()
)

$ToolsTask = Join-Path $PSScriptRoot "tools\task.ps1"
& $ToolsTask -Command $Command -Argument $Argument -SecondaryArgument $SecondaryArgument @RemainingArgs
