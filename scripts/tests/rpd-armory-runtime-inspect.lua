require 'RCE/RPDArmory'
local active=false
Events.OnServerStarted.Add(function()active=true end)
Events.OnTick.Add(function()
 if not active then return end
 RCENativeKeep(10224,10388,20)
 if not RCENativeLoaded(10224,10388,0,20)then return end
 active=false
 local ok,err=pcall(function()
  print('[RCE_BUNKER] STAIRS_OPEN '..tostring(RCE.RPDArmory.stairsOpen()))
  for x=10208,10239 do for y=10376,10407 do for z=-2,5 do
   local sq=getCell():getGridSquare(x,y,z)
   if sq then for i=0,sq:getObjects():size()-1 do
    local o=sq:getObjects():get(i)
    if x==10223 and y==10380 and z==3 then local s=o:getSprite();print('[RCE_BUNKER] ENTRANCE '..tostring(s and s:getName()))end
    local c=o:getContainer()
    if c then local items=c:getItems();for j=0,items:size()-1 do
     local item=items:get(j)
     if item:getType()=='MaidenBadge'then print('[RCE_BUNKER] MAIDEN '..x..','..y..','..z..' container='..c:getType())end
    end end
   end end
  end end end
  for x=10229,10235 do for y=10383,10384 do for z=2,3 do
   local s=getCell():getGridSquare(x,y,z)
   if s then
    local names={};for i=0,s:getObjects():size()-1 do local sprite=s:getObjects():get(i):getSprite();names[#names+1]=tostring(sprite and sprite:getName())end
    print('[RCE_BUNKER] STAIR '..x..','..y..','..z..' stairs='..tostring(s:getStairs())..' dir='..tostring(s:getStairsDirection())..' floor='..tostring(s:TreatAsSolidFloor())..' objects='..table.concat(names,';'))
   end
  end end end
  local sq=getCell():getGridSquare(10223,10380,3)
  assert(sq,'Entrance loaded')
  local function count()
   local n=0
   for i=0,sq:getObjects():size()-1 do local s=sq:getObjects():get(i):getSprite();if s and s:getName()=='d_shisan_cannotdamaged_16'then n=n+1 end end
   return n
  end
  local before=count()
  for y=10383,10384 do
   local a=getCell():getGridSquare(10231,y,2);local b=getCell():getGridSquare(10230,y,3)
   print('[RCE_BUNKER] BEFORE_DIRECTION y='..y..' up='..tostring(a:isBlockedTo(b))..' down='..tostring(b:isBlockedTo(a)))
  end
  local removed=RCE.RPDArmory.open()
  print('[RCE_BUNKER] REMOVAL before='..before..' removed='..removed..' after='..count())
  if RCE.RPDArmory.stairsOpen()then assert(count()==0,'Secret wall removed')end
  for x=10231,10233 do for y=10383,10384 do
   local s=getCell():getGridSquare(x,y,3)
   assert(not s:getFloor(),'No upper floor over stairwell')
  end end
  for y=10383,10384 do
   local a=getCell():getGridSquare(10231,y,2);local b=getCell():getGridSquare(10230,y,3)
   local up=a:testCollideAdjacentAdvanced(-1,0,1,false)
   local down=b:testCollideAdjacentAdvanced(1,0,-1,false)
   print('[RCE_BUNKER] AFTER_DIRECTION y='..y..' up='..tostring(up)..' down='..tostring(down)..' landing='..tostring(b:hasFloorAtTopOfStairs()))
   assert(not up and not down,'Both staircase collision directions are open')
  end
  assert(RCE.RPDArmory.open()==0,'Repeat is idempotent')
  print('[RCE_BUNKER] PASS armory inspection')
 end)
 if not ok then print('[RCE_BUNKER] FAIL '..tostring(err))end
end)
