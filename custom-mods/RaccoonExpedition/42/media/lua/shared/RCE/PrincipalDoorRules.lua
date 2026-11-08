require 'RCE/Config'
RCE.PrincipalDoorRules={x=10409,y=9999,z=2,module='RCEPrincipalDoor',command='Open'}
local P=RCE.PrincipalDoorRules
P.targets={
 {id='principal',key='principalDoor',x=10409,y=9999,z=2,source={x=10408,y=9999,z=2,sprite='shisan_furniture_5_21'},walls={}},
 {id='gunstore',key='gunstoreDoor',x=10315,y=9960,z=0,source={x=10315,y=9959,z=0,sprite='furniture_shelving_01_27'},walls={}},
 {id='slaughter-entry',key='slaughterEntryDoor',x=10122,y=10404,z=0,source={x=10122,y=10404,z=0,sprite='__no_original__'},walls={}},
 {id='slaughter-inner',key='slaughterInnerDoor',x=10119,y=10410,z=-1,source={x=10119,y=10410,z=-1,sprite='__no_original__'},walls={}},
}
local a,b=P.targets[1],P.targets[2]
a.walls[1]={x=10408,y=9999,z=2,sprite='location_business_bank_01_0'}
for x=10404,10407 do for y=9998,9999 do a.walls[#a.walls+1]={x=x,y=y,z=2,sprite='location_community_police_01_0'}end end
b.walls[1]={x=10315,y=9959,z=0,sprite='industry_trucks_01_5'}
for _,x in ipairs({10313,10315})do for y=9954,9958 do b.walls[#b.walls+1]={x=x,y=y,z=0,sprite='location_community_police_01_0'}end end
function P.target(id)
 for _,r in ipairs(P.targets)do if r.id==(id or 'principal')then return r end end
end
function P.at(sq)
 for _,r in ipairs(P.targets)do if sq and sq:getX()==r.x and sq:getY()==r.y and sq:getZ()==r.z then return r end end
end
function P.square(sq,r)
 r=r or P.targets[1];return sq and sq:getX()==r.x and sq:getY()==r.y and sq:getZ()==r.z
end
function P.cabinet(obj,r)
 return obj and P.square(obj:getSquare(),r) and obj:getSprite() and (obj:getContainerCount()>0 or (obj:getSprite():getProperties()and obj:getSprite():getProperties():Is('IsMoveAble')))
end
function P.members(obj)
 if not obj.getSpriteGrid or not obj:getSpriteGrid()then return {obj}end
 local grid=obj:getSpriteGrid()
 if grid:getSpriteCount()>16 or grid:getLevels()>1 then return nil end
 local group=obj:getSpriteGridObjectsIncludingSelf(ArrayList.new());local out={}
 if group:size()~=grid:getSpriteCount()then return nil end
 local sq=obj:getSquare()
 for i=0,group:size()-1 do
  local o=group:get(i);local s=o:getSquare()
  if not s or s:getZ()~=sq:getZ()or math.abs(s:getX()-sq:getX())>3 or math.abs(s:getY()-sq:getY())>3 then return nil end
  out[#out+1]=o
 end
 return out
end
function P.empty(obj)
 local group=P.members(obj);if not group then return false end
 for _,o in ipairs(group)do for i=0,o:getContainerCount()-1 do
  if o:getContainerByIndex(i):getItems():size()>0 then return false end
 end end
 return true
end
function P.near(player,r)
 r=r or P.targets[1]
 return player and not player:isDead() and player:getZ()==r.z and not player:getVehicle()
  and (player:getX()-r.x-0.5)^2+(player:getY()-r.y-0.5)^2<=6.25
end
return P
