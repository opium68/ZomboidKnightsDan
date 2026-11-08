require 'RCE/Server'
require 'RCE/SecretPools'
RCE.SecretLoot={}
local M=RCE.SecretLoot
function M.initialize()
 local state=RCE.Server.store()
 local med=state.secret
 if not med or med.cycle~=state.cycle then med={cycle=state.cycle,plan={},delivered={},buildings={},total=0}end
 local changed=false
 for _,building in ipairs(RCE.SecretPools)do
 if med.buildings[building.id]==nil then
  changed=true
  local pool={};for _,c in ipairs(building.containers)do pool[#pool+1]=c end
  if #pool>0 then
   local total=(building.min or 3)+ZombRand((building.max or 5)-(building.min or 3)+1);med.buildings[building.id]=total;med.total=med.total+total
   for i=1,total do
    local at=ZombRand(#pool)+1;local c=pool[at]
    local key=table.concat({c.x,c.y,c.z,c.type,c.tile},':')
    local e=med.plan[key]
    if not e then e={x=c.x,y=c.y,z=c.z,type=c.type,tile=c.tile,quantity=0,building=building.id};med.plan[key]=e end
    e.quantity=e.quantity+1
    -- Prefer different cabinets, retaining the one available cabinet when needed.
    if #pool>1 then table.remove(pool,at)end
   end
  end
 end
 end
 state.secret=med
 if changed then print('[RCE_SECRET] PLAN cycle='..state.cycle..' ampoules='..med.total)end
 return med
end
function M.fill(_,_,container)
 if not RCE.Server.prepared or not container then return end
 local state=RCE.Server.store();local med=M.initialize()
 local sq=container:getSourceGrid();local parent=container:getParent()
 local sprite=parent and parent.getSprite and parent:getSprite()
 if not sq or not sprite then return end
 local key=table.concat({sq:getX(),sq:getY(),sq:getZ(),container:getType(),sprite:getName()or''},':')
 local entry=med.plan[key];if not entry then return end
 local delivered=med.delivered[key]or 0
 while delivered<entry.quantity do
  local item=container:AddItem(RCE.Config.ampoule)
  if not item then return end
  delivered=delivered+1;med.delivered[key]=delivered
  if sendAddItemToContainer then sendAddItemToContainer(container,item)end
 end
end
function M.replaceSword(container)
 local items=container:getItems()
 for i=items:size()-1,0,-1 do
  local item=items:get(i)
  if item:getFullType()=='Base.dabaojian' then
   local replacement=container:AddItem(RCE.Config.ampoule)
   if replacement then
    container:Remove(item)
    if sendRemoveItemFromContainer then sendRemoveItemFromContainer(container,item)end
    if sendAddItemToContainer then sendAddItemToContainer(container,replacement)end
   end
  elseif item.getItemContainer then
   local nested=item:getItemContainer()
   if nested then M.replaceSword(nested)end
  end
 end
end
function M.square(sq)
 if not RCE.Server.ready or not sq or not RCE.inside(sq:getX(),sq:getY()) then return end
 local objects=sq:getObjects()
 for i=0,objects:size()-1 do
  local obj=objects:get(i)
  for j=0,obj:getContainerCount()-1 do local c=obj:getContainerByIndex(j);M.replaceSword(c);M.fill(nil,nil,c)end
 end
end
local last=-100
Events.OnTick.Add(function()
 if not RCE.Server.ready or RCE.Server.now()-last<2 then return end
 last=RCE.Server.now();local med=M.initialize()
 for y=9954,9958 do local sq=getCell():getGridSquare(10307,y,0);if sq then M.square(sq)end end
 for x=10309,10312 do local sq=getCell():getGridSquare(x,9954,0);if sq then M.square(sq)end end
 for key,c in pairs(med.plan)do
  if (med.delivered[key]or 0)<c.quantity then
   local sq=getCell():getGridSquare(c.x,c.y,c.z)
   if sq then M.square(sq)end
  end
 end
end)
Events.OnFillContainer.Add(M.fill)
Events.LoadGridsquare.Add(M.square)
return M
