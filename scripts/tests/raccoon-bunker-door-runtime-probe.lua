require 'RCE/BunkerDoors'
local D=RCE.BunkerDoors
local active,index=false,1
Events.OnServerStarted.Add(function()active=true;print('[RCE_BUNKER] BEGIN removal regression')end)
Events.OnTick.Add(function()
 if not active then return end
 local ok,err=pcall(function()
  local g=D.groups[index]
  if not g then print('[RCE_BUNKER] PASS door removal regression complete');active=false;return end
  local cx=math.floor((g.x1+g.x2)/2)
  RCENativeKeep(cx,g.y-10,24)
  if not RCENativeLoaded(cx,g.y-10,0,24)then return end
  local a=getCell():getGridSquare(cx,g.y-1,-1)
  local b=getCell():getGridSquare(cx,g.y,0)
  assert(a and b and a:hasSlopedSurfaceToLevelAbove(IsoDirections.S),'Original ramp reaches street')
  local before,removed=0,0
  local floors={}
  for x=g.x1,g.x2 do
   local sq=getCell():getGridSquare(x,g.y,0);assert(sq,'Landing loaded')
   floors[x]=sq:getFloor();assert(floors[x],'Street floor exists')
   for i=0,sq:getObjects():size()-1 do
    local o=sq:getObjects():get(i)
    if D.originalDoor(o)then o:setOpen(false);before=before+1 end
   end
   sq:RecalcProperties();sq:InvalidateSpecialObjectPaths()
  end
  assert(before>0 and a:isBlockedTo(b)and b:isBlockedTo(a),'Closed original gates block both directions')
  for x=g.x1,g.x2 do
   local sq=getCell():getGridSquare(x,g.y,0)
   removed=removed+D.square(sq)
   assert(D.square(sq)==0,'Repeat removal does nothing')
   assert(sq:getFloor()==floors[x],'Street floor preserved')
   for i=0,sq:getObjects():size()-1 do assert(not D.originalDoor(sq:getObjects():get(i)),'No garage doors remain')end
  end
  assert(removed==before,'All original gate segments removed')
  assert(not a:isBlockedTo(b)and not b:isBlockedTo(a),'Bidirectional landing passage after removal')
  assert(not a:testCollideAdjacentAdvanced(0,1,1,false)and not b:testCollideAdjacentAdvanced(0,-1,-1,false),'No residual door collision')
  assert(a:hasSlopedSurfaceToLevelAbove(IsoDirections.S),'Ramp preserved')
  print('[RCE_BUNKER_DOORS_TEST] PASS '..g.id..' removed='..removed..' floor/ramp preserved; both directions unblocked')
  index=index+1
 end)
 if not ok then active=false;print('[RCE_BUNKER] FAIL '..tostring(err))end
end)
