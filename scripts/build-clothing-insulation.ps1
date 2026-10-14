[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$config=Get-Content (Join-Path $root 'config/knights-clothing-insulation.json') -Raw | ConvertFrom-Json
$lines=@('require "KnightsDan/Core"','KnightsDan.clothingInsulationCaps = {')
foreach($entry in $config.entries | Sort-Object id){
    $lines+='    ["'+$entry.id+'"] = '+$entry.cap.ToString([Globalization.CultureInfo]::InvariantCulture)+','
}
$lines+='}'
[IO.File]::WriteAllLines((Join-Path $root 'custom-mods/KnightsDanServerPatch/42/media/lua/shared/KnightsDan/InsulationCaps.lua'),$lines,[Text.UTF8Encoding]::new($false))
Write-Output "Generated $($config.entries.Count) clothing insulation caps."
