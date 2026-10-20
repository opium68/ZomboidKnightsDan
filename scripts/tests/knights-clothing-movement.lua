local callbacks={}
Events=setmetatable({}, {__index=function(t,name) local e={Add=function(fn) callbacks[name]=fn end};rawset(t,name,e);return e end})
require 'KnightsDan/ClothingMovementIds'
local K=KnightsDan;local scripts={};local penaltyId,bonusId,neutralId
for id,value in pairs(K.modClothingMovement) do
 scripts[id]={value=value,DoParam=function(self,param) assert(param=='RunSpeedModifier = 1');self.value=1 end}
 if value<1 then penaltyId=id elseif value>1 then bonusId=id else neutralId=id end
end
assert(penaltyId and bonusId and neutralId)
function getScriptManager() return {FindItem=function(_,id) return scripts[id] end} end
function instanceof(item,kind) return item.kind==kind end
require 'zzzz_KnightsDanClothingMovement'
callbacks.OnGameBoot();callbacks.OnGameBoot()
for id,value in pairs(K.modClothingMovement) do assert(scripts[id].value==math.max(value,1),id) end
local function clothing(id,value)
 return {kind='Clothing',value=value,defense=100,weight=2,insulation=.2,combat=1.2,
 getFullType=function()return id end,getRunSpeedModifier=function(self)return self.value end,setRunSpeedModifier=function(self,v)self.value=v end}
end
local owned=clothing(penaltyId,.8);local vanilla=clothing('Base.Hat_Army',.7)
local bonus=clothing(bonusId,1.25);local modifiedBonus=clothing(penaltyId,1.1);local neutral=clothing(neutralId,.9)
local function list(t) return {size=function() return #t end,get=function(_,i)return t[i+1]end} end
local nested={getItems=function()return list({owned,vanilla,bonus,modifiedBonus,neutral})end}
local bag={kind='InventoryContainer',getInventory=function()return nested end}
local p={getWornItems=function() return list({{getItem=function()return owned end}})end,getInventory=function()return {getItems=function()return list({bag})end}end}
callbacks.OnCreatePlayer(0,p);callbacks.OnCreatePlayer(0,p)
assert(owned.value==1 and neutral.value==1 and vanilla.value==.7 and bonus.value==1.25 and modifiedBonus.value==1.1)
owned.value=.6;callbacks.OnClothingUpdated(p);assert(owned.value==1)
assert(owned.defense==100 and owned.weight==2 and owned.insulation==.2 and owned.combat==1.2)
callbacks.OnClothingUpdated(nil);callbacks.OnCreatePlayer(0,nil)
assert(not callbacks.OnTick and not callbacks.OnPlayerUpdate and not callbacks.EveryOneMinute)
return 'all script penalties normalized; new, existing, nested and worn clothing; bonuses/vanilla/other stats preserved; idempotent, no periodic scan'
