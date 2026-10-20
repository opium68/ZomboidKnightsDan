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
foreach($file in 'KNIGHTS-SUPPLY-20261018.md','PATCH-PLAN.md','PATCH-NOTES-20261018.md','KNIGHTS-IMPLEMENTATION-20261005.md','KNIGHTS-MANHUNT-20261010.md','KNIGHTS-JG-CLOTHING-20261012.md','KNIGHTS-TTAJ-CLOTHING-20261012.md','KNIGHTS-CLOTHING-SETS.md','KNIGHTS-MARKET-20261014.md','KNIGHTS-INSULATION-VISION-20261014.md','KNIGHTS-CONTRACT-MONEY-20261012.md','KNIGHTS-DAILY-CONTRACTS-20261009.md'){
    Copy-Item -LiteralPath (Join-Path $root "docs/$file") -Destination (Join-Path $repository "docs/$file") -Force
}
New-Item -ItemType Directory -Path (Join-Path $repository 'scripts/tests') -Force | Out-Null
foreach($file in 'knights-supply.lua','knights-delivery-feedback.lua','knights-market.lua','knights-midnight-market.lua','knights-market-regression.lua','knights-request-preview.lua','knights-clothing-sets.lua','knights-clothing-insulation.lua','knights-clothing-combat-speed.lua','knights-clothing-movement.lua','knights-contract-money.lua','knights-coop.lua','knights-native-reader.lua','knights-manhunt.lua','knights-pzlinux-safety.lua','test-pzlinux-safety.ps1','knights-daily-contracts.lua','knights-daily-requests.lua','knights-daily-requests-ui.lua','knights-protect-chase.lua','knights-plumbing-admin.lua','knights-plumbing-fixture.lua','knights-contract-sync.lua','knights-contract-sync-native.lua','knights-contract-money-regression.lua','knights-money-load-order.lua','native-knights-loader.lua','KnightsPlumbingAdminTest.java','KnightsDisabledRecipeTest.java'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "tests/$file") -Destination (Join-Path $repository "scripts/tests/$file") -Force
}
foreach($file in 'knights-supply.json','knights-selected-mods.json','knights-clothing-combat-speed.json','knights-clothing-movement.json','knights-clothing-insulation.json','knights-reward-prices.json','knights-jg-clothing.json','knights-ttaj-clothing.json','knights-clothing-sets.json','knights-clothing-set-prices.json'){
    Copy-Item -LiteralPath (Join-Path $root "config/$file") -Destination (Join-Path $repository "config/$file") -Force
}
foreach($file in 'build-supply.mjs','build-clothing-movement.mjs','common.ps1','LuaTestRunner.java','build-player-package.ps1','build-reward-catalog.ps1','build-jg-clothing.ps1','build-clothing-sets.ps1','build-clothing-insulation.ps1','build-knights-release.ps1','publish-knights-release.ps1'){
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

General Buy Goods offers are fixed per character for each existing 24-world-hour restock period. Contents, quantities, price, vehicle and delivery location are saved on the server. Declining/reopening/reconnecting does not reroll; orders use the saved offer reference and expired offers are rejected. Contracts pay 5x the original money reward; unfinished 10x records migrate to 5x while previously credited balances and queued payouts are preserved.

Building-defense contract zombies pursue the nearest living registered participant until the contract completes/cancels, retargeting on death/disconnect. Server-assigned targets are followed by the owning client with bounded extra path requests. Normal zombies and spawn counts are unchanged; unloaded chunks and native pathfinding restrictions remain.

Cooperative contracts: invite nearby players from the right-click menu; invited players accept the invitation before the leader accepts a computer contract. Everyone must be online and nearby at acceptance. The roster is then fixed. Progress is shared and every registered character receives the full reward once; offline receipts are settled on the next bank synchronization. Accounts and vehicle purchases remain personal.

PZLinux stock trading is enabled and buys/sells through personal bank accounts. ATM menus, cash deposit/withdrawal and new ATM refill contracts are disabled. Computer wear, repair UI and world-age price inflation remain disabled. Automatic login animation, electricity, ID-card hacking, mail and reputation remain enabled. Existing bank balances, holdings and cash items are preserved; existing ATM refill jobs can be cancelled from the computer. Selected equipment and cars are supplied through purchases/rewards; natural loot and manufacturing are blocked. Maintenance, fuel, ammunition loading and repairs remain available. M60 uses ordinary 7.62x51mm; linked ammunition is converted and empty links are removed. Metro is retired without compensation. See docs/KNIGHTS-SUPPLY-20261018.md for bundles and ammunition restocks.

Initial prices are editable in `config/knights-reward-prices.json`. Server startup, source checks, cooperative logic and updater rollback are tested separately from two-player equipment, NVG and turret gameplay verification.

Successful surplus-item and Dark Web sales credit the personal bank account directly. Replayed sale receipts do not credit twice. Previously created payment parcels retain their existing mailbox redemption flow. Neat Crafting list and detail views tolerate unresolved recipe skill references without changing server crafting requirements; actual ammunition unpacking remains a client gameplay check.

The shared contract board refreshes at midnight in game time with 3-5 random offers. Unaccepted offers from the previous day expire; accepted jobs remain active. Each participant can have only one active job. Boot and all common PZLinux dialogue/typing, including contracts, login and purchases, run about five times faster while retaining their text and login animation. The multiplier is applied once; existing fast login and purchase dialogue do not become 25 times faster.

Ammunition unpacking/repacking and opening purchased meal or weapon cases are permitted. Manufacturing reward equipment and food remains restricted. Restart both server and game after updating to reload recipe conditions.

Admins can use Restore extended plumbing (admin) from the root right-click menu without debug mode. Confirmation sends LG Extended Plumbing's existing server-authorized cleanup command; it switches extended plumbing off server-wide and restores loaded fixtures first. Check the original result dialog for unloaded areas. Physical sinks, barrels and pipes are retained. Real overhead barrels and water shutoff can still prevent mains water. Unsupported enabled=false recipe properties have been replaced with valid level-99 requirements; 129 restricted recipes pass the native debug-mode parser. Multiplayer restoration and rendered UI remain in-game checks.

Selected water fixtures also offer admin inspection and stranded-connection cleanup. The server validates role, distance, floor, object index and sprite. Cleanup requires extended plumbing to be off and no external source to remain; it clears only the selected fixture's external flag and LGEP marker through native synchronization. It never changes the moved-fixture flag or creates water. Inspection reports room/no-water conditions, source, available fluid and water shutoff timing to distinguish vanilla mains eligibility from an orphaned connection. Actual fixture state and multiplayer gameplay remain separate checks.

Lifestyle: Hobbies is installed through Steam Workshop (3403870858). Large fluid containers can use the native drink action without the 3 L capacity restriction; sealed-container and fullness checks remain. Multiplayer musical performance and drink synchronization still require in-game verification.

The vanilla fishing panel uses the Korean bitmap font in Korean-language games to avoid question-mark substitutions in its SDF font. Panel and fish-tooltip text retain native translation and discovery rules; visual gameplay verification remains separate from automated checks.

When a backpack's Bedroll attachment slot disappears, automatic detachment now synchronizes the tool's attachment fields with the multiplayer server. The tool remains in the character inventory. Actual backpack pickup and rewearing still require multiplayer verification; native weight limits remain.

The cooperative manhunt guard no longer calls a private native resolver as a global function. Successful decapitation uses the original evidence-bag creation path while retaining participant checks. In-game evidence delivery remains separate from automated native-Lua regression tests.

Humvee door and hood parts disable automatic display of all colour alternatives during repair item synchronization. Existing part models and repair rules are preserved. Unsupported reflection diagnostics were removed. Native script merge and isolated boot checks are distinct from pending in-game repair and hood-visibility verification. Tactical weapon component reassembly is allowed; component manufacturing remains restricted. Random parcel theft is removed from both basic and darknet purchase delivery; mailbox checks, weight limits and the existing delivery queue remain.

Multiplayer Humvee armor protection and wear are computed and synchronized by the server. Repair and replacement reset the damage baseline; other vehicles and single-player retain their original armor handling. Behavioral tests pass; multiplayer collision verification and the separate headlight condition investigation remain pending. Humvee repair diagnostics compare client/server and installed-item conditions without changing repair results. PZLinux sound clips use one quarter of their original volume.

Contract money is multiplied by five, including mission modifiers and the per-kill completion bonus. Offers and notes show increased rewards. Uncompleted contracts migrate once; completed contracts and existing cooperative receipts are preserved. Solo/cooperative payout and daily-board regression tests pass. Shop prices and stock transactions are unchanged.

The reward wrapper preserves correct 5x amounts across early shared-file autoload and normal require order. Known unfinished underpaid records are corrected from their original mission parameters without crediting money or resetting progress; completed rewards and queued receipts are retained. Join and right-click also request a character-checked authoritative contract snapshot through a separate server command, restoring objective flags when the client has lost its active contract state. Requests are limited to one per 2 seconds per local player and do not run a periodic scan or start objectives automatically. Native-source tests pass; multiplayer UI and objective interaction remain in-game checks.

J&G Forest Multicam, Black Multicam, Trauma Responder, MARPAT and British DPM are installed. Other J&G outfit packs with unresolved recent reports are held. Militek, Japanese Traditional Outfit and Lynx are also installed. Clothing is sold as 25 complete set bags, including 5 J&G sets and 4 TTAJ sets; take the garments out of the delivered bag to wear them. All four Vanguard colours include the matching Vanguard night-vision full helmet at unchanged set prices. Already-created bag contents and owned helmets are not replaced. Movement penalties are removed from 229 modded garments; movement bonuses and vanilla clothing are preserved. Modded clothing insulation is capped at J&G-like values; defense, wind resistance and night vision are retained. Existing worn gear is updated on login/equipment changes without a periodic scan. Zombie Visibility Fix + Stair-O-Vision is enabled with original defaults; in-game stairs visibility and dense-crowd FPS still need checking. See docs/KNIGHTS-INSULATION-VISION-20261014.md. Individual garment offers are removed, existing paid orders are retained, and new J&G masks/backpacks are not sold. Natural spawning and manufacture remain restricted. The 42.21 engine created all 25 complete sets and verified 94 J&G crafting restrictions in an isolated server; multiplayer appearance and mailbox delivery still need in-game checks. The dark market draws 0-3 distinct offers per category for each 24-hour world-time period, including optional repair supplies and 0-3 ration types. Ordinary purchase chats display exact contents and merged quantities before payment. Ordinary-shop daily fixed lists remain pending. See docs/KNIGHTS-MARKET-20261014.md. See docs/KNIGHTS-JG-CLOTHING-20261012.md and docs/KNIGHTS-TTAJ-CLOTHING-20261012.md.
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
