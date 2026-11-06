[CmdletBinding()]
param([string]$ServerName,[switch]$ForceFull,[string]$ZomboidHome,[string]$BackupRoot,[string]$StagingRoot)
. (Join-Path $PSScriptRoot 'common.ps1')
if(!$ServerName){$ServerName=(Get-PzConfig).ServerName}
if($ServerName -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid server name'}
if(!$ZomboidHome){$ZomboidHome=(Get-PzConfig).ZomboidHome}
if(!$BackupRoot){$BackupRoot=Join-Path $script:ProjectRoot 'backups'}
if(!$StagingRoot){$StagingRoot=Join-Path $env:LOCALAPPDATA 'PzEscapeServer/backup-staging'}
$ZomboidHome=[IO.Path]::GetFullPath($ZomboidHome);$BackupRoot=[IO.Path]::GetFullPath($BackupRoot);$StagingRoot=[IO.Path]::GetFullPath($StagingRoot)
# Never call a running game's live files a consistent restorable snapshot.
try{
 $running=@(Get-CimInstance Win32_Process -ErrorAction Stop|Where-Object {$_.Name -match '^java(w)?\.exe$' -and $_.CommandLine -match 'zombie.network.GameServer' -and $_.CommandLine -match ('-servername\s+"?'+[regex]::Escape($ServerName)+'"?(?:\s|$)')})
 if($running.Count){throw "Stop server '$ServerName' before creating its backup"}
}catch{
 if($_.Exception.Message -like 'Stop server*'){throw}
 if(@(Get-Process java,javaw -ErrorAction SilentlyContinue).Count){throw 'Cannot verify that the server is stopped; backup not started'}
}
$relative=@("Server/$ServerName.ini","Server/${ServerName}_SandboxVars.lua","Server/${ServerName}_spawnpoints.lua","Server/${ServerName}_spawnregions.lua","db/$ServerName.db","db/$ServerName.db-journal","db/$ServerName.db-wal","db/$ServerName.db-shm","Saves/Multiplayer/$ServerName","Lua/RCE-$ServerName-checkpoint.txt","Lua/RCE-$ServerName-reset.txt","Lua/RCE-$ServerName-initialized.txt","RCE-$ServerName-clean-stop.properties")
$sources=@($relative|Where-Object {Test-Path -LiteralPath (Join-Path $ZomboidHome $_)})
if(!$sources.Count){Write-Output "No existing data found for server '$ServerName'; no backup created.";return}
foreach($dir in @($BackupRoot,$StagingRoot)){[void](New-Item -ItemType Directory -Path $dir -Force)}
if(!('PzBackupIndex' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'PzBackupIndex.cs')}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$clock=[Diagnostics.Stopwatch]::StartNew();$phases=[ordered]@{}
$snapshot=[PzBackupIndex]::Scan($ZomboidHome,$ServerName,[string[]]$sources)
$phases.Scan=[math]::Round($clock.Elapsed.TotalSeconds,2)
$indexPath=Join-Path $BackupRoot ('.backup-index-'+$ServerName+'.tsv')
$sevenZip=$null;$command=Get-Command 7z.exe -ErrorAction SilentlyContinue
if($command){$sevenZip=$command.Source}elseif(Test-Path -LiteralPath "$env:ProgramFiles/7-Zip/7z.exe"){$sevenZip="$env:ProgramFiles/7-Zip/7z.exe"}
$previous=$null;$baseline=$null
if(!$ForceFull -and $sevenZip -and (Test-Path -LiteralPath $indexPath)){
 try{
  $candidate=[PzBackupIndex]::Load($indexPath)
  if($candidate.Root -ne $snapshot.Root -or $candidate.Profile -ne $ServerName){throw 'Index source/profile mismatch'}
  $basePath=Join-Path $BackupRoot $candidate.ArchiveName
  if(!(Test-Path -LiteralPath $basePath) -or (Get-FileHash -LiteralPath $basePath -Algorithm SHA256).Hash -ne $candidate.ArchiveHash){throw 'Baseline archive/hash unavailable'}
  $baseZip=[IO.Compression.ZipFile]::OpenRead($basePath)
  try{$candidate.ValidateZip($baseZip.Entries)}finally{$baseZip.Dispose()}
  $candidate.ArchiveTimeTicks=(Get-Item -LiteralPath $basePath).LastWriteTimeUtc.Ticks
  $previous=$candidate;$baseline=$basePath
 }catch{Write-Warning ('Incremental index unavailable; creating a full baseline. '+$_.Exception.Message)}
}
[string[]]$changed=@(if($previous){$snapshot.Changed($previous)}else{$snapshot.Files.Keys})
[string[]]$removed=@(if($previous){$previous.Removed($snapshot)})
$mode=if($previous){'Incremental standalone ZIP'}else{'Full baseline ZIP'}
$leaf=$ServerName+'-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.zip'
$archive=Join-Path $BackupRoot $leaf
if(Test-Path -LiteralPath $archive){$leaf=$ServerName+'-'+(Get-Date -Format yyyyMMdd-HHmmss)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)+'.zip';$archive=Join-Path $BackupRoot $leaf}
$id=[guid]::NewGuid().ToString('N')
$stage=Join-Path $StagingRoot ($id+'.zip');$changedList=Join-Path $StagingRoot ($id+'-changed.txt');$removedList=Join-Path $StagingRoot ($id+'-removed.txt');$indexTemp=Join-Path $BackupRoot ($id+'.index-tmp')
$temps=@($stage,$changedList,$removedList,$indexTemp)
function Invoke-Backup7Zip([string[]]$ZipArguments){
 $output=@(& $sevenZip @ZipArguments 2>&1)
 if($LASTEXITCODE -ne 0){throw ('7-Zip failed: '+($output -join ' '))}
}
Write-Host "Backing up '$ServerName': $mode; $($changed.Count) new/changed files, $($removed.Count) removed paths."
$phases.Baseline=[math]::Round($clock.Elapsed.TotalSeconds-[double]$phases.Scan,2)
$at=$clock.Elapsed.TotalSeconds
try{
 if($previous){Copy-Item -LiteralPath $baseline -Destination $stage}
 if($sevenZip){
  Push-Location -LiteralPath $ZomboidHome
  try{
   if($previous -and $removed.Count){
    [IO.File]::WriteAllLines($removedList,[string[]]$removed,[Text.UTF8Encoding]::new($false))
    Invoke-Backup7Zip @('d','-bb0','-bsp0','-y','-spd','-scsUTF-8',$stage,('@'+$removedList))
   }
   if($previous -and $changed.Count){
    [IO.File]::WriteAllLines($changedList,[string[]]$changed,[Text.UTF8Encoding]::new($false))
    # 'a' compresses named files even if their time matches/is older than ZIP.
    Invoke-Backup7Zip @('a','-tzip','-mx=1','-mmt=on','-mtc=on','-mcu=on','-bb0','-bsp0','-y','-spd','-scsUTF-8',$stage,('@'+$changedList))
   }elseif(!$previous){
    Invoke-Backup7Zip (@('a','-tzip','-mx=1','-mmt=on','-mtc=on','-mcu=on','-bb0','-bsp0','-y','-spd',$stage)+$sources)
   }
  }finally{Pop-Location}
 }else{
  $zip=[IO.Compression.ZipFile]::Open($stage,[IO.Compression.ZipArchiveMode]::Create)
  try{foreach($path in $snapshot.Files.Keys){[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $ZomboidHome $path),$path,[IO.Compression.CompressionLevel]::Fastest)}}finally{$zip.Dispose()}
 }
 $phases.Archive=[math]::Round($clock.Elapsed.TotalSeconds-$at,2)
