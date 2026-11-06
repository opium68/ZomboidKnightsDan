require 'RCE/Forge'
local Loot=require 'RPG_Shared_RandomboxLoot'
RCE.ForgeServer={}
local S=RCE.ForgeServer
local function sync(player,inv,item,remove)
 if remove then
  if player.sendRemoveItemFromContainer then player:sendRemoveItemFromContainer(inv,item)
  elseif sendRemoveItemFromContainer then sendRemoveItemFromContainer(inv,item) end
 else
  if player.sendAddItemToContainer then player:sendAddItemToContainer(inv,item)
  elseif sendAddItemToContainer then sendAddItemToContainer(inv,item) end
 end
end
function S.award(player,value)
 if not player or player:isDead() then return false end
 local r=tonumber(value)
 if not r then r=ZombRandFloat and ZombRandFloat(0,1) or ZombRand(100000000)/100000000 end
 if r>=RCE.Forge.probability(player) then return false end
 local inv=player:getInventory();local item=inv:AddItem(RCE.Forge.item)
 if not item then return false end
 sync(player,inv,item,false)
 if sendServerCommand then sendServerCommand(player,'RPGSkillTree','RandomboxSay',{textKey='UI_RPG_Randombox_Lucky',text='A sparkling thunder ember!'}) end
 return true
end
local function tell(player,payload)
 if isMultiplayer and not isMultiplayer() and triggerEvent then triggerEvent('OnServerCommand','RPGSkillTree','RandomboxReveal',payload)
 elseif sendServerCommand then sendServerCommand(player,'RPGSkillTree','RandomboxReveal',payload) end
end
function S.open(player,args)
 if not player or player:isDead() or not RCE.Forge.unlocked(player) or type(args)~='table' then return false end
 local id=args.requestId
 if type(id)~='string' or #id<1 or #id>48 then return false end
 local md=player:getModData();md.RCEForgeRequests=md.RCEForgeRequests or {}
 for _,old in ipairs(md.RCEForgeRequests) do if old==id then return false end end
 -- Record before any inventory mutation; repeated packets never spend twice.
 table.insert(md.RCEForgeRequests,id);if #md.RCEForgeRequests>64 then table.remove(md.RCEForgeRequests,1) end
 local count=tonumber(args.count) or 1
 if count~=count or count==math.huge or count==-math.huge then return false end
 count=math.max(1,math.min(200,math.floor(count)))
 local inv=player:getInventory();local awarded,tiers={},{};local opened=0
 for n=1,count do
  local box;local items=inv:getItems()
  for i=0,items:size()-1 do
   local item=items:get(i)
   if RCE.Forge.isItem(item) and item:getFullType()==args.boxType then box=item;break end
  end
  if not box then break end
  local entry=Loot.rollEntry();local quantity=entry and entry.count or 0
  if not entry or quantity<1 or quantity>100 or quantity~=math.floor(quantity) then break end
  local created={};local ok=true
  for i=1,quantity do
   local added,item=pcall(function()return inv:AddItem(entry.type)end)
   if not added or not item then ok=false;break end
   created[#created+1]=item
  end
  local removed=false
  if ok then
   local success=pcall(function()inv:Remove(box)end)
   if success then
    removed=true
    local current=inv:getItems()
    for i=0,current:size()-1 do if current:get(i)==box then removed=false;break end end
   end
  end
  if not removed then
   for _,item in ipairs(created) do inv:Remove(item) end
   break
  end
  sync(player,inv,box,true)
  for _,item in ipairs(created) do
   sync(player,inv,item,false);awarded[#awarded+1]=entry.type;tiers[#tiers+1]=entry.tier
  end
  opened=opened+1
 end
 local remaining=0;local items=inv:getItems()
 for i=0,items:size()-1 do if RCE.Forge.isItem(items:get(i)) and items:get(i):getFullType()==args.boxType then remaining=remaining+1 end end
 local preview,candidates={},{}
 for _,row in ipairs(Loot.POOL) do
  preview[#preview+1]={type=row.type,tier=row.tier,chance=row.chance*100,count=row.count}
  candidates[#candidates+1]=row.type
 end
 tell(player,{requestId=id,tier='Normal',boxId='default',boxType=args.boxType,opened=opened,rewards=awarded,rewardTiers=tiers,previewEntries=preview,previewItems=candidates,remainingTotal=remaining,remainingMatching=remaining})
 return opened>0
end
Events.OnClientCommand.Add(function(module,command,player,args)
 if module=='RPGSkillTree' and command=='RandomboxOpen' then S.open(player,args) end
end)
Events.OnZombieDead.Add(function(zombie)
 if not zombie or (isMultiplayer and not isMultiplayer()) then return end
 local killer=zombie.getAttackedBy and zombie:getAttackedBy()
 if not killer and zombie.getLastHitBy then killer=zombie:getLastHitBy() end
 if not killer or not instanceof(killer,'IsoPlayer') or killer:isDead() then return end
 local md=zombie:getModData();if md.RCEForgeProcessed then return end;md.RCEForgeProcessed=true
 S.award(killer)
end)
RPG_SP_OpenRandombox=function(player,args)
 if not isMultiplayer or isMultiplayer() then return false end
 return S.open(player,args)
end
