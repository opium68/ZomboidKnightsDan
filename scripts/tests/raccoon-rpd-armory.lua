isClient=function()return false end
Events={OnTick={Add=function()end}}
local squares={}
getCell=function()return {getGridSquare=function(_,x,y,z)return squares[x..','..y..','..z]end}end
local function obj(name)return {getSprite=function()return {getName=function()return name end}end}end
local function square(x,y,z,objects)
 local sq={}
 function sq:getObjects()return {size=function()return #objects end,get=function(_,i)return objects[i+1]end}end
 function sq:transmitRemoveItemFromSquare(o)for i,v in ipairs(objects)do if v==o then table.remove(objects,i);return end end end
 function sq:RecalcProperties()end
 function sq:RecalcAllWithNeighbours()end
 function sq:InvalidateSpecialObjectPaths()end
 squares[x..','..y..','..z]=sq
 return objects
end
local A=require 'RCE/RPDArmory'
local walls=square(10223,10380,3,{obj('floors_interior_tilesandwood_01_0'),obj('d_shisan_cannotdamaged_16'),obj('other_wall')})
assert(A.open()==0 and #walls==3,'Unactivated puzzle stays closed')
for x=10231,10233 do for y=10383,10384 do square(x,y,2,{obj('fixtures_stairs_01_'..tostring(18-(x-10231)))})end end
local missing=squares['10233,10384,2'];squares['10233,10384,2']=nil
assert(A.open()==0,'Partial/unloaded stairs cannot unlock')
squares['10233,10384,2']=missing
isClient=function()return true end
assert(A.open()==0,'Client cannot change world')
isClient=function()return false end
assert(A.open()==1 and #walls==2,'Activated existing stairs open exact secret entrance')
assert(A.open()==0 and #walls==2,'Idempotent; floor and unrelated wall retained')
for x=10231,10233 do for y=10383,10384 do square(x,y,3,{obj('d_shisan_floor_01_49'),obj('other_wall')})end end
assert(A.open()==6,'All six stairwell floor blockers removed')
for x=10231,10233 do for y=10383,10384 do assert(squares[x..','..y..',3']:getObjects():size()==1,'Other objects retained')end end
assert(A.open()==0,'Repaired stairwell remains idempotent')
square(10223,10380,3,{obj('d_shisan_cannotdamaged_16')})
squares['10231,10383,2']=nil
assert(A.open()==0,'Reset puzzle closes access again')
return 'server-only opening; six-stair proof; existing-cycle recovery; unloaded/reset/no-duplicate/floor guards PASS'
