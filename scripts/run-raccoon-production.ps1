[CmdletBinding()]
param([string]$ServerName='escape_test',[int]$MemoryMiB=8192,[switch]$LocalTest,[switch]$Managed)
. (Join-Path $PSScriptRoot 'common.ps1')
$cfg=Get-PzConfig
$cache=[IO.Path]::GetFullPath($cfg.ZomboidHome)
$java=Join-Path $cfg.ServerRoot 'jre64/bin/java.exe'
$agent=Join-Path $cfg.ServerRoot 'RCE/raccoon-bridge.jar'
$ini=Join-Path $cache "Server/$ServerName.ini"
if(!(Select-String -LiteralPath $ini -Pattern '^Mods=.*(?:^|;)RaccoonExpedition(?:;|$)' -Quiet)){
 # Check normalized individual IDs, including B42's optional backslash prefix.
 $mods=((Get-Content -LiteralPath $ini|Where-Object {$_ -match '^Mods='})-replace '^Mods=','') -split ';'
 if(@($mods|ForEach-Object {$_.TrimStart('\')}) -notcontains 'RaccoonExpedition'){throw 'RaccoonExpedition is not enabled'}
}
if(!(Test-Path -LiteralPath $agent)){throw 'Missing production RCE agent'}
$transaction=Join-Path $cache "RCE-$ServerName-reset-in-progress"
if(Test-Path -LiteralPath $transaction){throw 'Interrupted region reset: inspect its verified backup before starting'}
$checkpoint=Join-Path $cache "Lua/RCE-$ServerName-checkpoint.txt"
if(Test-Path -LiteralPath $checkpoint){
 & $java --enable-native-access=ALL-UNNAMED -cp ($agent+';'+(Join-Path $cfg.ServerRoot 'java/projectzomboid.jar')) raccoon.OfflineReset $cache $ServerName apply
 if($LASTEXITCODE){throw 'Offline expedition reset gate failed; server not started'}
}
$receipt=Join-Path $cache "RCE-$ServerName-clean-stop.properties"
if(Test-Path -LiteralPath $receipt){Remove-Item -LiteralPath $receipt}
$arguments=@(('-javaagent:'+$agent),'--enable-native-access=ALL-UNNAMED','-Djava.awt.headless=true','-Dzomboid.steam=1','-Dzomboid.znetlog=1','-XX:+UseZGC','-XX:-CreateCoredumpOnCrash','-XX:-OmitStackTraceInFastThrow',"-Xms${MemoryMiB}M","-Xmx${MemoryMiB}M",'-Djava.library.path=natives/','-cp','java/;java/projectzomboid.jar','zombie.network.GameServer','-servername',$ServerName,('-cachedir='+$cache))
if($LocalTest){$arguments+=@('-ip','127.0.0.1')}
$started=[DateTime]::UtcNow
Push-Location $cfg.ServerRoot
try {
 if(!$Managed){ & $java $arguments; $serverExit=$LASTEXITCODE }
 else {
  $stop=Join-Path $cache "RCE-$ServerName-stop.request"
  if(Test-Path -LiteralPath $stop){throw 'Remove stale managed stop request before startup'}
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$java;$info.WorkingDirectory=$cfg.ServerRoot
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardInput=$true
  foreach($argument in $arguments){$info.ArgumentList.Add([string]$argument)}
  $process=New-Object Diagnostics.Process;$process.StartInfo=$info
  if(!$process.Start()){throw 'Managed server start failed'}
  $pidPath=Join-Path $cache "RCE-$ServerName-managed.json"
  [IO.File]::WriteAllText($pidPath,(@{pid=$process.Id;wrapperPid=$PID;startedUtc=$started.ToString('o');localTest=[bool]$LocalTest}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  try {
   while(!$process.HasExited){
    if(Test-Path -LiteralPath $stop){
     $process.StandardInput.WriteLine('quit');$process.StandardInput.Flush()
     Remove-Item -LiteralPath $stop
    }
    Start-Sleep -Seconds 1
   }
   $serverExit=$process.ExitCode
  } finally {
   if($process.HasExited -and (Test-Path -LiteralPath $pidPath)){Remove-Item -LiteralPath $pidPath}
   $process.Dispose()
  }
 }
} finally {Pop-Location}
$console=Join-Path $cache 'server-console.txt'
if($serverExit -eq 0 -and (Test-Path -LiteralPath $checkpoint) -and (Get-Item -LiteralPath $console).LastWriteTimeUtc -ge $started){
 $log=[IO.File]::ReadAllText($console)
 if($log.LastIndexOf('Shutdown handling finished') -gt $log.LastIndexOf('SERVER STARTED')){
  $savedAt=[regex]::Match([IO.File]::ReadAllText($checkpoint),'(?m)^savedAt=(\d+)').Groups[1].Value
  if(!$savedAt){throw 'No saved checkpoint timestamp'}
  [IO.File]::WriteAllText($receipt,"savedAt=$savedAt`n",[Text.UTF8Encoding]::new($false))
 }
}
if($serverExit){throw "Server exited: $serverExit"}
