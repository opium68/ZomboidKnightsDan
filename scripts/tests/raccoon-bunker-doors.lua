local events={}
Events=setmetatable({},{__index=function(_,name)return {Add=function(fn)events[name]=fn end}end})
local client=false
isClient=function()return client end
instanceof=function(o,t)return o.kind==t end
IsoDoor={getGarageDoorFirst=function(o)return o end,getGarageDoorNext=function()return nil end}
require 'RCE/BunkerDoors'
local D=RCE.BunkerDoors
local function object(kind,name)
 local o={kind=kind,index=0}
 function o:getSprite()return {getName=function()return name end}end
 function o:getObjectIndex()return self.index end
 function o:getSquare()return self.square end
 return o
end
local function square(x,y,z)
 local s={items={object('IsoObject','blends_street_01_80'),object('IsoObject','walls_exterior_house_02_19'),object('IsoDoor','fixtures_doors_01_0'),object('IsoDoor','walls_garage_01_27'),object('IsoDoor','walls_garage_01_43')},removed=0}
 function s:getX()return x end;function s:getY()return y end;function s:getZ()return z end
 function s:getObjects()return {size=function()return #self.items end,get=function(_,i)return self.items[i+1]end}end
 function s:transmitRemoveItemFromSquare(o,multi)
  assert(multi==false,'Do not follow linked objects outside the explicit target square')
  for i,v in ipairs(self.items)do if v==o then table.remove(self.items,i);o.index=-1;self.removed=self.removed+1;return end end
 end
 function s:RecalcProperties()self.recalc=true end
 function s:InvalidateSpecialObjectPaths()self.paths=true end
 for _,o in ipairs(s.items)do o.square=s end
 return s
end
local checked=0
for _,g in ipairs(D.groups)do
 for x=g.x1,g.x2 do
  local s=square(x,g.y,0)
  assert(D.square(s)==2 and #s.items==3 and s.recalc and s.paths)
  assert(D.square(s)==0 and s.removed==2,'Repeated loading is idempotent')
  checked=checked+1
 end
 for _,p in ipairs({{g.x1-1,g.y,0},{g.x2+1,g.y,0},{g.x1,g.y-1,0},{g.x1,g.y,-1},{g.x1,g.y,1}})do
  local s=square(p[1],p[2],p[3]);assert(D.square(s)==0 and #s.items==5,'Exact coordinates/floor only')
 end
end
local invalid=square(10007,10164,0)
local first=invalid.items[4];invalid.items={first}
local outside=square(10006,10164,0).items[4]
IsoDoor.getGarageDoorNext=function(o)if o==first then return outside end end
assert(D.square(invalid)==0 and #invalid.items==1,'Reject a linked group extending outside the approved range')
IsoDoor.getGarageDoorNext=function()return nil end
client=true;local s=square(10007,10164,0);assert(D.square(s)==0 and #s.items==5,'Server authority')
client=false;D.install();assert(events.LoadGridsquare and events.OnTick and events.OnTickEvenPaused)
assert(checked==12)
return '12 exact landing squares; closed/open garage sprites removed; floors/frames/other doors preserved; repeat/client/outside/floor checks PASS'
