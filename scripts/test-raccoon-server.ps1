[CmdletBinding()]
param([string]$TestHome,[int]$TimeoutSeconds=600,[switch]$ReuseVerifiedWorld,[switch]$CharacterProbe)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if(!$TestHome){$TestHome=Join-Path 'C:/Users/goods/.codex/visualizations/2026/10/28/01a18188-eff1-7223-92c3-a2061633e907' ('rce-test-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
$cache=[IO.Path]::GetFullPath($TestHome)
if(!(Split-Path $cache -Leaf).StartsWith('rce-test-')){throw 'An isolated rce-test-* directory is required.'}
if(Test-Path -LiteralPath $cache){
    if(!$ReuseVerifiedWorld){throw 'Use a fresh isolated test directory.'}
    $previous=Join-Path $cache 'server-console.txt'
    if(!(Test-Path -LiteralPath (Join-Path $cache 'Server/rce_verify.ini')) -or !(Select-String -LiteralPath $previous -Pattern '\[RCE_RUNTIME\] PASS entries=\d+ exits=5' -Quiet)){
        throw 'Only a completed isolated RCE verification world may be reused.'
    }
    Copy-Item -LiteralPath $previous -Destination (Join-Path $cache ('server-console.before-reset-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.txt'))
    Remove-Item -LiteralPath $previous
}
$stage=Join-Path $root 'research/raccoon-expedition-stage'
if(!(Test-Path -LiteralPath (Join-Path $stage '.rce-stage'))){throw 'Build staged mods first.'}
if(!$ReuseVerifiedWorld){
foreach($dir in 'mods','Server','Lua'){[void](New-Item -ItemType Directory -Path (Join-Path $cache $dir) -Force)}
foreach($mod in 'RaccoonExpedition','ProjectRPG','RaccoonCityB42'){
    Copy-Item -LiteralPath (Join-Path $stage $mod) -Destination (Join-Path $cache 'mods') -Recurse
}
Copy-Item -LiteralPath 'D:/SteamLibrary/steamapps/workshop/content/108600/3414468585/mods/B42 PZLinux' -Destination (Join-Path $cache 'mods') -Recurse
$probe=if($CharacterProbe){'raccoon-character-probe.lua'}else{'raccoon-runtime-probe.lua'}
Copy-Item -LiteralPath (Join-Path $root ('scripts/tests/'+$probe)) -Destination (Join-Path $cache 'mods/RaccoonExpedition/42/media/lua/server/zzzzzz_RCERuntimeProbe.lua')
Copy-Item -LiteralPath (Join-Path $root 'artifacts/raccoon-expedition/raccoon-bridge.jar') -Destination $cache
$utf8=[Text.UTF8Encoding]::new($false)
$name='rce_verify'
$ini=@'
Public=false
PauseEmpty=false
MaxPlayers=2
DefaultPort=30581
UDPPort=30582
RCONEnabled=false
WorkshopItems=
Mods=\B42_PZLinux;\ProjectRPG;\RaccoonCityB42;\RaccoonExpedition
Map=RaccoonCity;Muldraugh, KY
SpawnPoint=10049,10116,0
BackupsOnStart=false
BackupsOnVersionChange=false
DoLuaChecksum=true
SafetySystem=false
AllowDestructionBySledgehammer=true
'@
[IO.File]::WriteAllText((Join-Path $cache "Server/$name.ini"),$ini,$utf8)
[IO.File]::WriteAllText((Join-Path $cache "Server/${name}_SandboxVars.lua"),@'
SandboxVars = {VERSION=6,Zombies=6,DayLength=2,
 ZombieConfig={PopulationMultiplier=0.0,PopulationStartMultiplier=0.0,PopulationPeakMultiplier=0.0,RespawnHours=0.0,RespawnUnseenHours=0.0,RespawnMultiplier=0.0},
 RPGSkillTree={KillXP=0,HordeRaidChancePercent=0,WorldDangerEnabled=false,RitualScrollDropPercent=0}}
'@,$utf8)
}else{$name='rce_verify';$utf8=[Text.UTF8Encoding]::new($false)}
if($CharacterProbe){
    if($ReuseVerifiedWorld){throw 'Character probe requires a fresh isolated profile.'}
    $classes=Join-Path $root 'artifacts/raccoon-expedition/character-probe'
    [void](New-Item -ItemType Directory -Path $classes -Force)
    & 'C:/Program Files/Java/jdk-21/bin/javac.exe' -cp (Join-Path $root 'artifacts/raccoon-expedition/compile-api.jar') -d $classes (Join-Path $root 'native/raccoon/CharacterProbeBridge.java')
    if($LASTEXITCODE){throw 'Test-only character adapter compile failed'}
    $probeJar=Join-Path $cache 'raccoon-character-probe.jar'
    & 'C:/Program Files/Java/jdk-21/bin/jar.exe' cf $probeJar -C $classes raccoon
    if($LASTEXITCODE){throw 'Character probe adapter packaging failed'}
}
$info=[Diagnostics.ProcessStartInfo]::new()
$info.FileName='D:/PZDedicated/jre64/bin/java.exe';$info.WorkingDirectory='D:/PZDedicated'
$info.UseShellExecute=$false;$info.CreateNoWindow=$true
$info.RedirectStandardInput=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
$serverClasspath='java/;java/projectzomboid.jar'
if($CharacterProbe){$info.ArgumentList.Add('-Drce.characterProbe=true');$serverClasspath+=';'+$probeJar}
foreach($arg in @(('-javaagent:'+($cache+'/raccoon-bridge.jar')),'--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-Dzomboid.steam=0','-Dzomboid.znetlog=1','-XX:+UseZGC','-Xms1024M','-Xmx4096M','-Djava.library.path=natives/','-cp',$serverClasspath,'zombie.network.GameServer','-servername',$name,('-cachedir='+$cache),'-nosteam','-adminpassword','isolated-rce-verification')){$info.ArgumentList.Add($arg)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$info
if(!$p.Start()){throw 'Cannot start isolated test server'}
$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
$watch=[Diagnostics.Stopwatch]::StartNew();$quitting=$false;$last=0
Write-Output "RCE_TEST_STARTED pid=$($p.Id) cache=$cache"
try{
    while(!$p.HasExited -and $watch.Elapsed.TotalSeconds -lt $TimeoutSeconds){
        Start-Sleep -Seconds 2
        $console=Join-Path $cache 'server-console.txt'
        if(Test-Path -LiteralPath $console){
            $tail=Get-Content -LiteralPath $console -Tail 80 -ErrorAction SilentlyContinue
            if(!$quitting -and (($tail -match '\[RCE_(RUNTIME|CHARACTER)\] (PASS|FAIL)') -or ($tail -match 'RCE probe timeout|Unsafe static entry/exit'))){
                $p.StandardInput.WriteLine('quit');$p.StandardInput.Flush();$quitting=$true
            }
            if(!$quitting -and $watch.Elapsed.TotalSeconds -gt 150 -and ($tail -match '\*\*\* SERVER STARTED') -and !(Select-String -LiteralPath $console -Pattern '\[RCE_RUNTIME\] BEGIN' -Quiet)){
                $p.StandardInput.WriteLine('quit');$p.StandardInput.Flush();$quitting=$true
            }
        }
        if($watch.Elapsed.TotalSeconds-$last -ge 20){Write-Output "RCE_TEST_RUNNING seconds=$([int]$watch.Elapsed.TotalSeconds) quitting=$quitting";$last=$watch.Elapsed.TotalSeconds}
    }
    if(!$p.HasExited){$p.StandardInput.WriteLine('quit');$p.StandardInput.Flush();if(!$p.WaitForExit(30000)){$p.Kill();throw 'Isolated test timed out'}}
    [IO.File]::WriteAllText((Join-Path $cache 'stdout.txt'),$stdout.GetAwaiter().GetResult(),$utf8)
    [IO.File]::WriteAllText((Join-Path $cache 'stderr.txt'),$stderr.GetAwaiter().GetResult(),$utf8)
    $log=[IO.File]::ReadAllText((Join-Path $cache 'server-console.txt'))
    $expected=if($CharacterProbe){'\[RCE_CHARACTER\] PASS checks=\d+'}else{'\[RCE_RUNTIME\] PASS entries=8 exits=5 primary=(8|9|10|11|12)'}
    if($p.ExitCode -ne 0 -or $log -notmatch $expected){throw "RCE runtime probe failed; inspect $cache"}
    if(!$CharacterProbe -and ([regex]::Matches($log,'\[RCE_BARRIER_NATIVE\] PASS')).Count -ne 4){throw 'Four native barrier checks required'}
    if(!$CharacterProbe -and $log -notmatch '\[RCE_FORGE_NATIVE\] PASS'){throw 'Forge native probe missing; do not accept the general region probe alone'}
    if(!(Test-Path -LiteralPath (Join-Path $cache 'Lua/RCE-rce_verify-checkpoint.txt'))){throw 'Runtime checkpoint was not written'}
    Write-Output "RCE_TEST_PASS cache=$cache"
} finally {if(!$p.HasExited){$p.Kill()};$p.Dispose()}
