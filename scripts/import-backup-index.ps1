[CmdletBinding()]
param([Parameter(Mandatory)][string]$Archive,[Parameter(Mandatory)][string]$ExpectedSHA256,[string]$ServerName='escape_test',[string]$ZomboidHome='C:/Users/goods/Zomboid')
$ErrorActionPreference='Stop'
if($ServerName -notmatch '^[A-Za-z0-9_-]+$'){throw 'Invalid server name'}
$Archive=(Resolve-Path -LiteralPath $Archive).Path
if((Get-FileHash -LiteralPath $Archive).Hash -ne $ExpectedSHA256){throw 'Baseline hash mismatch'}
$tool="$env:ProgramFiles/7-Zip/7z.exe"
if(!(Test-Path -LiteralPath $tool)){throw '7-Zip is required to import an older baseline'}
if(!('PzBackupIndex' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'PzBackupIndex.cs')}
Add-Type -AssemblyName System.IO.Compression.FileSystem
$directory=Split-Path $Archive -Parent
$indexPath=Join-Path $directory ('.backup-index-'+$ServerName+'.tsv')
if(Test-Path -LiteralPath $indexPath){throw 'Existing index retained; import requires an unindexed profile'}
$id=[guid]::NewGuid().ToString('N');$listing=Join-Path $directory ($id+'.listing.tmp');$errorFile=Join-Path $directory ($id+'.errors.tmp');$temp=Join-Path $directory ($id+'.index.tmp')
try{
 $test=@(& $tool t -bb0 -bsp0 -y $Archive 2>&1);if($LASTEXITCODE){throw 'Baseline CRC verification failed'}
 $process=Start-Process -FilePath $tool -ArgumentList @('l','-slt','-ba','-sccUTF-8',('"'+$Archive+'"')) -WindowStyle Hidden -RedirectStandardOutput $listing -RedirectStandardError $errorFile -Wait -PassThru
 if($process.ExitCode){throw 'Baseline metadata listing failed'}
 $index=[PzBackupIndex]::FromSevenZipListing($listing,$ZomboidHome,$ServerName,(Split-Path $Archive -Leaf),$ExpectedSHA256)
 $zip=[IO.Compression.ZipFile]::OpenRead($Archive)
 try{$index.ValidateZip($zip.Entries)}finally{$zip.Dispose()}
 $index.Save($temp);[IO.File]::Move($temp,$indexPath)
 [pscustomobject]@{Result='BASELINE_IMPORTED';Archive=$Archive;IndexedFiles=$index.Files.Count;Directories=$index.Directories.Count;Index=$indexPath;SourceWorldRead=$false;SourceWorldModified=$false}|Format-List
}finally{
 foreach($p in @($listing,$errorFile,$temp)){
  $full=[IO.Path]::GetFullPath($p)
  if(!$full.StartsWith([IO.Path]::GetFullPath($directory).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe import temporary path'}
  if(Test-Path -LiteralPath $full){Remove-Item -LiteralPath $full -Force}
 }
}
