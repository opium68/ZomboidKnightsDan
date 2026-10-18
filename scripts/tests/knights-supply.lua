require "knights-coop"
require "KnightsDan/Supply"
require "KnightsDan/Retirement"
require "KnightsDan/Market"
local K=KnightsDan
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
local scripts={}
local function script(id)
 if not scripts[id] then
  local s={name=id,weight=0.01}
  function s:getDisplayName() return self.name end
  function s:setDisplayName(n) self.name=n end
  function s:getActualWeight() return self.weight end
  function s:setActualWeight(n) self.weight=n end
  function s:getAmmoType() return nil end
  function s:isRanged() return false end
  function s:getItemType() return 'Normal' end
  function s:getDisplayCategory() return 'Ammo' end
  scripts[id]=s
 end
 return scripts[id]
end
function getScriptManager() return {FindItem=function(_,id) return script(id) end} end
PZLinuxDarkWebItemsTable={{id={'Base.M60MMG'},Price=10000},{id={'Base.Aksu'},Price=35000}}
PZLinuxRequestDefinitions={}
K.installSupply()
local magazineCount=0;for _,d in pairs(K.supplyProducts) do if d.category=='magazines' then magazineCount=magazineCount+1 end end
for seed=1,50 do
 local rng=seed
 function ZombRand(a,b) if not b then b=a;a=0 end;rng=(rng*1103515245+12345)%2147483647;return a+(rng%(b-a)) end
 local m={generation=seed};K.generateCategoryMarket(m)
 local counts,seen={},{}
 for _,offer in ipairs(m.offers) do
  local id=offer.item.id[1];assert(not seen[id]);seen[id]=true
  assert(not K.retiredMetro[id]);assert(not K.weaponBundles[id],'no bare firearm offer')
  counts[offer.knightsCategory]=(counts[offer.knightsCategory] or 0)+1
  if offer.knightsCategory=='cartons' or offer.knightsCategory=='vehicle' or offer.knightsCategory=='vehicleHE' then assert(offer.stock>=1 and offer.stock<=5) end
 end
 assert(counts.cartons==5 and counts.magazines==magazineCount and counts.vehicle==1)
 assert((counts.vehicleHE or 0)<=1)
end
local function container()
 local c={items={}}
 function c:getItems() return list(self.items) end
 function c:Remove(item) for i=#self.items,1,-1 do if self.items[i]==item then table.remove(self.items,i);return end end end
 function c:AddItem(id)
  local item={kind='InventoryItem',id=id,md={}}
  function item:getFullType() return self.id end
  function item:getModData() return self.md end
  function item:setCurrentAmmoCount(n) self.ammo=n end
  function item:setRoundChambered(n) self.chamber=n end
  function item:setAmmoType(n) self.ammoType=n end
  self.items[#self.items+1]=item;return item
 end
 return c
end
local inv=container();local md={}
local pack={getFullType=function() return 'KnightsDan.WeaponBundle_Base_M60MMG' end,getModData=function() return md end,getInventory=function() return inv end,setActualWeight=function() end,setCustomWeight=function() end}
K.createWeaponBundle(pack);K.createWeaponBundle(pack)
local counts={};for _,item in ipairs(inv.items) do counts[item.id]=(counts[item.id] or 0)+1 end
assert(counts['Base.M60MMG']==1 and counts['Base.M60Belt']==4 and counts['Base.308Bullets']==400)
local old=container();for id in pairs(K.retiredMetro) do old:AddItem(id) end
old:AddItem('Base.308Bullets');old:AddItem('Base.308BulletsLinked');old:AddItem('Base.M60_Link');old:AddItem('Base.M60_Links_Box')
K.cleanContainer(old);K.cleanContainer(old)
assert(#old.items==2 and old.items[1].id=='Base.308Bullets' and old.items[2].id=='Base.308Bullets')
local clean,changed=K.cleanOrderItems({{name='Base.Aksu',quantity=1},{name='Base.308BulletsLinked',quantity=150},{name='Base.TunaTin',quantity=2}})
assert(changed and #clean==2 and clean[1].name=='Base.308Bullets' and clean[1].quantity==150 and clean[2].quantity==2)
local old3={reward=42000,knightsRewardMultiplier=3,knightsRewardFormulaVersion=2,contractId=8,locationZ=0}
K.scaleContractReward(old3);K.scaleContractReward(old3);assert(old3.reward==70000 and old3.knightsRewardMultiplier==5)
local parked=container();parked:AddItem('Base.Aksu');parked:AddItem('Base.TunaTin')
local vehicle={kind='BaseVehicle',getPartCount=function() return 1 end,getPartByIndex=function() return {getItemContainer=function() return parked end} end}
local cleanupTick
Events.EveryOneMinute.Add=function(fn) cleanupTick=fn end
K.players=function() end
function getCell() return {getVehicles=function() return {iterator=function()
 local visited=false;return {hasNext=function() return not visited end,next=function() visited=true;return vehicle end}
end} end} end
require 'zzzzzzzzz_KnightsDanRetirement'
assert(cleanupTick);cleanupTick();cleanupTick()
assert(#parked.items==1 and parked.items[1].id=='Base.TunaTin','42.21 Set iterator cleans parked vehicles without touching common items')
return '50 restocks: exactly five distinct calibers, 1-5 cartons/packs, every magazine; M60 bundle 4/400, idempotent 58-ID retirement and linked conversion, 3x to 5x'
