require 'RCE/Forge'
-- MP drops are server-owned. Keep the original SP kill-counter strategy.
local lastPlayer,lastKills,ticks=nil,nil,0
Events.OnTick.Add(function()
 if not isMultiplayer or isMultiplayer() then return end
 ticks=ticks+1;if ticks%15~=0 then return end
 local player=getPlayer();if not player or player:isDead() then return end
 local kills=player:getZombieKills()
 if player~=lastPlayer or not lastKills or kills<lastKills then lastPlayer=player;lastKills=kills;return end
 local gained=math.min(100,kills-lastKills);lastKills=lastKills+gained
 if RCE.ForgeServer then for i=1,gained do RCE.ForgeServer.award(player) end end
end)
