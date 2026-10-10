[CmdletBinding()]
param([Parameter(Mandatory)][string]$Version,[ValidateSet('Prepare','Activate')][string]$Mode='Prepare')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$releaseRoot=Join-Path $root "packages/releases/$Version"
if(!(Test-Path -LiteralPath (Join-Path $releaseRoot 'stable.json'))){throw 'Build and verify a signed release first.'}
$credentialLines="protocol=https`nhost=github.com`nusername=opium68`n`n" | git credential fill
if($LASTEXITCODE -ne 0){throw 'GitHub credentials are unavailable.'}
$credentials=@{}
foreach($line in $credentialLines){if($line -match '^([^=]+)=(.*)$'){$credentials[$Matches[1]]=$Matches[2]}}
if(!$credentials.ContainsKey('password')){throw 'GitHub login has no credential.'}
$headers=@{Authorization='Bearer '+$credentials.password;Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28'}
$api='https://api.github.com/repos/opium68/ZomboidKnightsDan'
$user=Invoke-RestMethod -Uri 'https://api.github.com/user' -Headers $headers
if($user.login -ne 'opium68'){throw 'Publication must use the repository owner account.'}
$repository=Join-Path $root 'release-repository'
New-Item -ItemType Directory -Path $repository -Force | Out-Null
if(!(Test-Path -LiteralPath (Join-Path $repository '.git'))){
    & git -C $repository init -b main
    if($LASTEXITCODE){throw 'Publication repository initialization failed.'}
    & git -C $repository remote add origin 'https://opium68@github.com/opium68/ZomboidKnightsDan.git'
    & git -C $repository config user.name 'opium68'
    & git -C $repository config user.email '19261820+opium68@users.noreply.github.com'
}
& git -C $repository rev-parse --verify HEAD 2>$null | Out-Null
if($LASTEXITCODE -ne 0){
    [IO.File]::WriteAllText((Join-Path $repository 'README.md'),"# Zomboid Knights Dan`n`nServer patches and automatic launcher deployment are being prepared.`n",[Text.UTF8Encoding]::new($false))
    & git -C $repository add README.md
    & git -C $repository commit -m 'Initialize Knights Dan deployment repository'
    if($LASTEXITCODE){throw 'Initial commit failed.'}
    & git -C $repository push -u origin main
    if($LASTEXITCODE){throw 'Initial repository push failed.'}
}
$releases=@(Invoke-RestMethod -Uri ($api+'/releases') -Headers $headers)
$release=$releases | Where-Object {$_.tag_name -eq "v$Version"} | Select-Object -First 1
if($Mode -eq 'Prepare'){
    if(!$release){
        $body=@{tag_name="v$Version";name="Knights Dan $Version";draft=$true;prerelease=$false;
            body='Knights Dan server patch and automatic launcher. Workshop originals are installed through Steam; only server-owned patches and launcher files are distributed here. Initial setup: download KnightsDan-Launcher.zip, extract it and run JOIN-SERVER.cmd. Existing saves are retained. Two-player gameplay checks remain separate from headless and automated tests.'} | ConvertTo-Json
        $release=Invoke-RestMethod -Method Post -Uri ($api+'/releases') -Headers $headers -Body $body -ContentType 'application/json'
    }
    if(!$release.draft){throw 'Published releases are immutable. Use a new version.'}
    foreach($name in 'knights-client.zip','KnightsDan-Launcher.zip','stable.json'){
        if(@($release.assets | Where-Object {$_.name -eq $name}).Count){continue}
        $asset=Invoke-RestMethod -Method Post -Uri ("https://uploads.github.com/repos/opium68/ZomboidKnightsDan/releases/$($release.id)/assets?name=$name") -Headers $headers -InFile (Join-Path $releaseRoot $name) -ContentType 'application/octet-stream'
        Write-Output ('Uploaded draft asset: '+$asset.name)
    }
    Write-Output ('Prepared draft release v'+$Version)
    exit 0
}
if(!$release){throw 'Prepare the draft release before activation.'}
$repository=Join-Path $root 'release-repository'
New-Item -ItemType Directory -Path $repository -Force | Out-Null
if(!(Test-Path -LiteralPath (Join-Path $repository '.git'))){
    & git -C $repository init -b main
    if($LASTEXITCODE){throw 'Publication repository initialization failed.'}
    & git -C $repository remote add origin 'https://opium68@github.com/opium68/ZomboidKnightsDan.git'
    & git -C $repository config user.name 'opium68'
    & git -C $repository config user.email '19261820+opium68@users.noreply.github.com'
}
foreach($folder in 'custom-mods','player-launcher'){
    $target=Join-Path $repository $folder
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    & robocopy.exe (Join-Path $root $folder) $target /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP /XF player-settings.json release-state.json update-transaction.json | Out-Null
    if($LASTEXITCODE -gt 7){throw 'Publication source copy failed.'}
}
New-Item -ItemType Directory -Path (Join-Path $repository 'config'),(Join-Path $repository 'scripts'),(Join-Path $repository 'docs/distribution'),(Join-Path $repository 'distribution') -Force | Out-Null
foreach($file in 'knights-selected-mods.json','knights-reward-prices.json'){
    Copy-Item -LiteralPath (Join-Path $root "config/$file") -Destination (Join-Path $repository "config/$file") -Force
}
foreach($file in 'common.ps1','build-player-package.ps1','build-reward-catalog.ps1','build-knights-release.ps1','publish-knights-release.ps1'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $repository "scripts/$file") -Force
}
New-Item -ItemType Directory -Path (Join-Path $repository 'config/escape_test') -Force | Out-Null
$publicIni=@(Get-Content -LiteralPath (Join-Path $root 'config/escape_test/escape_test.ini') | Where-Object {$_ -match '^(Mods|WorkshopItems|DoLuaChecksum)='}) -join "`n"
[IO.File]::WriteAllText((Join-Path $repository 'config/escape_test/escape_test.ini'),$publicIni,[Text.UTF8Encoding]::new($false))
$readme=@'
# Zomboid Knights Dan

