require 'RCE/Server'
local rules=require 'RCE/PrincipalDoorRules'
RCE.PrincipalDoor=RCE.PrincipalDoor or {}
local D=RCE.PrincipalDoor
local function refresh(sq)
 sq:RecalcProperties();sq:RecalcAllWithNeighbours(true);sq:InvalidateSpecialObjectPaths()
end
function D.state(rule)
 rule=rule or rules.targets[1]
 local state=RCE.Server.store()
 if not state[rule.key] or state[rule.key].cycle~=state.cycle then
  state[rule.key]={cycle=state.cycle,opened=false,installed=false}
 end
 if state[rule.key].enabled==nil then state[rule.key].enabled=ZombRand(2)==0 end
 return state[rule.key]
end
function D.clearWalls(rule)
 rule=rule or rules.targets[1]
 local n=0
 for _,t in ipairs(rule.walls)do
  local sq=getCell():getGridSquare(t.x,t.y,t.z)
  if sq then
   local changed=false
   for i=sq:getObjects():size()-1,0,-1 do
    local obj=sq:getObjects():get(i);local sprite=obj:getSprite()
    if sprite and sprite:getName()==t.sprite then sq:transmitRemoveItemFromSquare(obj);n=n+1;changed=true end
   end
   if changed then refresh(sq)end
  end
 end
 if n>0 then print('[RCE_PRINCIPAL] WALLS_REMOVED site='..rule.id..' count='..n)end
 return n
