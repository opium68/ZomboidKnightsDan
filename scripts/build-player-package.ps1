[CmdletBinding()]
param(
    [string] $ServerAddress,
    [ValidateRange(1, 65535)] [int] $Port = 16261
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $projectRoot 'player-launcher'
$packageRoot = Join-Path $projectRoot 'packages'
. (Join-Path $PSScriptRoot 'common.ps1')
$cfg = Get-PzConfig

if (-not $ServerAddress) {
    $secretsPath = Join-Path $projectRoot 'config\secrets.psd1'
    $secrets = if (Test-Path -LiteralPath $secretsPath) {
        Import-PowerShellDataFile -LiteralPath $secretsPath
    }
    else {
        @{}
    }
    if ($secrets.ContainsKey('DuckDnsDomain') -and -not [string]::IsNullOrWhiteSpace([string]$secrets.DuckDnsDomain)) {
        $ServerAddress = ([string]$secrets.DuckDnsDomain).Trim().ToLowerInvariant()
        Write-Output "Using configured DuckDNS domain: $ServerAddress"
    }
    else {
        $publicCandidates = @([Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces() |
            Where-Object { $_.OperationalStatus -eq [Net.NetworkInformation.OperationalStatus]::Up } |
            ForEach-Object { $_.GetIPProperties().UnicastAddresses } |
            Where-Object { $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork } |
            ForEach-Object { $_.Address.IPAddressToString } |
            Where-Object {
                $octets = [Net.IPAddress]::Parse($_).GetAddressBytes()
                -not (
                    $octets[0] -eq 10 -or
                    ($octets[0] -eq 172 -and $octets[1] -ge 16 -and $octets[1] -le 31) -or
                    ($octets[0] -eq 192 -and $octets[1] -eq 168) -or
                    ($octets[0] -eq 100 -and $octets[1] -ge 64 -and $octets[1] -le 127) -or
                    $octets[0] -eq 127 -or
                    ($octets[0] -eq 169 -and $octets[1] -eq 254)
                )
            } | Sort-Object -Unique)
        if ($publicCandidates.Count -eq 1) {
            $ServerAddress = $publicCandidates[0]
            Write-Output 'Detected a directly assigned public IPv4 address.'
        }
        else {
            $ServerAddress = (Read-Host 'Public IPv4 address or domain to embed').Trim()
        }
    }
}
if ($ServerAddress -notmatch '^[A-Za-z0-9.-]+$') {
    throw 'The server address must be an IPv4 address or an ASCII domain name.'
}
$secretsPath = Join-Path $projectRoot 'config\secrets.psd1'
if (Test-Path -LiteralPath $secretsPath) {
    $packageSecrets = Import-PowerShellDataFile -LiteralPath $secretsPath
    $domainLabel = $ServerAddress -replace '\.duckdns\.org$', ''
    if ($ServerAddress -match '\.duckdns\.org$' -and
        $packageSecrets.ContainsKey('ServerPassword') -and
        $domainLabel -ceq [string]$packageSecrets.ServerPassword) {
        throw 'SECURITY STOP: The DuckDNS subdomain must not be the same as the server password.'
    }
}

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tempRoot = Join-Path $tempBase ('pz-player-launcher-' + [Guid]::NewGuid().ToString('N'))
$tempArchive = Join-Path $tempBase ('pz-player-package-' + [Guid]::NewGuid().ToString('N') + '.zip')
$resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
if (-not $resolvedTemp.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to create a temporary package outside the system temporary directory.'
}

try {
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    foreach ($name in @(
        'JOIN-SERVER.cmd',
        'OPEN-MANUAL.cmd',
        'RESET-SERVER-ADDRESS.cmd',
        'CHECK-CLIENT-MODS.cmd',
        'RESTORE-CLIENT-MODS.cmd',
        'join-server.ps1',
        'bootstrap.ps1',
        'update-client.ps1',
        'update-config.json',
        'release-public.xml',
        'restore-client-mods.ps1',
        'PLAYER-MANUAL.html',
        'README.txt'
    )) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $tempRoot $name)
    }
    [ordered]@{ ServerAddress = $ServerAddress; Port = $Port } |
        ConvertTo-Json |
        Set-Content -LiteralPath (Join-Path $tempRoot 'player-settings.json') -Encoding UTF8

    $localModIds = @()
    $customModsRoot = Join-Path $projectRoot 'custom-mods'
    if (Test-Path -LiteralPath $customModsRoot -PathType Container) {
        $bundledModsRoot = Join-Path $tempRoot 'local-mods'
        New-Item -ItemType Directory -Path $bundledModsRoot -Force | Out-Null
        foreach ($modDirectory in Get-ChildItem -LiteralPath $customModsRoot -Directory) {
            $localModIds += $modDirectory.Name
            Copy-Item -LiteralPath $modDirectory.FullName -Destination $bundledModsRoot -Recurse -Force
        }
    }

    $serverIni = Join-Path $projectRoot ("config\{0}\{0}.ini" -f $cfg.ServerName)
    if (-not (Test-Path -LiteralPath $serverIni)) {
        throw "Server configuration not found: $serverIni"
    }
    $iniValues = @{}
    foreach ($line in Get-Content -LiteralPath $serverIni) {
        if ($line -match '^([^#=]+)=(.*)$') { $iniValues[$Matches[1]] = $Matches[2] }
    }
    if (-not $iniValues.ContainsKey('Mods') -or -not $iniValues.ContainsKey('WorkshopItems')) {
        throw 'Server configuration is missing Mods= or WorkshopItems=.'
    }
    [ordered]@{
        ServerName = $cfg.ServerName
        ModIds = @($iniValues.Mods -split ';' | Where-Object { $_ })
        WorkshopItems = @($iniValues.WorkshopItems -split ';' | Where-Object { $_ })
        LocalModIds = @($localModIds)
    } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $tempRoot 'server-mods.json') -Encoding UTF8

    New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
    Compress-Archive -Path (Join-Path $tempRoot '*') -DestinationPath $tempArchive
    $preferredArchive = Join-Path $packageRoot ("pz-escape-player-{0}.zip" -f $Port)
    $archive = $preferredArchive
    try {
        if (Test-Path -LiteralPath $preferredArchive) {
            Remove-Item -LiteralPath $preferredArchive -Force -ErrorAction Stop
        }
        Move-Item -LiteralPath $tempArchive -Destination $preferredArchive -ErrorAction Stop
    }
    catch {
        $archive = Join-Path $packageRoot ("pz-escape-player-{0}-{1}.zip" -f $Port, (Get-Date -Format 'yyyyMMdd-HHmmss'))
        Move-Item -LiteralPath $tempArchive -Destination $archive -ErrorAction Stop
        Write-Warning 'The usual ZIP was open, so a new timestamped ZIP was created instead.'
    }
    Write-Output "Created player package: $archive"
    Write-Output 'The package contains the server address, port, public mod IDs, and bundled local server mods; it contains no passwords, tokens, or game files.'
}
finally {
    if (Test-Path -LiteralPath $tempArchive) {
        $archiveDeleteTarget = [IO.Path]::GetFullPath($tempArchive)
        if (-not $archiveDeleteTarget.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove an unexpected temporary archive path.'
        }
        Remove-Item -LiteralPath $archiveDeleteTarget -Force
    }
    if (Test-Path -LiteralPath $tempRoot) {
        $deleteTarget = [IO.Path]::GetFullPath($tempRoot)
        if (-not $deleteTarget.StartsWith($tempBase, [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove an unexpected temporary path.'
        }
        Remove-Item -LiteralPath $deleteTarget -Recurse -Force
    }
}
