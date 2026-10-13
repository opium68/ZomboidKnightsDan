require "KnightsDan/Market"
require "PZLinux/PZLinuxDarkWeb"
local K=KnightsDan
local scripts={}
local function item(id,kind,category,ranged)
    scripts[id]={getItemType=function() return kind end,getDisplayCategory=function() return category end,isRanged=function() return ranged end}
end
PZLinuxDarkWebItemsTable={}
local function add(id,kind,category,ranged)
    item(id,kind,category,ranged)
    table.insert(PZLinuxDarkWebItemsTable,{id={id},Price=100})
end
for i=1,6 do
    add('bdtmre.bdtmre'..i,'Food','Food',false)
    add('Base.Gun'..i,'Weapon','Weapon',true)
    add('Base.Knife'..i,'Weapon','Weapon',false)
    add('Base.Ammo'..i,'Normal','Ammo',false)
end
add('GunRepairKit.GunRepairKit','Normal','Tool',false)
add('GunRepairKit.GunRepairKitAdvanced','Normal','Tool',false)
add('KnightsDan.ClothingSet_haori','Container','Clothing',false)
add('Missing.Item','Normal','Other',false);scripts['Missing.Item']=nil
table.insert(PZLinuxDarkWebItemsTable,PZLinuxDarkWebItemsTable[1])
function getScriptManager() return {FindItem=function(_,id) return scripts[id] end} end
function PZLinuxDarkWebGetFirstItemId(e) return e.id[1] end
function PZLinuxDarkWebGetItemIds(e) return e.id end
function PZLinuxDarkWebGetStockRange() return 2,4 end
local maximum=false
function ZombRand(a,b) return maximum and b-1 or a end
local market={generation=1}
K.generateCategoryMarket(market)
assert(#market.offers==0,'all categories must permit zero, including kits/rations')
maximum=true
K.generateCategoryMarket(market)
local counts,seen={},{}
for _,offer in ipairs(market.offers) do
    counts[offer.knightsCategory]=(counts[offer.knightsCategory] or 0)+1
    assert(not seen[offer.item.id[1]]);seen[offer.item.id[1]]=true
    assert(offer.stock==4 and offer.initialStock==4)
end
assert(counts.rations==3 and counts.repair==2 and counts.clothing==1)
for _,count in pairs(counts) do assert(count<=3) end
local bootMarket={generation=2,offers={}}
ModData={getOrCreate=function() return bootMarket end,transmit=function() end}
PZLinux={darkWebBuySessions={}}
function isClient() return false end
function PZLinuxDarkWebBuildBuyOffers()
    if #bootMarket.offers==0 then bootMarket.offers={{item={id={'Base.Gun1'}},stock=8}} end
    return {offers=bootMarket.offers}
end
require 'zzz_KnightsDanSupply'
local first=PZLinuxDarkWebBuildBuyOffers({})
first.offers[1].stock=0
local second=PZLinuxDarkWebBuildBuyOffers({})
assert(second.offers==first.offers and second.offers[1].stock==0,'reentry must preserve consumed stock')
maximum=false;bootMarket.generation=3
local empty=PZLinuxDarkWebBuildBuyOffers({})
assert(#empty.offers==0)
assert(#PZLinuxDarkWebBuildBuyOffers({}).offers==0,'all-zero day must not reroll')
return '0-3 per category, optional repair/rations, no duplicate offers, persistent stock and valid empty days'