$at=$clock.Elapsed.TotalSeconds
 # Verify EVERY CRC, including compressed entries reused from the previous ZIP.
 if($sevenZip){Invoke-Backup7Zip @('t','-bb0','-bsp0','-y',$stage)}
 $zip=[IO.Compression.ZipFile]::OpenRead($stage)
 try{
  $snapshot.ValidateZip($zip.Entries);$entryCount=$zip.Entries.Count
  if(!$sevenZip){$snapshot.VerifyPayload($zip.Entries)}
 }finally{$zip.Dispose()}
 $after=[PzBackupIndex]::Scan($ZomboidHome,$ServerName,[string[]]$relative)
 if(!$snapshot.Equivalent($after)){throw 'Source changed during backup; snapshot not published'}
 $phases.Verify=[math]::Round($clock.Elapsed.TotalSeconds-$at,2)
$at=$clock.Elapsed.TotalSeconds
 Move-Item -LiteralPath $stage -Destination $archive
 $hash=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
 $snapshot.ArchiveName=$leaf;$snapshot.ArchiveHash=$hash
 try{
  $snapshot.Save($indexTemp)
  if(Test-Path -LiteralPath $indexPath){[IO.File]::Replace($indexTemp,$indexPath,($indexPath+'.previous'))}else{[IO.File]::Move($indexTemp,$indexPath)}
 }catch{Write-Warning ('ZIP is valid, but index was not updated: '+$_.Exception.Message)}
 $phases.Finalize=[math]::Round($clock.Elapsed.TotalSeconds-$at,2)
}finally{
 $clock.Stop()
 foreach($p in $temps){
  $full=[IO.Path]::GetFullPath($p)
  if(!$full.StartsWith($StagingRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase) -and !$full.StartsWith($BackupRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe backup temporary path'}
  if(Test-Path -LiteralPath $full){Remove-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue}
 }
}
[pscustomobject]@{Archive=$archive;Bytes=(Get-Item -LiteralPath $archive).Length;Entries=$entryCount;Mode=$mode;ChangedFiles=$changed.Count;RemovedPaths=$removed.Count;Seconds=[math]::Round($clock.Elapsed.TotalSeconds,1);Phases=($phases|ConvertTo-Json -Compress);SHA256=$hash}|Format-List
