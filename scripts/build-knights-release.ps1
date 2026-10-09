[CmdletBinding()]
param([string]$Version='0.1.0-20261005.1')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if($Version -notmatch '^[A-Za-z0-9_.-]+$'){throw 'Invalid release version.'}
& (Join-Path $PSScriptRoot 'validate-config.ps1') -SkipInstalledWorkshopCheck
$privatePath=Join-Path $root 'config/release-signing.secret.bin'
$publicPath=Join-Path $root 'player-launcher/release-public.xml'
Add-Type -AssemblyName System.Security
$rsa=New-Object Security.Cryptography.RSACryptoServiceProvider 3072
$rsa.PersistKeyInCsp=$false
try {
    if(Test-Path -LiteralPath $privatePath){
        $xml=[Text.Encoding]::UTF8.GetString([Security.Cryptography.ProtectedData]::Unprotect(
            [IO.File]::ReadAllBytes($privatePath),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser))
        $rsa.FromXmlString($xml)
    } else {
        if(Test-Path -LiteralPath $publicPath){throw 'Signing key is missing. Restore it instead of silently rotating the trusted public key.'}
        [IO.File]::WriteAllBytes($privatePath,[Security.Cryptography.ProtectedData]::Protect(
            [Text.Encoding]::UTF8.GetBytes($rsa.ToXmlString($true)),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser))
        [IO.File]::WriteAllText($publicPath,$rsa.ToXmlString($false),[Text.UTF8Encoding]::new($false))
    }
    $packageOutput=& (Join-Path $PSScriptRoot 'build-player-package.ps1')
    $packageOutput | Write-Output
    $initialZip=Get-ChildItem -LiteralPath (Join-Path $root 'packages') -Filter 'pz-escape-player-16261*.zip' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if(!$initialZip){throw 'Player launcher package was not generated.'}
    $releaseRoot=Join-Path $root "packages/releases/$Version"
    if(Test-Path -LiteralPath (Join-Path $releaseRoot 'stable.json')){throw 'Release already exists; use a new version to keep published assets immutable.'}
    New-Item -ItemType Directory -Path $releaseRoot -Force | Out-Null
    Copy-Item -LiteralPath $initialZip.FullName -Destination (Join-Path $releaseRoot 'KnightsDan-Launcher.zip') -Force
    $stage=Join-Path ([IO.Path]::GetTempPath()) ('knights-build-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        Expand-Archive -LiteralPath $initialZip.FullName -DestinationPath $stage
        Remove-Item -LiteralPath (Join-Path $stage 'player-settings.json') -Force
        $files=@(Get-ChildItem -LiteralPath $stage -File -Recurse | Sort-Object FullName | ForEach-Object {
            [ordered]@{path=$_.FullName.Substring($stage.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        })
        $archive=Join-Path $releaseRoot 'knights-client.zip'
        # Explicit forward-slash entries work with both PowerShell 5.1 and 7.
        # Compress-Archive on Framework writes backslash paths rejected by the
        # existing strict launcher. Include only the signed files, no folders.
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip=[IO.Compression.ZipFile]::Open($archive,[IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach($file in $files){
                $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,
                    (Join-Path $stage $file.path),$file.path,[IO.Compression.CompressionLevel]::Optimal)
            }
        } finally {$zip.Dispose()}
        $serverMods=Get-Content -LiteralPath (Join-Path $stage 'server-mods.json') -Raw | ConvertFrom-Json
        $manifest=[ordered]@{schema=1;version=$Version;revision=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();
            assetUrl="https://github.com/opium68/ZomboidKnightsDan/releases/download/v$Version/knights-client.zip";
            sha256=(Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash;files=$files;localModIds=@($serverMods.LocalModIds)}
        $payload=[Text.Encoding]::UTF8.GetBytes(($manifest | ConvertTo-Json -Depth 8 -Compress))
        $sha=[Security.Cryptography.SHA256]::Create()
        try {$signature=$rsa.SignHash($sha.ComputeHash($payload),[Security.Cryptography.CryptoConfig]::MapNameToOID('SHA256'))}finally{$sha.Dispose()}
        $envelope=@{payload=[Convert]::ToBase64String($payload);signature=[Convert]::ToBase64String($signature)} | ConvertTo-Json
        # Public WebRequest.Content is parsed by already installed launchers:
        # Framework ConvertFrom-Json rejects a leading BOM. Explicitly omit it.
        [IO.File]::WriteAllText((Join-Path $releaseRoot 'stable.json'),$envelope,[Text.UTF8Encoding]::new($false))
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseRoot 'manifest-readable.json') -Encoding UTF8
        Write-Output ('Built signed release: '+$Version+'; '+$files.Count+' owned files.')
    } finally {
        $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
        if(![IO.Path]::GetFullPath($stage).StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe staging cleanup.'}
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
} finally {$rsa.Dispose()}
