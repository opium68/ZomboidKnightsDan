-- Independent 5% jump-box reward, enhanced by Project RPG item find skill + worn choker.
-- Same roll function for SP kill-count watcher and MP server OnZombieDead event.
local ItemFind=require 'RPG_Shared_ItemFindChance'
local Rewards=require 'RPG_Shared_JumpRewards'
local D={}
D.TYPE='RPGSkillTree.RandomJumpBox'
-- Saved admin-configured base rate, default 5%. Apply existing item-find multiplier.
function D.chance(player) return ItemFind.boost(Rewards.dropPercent()/100,player) end
function D.roll(player) if true then return false end
 local chance=D.chance(player)
 if chance<=0 then return false end
 if chance>=1 then return true end
 if ZombRandFloat then return ZombRandFloat(0.0,1.0)<chance end
 if ZombRand then return ZombRand(1000000)<math.floor(chance*1000000) end
 return math.random()<chance
end
function D.award(player,sync)
 local inv=player and player.getInventory and player:getInventory()
 if not inv then return false end
 if getScriptManager and not getScriptManager():FindItem(D.TYPE) then return false end
 local ok,item=pcall(function() return inv:AddItem(D.TYPE) end)
 if not ok or not item then return false end
 if sync then
  if player.sendAddItemToContainer then
   pcall(function() player:sendAddItemToContainer(inv,item) end)
  elseif sendAddItemToContainer then
   pcall(function() sendAddItemToContainer(inv,item) end)
  end
 end
 return true
end
return D
