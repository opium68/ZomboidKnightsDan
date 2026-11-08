local original=require
local state={cycle=8}
RCE={Server={ready=true,store=function()return state end,now=function()return 5 end}}
require=function(name)if name=='RCE/Server'or name=='RCE/Config'then return true end;return original(name)end
isClient=function()return false end
ZombRand=function()return 0 end
local callbacks={}
Events=setmetatable({},{__index=function(t,k)local event={Add=function(f)callbacks[k]=f end};rawset(t,k,event);return event end})
local world={}
local function obj(sprite,containers)
 local o={sprite=sprite,containers=containers or {}}
 function o:getSprite()return {getName=function()return self.sprite end,getProperties=function()return {Is=function()return false end}end}end
 function o:getSquare()return self.sq end
 function o:setSquare(sq)self.sq=sq end
 function o:getContainerCount()return #self.containers end
 function o:getContainerByIndex(i)return self.containers[i+1]end
 function o:transmitCompleteItemToClients()end
 function o:getObjectIndex()for i,v in ipairs(self.sq.objects)do if v==self then return i-1 end end;return -1 end
 function o:createContainersFromSpriteProperties()self.containers={{getItems=function()return {size=function()return 0 end}end,setSourceGrid=function()end}}end
 return o
end
local function square(x,y,z,objects)
 local sq={x=x,y=y,z=z,objects=objects or {}}
 function sq:getX()return self.x end;function sq:getY()return self.y end;function sq:getZ()return self.z end
 function sq:getObjects()return {size=function()return #self.objects end,get=function(_,i)return self.objects[i+1]end}end
 function sq:transmitRemoveItemFromSquare(o)for i,v in ipairs(self.objects)do if v==o then table.remove(self.objects,i);return end end end
 function sq:AddTileObject(o)o.sq=self;self.objects[#self.objects+1]=o end
 function sq:RecalcProperties()end;function sq:RecalcAllWithNeighbours()end;function sq:InvalidateSpecialObjectPaths()end
 function sq:TreatAsSolidFloor()return true end
 function sq:isFree()return #self.objects<=1 end
 for _,o in ipairs(sq.objects)do o.sq=sq end
 world[x..','..y..','..z]=sq;return sq
end
getCell=function()return {getGridSquare=function(_,x,y,z)return world[x..','..y..','..z]end}end
IsoObject={new=function(_,sprite)return obj(sprite)end}
local anchor=square(10409,9999,2,{obj('floor')})
local count=0
local contents={getItems=function()return {size=function()return count end}end,setSourceGrid=function(self,sq)self.source=sq end}
local cabinet=obj('shisan_furniture_5_21',{contents})
local source=square(10408,9999,2,{obj('floor'),obj('location_business_bank_01_0'),cabinet})
for x=10404,10407 do for y=9998,9999 do square(x,y,2,{obj('floor'),obj('location_community_police_01_0'),obj('unrelated_wall')})end end
local D=original('RCE/PrincipalDoor')
assert(D.prepare()and #anchor.objects==2 and cabinet.sq==anchor and contents.source==anchor)
assert(#source.objects==1,'Original cabinet moved intact, exact west wall removed')
for x=10404,10407 do for y=9998,9999 do assert(#world[x..','..y..',2'].objects==2,'Floor and other wall remain')end end
assert(D.prepare()and #anchor.objects==2,'No duplicate cabinet')
local p={getX=function()return 10410 end,getY=function()return 9999 end,getZ=function()return 2 end,isDead=function()return false end,getVehicle=function()return nil end,getUsername=function()return 'tester'end}
local args={index=1,sprite='shisan_furniture_5_21'}
p.getX=function()return 10420 end;assert(not D.open(p,args),'Remote rejected');p.getX=function()return 10410 end
p.getZ=function()return 1 end;assert(not D.open(p,args),'Other floor rejected');p.getZ=function()return 2 end
assert(not D.open(p,{index=0,sprite='floor'}),'Non-container rejected')
assert(not D.open(p,{index=1,sprite='different'}),'Stale object rejected')
count=1;assert(not D.open(p,args),'Occupied cabinet preserved');count=0
local rules=RCE.PrincipalDoorRules
getSpecificPlayer=function()return p end
getText=function(key)return key end
ISWorldObjectContextMenu={addToolTip=function()return {}end}
local options={};local context={addOption=function(_,text,target,fn)local o={text=text,target=target,fn=fn};options[#options+1]=o;return o end}
original('RCE/PrincipalDoorClient')
local U=RCE.PrincipalDoorClient;U.status=D.public()
local menu=callbacks.OnFillWorldObjectContextMenu
assert(menu(0,context,{cabinet},true)==true and #options==0)
count=1;menu(0,context,{cabinet},false);assert(options[1].notAvailable and options[1].toolTip.description)
count=0;options={};menu(0,context,{cabinet},false);assert(#options==1 and not options[1].notAvailable)
local sent=false;sendClientCommand=function(who,module,cmd,a)assert(who==p and module==rules.module and cmd=='Open'and a.index==1);sent=true end
options[1].fn(options[1].target);assert(sent)
assert(D.open(p,args)and #anchor.objects==1 and state.principalDoor.opened)
assert(not D.open(p,args)and D.prepare()and #anchor.objects==1,'Replay/restart does not recreate opened cabinet')
state.cycle=9;assert(D.prepare()and #anchor.objects==2 and not D.state().opened,'New cycle prepares a new empty cabinet')
local gun=rules.target('gunstore')
local ga=square(gun.x,gun.y,gun.z,{obj('floor')})
local gc=obj(gun.source.sprite,{contents})
local gs=square(gun.source.x,gun.source.y,gun.source.z,{obj('floor'),obj('industry_trucks_01_5'),gc})
local leftCount=0
local left=obj('furniture_shelving_01_26',{{getItems=function()return {size=function()return leftCount end}end,setSourceGrid=function()end}})
local ls=square(10314,9959,0,{obj('floor'),left})
local ld=square(10314,9960,0,{obj('floor')})
ArrayList={new=function()return {}end}
local grid={getSpriteCount=function()return 2 end,getLevels=function()return 1 end}
local members={gc,left}
for _,o in ipairs(members)do
 o.getSpriteGrid=function()return grid end
 o.getSpriteGridObjectsIncludingSelf=function()return {size=function()return 2 end,get=function(_,i)return members[i+1]end}end
end
for _,t in ipairs(gun.walls)do if t.x~=gun.source.x or t.y~=gun.source.y then square(t.x,t.y,t.z,{obj('floor'),obj(t.sprite)})end end
assert(D.prepare(gun)and gc.sq==ga and #gs.objects==1)
assert(left.sq==ld and #ls.objects==1,'Multi-square cabinet moves together')
assert(D.state(gun)~=D.state(),'Independent door state')
local gp={getX=function()return gun.x end,getY=function()return gun.y end,getZ=function()return gun.z end,isDead=p.isDead,getVehicle=p.getVehicle,getUsername=p.getUsername}
getSpecificPlayer=function()return gp end;options={};menu(0,context,{gc},false);assert(#options==1,'Second cabinet also has menu')
leftCount=1;assert(not rules.empty(gc),'Contents in the other half prevent deletion');leftCount=0
local gargs={id='gunstore',index=gc:getObjectIndex(),sprite=gc.sprite}
assert(not D.open(p,gargs),'School player cannot open gun store remotely')
assert(not D.open(gp,{id='unknown',index=1,sprite=gc.sprite}),'Unknown target rejected')
assert(D.open(gp,gargs)and D.state(gun).opened and not D.state().opened,'Opening gun store does not unlock school')
assert(#ld.objects==1 and #ga.objects==1,'Both cabinet halves removed')
-- A full second of proximity, exactly two seconds of rendering, no per-tick spam.
getSpecificPlayer=function()return p end;sendClientCommand=function()end
U.status=D.public();U.hints={};U.proximity={};U.polls={}
U.update(p,0,0);U.update(p,0,999);assert(not U.hints[0])
U.update(p,0,1000);assert(U.hints[0]and U.hints[0].untilMs==3000)
local clock,draws=1000,0
getTimestampMs=function()return clock end;getCore=function()return {getZoom=function()return 1 end}end
p.getScreenX=function()return 100 end;p.getScreenY=function()return 100 end
IsoCamera={getOffX=function()return 0 end,getOffY=function()return 0 end,getScreenLeft=function()return 0 end,getScreenTop=function()return 0 end}
UIFont={Medium='medium'};getTextManager=function()return {DrawStringCentre=function()draws=draws+1 end}end
U.render();clock=2999;U.render();assert(draws==2)
clock=3000;U.render();assert(draws==2,'Exact real-time display deadline')
U.update(p,0,3000);U.update(p,0,3001);assert(not U.hints[0],'No continuous retrigger')
U.status.doors.principal.enabled=false;options={};menu(0,context,{anchor.objects[2]},false);assert(#options==0,'No menu in an unselected cycle')
-- Each of four doors rolls independently and persists until the next cycle.
state.cycle=20;local rolls=0
ZombRand=function(n)assert(n==2);rolls=rolls+1;return(rolls-1)%2 end
local public=D.public();assert(rolls==4 and public.doors.principal.enabled and not public.doors.gunstore.enabled and public.doors['slaughter-entry'].enabled and not public.doors['slaughter-inner'].enabled)
D.public();assert(rolls==4,'No re-roll on sync/restart')
for _,rule in ipairs(rules.targets)do if rule.id=='slaughter-entry'or rule.id=='slaughter-inner'then
 local sq=square(rule.x,rule.y,rule.z,{obj('floor')});assert(D.prepare(rule))
 local player={getX=function()return rule.x end,getY=function()return rule.y end,getZ=function()return rule.z end,isDead=p.isDead,getVehicle=p.getVehicle,getUsername=p.getUsername}
 local furniture=sq.objects[2]
 local opened=D.open(player,{id=rule.id,index=1,sprite=furniture.sprite})
 assert(opened==D.state(rule).enabled,'New furniture buttons enforce their independent chance on server')
end end
state.cycle=21;D.public();assert(rolls==8,'New cycle rolls all four again')
isClient=function()return true end;assert(not D.open(p,args)and not D.prepare(),'Client never mutates world')
return 'Four persisted independent 50% buttons; exact 1s dwell/2s hint; multi-square cabinet preservation; spoof/replay/client guards PASS'
