require 'RCE/Server'
require 'RCE/MedicalPools'
RCE.MedicalLoot={}
local M=RCE.MedicalLoot
function M.initialize()
 local state=RCE.Server.store()
 if state.medical and state.medical.cycle==state.cycle then return state.medical end
 local med={cycle=state.cycle,plan={},delivered={},buildings={},total=0}
 for _,building in ipairs(RCE.MedicalPools)do
  local pool={};for _,c in ipairs(building.containers)do pool[#pool+1]=c end
  if #pool>0 then
   local total=ZombRand(4);med.buildings[building.id]=total;med.total=med.total+total
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
 state.medical=med
 print('[RCE_MEDICAL] PLAN cycle='..state.cycle..' ampoules='..med.total)
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
function M.square(sq)
 if not RCE.Server.ready or not sq then return end
 local objects=sq:getObjects()
 for i=0,objects:size()-1 do
  local obj=objects:get(i)
  for j=0,obj:getContainerCount()-1 do M.fill(nil,nil,obj:getContainerByIndex(j))end
 end
end
local last=-100
Events.OnTick.Add(function()
 if not RCE.Server.ready or RCE.Server.now()-last<2 then return end
 last=RCE.Server.now();local med=M.initialize()
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
