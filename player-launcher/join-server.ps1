[CmdletBinding()]
param(
    [switch] $Reset,
    [string] $ServerAddress,
    [ValidateRange(1, 65535)] [int] $Port = 16261,
    [switch] $ReviewModsOnly,
    [ValidateSet('Clean', 'Keep')] [string] $ModReviewChoice,
    [string] $ZomboidHome = (Join-Path $env:USERPROFILE 'Zomboid'),
    [switch] $TestOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$settingsPath = Join-Path $PSScriptRoot 'player-settings.json'
$serverModsPath = Join-Path $PSScriptRoot 'server-mods.json'
$bundledModsRoot = Join-Path $PSScriptRoot 'local-mods'

function Get-ModFingerprint {
    param([string[]] $ModIds)
    $payload = ((@($ModIds | Sort-Object -Unique)) -join "`n")
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-DirectoryFingerprint {
    param([Parameter(Mandatory)] [string] $Path)
    $root = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $entries = @(Get-ChildItem -LiteralPath $root -File -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($root.Length).TrimStart('\')
        '{0}|{1}' -f $relative, (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    })
    return Get-ModFingerprint -ModIds $entries
}

function Get-DeclaredLocalModIds {
    param([Parameter(Mandatory)] [string] $Path)
    return @(Get-ChildItem -LiteralPath $Path -Filter 'mod.info' -File -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object {
            Get-Content -LiteralPath $_.FullName | Where-Object { $_ -match '^id=(.+)$' } |
                ForEach-Object { $Matches[1].Trim() }
        } | Sort-Object -Unique)
}

function Install-BundledLocalMods {
    param(
        [Parameter(Mandatory)] [string] $SourceRoot,
        [Parameter(Mandatory)] [string] $DestinationRoot,
        [string[]] $ExpectedModIds = @(),
        [switch] $ValidateOnly
    )

    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) {
        if ($ExpectedModIds.Count -gt 0) { throw 'The package is missing its bundled local mods.' }
        return
    }

    $sourceDirectories = @(Get-ChildItem -LiteralPath $SourceRoot -Directory)
    foreach ($expectedId in $ExpectedModIds) {
        if ($sourceDirectories.Name -notcontains $expectedId) {
            throw "Bundled local mod is missing: $expectedId"
        }
    }

    foreach ($sourceDirectory in $sourceDirectories) {
        $modId = $sourceDirectory.Name
        if ($modId -notmatch '^[A-Za-z0-9_.-]+$') { throw "Invalid bundled local mod folder name: $modId" }
        $declaredIds = @(Get-DeclaredLocalModIds -Path $sourceDirectory.FullName)
        if ($declaredIds -notcontains $modId) {
            throw "Bundled local mod '$modId' has no matching mod.info ID."
        }

        $destination = Join-Path $DestinationRoot $modId
        $sourceFingerprint = Get-DirectoryFingerprint -Path $sourceDirectory.FullName
        $isCurrent = (Test-Path -LiteralPath $destination -PathType Container) -and
            ((Get-DirectoryFingerprint -Path $destination) -eq $sourceFingerprint)
        if ($ValidateOnly) {
            Write-Output "Bundled local mod validation PASS: $modId"
            continue
        }
        if ($isCurrent) {
            Write-Host "Local server mod is current: $modId" -ForegroundColor Green
            continue
        }

        $runningGame = @(Get-Process -Name 'ProjectZomboid64', 'ProjectZomboid' -ErrorAction SilentlyContinue)
        if ($runningGame.Count -gt 0) { throw 'Close Project Zomboid before installing the bundled local server mod.' }

        New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
        if (Test-Path -LiteralPath $destination) {
            $backupRoot = Join-Path $env:LOCALAPPDATA 'PzEscapeLauncher\local-mod-backups'
            New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
            $backup = Join-Path $backupRoot ('{0}-{1}' -f $modId, (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Move-Item -LiteralPath $destination -Destination $backup
            Write-Host "Previous local server mod backed up: $backup" -ForegroundColor Yellow
        }
        Copy-Item -LiteralPath $sourceDirectory.FullName -Destination $destination -Recurse
        Write-Host "Installed local server mod: $modId" -ForegroundColor Green
    }
}

function Get-ReviewStatePath {
    param([Parameter(Mandatory)] [string] $ServerName)
    $safeName = $ServerName -replace '[^A-Za-z0-9_.-]', '_'
    $stateRoot = Join-Path $env:LOCALAPPDATA 'PzEscapeLauncher'
    New-Item -ItemType Directory -Path $stateRoot -Force | Out-Null
    return Join-Path $stateRoot "$safeName-mod-review.json"
}

function Get-ClientDefaultMods {
    param([Parameter(Mandatory)] [string] $DefaultPath)
    if (-not (Test-Path -LiteralPath $DefaultPath)) { return @() }
    return @(Get-Content -LiteralPath $DefaultPath | ForEach-Object {
        if ($_ -match '^\s*mod\s*=\s*(.+?),\s*$') {
            ($Matches[1].Trim() -replace '^\d+/', '')
        }
    } | Where-Object { $_ })
}

function Invoke-ClientModReview {
    param(
        [Parameter(Mandatory)] $ServerMods,
        [switch] $ForceReview
    )

    $serverName = [string]$ServerMods.ServerName
    $allowedMods = @($ServerMods.ModIds | ForEach-Object { ([string]$_) -replace '^\d+/', '' })
    if ([string]::IsNullOrWhiteSpace($serverName) -or $allowedMods.Count -eq 0) {
        Write-Warning 'The package has no server mod manifest. Skipping the client mod review.'
        return
    }

    $fingerprint = Get-ModFingerprint -ModIds $allowedMods
    $statePath = Get-ReviewStatePath -ServerName $serverName
    if (-not $ForceReview -and (Test-Path -LiteralPath $statePath)) {
        try {
            $state = Get-Content -Raw -Encoding UTF8 -LiteralPath $statePath | ConvertFrom-Json
            if ([string]$state.ServerModFingerprint -eq $fingerprint) { return }
        }
        catch {
            Write-Warning 'The previous mod review state was invalid. Running the review again.'
        }
    }

    $defaultPath = Join-Path (Join-Path $ZomboidHome 'mods') 'default.txt'
    $clientMods = @(Get-ClientDefaultMods -DefaultPath $defaultPath)
    $extraMods = @($clientMods | Where-Object { $_ -notin $allowedMods } | Sort-Object -Unique)

    Write-Host "`n=== First-run client mod check ===" -ForegroundColor Cyan
    Write-Host "Server mods: $($allowedMods.Count) / globally enabled client mods: $($clientMods.Count)"
    if ($extraMods.Count -eq 0) {
        Write-Host 'No client-only globally enabled mods were found.' -ForegroundColor Green
        [ordered]@{
            ServerModFingerprint = $fingerprint
            Decision = 'NoExtras'
            ReviewedAt = (Get-Date).ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
        return
    }

    Write-Host "$($extraMods.Count) client-only mods can cause checksum disconnects:" -ForegroundColor Yellow
    $extraMods | Select-Object -First 25 | ForEach-Object { Write-Host "  - $_" }
    if ($extraMods.Count -gt 25) { Write-Host "  ... and $($extraMods.Count - 25) more" }
    Write-Host 'Choosing Clean backs up default.txt and disables all globally enabled client mods.' -ForegroundColor Cyan
    Write-Host 'The server will load its required mods during connection.' -ForegroundColor Cyan

    $choice = $ModReviewChoice
    if (-not $choice) {
        $answer = (Read-Host 'Clean global client mods now? [Y]es / [N]o').Trim()
        $choice = if ($answer -match '^(?i:y|yes)$') { 'Clean' } else { 'Keep' }
    }

    $backupPath = $null
    if ($choice -eq 'Clean') {
        $runningGame = @(Get-Process -Name 'ProjectZomboid64', 'ProjectZomboid' -ErrorAction SilentlyContinue)
        if ($runningGame.Count -gt 0) {
            throw 'Close Project Zomboid before cleaning the client mod list.'
        }
        if (Test-Path -LiteralPath $defaultPath) {
            $modsRoot = Split-Path -Parent $defaultPath
            $backupPath = Join-Path $modsRoot ('default.pz-escape-backup-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            Move-Item -LiteralPath $defaultPath -Destination $backupPath
            Write-Host "Client mod list backed up and disabled: $backupPath" -ForegroundColor Green
        }
    }
    else {
        Write-Warning 'Client mods were left unchanged. A checksum disconnect may still occur.'
    }

    [ordered]@{
        ServerModFingerprint = $fingerprint
        Decision = $choice
        BackupPath = $backupPath
        ReviewedAt = (Get-Date).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8
}

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
    if ($Reset -and (Test-Path -LiteralPath $settingsPath)) {
        Remove-Item -LiteralPath $settingsPath
        Write-Host 'Cleared the saved server address.' -ForegroundColor Yellow
    }

    if (-not $ServerAddress -and (Test-Path -LiteralPath $settingsPath)) {
        $settings = Get-Content -Raw -Encoding UTF8 -LiteralPath $settingsPath | ConvertFrom-Json
        $ServerAddress = [string]$settings.ServerAddress
        $Port = [int]$settings.Port
    }

    if (-not $ServerAddress) {
        Write-Host 'Enter the server address once. This launcher never stores passwords.' -ForegroundColor Cyan
        $ServerAddress = (Read-Host 'Public IPv4 address or domain from the host').Trim()
        $portText = (Read-Host 'Port [default 16261]').Trim()
        if ($portText) { $Port = [int]$portText }
    }

    if ($ServerAddress -notmatch '^[A-Za-z0-9.-]+$') {
        throw 'The server address must be an IPv4 address or an ASCII domain name.'
    }
    if ($Port -lt 1 -or $Port -gt 65535) {
        throw 'The port must be between 1 and 65535.'
    }

    $settings = [ordered]@{ ServerAddress = $ServerAddress; Port = $Port }
    if (-not $TestOnly) {
        $settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    }

    if (Test-Path -LiteralPath $serverModsPath) {
        $serverMods = Get-Content -Raw -Encoding UTF8 -LiteralPath $serverModsPath | ConvertFrom-Json
        $localModIds = if ($serverMods.PSObject.Properties['LocalModIds']) { @($serverMods.LocalModIds) } else { @() }
        Install-BundledLocalMods -SourceRoot $bundledModsRoot -DestinationRoot (Join-Path $ZomboidHome 'mods') -ExpectedModIds $localModIds -ValidateOnly:$TestOnly
        if (-not $TestOnly -or $ReviewModsOnly) {
            Invoke-ClientModReview -ServerMods $serverMods -ForceReview:$ReviewModsOnly
        }
    }
    elseif (-not $TestOnly) {
        Write-Warning 'server-mods.json is missing. Create a fresh player package on the host.'
    }

    if ($ReviewModsOnly) {
        Write-Output 'Client mod review complete.'
        return
    }

    $target = '{0}:{1}' -f $ServerAddress, $Port
    $uri = 'steam://run/108600//+connect%20{0}/' -f $target
    if ($TestOnly) {
        Write-Output "Player launcher validation PASS: $uri"
        return
    }

    $steamCommand = Get-ItemProperty -LiteralPath 'Registry::HKEY_CLASSES_ROOT\steam\shell\open\command' -ErrorAction SilentlyContinue
    if (-not $steamCommand) {
        throw 'Steam URL protocol was not found. Install or repair the Steam client.'
    }

    Write-Host "Launching Project Zomboid and connecting to $target..." -ForegroundColor Green
    Start-Process $uri
}
catch {
    Write-Host "Player launcher error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