Project Zomboid 42.21 server patches and automatic client launcher.

Download [KnightsDan-Launcher.zip](https://github.com/opium68/ZomboidKnightsDan/releases/latest/download/KnightsDan-Launcher.zip), extract it and run `JOIN-SERVER.cmd`. Subsequent runs obtain the server's signed release, verify SHA-256, install the owned patches together and then launch the game. The server password is supplied separately.

Original mods remain on Steam Workshop. This repository contains only our own patches, launcher files and configuration references. It contains no save, database, server password or signing credential.

Cooperative contracts: invite nearby players from the right-click menu; invited players accept the invitation before the leader accepts a computer contract. Everyone must be online and nearby at acceptance. The roster is then fixed. Progress is shared and every registered character receives the full reward once; offline receipts are settled on the next bank synchronization. Accounts and vehicle purchases remain personal.

PZLinux stock trading is enabled and buys/sells through personal bank accounts. ATM menus, cash deposit/withdrawal and new ATM refill contracts are disabled. Computer wear, repair UI and world-age price inflation remain disabled. Automatic login animation, electricity, ID-card hacking, mail and reputation remain enabled. Existing bank balances, holdings and cash items are preserved; existing ATM refill jobs can be cancelled from the computer. Selected equipment and cars are supplied through purchases/rewards; natural loot and manufacturing are blocked. Maintenance, fuel, ammunition loading and repairs remain available. M60 linking has a separate 100-round recipe.

Initial prices are editable in `config/knights-reward-prices.json`. Server startup, source checks, cooperative logic and updater rollback are tested separately from two-player equipment, NVG and turret gameplay verification.

Successful surplus-item and Dark Web sales credit the personal bank account directly. Replayed sale receipts do not credit twice. Previously created payment parcels retain their existing mailbox redemption flow. Neat Crafting list and detail views tolerate unresolved recipe skill references without changing server crafting requirements; actual ammunition unpacking remains a client gameplay check.

The shared contract board refreshes at midnight in game time with 3-5 random offers. Unaccepted offers from the previous day expire; accepted jobs remain active. Each participant can have only one active job. Boot, automatic login and general item-purchase dialogue run about five times faster while retaining their text and login animation.

Ammunition unpacking/repacking and opening purchased meal or weapon cases are permitted. Manufacturing reward equipment and food remains restricted. Restart both server and game after updating to reload recipe conditions.

Lifestyle: Hobbies is installed through Steam Workshop (3403870858). Large fluid containers can use the native drink action without the 3 L capacity restriction; sealed-container and fullness checks remain. Multiplayer musical performance and drink synchronization still require in-game verification.

The vanilla fishing panel uses the Korean bitmap font in Korean-language games to avoid question-mark substitutions in its SDF font. Panel and fish-tooltip text retain native translation and discovery rules; visual gameplay verification remains separate from automated checks.

When a backpack's Bedroll attachment slot disappears, automatic detachment now synchronizes the tool's attachment fields with the multiplayer server. The tool remains in the character inventory. Actual backpack pickup and rewearing still require multiplayer verification; native weight limits remain.
'@
[IO.File]::WriteAllText((Join-Path $repository 'README.md'),$readme,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $repository '.gitignore'),"config/*.secret.*`nconfig/release-private.xml`npackages/`nresearch/`nplayer-launcher/player-settings.json`nplayer-launcher/release-state.json`nplayer-launcher/.knights-update-backups/`n",[Text.UTF8Encoding]::new($false))
$html='<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Knights Dan</title><body><h1>Knights Dan 접속 런처</h1><p><a href="https://github.com/opium68/ZomboidKnightsDan/releases/latest/download/KnightsDan-Launcher.zip">런처 ZIP 다운로드</a></p><p>압축을 풀고 JOIN-SERVER.cmd를 실행하세요. 이후 패치는 자동으로 받습니다. 서버 비밀번호는 별도로 안내합니다.</p></body></html>'
[IO.File]::WriteAllText((Join-Path $repository 'docs/index.html'),$html,[Text.UTF8Encoding]::new($false))
& git -C $repository add README.md .gitignore custom-mods player-launcher config scripts docs distribution
if($LASTEXITCODE){throw 'Publication staging failed.'}
& git -C $repository diff --cached --quiet
if($LASTEXITCODE -eq 1){& git -C $repository commit -m "Release Knights Dan $Version";if($LASTEXITCODE){throw 'Publication commit failed.'}}
& git -C $repository push -u origin main
if($LASTEXITCODE){throw 'GitHub publication push failed.'}
$commit=(& git -C $repository rev-parse HEAD).Trim()
if($release.draft){$null=Invoke-RestMethod -Method Patch -Uri ($api+'/releases/'+$release.id) -Headers $headers -Body (@{draft=$false;target_commitish=$commit}|ConvertTo-Json) -ContentType 'application/json'}
Copy-Item -LiteralPath (Join-Path $releaseRoot 'stable.json') -Destination (Join-Path $repository 'distribution/stable.json') -Force
Copy-Item -LiteralPath (Join-Path $releaseRoot 'stable.json') -Destination (Join-Path $repository 'docs/distribution/stable.json') -Force
& git -C $repository add distribution/stable.json docs/distribution/stable.json
& git -C $repository diff --cached --quiet
if($LASTEXITCODE -eq 1){& git -C $repository commit -m "Activate server deployment $Version";if($LASTEXITCODE){throw 'Deployment manifest commit failed.'}}
& git -C $repository push origin main
if($LASTEXITCODE){throw 'Deployment manifest publication failed.'}
try {
    $null=Invoke-RestMethod -Uri ($api+'/pages') -Headers $headers
}catch{
    if($_.Exception.Response.StatusCode -eq 404){
        $null=Invoke-RestMethod -Method Post -Uri ($api+'/pages') -Headers $headers -Body (@{source=@{branch='main';path='/docs'}}|ConvertTo-Json -Depth 4) -ContentType 'application/json'
    }else{throw}
}
Write-Output ('Activated signed deployment '+$Version)
Write-Output 'Launcher: https://github.com/opium68/ZomboidKnightsDan/releases/latest/download/KnightsDan-Launcher.zip'
Write-Output 'Manifest: https://raw.githubusercontent.com/opium68/ZomboidKnightsDan/main/distribution/stable.json'
