[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
try {
    . (Join-Path $PSScriptRoot 'update-client.ps1')
    Invoke-KnightsUpdate -LauncherRoot $PSScriptRoot -ZomboidHome (Join-Path $env:USERPROFILE 'Zomboid')
    # Run the newly installed launcher in a fresh PowerShell process.
    $engine=(Get-Process -Id $PID).Path
    & $engine -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'join-server.ps1')
    exit $LASTEXITCODE
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
