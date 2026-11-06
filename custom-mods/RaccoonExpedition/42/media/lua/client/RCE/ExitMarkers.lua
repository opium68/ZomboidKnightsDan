require 'RCE/Config'
-- Loaded by EVERY client; follows KnoxEscapeQuest's per-player highlight API.
RCE.ExitMarkers={players={}}
local M=RCE.ExitMarkers
local color=ColorInfo.new(0.15,1,0.35,0.65)
local function clear(object,index)
 object:setHighlighted(index,false)
 object:setOutlineHighlight(index,false)
end
function M.clear()
 for index,state in pairs(M.players) do
  for object in pairs(state.objects) do clear(object,index) end
 end
 M.players={}
end
function M.update(player)
 if not player then return end
 local index=player:getPlayerNum()
 if getSpecificPlayer(index)~=player then return end
 local state=M.players[index] or {objects={},last=-1000}
 M.players[index]=state
 local now=getTimestampMs()
 if now-state.last<500 then return end
 state.last=now
 local wanted={}
 if not player:isDead() then
  local pos=RCE.position(player)
  for _,exit in ipairs(RCE.Config.exits) do
   if pos.z==exit.z and RCE.distance2(pos,exit)<=900 then
    local r=RCE.Config.exitRadius
    for x=exit.x-r,exit.x+r do for y=exit.y-r,exit.y+r do
     if RCE.exitAt({x=x+0.5,y=y+0.5,z=exit.z}) then
      local square=getCell():getGridSquare(x,y,exit.z)
      local floor=square and square:getFloor()
      if floor and square:TreatAsSolidFloor() then
       wanted[floor]=true
       floor:setHighlighted(index,true,true)
       floor:setHighlightColor(index,color)
       floor:setOutlineHighlight(index,true)
      end
     end
    end end
   end
  end
 end
 for object in pairs(state.objects) do if not wanted[object] then clear(object,index) end end
 state.objects=wanted
end
Events.OnPlayerUpdate.Add(M.update)
Events.OnGameStart.Add(M.clear)
