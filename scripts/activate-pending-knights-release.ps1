[CmdletBinding()]
param([string]$ServerName,[switch]$CheckOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$cfg=Get-PzConfig
if(!$ServerName){$ServerName=$cfg.ServerName}
$pendingPath=Join-Path $script:ProjectRoot 'config/pending-knights-release.secret.json'
if(!(Test-Path -LiteralPath $pendingPath)){return}
$pending=Get-Content -LiteralPath $pendingPath -Raw|ConvertFrom-Json
if($pending.schema -ne 1 -or $pending.version -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid pending release instruction'}
if($pending.serverName -ne $ServerName){return}
if(!$CheckOnly){
 $listener=@(Get-NetUDPEndpoint -ErrorAction Stop | Where-Object LocalPort -eq 16261)
 if($listener.Count){throw 'Pending release refused: server port is still running'}
}
$releaseRoot=Join-Path $script:ProjectRoot ('packages/releases/'+$pending.version)
$manifestPath=Join-Path $releaseRoot 'stable.json'
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -ne $pending.manifestSHA256){throw 'Pending manifest hash changed; rebuild and requeue'}
$envelope=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$payload=[Convert]::FromBase64String($envelope.payload)
$signature=[Convert]::FromBase64String($envelope.signature)
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
$rsa.PersistKeyInCsp=$false
$sha=[Security.Cryptography.SHA256]::Create()
try{
 $rsa.FromXmlString([IO.File]::ReadAllText((Join-Path $script:ProjectRoot 'player-launcher/release-public.xml')))
 if(!$rsa.VerifyHash($sha.ComputeHash($payload),[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'),$signature)){throw 'Pending release signature invalid'}
}finally{$rsa.Dispose();$sha.Dispose()}
$manifest=[Text.Encoding]::UTF8.GetString($payload)|ConvertFrom-Json
if($manifest.version -ne $pending.version){throw 'Pending release version mismatch'}
if((Get-FileHash -LiteralPath (Join-Path $releaseRoot 'knights-client.zip') -Algorithm SHA256).Hash -ne $manifest.sha256){throw 'Pending archive hash mismatch'}
if($CheckOnly){Write-Output ('PENDING_RELEASE_VALIDATED version='+$pending.version+' activation=deferred');return}
$liveRoot=[IO.Path]::GetFullPath((Join-Path $cfg.ZomboidHome 'mods'))
$checked=0
foreach($file in $manifest.files){
 if(!$file.path.StartsWith('local-mods/')){continue}
 $target=[IO.Path]::GetFullPath((Join-Path $liveRoot $file.path.Substring(11)))
 if(!$target.StartsWith($liveRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Pending live path escaped mods'}
 if(!(Test-Path -LiteralPath $target) -or (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $file.sha256){throw ('Installed server patch differs from pending release: '+$file.path)}
 $checked++
}
if(!$checked){throw 'Pending release has no server patch files'}
& (Join-Path $PSScriptRoot 'publish-knights-release.ps1') -Version $pending.version -Mode Activate
if($LASTEXITCODE){throw 'Pending release activation failed; server not started'}
$history=Join-Path $script:ProjectRoot ('config/applied-knights-release-'+(Get-Date -Format yyyyMMdd-HHmmss)+'.secret.json')
Move-Item -LiteralPath $pendingPath -Destination $history
Write-Output ('PENDING_RELEASE_ACTIVATED version='+$pending.version+' verifiedServerFiles='+$checked)
