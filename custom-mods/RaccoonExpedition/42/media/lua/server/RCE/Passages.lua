require 'RCE/Server'
RCE.Passages={}
local P=RCE.Passages
P.seen=setmetatable({},{__mode='k'})
function P.repair()
 local cell=getCell();local src=cell:getGridSquare(10221,10410,0)
 local dst=cell:getGridSquare(10221,10409,0)
 if src and dst and dst:TreatAsSolidFloor() and dst:isFree(false) then
  for i=src:getObjects():size()-1,0,-1 do
   local o=src:getObjects():get(i);local s=o:getSprite()
   if s and s:getName()=='furniture_shelving_01_25' then
    src:transmitRemoveItemFromSquare(o)
    o:setSquare(dst);dst:AddTileObject(o)
    for j=0,o:getContainerCount()-1 do o:getContainerByIndex(j):setSourceGrid(dst)end
    o:transmitCompleteItemToClients()
    src:RecalcProperties();src:RecalcAllWithNeighbours(true);src:InvalidateSpecialObjectPaths()
    dst:RecalcProperties();dst:RecalcAllWithNeighbours(true)
    print('[RCE_PASSAGE] Shelf relocated 10221,10410,0 -> 10221,10409,0 contents preserved')
   end
  end
 end
 local sq=cell:getGridSquare(10217,10401,0)
 if sq and not P.seen[sq] then
  sq:RecalcProperties();sq:RecalcAllWithNeighbours(true);sq:InvalidateSpecialObjectPaths();P.seen[sq]=true
  print('[RCE_PASSAGE] Checked 10217,10401,0 free='..tostring(sq:isFree(false)))
 end
end
local last=-100
Events.OnTick.Add(function()
 if not RCE.Server.ready or RCE.Server.now()-last<1 then return end
 last=RCE.Server.now();P.repair()
end)
return P
