assert(loadfile('scripts/tests/native-knights-loader.lua'))()
local callbacks={}
Events=setmetatable({}, {__index=function(t,name)
    local event={Add=function(fn) callbacks[name]=fn end}; rawset(t,name,event); return event
end})
require 'KnightsDan/ClothingCombatSpeedIds'
local scripts={}; local penaltyId; local bonusId
for id,value in pairs(KnightsDan.modClothingCombatSpeed) do
    scripts[id]={value=value,DoParam=function(self,param)
        assert(param=='CombatSpeedModifier = 1'); self.value=1
    end}
    if value<1 then penaltyId=id end
    if value>1 then bonusId=id end
end
function getScriptManager() return {FindItem=function(_,id)return scripts[id]end} end
function instanceof(item,kind)return item.kind==kind end
require 'zzzz_KnightsDanClothingCombatSpeed'
callbacks.OnGameBoot()
for id,value in pairs(KnightsDan.modClothingCombatSpeed) do assert(scripts[id].value==math.max(value,1),id) end
local function clothing(id,value)
    return {kind='Clothing',value=value,defense=100,weight=2,insulation=.2,
        getFullType=function()return id end,
        getCombatSpeedModifier=function(self)return self.value end,
        setCombatSpeedModifier=function(self,v)self.value=v end}
end
local owned=clothing(penaltyId,.8)
local vanilla=clothing('Base.Hat_Army',.7)
local bonus=clothing(penaltyId,1.2)
local function list(items) return {size=function()return #items end,get=function(_,i)return items[i+1]end}end
local nested={getItems=function()return list({owned,vanilla,bonus})end}
local bag={kind='InventoryContainer',getInventory=function()return nested end}
local player={getWornItems=function()return list({{getItem=function()return owned end}})end,
    getInventory=function()return {getItems=function()return list({bag})end}end}
callbacks.OnCreatePlayer(0,player)
assert(owned.value==1 and vanilla.value==.7 and bonus.value==1.2)
owned.value=.6; callbacks.OnClothingUpdated(player); assert(owned.value==1)
assert(owned.defense==100 and owned.weight==2 and owned.insulation==.2)
assert(not callbacks.OnTick and not callbacks.EveryOneMinute)
return 'script penalties, owned/nested/worn clothing, vanilla and bonuses preserved; no periodic scan'
