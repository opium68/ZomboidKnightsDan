[CmdletBinding()]
param([string]$ProjectRoot='D:/PZProject/pz-zombie-escape',[ValidateRange(10,100000)][int]$FileCount=15000)
$ErrorActionPreference='Stop'
$root=$ProjectRoot
$fixture=Join-Path $PSScriptRoot ('backup-speed-fixture-'+[guid]::NewGuid().ToString('N'))
$fixtureHome=Join-Path $fixture 'home';$backups=Join-Path $fixture 'backups';$stage=Join-Path $fixture 'stage'
$world=Join-Path $fixtureHome 'Saves/Multiplayer/backup_fixture'
foreach($dir in @($world,"$world/map/1","$world/obsolete/deep","$fixtureHome/Server","$fixtureHome/db","$fixtureHome/Lua")){[void](New-Item -ItemType Directory -Path $dir -Force)}
foreach($name in 'map_t.bin','map_meta.bin','vehicles.db','players.db','global_mod_data.bin'){[IO.File]::WriteAllText((Join-Path $world $name),'fixture-'+$name)}
[IO.File]::WriteAllText("$fixtureHome/Server/backup_fixture.ini",'test settings')
[IO.File]::WriteAllText("$fixtureHome/db/backup_fixture.db",'account-db')
[IO.File]::WriteAllText("$fixtureHome/db/backup_fixture.db-wal",'account-wal')
[IO.File]::WriteAllText("$fixtureHome/Lua/RCE-backup_fixture-checkpoint.txt",'cycle=4')
[IO.File]::WriteAllText("$world/obsolete/deep/delete.bin",'deleted directory payload')
$content=[Text.Encoding]::UTF8.GetBytes(('PZ map contents 0123456789 '*80))
for($i=0;$i -lt $FileCount;$i++){[IO.File]::WriteAllBytes("$world/map/1/$i.bin",$content)}
function Run-Backup([switch]$Force){
 $clock=[Diagnostics.Stopwatch]::StartNew()
 & "$root/scripts/backup-server.ps1" -ServerName backup_fixture -ZomboidHome $fixtureHome -BackupRoot $backups -StagingRoot $stage -ForceFull:$Force
 if(!$?){throw 'Fixture backup failed'}
 $clock.Stop();$script:lastSeconds=$clock.Elapsed.TotalSeconds
 $script:index=[PzBackupIndex]::Load("$backups/.backup-index-backup_fixture.tsv")
 $script:archive=Join-Path $backups $script:index.ArchiveName
}
Run-Backup -Force
$baseline=$archive;$baselineHash=(Get-FileHash -LiteralPath $baseline).Hash;$fullSeconds=$lastSeconds
$oldTime=[IO.File]::GetLastWriteTimeUtc("$world/map/1/1.bin")
$different=[byte[]]$content.Clone();$different[0]=[byte]90
[IO.File]::WriteAllBytes("$world/map/1/1.bin",$different)
[IO.File]::SetLastWriteTimeUtc("$world/map/1/1.bin",$oldTime.AddTicks(1000))
[IO.File]::WriteAllText("$world/map/1/2.bin",'older replacement')
[IO.File]::SetLastWriteTimeUtc("$world/map/1/2.bin",$oldTime.AddDays(-2))
[IO.File]::Delete("$world/map/1/3.bin")
[IO.File]::WriteAllText("$world/new 한글 file.bin",'new file')
$delete=[IO.Path]::GetFullPath("$world/obsolete")
if(!$delete.StartsWith([IO.Path]::GetFullPath($fixture)+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup'}
Remove-Item -LiteralPath $delete -Recurse -Force
Run-Backup
$incrementalSeconds=$lastSeconds
if((Get-FileHash -LiteralPath $baseline).Hash -ne $baselineHash){throw 'Previous backup was modified'}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{
 $current=[PzBackupIndex]::Scan($fixtureHome,'backup_fixture',[string[]]@('Server/backup_fixture.ini','db/backup_fixture.db','db/backup_fixture.db-wal','Saves/Multiplayer/backup_fixture','Lua/RCE-backup_fixture-checkpoint.txt'))
 $current.ValidateZip($zip.Entries);$current.VerifyPayload($zip.Entries)
 if($zip.GetEntry('Saves/Multiplayer/backup_fixture/map/1/3.bin')){throw 'Deleted file resurrected'}
 if(!$zip.GetEntry('db/backup_fixture.db-wal')){throw 'Account WAL omitted'}
}finally{$zip.Dispose()}
Run-Backup
$unchangedSeconds=$lastSeconds
# A mismatched baseline hash must force a fresh complete ZIP.
$stream=[IO.File]::Open($archive,[IO.FileMode]::Append);try{$stream.WriteByte(42)}finally{$stream.Dispose()}
Run-Backup
if($index.Files.Count -ne $current.Files.Count){throw 'Fallback snapshot missing files'}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{$current.ValidateZip($zip.Entries);$current.VerifyPayload($zip.Entries)}finally{$zip.Dispose()}
$indexFile=Join-Path $backups '.backup-index-backup_fixture.tsv'
$lines=[IO.File]::ReadAllLines($indexFile)
[IO.File]::WriteAllLines($indexFile,[string[]]$lines[0..6],[Text.UTF8Encoding]::new($false))
Run-Backup
if($index.Files.Count -ne $current.Files.Count){throw 'Truncated index did not recover through full backup'}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{$current.ValidateZip($zip.Entries);$current.VerifyPayload($zip.Entries)}finally{$zip.Dispose()}
$result=[pscustomobject]@{Result='FAST_BACKUP_PASS';Files=$current.Files.Count;FullSeconds=[math]::Round($fullSeconds,2);IncrementalSeconds=[math]::Round($incrementalSeconds,2);UnchangedSeconds=[math]::Round($unchangedSeconds,2);Checks='all restored bytes match; same-size subsecond change; older replacement; additions/deletions; prior archive immutable; WAL/RCE included; corrupt baseline falls back';Fixture=$fixture}
$result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $fixture 'VERIFIED.json') -Encoding utf8
$result|Format-List
