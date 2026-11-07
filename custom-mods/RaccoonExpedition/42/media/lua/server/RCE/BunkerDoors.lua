require 'RCE/Config'
RCE.BunkerDoors=RCE.BunkerDoors or {}
local D=RCE.BunkerDoors
D.removedCount=0
D.groups={
 {id='west',x1=10007,x2=10012,y=10164,z=0},
 {id='right',x1=10030,x2=10035,y=10116,z=0},
}
function D.target(x,y,z)
 for _,g in ipairs(D.groups)do
  if z==g.z and y==g.y and x>=g.x1 and x<=g.x2 then return true end
 end
 return false
end
function D.originalDoor(obj)
 return obj and instanceof(obj,'IsoDoor') and obj:getSprite()
  and string.match(obj:getSprite():getName() or '', '^walls_garage_01_%d+$')~=nil
end
function D.group(obj)
 local first=IsoDoor.getGarageDoorFirst(obj)or obj
 local members,seen={},{}
 local current=first
 while current and not seen[current]do
  local sq=current:getSquare()
  if not sq or not D.target(sq:getX(),sq:getY(),sq:getZ())or not D.originalDoor(current)then return nil end
  seen[current]=true;members[#members+1]=current
  if #members>12 then return nil end
  current=IsoDoor.getGarageDoorNext(current)
 end
 return members
end
function D.square(sq)
 if isClient() or not sq or not D.target(sq:getX(),sq:getY(),sq:getZ())then return 0 end
 local remove={};local objects=sq:getObjects()
 for i=0,objects:size()-1 do
  local obj=objects:get(i)
  if D.originalDoor(obj)then remove[#remove+1]=obj end
 end
 local count=0
 for _,obj in ipairs(remove)do
  if obj:getObjectIndex()~=-1 then
   -- The engine removes linked garage panels even through the single-object
   -- packet path. Validate the complete group before using that standard path.
   local members=D.group(obj)
   if members then
    sq:transmitRemoveItemFromSquare(obj,false)
    for _,member in ipairs(members)do if member:getObjectIndex()==-1 then count=count+1 end end
   end
  end
 end
 if count>0 then
  D.removedCount=D.removedCount+count
  sq:RecalcProperties();sq:InvalidateSpecialObjectPaths()
  print('[RCE_BUNKER_DOORS] REMOVED '..sq:getX()..','..sq:getY()..','..sq:getZ()..' count='..count)
 end
 return count
end
local pending,last=1,0
function D.maintain()
 if pending>#D.groups or not RCENativeKeep then return end
 local g=D.groups[pending];local cx=math.floor((g.x1+g.x2)/2)
 -- Keep the whole landing loaded every tick until all six squares are checked.
 RCENativeKeep(cx,g.y,17)
 if getTimestampMs()-last<1000 then return end
 last=getTimestampMs()
 if not RCENativeLoaded(cx,g.y,g.z,8)then return end
 for x=g.x1,g.x2 do
  local sq=getCell():getGridSquare(x,g.y,g.z)
  if not sq then return end
  D.square(sq)
 end
 pending=pending+1
 if pending>#D.groups then print('[RCE_BUNKER_DOORS] READY groups=2 removed='..D.removedCount)end
end
function D.install()
 if D.installed or isClient()then return end
 D.installed=true
 Events.LoadGridsquare.Add(D.square)
 Events.OnTick.Add(D.maintain)
 Events.OnTickEvenPaused.Add(D.maintain)
end
