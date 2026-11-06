[CmdletBinding()]
param(
    [string] $ServerName,
    [int] $MemoryMiB = 8192
)

. (Join-Path $PSScriptRoot 'common.ps1')
$cfg = Get-PzConfig
if (-not $ServerName) { $ServerName = $cfg.ServerName }

# RCE production dispatch: retain the original launcher for other profiles.
$liveIni=Join-Path $cfg.ZomboidHome ("Server/"+$ServerName+".ini")
$enabled=((Get-Content -LiteralPath $liveIni | Where-Object {$_ -match '^Mods='}) -replace '^Mods=','') -split ';'
if(@($enabled|ForEach-Object {$_.TrimStart('\')}) -contains 'RaccoonExpedition'){
    & (Join-Path $PSScriptRoot 'run-raccoon-production.ps1') -ServerName $ServerName -MemoryMiB $MemoryMiB
    return
}
$java = Join-Path $cfg.ServerRoot 'jre64\bin\java.exe'
$jar = Join-Path $cfg.ServerRoot 'java\projectzomboid.jar'
if (-not (Test-Path -LiteralPath $java) -or -not (Test-Path -LiteralPath $jar)) {
    throw "Dedicated server runtime is incomplete at $($cfg.ServerRoot)."
}

$arguments = @(
    '--enable-native-access=ALL-UNNAMED',
    '-Djava.awt.headless=true',
    '-Dzomboid.steam=1',
    '-Dzomboid.znetlog=1',
    '-XX:+UseZGC',
    '-XX:-CreateCoredumpOnCrash',
    '-XX:-OmitStackTraceInFastThrow',
    "-Xms$($MemoryMiB)M",
    "-Xmx$($MemoryMiB)M",
    '-Djava.library.path=natives/',
    '-cp',
    'java/;java/projectzomboid.jar',
    'zombie.network.GameServer',
    '-servername',
    $ServerName
)

$database = Join-Path $cfg.ZomboidHome "db\$ServerName.db"
$secretsPath = Join-Path $script:ProjectRoot 'config\secrets.psd1'
if (-not (Test-Path -LiteralPath $database)) {
    if (-not (Test-Path -LiteralPath $secretsPath)) {
        throw "Initial server boot requires config\secrets.psd1. Run initialize-secrets.ps1 first."
    }
    $secrets = Import-PowerShellDataFile -LiteralPath $secretsPath
    if (-not $secrets.ContainsKey('AdminPassword') -or [string]::IsNullOrWhiteSpace($secrets.AdminPassword)) {
        throw 'AdminPassword is missing from config\secrets.psd1.'
    }
    $arguments += @('-adminpassword', [string]$secrets.AdminPassword)
}

Push-Location $cfg.ServerRoot
try {
    & $java $arguments
}
finally {
    Pop-Location
}
