require 'RCE/Config'
RCE.BackpackPolicy={last=-10000}
local B=RCE.BackpackPolicy
function B.apply(container,seen)
 if not container then return 0 end
 seen=seen or {};if seen[container] then return 0 end;seen[container]=true
 local items=container:getItems();local changed=0
 for i=0,items:size()-1 do
  local item=items:get(i)
  local inner=item.getInventory and item:getInventory()
  if item:getFullType()=='RPGSkillTree.HydrationBackpack_Mythic' then
   if inner and inner:getCapacity()~=50 then item:setCapacity(50);changed=changed+1 end
   if item:getWeightReduction()~=99 then item:setWeightReduction(99);changed=changed+1 end
  end
  if inner then changed=changed+B.apply(inner,seen) end
 end
 return changed
end
Events.OnTick.Add(function()
 local now=getTimestampMs();if now-B.last<10000 then return end;B.last=now
 if isServer() then
  local players=getOnlinePlayers()
  for i=0,players:size()-1 do B.apply(players:get(i):getInventory()) end
 elseif getPlayer then
  for index=0,3 do
   local player=getSpecificPlayer(index)
   if player then B.apply(player:getInventory()) end
  end
 end
end)
