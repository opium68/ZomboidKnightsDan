RCE=RCE or {}
RCE.RPDArmory=RCE.RPDArmory or {}
local A=RCE.RPDArmory
function A.stairsOpen()
 for x=10231,10233 do
  for y=10383,10384 do
   local sq=getCell():getGridSquare(x,y,2)
   if not sq then return false end
   local found=false
   local expected='fixtures_stairs_01_'..tostring(18-(x-10231))
   for i=0,sq:getObjects():size()-1 do
    local sprite=sq:getObjects():get(i):getSprite()
    if sprite and sprite:getName()==expected then found=true;break end
   end
   if not found then return false end
  end
 end
 return true
end
local function remove(x,y,z,name)
 local sq=getCell():getGridSquare(x,y,z)
 if not sq then return 0 end
 local removed=0
 for i=sq:getObjects():size()-1,0,-1 do
  local obj=sq:getObjects():get(i)
  local sprite=obj:getSprite()
  if sprite and sprite:getName()==name then
   sq:transmitRemoveItemFromSquare(obj)
   removed=removed+1
  end
 end
 if removed>0 then
  sq:RecalcProperties();sq:RecalcAllWithNeighbours(true);sq:InvalidateSpecialObjectPaths()
 end
 return removed
end
function A.open()
 if isClient() or not A.stairsOpen() then return 0 end
 local removed=remove(10223,10380,3,'d_shisan_cannotdamaged_16')
 local floors=0
 for x=10231,10233 do for y=10383,10384 do
  floors=floors+remove(x,y,3,'d_shisan_floor_01_49')
 end end
 if removed+floors>0 then print('[RCE_RPD_ARMORY] OPEN wall='..removed..' stairFloors='..floors..' verifiedStairs=6')end
 return removed+floors
end
local last=-1
function A.tick()
 local now=getTimestampMs()
 if now-last<1000 then return end
 last=now
 A.open()
end
function A.install()
 if A.installed or isClient() then return end
 A.installed=true
 Events.OnTick.Add(A.tick)
end
return A
