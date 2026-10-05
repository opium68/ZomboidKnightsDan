[CmdletBinding()]
param(
    [string] $ZomboidHome = (Join-Path $env:USERPROFILE 'Zomboid')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$serverModsPath = Join-Path $PSScriptRoot 'server-mods.json'

try {
    if (-not (Test-Path -LiteralPath $serverModsPath)) {
        throw 'server-mods.json is missing. Use the restore file from the same player package.'
    }
    $serverMods = Get-Content -Raw -Encoding UTF8 -LiteralPath $serverModsPath | ConvertFrom-Json
    $safeName = ([string]$serverMods.ServerName) -replace '[^A-Za-z0-9_.-]', '_'
    $statePath = Join-Path (Join-Path $env:LOCALAPPDATA 'PzEscapeLauncher') "$safeName-mod-review.json"
    if (-not (Test-Path -LiteralPath $statePath)) {
        throw 'No saved mod-cleanup state was found.'
    }
    $state = Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json
    $backupPath = [string]$state.BackupPath
    if ([string]::IsNullOrWhiteSpace($backupPath) -or -not (Test-Path -LiteralPath $backupPath)) {
        throw 'The original client mod-list backup was not found.'
    }

    $modsRoot = [IO.Path]::GetFullPath((Join-Path $ZomboidHome 'mods'))
    $resolvedBackup = [IO.Path]::GetFullPath($backupPath)
    if (-not $resolvedBackup.StartsWith($modsRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to restore a backup outside the Zomboid mods directory.'
    }
    $defaultPath = Join-Path $modsRoot 'default.txt'
    if (Test-Path -LiteralPath $defaultPath) {
        $currentBackup = Join-Path $modsRoot ('default.before-restore-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $defaultPath -Destination $currentBackup
        Write-Host "The current default.txt was preserved at: $currentBackup" -ForegroundColor Yellow
    }
    Move-Item -LiteralPath $resolvedBackup -Destination $defaultPath
    Remove-Item -LiteralPath $statePath -Force
    Write-Host 'The original globally enabled client mods were restored.' -ForegroundColor Green
}
catch {
    Write-Host "Client mod restore error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
