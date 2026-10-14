local callbacks={}
Events=setmetatable({}, {__index=function(t,name)
 local event={Add=function(f) callbacks[name]=callbacks[name] or {};table.insert(callbacks[name],f) end};rawset(t,name,event);return event
end})
local scripts={}
require 'KnightsDan/InsulationCaps'
for id,cap in pairs(KnightsDan.clothingInsulationCaps) do
 scripts[id]={value=1,wind=.9,defense=100,getInsulation=function(self) return self.value end,setInsulation=function(self,value) self.value=value end}
end
function getScriptManager() return {FindItem=function(_,id) return scripts[id] end} end
function instanceof(item,kind) return item and item.kind==kind end
require 'zzzz_KnightsDanClothingInsulation'
callbacks.OnGameBoot[1]()
for id,cap in pairs(KnightsDan.clothingInsulationCaps) do assert(scripts[id].value==cap and scripts[id].wind==.9 and scripts[id].defense==100) end
local id='Base.Military_FullHelmet_Vanguard-Black'
local item={kind='Clothing',value=1,getFullType=function() return id end,getInsulation=function(self) return self.value end,setInsulation=function(self,value) self.value=value end}
KnightsDan.reduceItemInsulation(item);assert(item.value==.2)
item.value=.1;KnightsDan.reduceItemInsulation(item);assert(item.value==.1,'never raise lower values')
id='Base.Hat_Army';item.value=.25;KnightsDan.reduceItemInsulation(item);assert(item.value==.25,'vanilla unaffected')
id='Base.Military_FullHelmet_Vanguard-Black';item.value=1
local player={getWornItems=function() return {size=function() return 1 end,get=function() return {getItem=function() return item end} end} end}
callbacks.OnClothingUpdated[1](player);assert(item.value==.2,'existing worn gear must update')
return 'script and existing worn item caps, lower values/vanilla preserved, wind/defense untouched; no periodic handlers'
