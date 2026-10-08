Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Get-KnightsSafePath {
    param([string]$Root,[string]$Relative)
    if (!$Relative -or $Relative -match '[\\:]|(^|/)\.\.(/|$)|^/' -or
        $Relative -match '(^|/)[^/]*[. ]($|/)' -or $Relative -match '[\x00-\x1F]' -or
        $Relative -match '(?i)(^|/)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:[./]|$)') {throw "Invalid release path: $Relative"}
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $path=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    if (!$path.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) {throw 'Release path escapes destination.'}
    return $path
}
function Test-KnightsManifest {
    param([string]$Envelope,[string]$PublicKey)
    # ReadAllText strips a UTF-8 BOM, while WebRequest.Content retains it on
    # Windows PowerShell 5.1. Normalize both paths before parsing the envelope.
    $signed=$Envelope.TrimStart([char]0xFEFF) | ConvertFrom-Json
    $payload=[Convert]::FromBase64String($signed.payload)
    $signature=[Convert]::FromBase64String($signed.signature)
    $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        $rsa.FromXmlString($PublicKey)
        if (!$rsa.VerifyHash($sha.ComputeHash($payload),[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'),$signature)) {throw 'Release signature verification failed.'}
    } finally {$rsa.Dispose();$sha.Dispose()}
    $manifest=[Text.Encoding]::UTF8.GetString($payload) | ConvertFrom-Json
    if ($manifest.schema -ne 1 -or $manifest.version -notmatch '^[A-Za-z0-9_.-]+$' -or
        $manifest.assetUrl -notmatch '^https://github\.com/opium68/ZomboidKnightsDan/releases/download/[^/]+/knights-client\.zip$' -or
        $manifest.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {throw 'Unsupported release manifest.'}
    $allowed=@('JOIN-SERVER.cmd','OPEN-MANUAL.cmd','RESET-SERVER-ADDRESS.cmd','CHECK-CLIENT-MODS.cmd','RESTORE-CLIENT-MODS.cmd',
        'join-server.ps1','restore-client-mods.ps1','bootstrap.ps1','update-client.ps1','PLAYER-MANUAL.html','README.txt',
        'server-mods.json','update-config.json','release-public.xml')
    $seen=@{}
    foreach($file in $manifest.files) {
        $name=[string]$file.path
        if ($name -notin $allowed -and $name -notmatch '^local-mods/[A-Za-z0-9_.-]+/.+') {throw "Unmanaged release file: $name"}
        $null=Get-KnightsSafePath -Root ([IO.Path]::GetTempPath()) -Relative $name
        if ($seen.ContainsKey($name.ToLowerInvariant()) -or $file.sha256 -notmatch '^[A-Fa-f0-9]{64}$') {throw 'Duplicate path or invalid file hash.'}
        $seen[$name.ToLowerInvariant()]=$true
    }
    foreach($id in $manifest.localModIds) {if($id -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid managed mod ID.'}}
    return $manifest
}
function Test-KnightsFiles {
    param($Manifest,[string]$Root)
    foreach($file in $Manifest.files) {
        $path=Get-KnightsSafePath $Root $file.path
        if (!(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) {return $false}
    }
    return $true
}
function Restore-KnightsTransaction {
    param([string]$JournalPath,[string]$LauncherRoot,[string]$ZomboidHome)
    if (!(Test-Path -LiteralPath $JournalPath)) {return}
    $journal=Get-Content -LiteralPath $JournalPath -Raw | ConvertFrom-Json
    $backup=Get-KnightsSafePath $LauncherRoot $journal.backup
    foreach($entry in @($journal.entries)) {
        $root=if($entry.scope -eq 'launcher'){$LauncherRoot}elseif($entry.scope -eq 'mods'){Join-Path $ZomboidHome 'mods'}else{throw 'Invalid recovery scope.'}
        $path=Get-KnightsSafePath $root $entry.path
        $saved=Get-KnightsSafePath $backup ($entry.scope+'/'+$entry.path)
        if($entry.existed -and !(Test-Path -LiteralPath $saved)){throw 'Recovery backup is incomplete; installation stopped.'}
        if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Recurse -Force}
        if($entry.existed){New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null; Copy-Item -LiteralPath $saved -Destination $path -Recurse -Force}
    }
    Remove-Item -LiteralPath $JournalPath -Force
}
function Invoke-KnightsUpdate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$LauncherRoot,[Parameter(Mandatory)][string]$ZomboidHome,
        [string]$EnvelopePath,[string]$ArchivePath,[switch]$TestOnly)
    [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
    $key=Get-Content -LiteralPath (Join-Path $LauncherRoot 'release-public.xml') -Raw
    $config=Get-Content -LiteralPath (Join-Path $LauncherRoot 'update-config.json') -Raw | ConvertFrom-Json
    $journalPath=Join-Path $LauncherRoot 'update-transaction.json'
    $game=@(Get-Process -Name ProjectZomboid64,ProjectZomboid -ErrorAction SilentlyContinue)
    if(Test-Path -LiteralPath $journalPath) {
        if($game.Count){throw 'Close Project Zomboid to recover an interrupted update.'}
        Restore-KnightsTransaction $journalPath $LauncherRoot $ZomboidHome
    }
    $envelope=if($EnvelopePath){[IO.File]::ReadAllText($EnvelopePath)}else{
        if($config.manifestUrl -notmatch '^https://(opium68\.github\.io/ZomboidKnightsDan/|raw\.githubusercontent\.com/opium68/ZomboidKnightsDan/main/)distribution/stable\.json$'){throw 'Untrusted update endpoint.'}
        (Invoke-WebRequest -Uri $config.manifestUrl -UseBasicParsing -TimeoutSec 30).Content
    }
    $manifest=Test-KnightsManifest $envelope $key
    $statePath=Join-Path $LauncherRoot 'release-state.json'
    $current=$null
    $previousManifest=$null
    if(Test-Path -LiteralPath $statePath){
        $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if(!$state.PSObject.Properties['envelope']){throw 'The installed release state has no verified signature.'}
        $previousManifest=Test-KnightsManifest $state.envelope $key
        $current=$previousManifest
    }
    if($current -and [long]$manifest.revision -lt [long]$current.revision){throw 'Rejected an older signed deployment manifest.'}
    if($current -and $current.version -eq $manifest.version -and (Test-KnightsFiles $manifest $LauncherRoot)){
        Write-Host ('Server release is current: '+$manifest.version) -ForegroundColor Green; return
    }
    if($game.Count){throw 'Close Project Zomboid before updating server mods.'}
    $stage=Join-Path ([IO.Path]::GetTempPath()) ('knights-update-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        $zipPath=Join-Path $stage 'release.zip'
        if($ArchivePath){Copy-Item -LiteralPath $ArchivePath -Destination $zipPath}else{
            Invoke-WebRequest -Uri $manifest.assetUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120
        }
        if((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ne $manifest.sha256){throw 'Release archive SHA-256 mismatch.'}
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip=[IO.Compression.ZipFile]::OpenRead($zipPath)
        $expected=@{}; foreach($file in $manifest.files){$expected[$file.path.ToLowerInvariant()]=$true}
        $extract=Join-Path $stage 'extracted'; New-Item -ItemType Directory -Path $extract | Out-Null
        try {
            $total=0L;$found=@{}
            foreach($entry in $zip.Entries){
                if($entry.FullName.EndsWith('/')){continue}
                $path=Get-KnightsSafePath $extract $entry.FullName
                $name=$entry.FullName.ToLowerInvariant()
                if(!$expected.ContainsKey($name) -or $found.ContainsKey($name)){throw 'Unexpected or duplicate archive entry.'}
                $found[$name]=$true; $total+=$entry.Length
                if($total -gt 104857600 -or $found.Count -gt 5000){throw 'Release archive exceeds size limits.'}
                New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entry,$path,$false)
            }
        } finally {$zip.Dispose()}
        if(!(Test-KnightsFiles $manifest $extract)){throw 'Extracted release integrity check failed.'}
        $serverMods=Get-Content -LiteralPath (Join-Path $extract 'server-mods.json') -Raw | ConvertFrom-Json
        $ids=@($serverMods.LocalModIds | Sort-Object)
        if(($ids -join ';') -ne (@($manifest.localModIds | Sort-Object) -join ';')){throw 'Release mod IDs disagree.'}
        foreach($id in $ids){
            $info=@(Get-ChildItem -LiteralPath (Join-Path $extract "local-mods/$id") -Recurse -Filter mod.info -File |
                ForEach-Object {Get-Content -LiteralPath $_.FullName} | Where-Object {$_ -ceq "id=$id"})
            if(!$info.Count){throw "Missing mod.info identity: $id"}
        }
        if($TestOnly){Write-Output ('Signed release validation PASS: '+$manifest.version); return}
        $backupRel='.knights-update-backups/'+[Guid]::NewGuid().ToString('N')
        $backup=Get-KnightsSafePath $LauncherRoot $backupRel
        $entries=@()
        $oldFiles=if($previousManifest){@($previousManifest.files | ForEach-Object {$_.path})}else{@()}
        $paths=@(@($manifest.files | ForEach-Object {$_.path})+@($oldFiles) | Sort-Object -Unique)
        foreach($path in $paths){$entries+=@{scope='launcher';path=$path;existed=(Test-Path -LiteralPath (Get-KnightsSafePath $LauncherRoot $path))}}
        $entries+=@{scope='launcher';path='release-state.json';existed=(Test-Path -LiteralPath $statePath)}
        $oldMods=if($previousManifest){@($previousManifest.localModIds)}else{@()}
        foreach($id in @(@($ids)+@($oldMods) | Sort-Object -Unique)){$entries+=@{scope='mods';path=$id;existed=(Test-Path -LiteralPath (Get-KnightsSafePath (Join-Path $ZomboidHome 'mods') $id))}}
        foreach($entry in $entries){
            if($entry.existed){
                $root=if($entry.scope -eq 'launcher'){$LauncherRoot}else{Join-Path $ZomboidHome 'mods'}
                $saved=Get-KnightsSafePath $backup ($entry.scope+'/'+$entry.path)
                New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
                Copy-Item -LiteralPath (Get-KnightsSafePath $root $entry.path) -Destination $saved -Recurse -Force
            }
        }
        @{backup=$backupRel;entries=$entries} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $journalPath -Encoding UTF8
        try {
            foreach($path in $paths){
                $dest=Get-KnightsSafePath $LauncherRoot $path
                $source=Get-KnightsSafePath $extract $path
                if(Test-Path -LiteralPath $source){New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null;Copy-Item -LiteralPath $source -Destination $dest -Force}
                elseif(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Force}
            }
            foreach($id in @(@($ids)+@($oldMods) | Sort-Object -Unique)){
                $dest=Get-KnightsSafePath (Join-Path $ZomboidHome 'mods') $id
                if(Test-Path -LiteralPath $dest){Remove-Item -LiteralPath $dest -Recurse -Force}
                if($id -in $ids){New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force | Out-Null;Copy-Item -LiteralPath (Join-Path $extract "local-mods/$id") -Destination $dest -Recurse -Force}
            }
            if(!(Test-KnightsFiles $manifest $LauncherRoot)){throw 'Post-install integrity check failed.'}
            @{version=$manifest.version;revision=$manifest.revision;envelope=$envelope} |
                ConvertTo-Json -Depth 5 | Set-Content -LiteralPath ($statePath+'.tmp') -Encoding UTF8
            Move-Item -LiteralPath ($statePath+'.tmp') -Destination $statePath -Force
            Remove-Item -LiteralPath $journalPath -Force
            Write-Host ('Updated server release: '+$manifest.version) -ForegroundColor Green
        } catch {Restore-KnightsTransaction $journalPath $LauncherRoot $ZomboidHome; throw}
    } finally {
        $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
        if(![IO.Path]::GetFullPath($stage).StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe cleanup path.'}
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
