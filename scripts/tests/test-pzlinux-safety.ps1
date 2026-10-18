[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'common.ps1')
$cfg=Get-PzConfig
$root=$script:ProjectRoot
$native=Join-Path $cfg.ServerRoot 'steamapps/workshop/content/108600/3414468585/mods/B42 PZLinux/42'
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
$fixtures=Join-Path $tempBase ('pzlinux-safety-'+[guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $fixtures | Out-Null
    $parts=@('KnightsNativeSources={}')
    foreach($path in @('media/lua/shared/PZLinux/PZLinuxDeliveryQueue.lua','media/lua/client/Context/World/Events/PZLinuxOnEvents.lua')) {
        $source=[IO.File]::ReadAllText((Join-Path $native $path))
        if($source.Contains(']====]')){throw 'Native source fixture delimiter collision.'}
        $parts+='KnightsNativeSources["'+$path+'"]=[====['+$source+']====]'
    }
    [IO.File]::WriteAllText((Join-Path $fixtures 'pzlinux-native-sources.lua'),($parts -join "`n"),[Text.UTF8Encoding]::new($false))
    $java=Join-Path $cfg.ServerRoot 'jre64/bin/java.exe'
    $classPath=(Join-Path $root 'scripts')+';'+(Join-Path $cfg.ServerRoot 'java/*')
    $lua=Join-Path $root 'custom-mods/KnightsDanServerPatch/42/media/lua'
    $searchRoots=@($PSScriptRoot,$fixtures,(Join-Path $lua 'shared'),(Join-Path $lua 'server'),(Join-Path $lua 'client'),(Join-Path $native 'media/lua/shared'))
    Push-Location $cfg.ServerRoot
    try {
        foreach($test in @('knights-pzlinux-safety.lua','knights-manhunt.lua')) {
            & $java -cp $classPath LuaTestRunner (Join-Path $PSScriptRoot $test) @searchRoots
            if($LASTEXITCODE){throw "PZLinux safety regression failed: $test"}
        }
        & $java -cp $classPath LuaSyntaxCheck $lua
        if($LASTEXITCODE){throw 'Owned Lua syntax check failed.'}
    } finally { Pop-Location }
} finally {
    $resolved=[IO.Path]::GetFullPath($fixtures)
    if(!$resolved.StartsWith($tempBase,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'pzlinux-safety-*'){
        throw 'Unexpected temporary fixture cleanup path.'
    }
    if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
