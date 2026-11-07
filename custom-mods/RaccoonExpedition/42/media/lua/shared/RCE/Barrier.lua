require 'RCE/Config'
RCE.Barrier=RCE.Barrier or {}
local B=RCE.Barrier
local sprites={shisan_otherfurniture_0=true,shisan_otherfurniture_1=true,shisan_otherfurniture_2=true,shisan_otherfurniture_27=true}
for i=80,87 do sprites['shisan_furnace_'..i]=true end
B.repairs={
 {x=9926,y=10499,z=0,sprite='shisan_otherfurniture_1'},
 {x=9926,y=10498,z=0,sprite='shisan_furnace_80'},
 {x=10495,y=10171,z=0,sprite='shisan_otherfurniture_0'},
 {x=10494,y=10171,z=0,sprite='shisan_furnace_81'},
}
function B.location(x,y,z,name)
 return z==0 and x>=9909 and x<=10496 and y>=9899 and y<=10500
  and (x<=9911 or x>=10494 or y<=9901 or y>=10498) and sprites[name]==true
end
function B.protected(obj)
 if not obj or not obj:getSquare() or not obj:getSprite() then return false end
 local sq=obj:getSquare()
 return B.location(sq:getX(),sq:getY(),sq:getZ(),obj:getSprite():getName())
end
function B.prepareSprite(name)
 local sprite=getSprite(name)
 if not sprite then return end
 -- These sprite names are unique to the Raccoon exterior barricade set.
 -- Keep collision/appearance/CantClimb; remove pickup and scrap interactions.
 local props=sprite:getProperties()
 props:unset('CanScrap');props:unset('IsMoveAble')
end
local function prepareAll()for name in pairs(sprites)do B.prepareSprite(name)end end
Events.OnGameBoot.Add(prepareAll)
Events.OnServerStarted.Add(prepareAll)
Events.OnGameStart.Add(prepareAll)
if not isClient() then
 function B.square(sq)
  if not sq then return end
  for _,p in ipairs(B.repairs)do
   if sq:getX()==p.x and sq:getY()==p.y and sq:getZ()==p.z then
    B.prepareSprite(p.sprite)
    local found=false;local objects=sq:getObjects()
    for i=0,objects:size()-1 do
     local o=objects:get(i)
     if o:getSprite() and o:getSprite():getName()==p.sprite then found=true;break end
    end
    if not found then
     local o=IsoObject.new(getCell(),sq,getSprite(p.sprite))
     sq:AddTileObject(o);sq:RecalcProperties();o:transmitCompleteItemToClients()
     print('[RCE_BARRIER] REPAIRED '..p.x..','..p.y..','..p.z..' '..p.sprite)
    end
   end
  end
 end
 Events.LoadGridsquare.Add(B.square)
 local pending,last=1,0
 local function maintain()
  if pending>#B.repairs or not RCENativeKeep then return end
  local p=B.repairs[pending]
  RCENativeKeep(p.x,p.y,17)
  if getTimestampMs()-last<1000 then return end
  last=getTimestampMs()
  if not RCENativeLoaded(p.x,p.y,p.z,2)then return end
  local sq=getCell():getGridSquare(p.x,p.y,p.z)
  if not sq then return end
  B.square(sq);pending=pending+1
  if pending>#B.repairs then print('[RCE_BARRIER] READY repairs=4 protection=outer-only')end
 end
 Events.OnTick.Add(maintain)
 Events.OnTickEvenPaused.Add(maintain)
end