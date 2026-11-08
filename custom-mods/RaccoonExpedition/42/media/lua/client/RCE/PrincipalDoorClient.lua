local rules=require 'RCE/PrincipalDoorRules'
RCE.PrincipalDoorClient=RCE.PrincipalDoorClient or {}
local U=RCE.PrincipalDoorClient
if U.installed then return U end
U.installed=true;U.hints={};U.proximity={};U.polls={}
local function tr(key,fallback)
 local text=getText(key);return text and text~=key and text or fallback
end
function U.eligible(rule)
 local state=U.status and U.status.doors and U.status.doors[rule.id]
 return state and state.enabled==true and not state.opened
end
Events.OnServerCommand.Add(function(module,command,args)
 if module~=rules.module or command~='Status'or type(args)~='table'or type(args.cycle)~='number'or type(args.doors)~='table'then return end
 if U.status and args.cycle<U.status.cycle then return end
 if not U.status or U.status.cycle~=args.cycle then U.proximity={};U.hints={}end
 U.status=args
end)
Events.OnFillWorldObjectContextMenu.Add(function(playerIndex,context,objects,test)
 local player=getSpecificPlayer(playerIndex);local square,rule
 for _,obj in ipairs(objects)do if obj then local r=rules.at(obj:getSquare());if r then square=obj:getSquare();rule=r;break end end end
 if not square or not rules.near(player,rule)or not U.eligible(rule)then return end
 for i=0,square:getObjects():size()-1 do
  local obj=square:getObjects():get(i)
  if rules.cabinet(obj,rule)then
   if test then return true end
   local index,sprite=obj:getObjectIndex(),obj:getSprite():getName()
   local option=context:addOption(tr('IGUI_RCE_OpenPrincipalSecret','Open secret passage'),player,function(p)
    sendClientCommand(p,rules.module,rules.command,{id=rule.id,index=index,sprite=sprite})
   end)
   if not rules.empty(obj)then
    option.notAvailable=true;option.toolTip=ISWorldObjectContextMenu.addToolTip()
    option.toolTip.description=tr('IGUI_RCE_EmptyPrincipalCabinet','Empty the cabinet first.')
   end
   return
  end
 end
end)
function U.update(player,index,now)
 local nearby=false
 U.proximity[index]=U.proximity[index]or {}
 for _,rule in ipairs(rules.targets)do
  local distance=player and(player:getX()-rule.x-0.5)^2+(player:getY()-rule.y-0.5)^2 or math.huge
  local same=player and not player:isDead()and player:getZ()==rule.z
  if same and distance<=100 then nearby=true end
  local record=U.proximity[index][rule.id]
  if not same or distance>25 or not U.eligible(rule)then
   U.proximity[index][rule.id]=nil
  elseif distance<=9 then
   local sq=getCell():getGridSquare(rule.x,rule.y,rule.z);local found=false
   if sq then for i=0,sq:getObjects():size()-1 do if rules.cabinet(sq:getObjects():get(i),rule)then found=true;break end end end
   if found then
    if not record then record={since=now,shown=false};U.proximity[index][rule.id]=record end
    if not record.shown and now-record.since>=1000 then
     record.shown=true;U.hints[index]={player=player,untilMs=now+2000,rule=rule.id}
    end
   end
  elseif record and not record.shown then U.proximity[index][rule.id]=nil end
 end
 if nearby and now-(U.polls[index]or -10000)>=3000 then U.polls[index]=now;sendClientCommand(player,rules.module,'GetStatus',{})end
 local hint=U.hints[index]
 if hint and(now>=hint.untilMs or not player or player:isDead())then U.hints[index]=nil end
end
function U.tick()
 local now=getTimestampMs()
 if U.lastTick and now-U.lastTick<100 then return end
 U.lastTick=now
 for i=0,(getNumActivePlayers and getNumActivePlayers()or 1)-1 do U.update(getSpecificPlayer(i),i,now)end
end
function U.render()
 local now=getTimestampMs()
 for index,hint in pairs(U.hints)do
  local p=getSpecificPlayer(index)
  if now<hint.untilMs and p==hint.player and not p:isDead()then
   local zoom=getCore():getZoom(index)
   local x=(p:getScreenX()-IsoCamera.getOffX(index))/zoom+IsoCamera.getScreenLeft(index)
   local y=(p:getScreenY()-IsoCamera.getOffY(index)-110)/zoom+IsoCamera.getScreenTop(index)
   getTextManager():DrawStringCentre(UIFont.Medium,x,y,tr('IGUI_RCE_SuspiciousFurniture','Something seems suspicious.'),1,0.85,0.4,1)
  end
 end
end
Events.OnTick.Add(U.tick)
Events.OnPostUIDraw.Add(U.render)
return U
