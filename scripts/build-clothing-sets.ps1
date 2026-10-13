[CmdletBinding()]
param([string]$WorkshopRoot='D:/PZDedicated/steamapps/workshop/content/108600')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$sources=@(
    @{mod='KATTAJ1_Military';path='3470426196/mods/KATTAJ1 Military Pack/42.15'},
    @{mod='CerberusPack';path='3470478700/mods/Cerberus Pack/42.15'},
    @{mod='[MT] Nano Armor - Easy';path='3474774172/mods/[MT] Nano Armor - Easy/42'}
)
$items=@{}
foreach($source in $sources) {
    $build=Join-Path $WorkshopRoot $source.path
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $build 'media/scripts') -Recurse -File -Filter '*.txt') {
        $text=[IO.File]::ReadAllText($file.FullName)
        $module=[regex]::Match($text,'(?m)^\s*module\s+(\S+)').Groups[1].Value
        foreach($m in [regex]::Matches($text,'(?m)^\s*item\s+(\S+)\s*\{')) {
            $start=$text.IndexOf('{',$m.Index); $depth=1; $end=$start+1
            while($depth -gt 0 -and $end -lt $text.Length) {
                if($text[$end] -eq '{') {$depth++} elseif($text[$end] -eq '}') {$depth--}; $end++
            }
            $block=$text.Substring($start,$end-$start)
            $fields=@{}
            foreach($field in [regex]::Matches($block,'(?m)^\s*(\w+)\s*=\s*([^,\r\n]+)')) {$fields[$field.Groups[1].Value]=$field.Groups[2].Value.Trim()}
            $id=$module+'.'+$m.Groups[1].Value
            $textures=@()
            if($fields.ClothingItem) {
                $xmlPath=Join-Path $build ('media/clothing/clothingItems/'+$fields.ClothingItem+'.xml')
                if(Test-Path -LiteralPath $xmlPath) {
                    [xml]$xml=[IO.File]::ReadAllText($xmlPath)
                    $textures=@($xml.SelectNodes('//m_BaseTextures|//textureChoices') | ForEach-Object {$_.InnerText})
                }
            }
            $items[$id]=[ordered]@{id=$id;quantity=1;mod=$source.mod;originalName=$fields.DisplayName;bodyLocation=$fields.BodyLocation;weight=$fields.Weight;clothingItem=$fields.ClothingItem;textureChoices=$textures}
        }
    }
}
$prices=@{}
$priceConfig=Get-Content -LiteralPath (Join-Path $root 'config/knights-reward-prices.json') -Raw | ConvertFrom-Json
foreach($entry in $priceConfig.items) {$prices[$entry.id]=$entry.price}
$sets=[Collections.Generic.List[object]]::new()
$setPriceConfig=Get-Content -LiteralPath (Join-Path $root 'config/knights-clothing-set-prices.json') -Raw | ConvertFrom-Json
$familyPrices=@{}
foreach($entry in $setPriceConfig.families) {$familyPrices[$entry.id]=$entry.price}
function Add-Set($id,$name,$family,$color,$ids) {
    $parts=@(); $locations=@{}; $sum=0
    foreach($itemId in $ids) {
        if(!$items.ContainsKey($itemId)) {throw "Missing installed item: $itemId"}
        if(!$prices.ContainsKey($itemId)) {throw "Missing catalog price: $itemId"}
        $item=$items[$itemId]
        if(!$item.bodyLocation) {throw "Missing clothing body location: $itemId"}
        if($locations.ContainsKey($item.bodyLocation)) {throw "Duplicate slot in ${id}: $($item.bodyLocation)"}
        $locations[$item.bodyLocation]=$true
        $parts+=$item; $sum+=$prices[$itemId]
    }
    if(!$familyPrices.ContainsKey($family)) {throw "Missing family price: $family"}
    $sets.Add([ordered]@{id=$id;name=$name;family=$family;color=$color;price=$familyPrices[$family];referencePrice=$sum;items=$parts})
}
$colors=[ordered]@{Black='검정';Green='녹색';Desert='사막색';White='흰색'}
foreach($color in $colors.Keys) {
    $basic=@('Military_Shirt_Classic','Military_Pants_Cargo','Military_Gloves_Grips','Military_Shoes_TacticalBoots') | ForEach-Object {'Base.'+$_+'-'+$color}
    Add-Set ('patriot-'+$color.ToLower()) ('패트리어트 경량 전술 세트 ('+$colors[$color]+')') 'patriot' $color ($basic+@(('Base.Military_Helmet_Patriot-'+$color),('Base.Military_BulletproofVest_Patriot_Light-'+$color)))
    $armor=@('ArmsProtectionUpper','ArmsProtectionLower','LegsProtectionUpper','LegsProtectionLower')
    $medium=@($armor | ForEach-Object {'Base.Military_'+$_+'_Defender_Medium-'+$color})
    Add-Set ('defender-'+$color.ToLower()) ('디펜더 중형 전술 세트 ('+$colors[$color]+')') 'defender' $color ($basic+@(('Base.Military_Helmet_Defender-'+$color),('Base.Military_BulletproofVest_Defender_Medium-'+$color))+$medium)
    $heavy=@($armor | ForEach-Object {'Base.Military_'+$_+'_Vanguard_Heavy-'+$color})
    Add-Set ('vanguard-'+$color.ToLower()) ('뱅가드 중장갑 전술 세트 ('+$colors[$color]+')') 'vanguard' $color ($basic+@(('Base.Military_FullHelmet_Vanguard-'+$color),('Base.Military_BulletproofVest_Vanguard_Heavy-'+$color))+$heavy)
}
$cerberus=@('Base.Shirt_Cerberus','Base.Pants_Classic_Cerberus','Base.Gloves_Cerberus','Base.Shoes_TacticalBoots_Cerberus','Base.Helmet_Cerberus')
Add-Set 'cerberus-light' '세베루스 경량 돌격 세트' 'cerberus-light' 'Cerberus' ($cerberus+@('Base.BulletproofVest_Cerberus_AssaultLightKit'))
Add-Set 'cerberus-assault' '세베루스 돌격 세트' 'cerberus-assault' 'Cerberus' ($cerberus+@('Base.BulletproofVest_Cerberus_AssaultKit'))
Add-Set 'cerberus-full' '세베루스 전신 보호 세트' 'cerberus-full' 'Cerberus' ($cerberus+@('Base.BulletproofVest_Cerberus_FullProtectionKit'))
Add-Set 'nano-standard' '나노아머 기본 세트' 'nano' 'Invisible' @('Base.MT_Nano_Helmet','Base.MT_Nano_Top','Base.MT_Nano_Bot','Base.MT_Nano_Gloves','Base.MT_Nano_Shoes')
$result=[ordered]@{
    schemaVersion=1
    status='assembled-pending-shop-integration'
    note='현재 설치 파일로 조립한 판매 구성안. 운영 카탈로그는 아직 변경하지 않음. price는 제안 기본가의 3배로 지정한 세트 기본가, referencePrice는 기존 개별 기준가 합계.'
    selectionPolicy='암시장 의류 세트 상품군에서 게임 시간 24시간 단위로 0~3종 추첨. 세트별 색상과 구성은 고정.'
    verification='설치 아이템 선언·가격·착용 부위 중복 검사 완료. 코어 배타 슬롯 검토. 게임 내 외형/남녀 착용 및 배송 검증은 미완료.'
    notes=@('뱅가드 세트는 같은 색 뱅가드 야간투시 풀헬멧을 포함.','Cerberus 방탄복 키트는 서로 배타적이므로 세트당 한 종류만 포함. 별도 기본 방탄복 중복 제공 안 함.','배낭·홀스터·칼집·램프는 별도 상품으로 유지. 뱅가드 야간투시 풀헬멧은 뱅가드 세트에 포함.','일부 옷은 같은 아이템 코드 안에 무늬/단색 텍스처가 여러 개 있으므로 판매 연동 시 텍스처 고정 필요.','나노아머는 blank 모델/텍스처를 사용하는 보이지 않는 보호 장비. H/FH 변형은 동봉하지 않음.')
    sets=@($sets.ToArray())
}
$jsonPath=Join-Path $root 'config/knights-clothing-sets.json'
[IO.File]::WriteAllText($jsonPath,($result | ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))
$doc=[Collections.Generic.List[string]]::new()
$doc.Add('# 현재 모드 의류 세트 구성')
$doc.Add('')
$doc.Add('상태: 세트 구성 완료, 블랙마켓 판매 연동·운영 적용은 미완료. 새 의류 모드는 추가하지 않았다.')
$doc.Add('')
$doc.Add('구성 원본은 `config/knights-clothing-sets.json`. `scripts/build-clothing-sets.ps1`이 설치된 Workshop 파일에서 구성품 정보와 텍스처 목록을 읽고 현재 개별 기준가를 합산한다.')
$doc.Add('')
$doc.Add('## 상품군')
$doc.Add('')
$doc.Add('| 상품군 | 구성 | 색상/변형 |')
$doc.Add('|---|---|---|')
$doc.Add('| 패트리어트 경량 | 셔츠·카고바지·장갑·전술화·패트리어트 헬멧·경량 방탄복, 6종 | 검정·녹색·사막색·흰색 |')
$doc.Add('| 디펜더 중형 | 셔츠·카고바지·장갑·전술화·디펜더 헬멧·중형 방탄복·상완/전완/허벅지/정강이 보호대, 10종 | 검정·녹색·사막색·흰색 |')
$doc.Add('| 뱅가드 중장갑 | 같은 색 기본 의류·뱅가드 야간투시 풀헬멧·뱅가드 중장갑 방탄복·4부위 중장갑 보호대, 10종 | 검정·녹색·사막색·흰색 |')
$doc.Add('| 세베루스 경량 돌격 | 셔츠·바지·장갑·전술화·헬멧·AssaultLightKit, 6종 | 모드 기본 텍스처 |')
$doc.Add('| 세베루스 돌격 | 같은 기본 의류·AssaultKit, 6종 | 모드 기본 텍스처 |')
$doc.Add('| 세베루스 전신 보호 | 같은 기본 의류·FullProtectionKit, 6종 | 모드 기본 텍스처 |')
$doc.Add('| 나노아머 기본 | 헬멧·상의·하의·장갑·신발, 5종 | 보이지 않는 보호 장비 |')
$doc.Add('')
$doc.Add('## 검증과 남은 작업')
$doc.Add('')
$doc.Add('7개 상품군, 색상을 포함한 16개 세트. 모든 구성품이 실제 설치 파일 및 현재 가격 카탈로그에 존재하며 각 세트 안에 동일 착용 슬롯은 없다. Cerberus의 일체형 방탄복은 코어 배타 설정에 따라 한 종류만 넣었다. 무늬/단색 선택과 겹침은 게임 내 착용으로 추가 확인해야 한다.')
$doc.Add('')
foreach($note in $result.notes) {$doc.Add('- '+$note)}
$doc.Add('')
$doc.Add('추후 판매 구현에서는 구성품 전체 배송, 서버 구매 검증, 기존 단품 의류 제거, 의류 상품군 추첨 제한, 당일 목록 고정이 필요하다. 현재 운영 카탈로그의 단품 판매 동작은 아직 그대로다.')
$doc.Add('')
$doc.Add('## 세트 기본 가격')
$doc.Add('')
$doc.Add('2026-10-12 사용자 지시에 따라 제안 가격을 3배로 설정했다. 색상별 가격은 동일. 가격 원본은 `config/knights-clothing-set-prices.json`. Black Multicam과 Trauma Responder는 추가 예정이며 구성품 감사 전이다. 운영 적용은 미완료.')
$doc.Add('')
$doc.Add('| 상품군 | 기본 가격 |')
$doc.Add('|---|---:|')
foreach($entry in $setPriceConfig.families) {$doc.Add('| '+$entry.name+' | $'+$entry.price+' |')}
$doc.Add('')
$doc.Add('## 세트별 아이템 코드 및 기준가')
foreach($set in $sets) {
    $doc.Add(''); $doc.Add('### '+$set.name); $doc.Add(''); $doc.Add('세트 기본가: $'+$set.price+' / 참고용 개별 기준가 합계: $'+$set.referencePrice); $doc.Add('')
    foreach($part in $set.items) {$doc.Add('- `'+$part.id+'` — `'+$part.bodyLocation+'`')}
}
[IO.File]::WriteAllLines((Join-Path $root 'docs/KNIGHTS-CLOTHING-SETS.md'),$doc,[Text.UTF8Encoding]::new($false))
Write-Output ('Validated {0} sets in {1} families against installed declarations and prices.' -f $sets.Count,(@($sets | ForEach-Object {$_.family} | Sort-Object -Unique).Count))
if(Test-Path (Join-Path $root 'config/knights-jg-clothing.json')){& (Join-Path $PSScriptRoot 'build-jg-clothing.ps1')}
