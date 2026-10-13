[CmdletBinding()]
param([string]$StageRoot)
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if(!$StageRoot){
    $StageRoot=Join-Path $root 'research/jg-workshop-staging'
    if(!(Test-Path -LiteralPath $StageRoot)){$StageRoot='D:/PZDedicated'}
}
$selection=Get-Content (Join-Path $root 'config/knights-jg-clothing.json') -Raw | ConvertFrom-Json
$ttaj=Get-Content (Join-Path $root 'config/knights-ttaj-clothing.json') -Raw | ConvertFrom-Json
$allEntries=@($selection.selected)+@($ttaj.selected)
$families=@($selection.selected.family)+@($ttaj.selected.sets.family)
$setsConfig=Get-Content (Join-Path $root 'config/knights-clothing-sets.json') -Raw | ConvertFrom-Json
$oldSets=@($setsConfig.sets | Where-Object {$_.family -notin $families})
$items=@{}; $recipes=@{}; $modRecords=@(); $sets=@($oldSets)
$utf8=[Text.UTF8Encoding]::new($false)
$patch=Join-Path $root 'custom-mods/KnightsDanServerPatch/42/media'
foreach($entry in $allEntries){
    $source=if($entry.build){Join-Path $root 'research/ttaj-workshop-staging'}else{$StageRoot}
    if(!(Test-Path -LiteralPath $source)){$source=$StageRoot}
    $build=if($entry.build){$entry.build}else{'42.20'}
    $mod=Get-ChildItem -LiteralPath (Join-Path $source ('steamapps/workshop/content/108600/'+$entry.WorkshopId+'/mods')) -Directory | Select-Object -First 1
    $info=Get-Content -LiteralPath (Join-Path $mod.FullName ($build+'/mod.info'))
    $id=($info | Where-Object {$_ -match '^id='}) -replace '^id=',''
    if($id -cne $entry.ModId){throw 'Unexpected J&G Mod ID.'}
    $require=($info | Where-Object {$_ -match '^require='}) -replace '^require=',''
    if($entry.build -and $require -ne $entry.requires -or !$entry.build -and $require -ne '\KATTAJ1_ClothesCore'){throw 'Unexpected J&G dependency.'}
    $modRecords+=[ordered]@{WorkshopId=$entry.WorkshopId;ModId=$id;Version='';Requires=$require}
    $media=Join-Path $mod.FullName $(if($entry.build){$build+'/media'}else{'common/media'})
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $media 'scripts') -Recurse -File -Filter '*.txt'){
        $text=[IO.File]::ReadAllText($file.FullName)
        $module=[regex]::Match($text,'(?m)^\s*module\s+(\S+)').Groups[1].Value
        foreach($m in [regex]::Matches($text,'(?m)^\s*(item|craftRecipe|recipe)\s+(\S+)\s*\{')){
            $start=$text.IndexOf('{',$m.Index);$depth=1;$end=$start+1
            while($depth -gt 0 -and $end -lt $text.Length){if($text[$end] -eq '{'){$depth++}elseif($text[$end] -eq '}'){$depth--};$end++}
            $block=$text.Substring($start,$end-$start);$name=$m.Groups[2].Value
            if($m.Groups[1].Value -ne 'item'){$recipes[$module+'.'+$name]=$m.Groups[1].Value;continue}
            $fields=@{};foreach($f in [regex]::Matches($block,'(?m)^\s*(\w+)\s*=\s*([^,\r\n]+)')){$fields[$f.Groups[1].Value]=$f.Groups[2].Value.Trim()}
            $textures=@();$clothing=$fields.ClothingItem
            if($clothing){
                $xmlPath=Join-Path $media ('clothing/clothingItems/'+$clothing+'.xml')
                if(Test-Path -LiteralPath $xmlPath){
                    [xml]$xml=[IO.File]::ReadAllText($xmlPath)
                    $textures=@($xml.SelectNodes('//m_BaseTextures|//textureChoices') | ForEach-Object {$_.InnerText})
                }elseif(!$entry.build){throw "Missing clothing XML: $clothing"}
            }
            $items[$module+'.'+$name]=[ordered]@{id=$module+'.'+$name;quantity=1;mod=$id;originalName=$fields.DisplayName;bodyLocation=$fields.BodyLocation;weight=$fields.Weight;clothingItem=$clothing;textureChoices=$textures}
        }
    }
    if($entry.sets){
        foreach($definition in $entry.sets){
            $parts=@();$slots=@{}
            foreach($component in $definition.parts){
                $part=$items[$component]
                if(!$part -or !$part.bodyLocation -or $slots.ContainsKey($part.bodyLocation) -or !(Test-Path -LiteralPath (Join-Path $media ('clothing/clothingItems/'+$part.clothingItem+'.xml')))){throw "Invalid TTAJ set component: $component"}
                $slots[$part.bodyLocation]=$true;$parts+=$part
            }
            $sets+=[ordered]@{id=$definition.family;name=$definition.name;family=$definition.family;color='fixed';price=$definition.price;referencePrice=($definition.price/3);items=$parts}
        }
        continue
    }
    $prefix=$entry.prefix
    $names=if($prefix -eq 'Medical_Red'){@('Jacket','Pants','Gloves','TacBoots','Helmet_Patriot','BulletproofVest_Patriot','ShoulderPads_Patriot','ElbowPads','HeavyKneePads')}else{@('Jacket','Pants','Gloves','TacBoots','Helmet','Vest','ShoulderPads_Patriot','Elbow_Pads','KneePads_Defender')}
    $parts=@();$slots=@{}
    foreach($name in $names){
        $part=$items['Base.'+$prefix+'_'+$name]
        if(!$part){throw "Missing J&G set component: $prefix $name"}
        if(!$part.bodyLocation -or $slots.ContainsKey($part.bodyLocation)){throw "Invalid/duplicate slot: $($part.id)"}
        $slots[$part.bodyLocation]=$true;$parts+=$part
    }
    $sets+=[ordered]@{id=$entry.family;name=$entry.name;family=$entry.family;color=$prefix;price=$entry.price;referencePrice=67500;items=$parts}
}
$selectedPath=Join-Path $root 'config/knights-selected-mods.json'
$selected=@(Get-Content $selectedPath -Raw | ConvertFrom-Json | Where-Object {$_.ModId -notin $allEntries.ModId})+@($modRecords)
[IO.File]::WriteAllText($selectedPath,($selected | ConvertTo-Json -Depth 8),$utf8)
$lua=[Collections.Generic.List[string]]::new()
$lua.Add('require "KnightsDan/Catalog"')
$lua.Add('KnightsDan.clothingSets = {')
$script=[Collections.Generic.List[string]]::new();$script.Add('module KnightsDan {')
$translationRoot=Join-Path $patch 'lua/shared/Translate'
$ko=Get-Content (Join-Path $translationRoot 'KO/ItemName.json') -Raw | ConvertFrom-Json -AsHashtable
$en=Get-Content (Join-Path $translationRoot 'EN/ItemName.json') -Raw | ConvertFrom-Json -AsHashtable
foreach($set in $sets){
    $code='ClothingSet_'+($set.id -replace '[^A-Za-z0-9_]','_')
    $set | Add-Member -NotePropertyName packageId -NotePropertyValue ('KnightsDan.'+$code) -Force
    $lua.Add('    ["KnightsDan.'+$code+'"] = {price='+$set.price+', family="'+$set.family+'", items={')
    foreach($part in $set.items){$lua.Add('        "'+$part.id+'",')}
    $lua.Add('    }},')
    $script.Add('    item '+$code+' { ItemType = base:container, DisplayName = Clothing Set '+$set.id+', Icon = Bag_DuffelBag, Weight = 0.5, Capacity = 50, WeightReduction = 0, CanBeEquipped = Secondary, OnCreate = KnightsDan.createClothingSet, }')
    $ko['KnightsDan.'+$code]=$set.name
    $en['KnightsDan.'+$code]='Clothing Set ('+$set.id+')'
}
$lua.Add('}');$lua.Add('KnightsDan.jgItems = {')
foreach($id in ($items.Keys | Sort-Object)){$lua.Add('    ["'+$id+'"] = true,')}
$lua.Add('}');$lua.Add('KnightsDan.jgOutfits = {')
foreach($entry in $allEntries){foreach($outfit in @($entry.outfit)+@($entry.outfits)){if($outfit){$lua.Add('    ["'+$outfit+'"] = true,')}}}
$lua.Add('}');$lua.Add('KnightsDan.jgRecipes = {')
foreach($key in ($recipes.Keys | Sort-Object)){$name=($key -split '\.',2)[1];$lua.Add('    ["'+$name+'"] = true,')}
$lua.Add('}');$lua.Add('KnightsDan.individualClothingItems = {')
$rewardPrices=Get-Content (Join-Path $root 'config/knights-reward-prices.json') -Raw | ConvertFrom-Json
foreach($entry in $rewardPrices.items){
    if($entry.type -match 'Clothing' -and $entry.id -notmatch '(?i)holster|sheath|pouch|strap|mount|nightvision|gasmask|balaclava|mask|flashlight|lamp'){$lua.Add('    ["'+$entry.id+'"] = true,')}
}
$lua.Add('}')
$script.Add('}')
[IO.File]::WriteAllLines((Join-Path $patch 'lua/shared/KnightsDan/ClothingSets.lua'),$lua,$utf8)
[IO.File]::WriteAllLines((Join-Path $patch 'scripts/KnightsDanClothingSets.txt'),$script,$utf8)
foreach($language in @('KO','EN')){
    $table=if($language -eq 'KO'){$ko}else{$en}
    [IO.File]::WriteAllText((Join-Path $translationRoot ($language+'/ItemName.json')),($table | ConvertTo-Json -Depth 5),$utf8)
}
# The 42.21 native loader does not recognize an "enabled" recipe key.
# J&G manufacture is restricted by the existing server-side required-skill
# boot callback; do not create empty overlays or loader warnings here.
$setsConfig.sets=@($sets);$setsConfig.status='implemented-awaiting-validation';$setsConfig.note='세트 가방 전체 구성품 배송; 개별 의복 판매 제거. 가방 내부에서 꺼내 착용. 고정 텍스처 0 사용.'
[IO.File]::WriteAllText((Join-Path $root 'config/knights-clothing-sets.json'),($setsConfig | ConvertTo-Json -Depth 12),$utf8)
$pricesPath=Join-Path $root 'config/knights-clothing-set-prices.json'
$priceConfig=Get-Content $pricesPath -Raw | ConvertFrom-Json
$priceConfig.families=@($priceConfig.families | Where-Object {$_.id -notin $families})+@($sets | Where-Object {$_.family -in $families} | ForEach-Object {[ordered]@{id=$_.family;name=$_.name;price=$_.price;status='implemented'}})
$priceConfig.status='implemented-awaiting-validation'
[IO.File]::WriteAllText($pricesPath,($priceConfig | ConvertTo-Json -Depth 8),$utf8)
$doc=@('# 의류 세트 판매','','상태: 구현 완료, 자동 검사/격리 서버 검증 및 운영 적용 상태는 J&G 배포 기록 참조.','',
    'PZLinux 블랙마켓에서 세트 가방을 구매·수령하고 내부 구성품을 꺼내 착용한다. 세트당 모든 구성품을 동봉하며 텍스처 인덱스 0으로 고정한다. 기존 개별 의복은 새 판매 후보에서 제거하고 배낭·홀스터·칼집·야시경·램프·마스크 등 보조품은 유지한다. 이미 결제한 단품 주문은 삭제하지 않는다.','',
    '암시장은 게임 시간 24시간 단위로 상품군마다 0~3종 추첨한다. 의류 세트는 합계 0~3종이며 세트 하나가 상품 1종이다. 일반 구매의 당일 고정 목록은 아직 구현 전이다. 시장 변경 기록: KNIGHTS-MARKET-20261014.md.','',
    '가격은 사용자 지시대로 기존 제안의 3배이며 같은 상품군 색상은 동일하다. 새 위장복 세트는 블랙 멀티캠과 같은 $105,000, 트라우마 대응은 $270,000. 실제 구매가는 PZLinux의 기존 거래 기술·평판 계산을 따른다.','',
    '## 세트 목록','','| 세트 | 가격 | 구성품 수 |','|---|---:|---:|')
foreach($set in $sets){$doc+='| '+$set.name+' | $'+$set.price+' | '+@($set.items).Count+' |'}
$doc+=@('',('총 '+$sets.Count+'개 세트. 코드/착용 부위/텍스처 원본은 config/knights-clothing-sets.json. 선언 및 슬롯 중복을 검사했으며 실제 남녀 착용·외형·멀티 수령은 게임에서 확인해야 한다.'),'',
    'KATTAJ1 뱅가드에는 같은 색 디펜더 헬멧을 사용한다. 세베루스 키트는 세트당 한 종류다. 나노아머는 보이지 않는 보호 모델이다. J&G 마스크는 소진 필터 관련 보고를 고려해 세트 동봉 및 신규 판매에서 제외한다.')
[IO.File]::WriteAllLines((Join-Path $root 'docs/KNIGHTS-CLOTHING-SETS.md'),$doc,$utf8)
Write-Output "Built $($modRecords.Count) J&G/TTAJ mods, $($items.Count) items, $($recipes.Count) restricted recipes, $($sets.Count) clothing set packages."
