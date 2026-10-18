require "KnightsDan/Retirement"
require "KnightsDan/Supply"
local K=KnightsDan
local function configure()
 for _,id in ipairs({'Base.M60MMG','Base.M60MMG_Bipod','Base.M60Belt'}) do
  local s=getScriptManager():FindItem(id);assert(s,'M60 item missing: '..id);s:setAmmoType(AmmoType.BULLETS_308)
 end
 local manager=getScriptManager()
 for _,list in ipairs({manager:getAllCraftRecipes(),manager:getAllRecipes()}) do
  for i=0,list:size()-1 do
   local recipe=list:get(i);local name=recipe:getName()
   if name=='KnoxM60_Link100' or name:find('M13') or name:find('308.*Links') or name:find('Links.*308') or name:find('M60Links') then recipe:addRequiredSkill(Perks.Woodwork,99) end
  end
 end
end
Events.OnGameBoot.Add(configure)
Events.OnCreatePlayer.Add(function(_,player) K.cleanContainer(player:getInventory(),player) end)
if isClient() then
 local checked={}
 Events.OnPlayerUpdate.Add(function(player)
  if not player:isLocalPlayer() then return end
  local now=getTimestampMs()
  if now<(checked[player] or 0) then return end
  checked[player]=now+5000;K.cleanContainer(player:getInventory(),player)
 end)
end
if not isClient() then
 Events.LoadGridsquare.Add(K.cleanSquare)
 Events.OnFillContainer.Add(function(_,_,container) K.cleanContainer(container) end)
 Events.OnInitGlobalModData.Add(K.cleanSavedPurchases)
 Events.EveryOneMinute.Add(function()
  K.players(function(p)
   K.cleanContainer(p:getInventory(),p)
   local vehicle=p:getVehicle();if vehicle then for n=0,vehicle:getPartCount()-1 do K.cleanContainer(vehicle:getPartByIndex(n):getItemContainer()) end end
  end)
  local vehicles=getCell() and getCell():getVehicles()
  local iterator=vehicles and vehicles:iterator()
  while iterator and iterator:hasNext() do
   local vehicle=iterator:next()
   for n=0,vehicle:getPartCount()-1 do K.cleanContainer(vehicle:getPartByIndex(n):getItemContainer()) end
  end
 end)
end
