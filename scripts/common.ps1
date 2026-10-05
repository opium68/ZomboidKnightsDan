Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:DefaultConfig = @{
    SteamCmdRoot = 'D:\SteamCMD'
    ServerRoot   = 'D:\PZDedicated'
    ZomboidHome = Join-Path $env:USERPROFILE 'Zomboid'
    ServerName   = 'escape_test'
}

$localConfigPath = Join-Path $script:ProjectRoot 'config\paths.psd1'
if (Test-Path -LiteralPath $localConfigPath) {
    $localConfig = Import-PowerShellDataFile -LiteralPath $localConfigPath
    foreach ($key in $localConfig.Keys) {
        $script:DefaultConfig[$key] = $localConfig[$key]
    }
}

function Get-PzConfig {
    [CmdletBinding()]
    param()
    return $script:DefaultConfig.Clone()
}

function New-DatedBackupPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Prefix
    )
    $backupRoot = Join-Path $script:ProjectRoot 'backups'
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    return Join-Path $backupRoot "$Prefix-$timestamp.zip"
}