end
function D.move(cabinet,source,destination)
 local group=rules.members(cabinet);if not group then return false end
 local plan={}
 for _,o in ipairs(group)do
  local sq=o:getSquare()
  local dst=getCell():getGridSquare(destination:getX()+sq:getX()-source:getX(),destination:getY()+sq:getY()-source:getY(),destination:getZ())
  if not dst or not dst:TreatAsSolidFloor()or not dst:isFree(false)then return false end
  plan[#plan+1]={obj=o,src=sq,dst=dst}
 end
 for _,p in ipairs(plan)do if p.obj:getObjectIndex()~=-1 then p.src:transmitRemoveItemFromSquare(p.obj)end end
 for _,p in ipairs(plan)do
  p.obj:setSquare(p.dst);p.dst:AddTileObject(p.obj)
  for i=0,p.obj:getContainerCount()-1 do p.obj:getContainerByIndex(i):setSourceGrid(p.dst)end
  p.obj:transmitCompleteItemToClients();refresh(p.src);refresh(p.dst)
 end
 return true
end
function D.prepare(rule)
 rule=rule or rules.targets[1]
 if isClient()or not RCE.Server.ready then return false end
 local anchor=getCell():getGridSquare(rule.x,rule.y,rule.z)
 local source=getCell():getGridSquare(rule.source.x,rule.source.y,rule.source.z)
 if not anchor or not source then return false end
 for _,t in ipairs(rule.walls)do if not getCell():getGridSquare(t.x,t.y,t.z)then return false end end
 D.clearWalls(rule)
 local state=D.state(rule)
 if state.opened or state.installed then return true end
 local existing
 for i=0,anchor:getObjects():size()-1 do
  if rules.cabinet(anchor:getObjects():get(i),rule)then existing=anchor:getObjects():get(i);break end
 end
 local cabinet
 for i=0,source:getObjects():size()-1 do
  local obj=source:getObjects():get(i);local sprite=obj:getSprite()
  if sprite and sprite:getName()==rule.source.sprite then cabinet=obj;break end
 end
 if existing then
  -- A player may have placed a different cabinet without moving the original shelf.
  -- Relocate the old blocker intact, preserving its inventory outside the entry path.
  if cabinet then
   local destination
   for _,d in ipairs({{1,1},{-1,1},{1,-1},{-1,-1},{2,1},{2,-1}})do
    local sq=getCell():getGridSquare(rule.x+d[1],rule.y+d[2],rule.z)
    if sq and sq:TreatAsSolidFloor()and sq:isFree(false)then destination=sq;break end
   end
   if not destination then return false end
   if not D.move(cabinet,source,destination)then return false end
   print('[RCE_PRINCIPAL] OLD_SHELF_RELOCATED site='..rule.id..' contents=preserved')
  end
  state.installed=true;return true
 elseif cabinet then
  if not D.move(cabinet,source,anchor)then return false end
 else
  cabinet=IsoObject.new(anchor,'shisan_furniture_5_21','')
  cabinet:createContainersFromSpriteProperties();anchor:AddTileObject(cabinet)
  cabinet:transmitCompleteItemToClients()
 end
 if not rules.cabinet(cabinet,rule)then error('Principal cabinet has no container')end
 refresh(anchor);state.installed=true
 print('[RCE_PRINCIPAL] CABINET_READY site='..rule.id..' at='..rule.x..','..rule.y..','..rule.z..' cycle='..state.cycle)
 return true
end
function D.open(player,args)
 if type(args)~='table'then return false end
 local rule=rules.target(args.id)
 if not rule then return false end
 if isClient()or not RCE.Server.ready or not rules.near(player,rule)or type(args)~='table' then return false end
 local state=D.state(rule);if not state.enabled or state.opened then return false end
 local sq=getCell():getGridSquare(rule.x,rule.y,rule.z)
 local i=args.index
 if not sq or type(i)~='number'or i~=math.floor(i)or i<0 or i>=sq:getObjects():size()then return false end
 local obj=sq:getObjects():get(i)
 if not rules.cabinet(obj,rule)or obj:getSprite():getName()~=args.sprite or not rules.empty(obj)then return false end
 -- Only the cabinet is removed by this request. Structural blockers are maintained separately.
 local group=rules.members(obj);if not group then return false end
 for _,o in ipairs(group)do local s=o:getSquare();if o:getObjectIndex()~=-1 then s:transmitRemoveItemFromSquare(o)end;refresh(s)end
 state.installed=true;state.opened=true
 if sendServerCommand then sendServerCommand(rules.module,'Status',D.public())end
 print('[RCE_PRINCIPAL] OPEN by='..tostring(player:getUsername())..' site='..rule.id..' cycle='..state.cycle)
 return true
end
function D.public()
 local doors={}
 for _,rule in ipairs(rules.targets)do
  local state=D.state(rule);doors[rule.id]={enabled=state.enabled,opened=state.opened}
 end
 return {cycle=RCE.Server.store().cycle,doors=doors}
end
function D.install()
 if D.installed or isClient()then return end
 D.installed=true
 Events.OnClientCommand.Add(function(module,command,player,args)
  if module~=rules.module or not player or not RCE.Server.ready then return end
  if command==rules.command then D.open(player,args)
  elseif command=='GetStatus'and not player:isDead()then
   local close=false
   for _,rule in ipairs(rules.targets)do
    if player:getZ()==rule.z and math.abs(player:getX()-rule.x)<=12 and math.abs(player:getY()-rule.y)<=12 then close=true;break end
   end
   D.syncAt=D.syncAt or {};local key=player:getUsername();local now=RCE.Server.now()
   if close and now-(D.syncAt[key]or -100)>=1 then
    D.syncAt[key]=now;sendServerCommand(player,rules.module,'Status',D.public())
   end
  end
 end)
 local last=-100
 local function tick()
  if not RCE.Server.ready then return end
  D.prepared=D.prepared or {}
  for _,rule in ipairs(rules.targets)do if not D.prepared[rule.id]and RCENativeKeep then RCENativeKeep(rule.x,rule.y,17)end end
  if RCE.Server.now()-last<2 then return end
  last=RCE.Server.now()
  for _,rule in ipairs(rules.targets)do if D.prepare(rule)then D.prepared[rule.id]=true end end
 end
 Events.OnTick.Add(tick)
 Events.OnTickEvenPaused.Add(tick)
 Events.LoadGridsquare.Add(function(sq)
  if not sq then return end
  for _,rule in ipairs(rules.targets)do
   if sq:getZ()==rule.z and math.abs(sq:getX()-rule.x)<=6 and math.abs(sq:getY()-rule.y)<=6 then D.prepare(rule)end
  end
 end)
end
return D
