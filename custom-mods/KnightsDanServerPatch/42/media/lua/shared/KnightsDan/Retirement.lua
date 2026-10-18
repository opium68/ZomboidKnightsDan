require "KnightsDan/SupplyDefinitions"
local K=KnightsDan
K.retiredLinks={['Base.M60_Link']=true,['Base.M60_Links_Box']=true}
function K.removedItem(id) return K.retiredMetro[id] or K.retiredLinks[id] end
function K.cleanOrderItems(items)
 local result,changed={},false
 for _,entry in ipairs(items or {}) do
  local id=entry.name
  if K.removedItem(id) then changed=true
  else
   if id=='Base.308BulletsLinked' then id='Base.308Bullets';changed=true end
   local copy={};for k,v in pairs(entry) do copy[k]=v end;copy.name=id;result[#result+1]=copy
  end
 end
 return result,changed
end
function K.cleanContainer(container,player,seen)
 if not container then return end
 seen=seen or {};if seen[container] then return end;seen[container]=true
 local items=container:getItems()
 for i=items:size()-1,0,-1 do
  local item=items:get(i);local id=item:getFullType()
  if K.removedItem(id) or id=='Base.308BulletsLinked' then
   if id=='Base.308BulletsLinked' then
    local replacement=container:AddItem('Base.308Bullets')
    if not replacement then error('7.62x51 conversion failed; old item retained') end
    if sendAddItemToContainer then sendAddItemToContainer(container,replacement) end
   end
   if player then
    if player:getPrimaryHandItem()==item then player:setPrimaryHandItem(nil) end
    if player:getSecondaryHandItem()==item then player:setSecondaryHandItem(nil) end
    if player.removeWornItem then player:removeWornItem(item) end
   end
   if sendRemoveItemFromContainer then sendRemoveItemFromContainer(container,item) end
   container:Remove(item)
  else
   if id=='Base.M60MMG' or id=='Base.M60MMG_Bipod' or id=='Base.M60Belt' then item:setAmmoType(AmmoType.BULLETS_308) end
   if instanceof(item,'InventoryContainer') then K.cleanContainer(item:getInventory(),player,seen) end
  end
 end
end
function K.cleanSquare(square)
 if not square then return end
 for _,list in ipairs({square:getObjects(),square:getStaticMovingObjects(),square:getMovingObjects()}) do
  for i=0,list:size()-1 do
   local obj=list:get(i)
   if obj.getContainerCount then for n=0,obj:getContainerCount()-1 do K.cleanContainer(obj:getContainerByIndex(n)) end
   elseif obj.getContainer then K.cleanContainer(obj:getContainer()) end
   if instanceof(obj,'BaseVehicle') then for n=0,obj:getPartCount()-1 do K.cleanContainer(obj:getPartByIndex(n):getItemContainer()) end end
  end
 end
 local world=square:getWorldObjects()
 for i=world:size()-1,0,-1 do
  local obj=world:get(i);local item=obj:getItem();local id=item and item:getFullType()
  if id and (K.removedItem(id) or id=='Base.308BulletsLinked') then
   if id=='Base.308BulletsLinked' then assert(square:AddWorldInventoryItem('Base.308Bullets',obj:getOffX(),obj:getOffY(),obj:getOffZ())) end
   square:transmitRemoveItemFromSquare(obj)
  elseif item then
   if id=='Base.M60MMG' or id=='Base.M60MMG_Bipod' or id=='Base.M60Belt' then item:setAmmoType(AmmoType.BULLETS_308) end
   if instanceof(item,'InventoryContainer') then K.cleanContainer(item:getInventory()) end
  end
 end
end
function K.cleanSavedPurchases()
 local ledger=PZLinuxDeliveryGetLedger()
 for _,record in pairs(ledger.players or {}) do
  for _,order in ipairs(record.orders or {}) do
   if order.status=='pending' or order.status=='materializing' then
    local clean,changed=K.cleanOrderItems(order.items)
    if changed then
     -- Preserve delivered parcel parts. Only pending parts change; IDs and
     -- delivered markers must survive so recovery never pays a part twice.
     order.items=clean
     for _,part in ipairs(order.parts or order.parcels or {}) do
      if part.status~='delivered' then
       part.items=K.cleanOrderItems(part.items)
       if #part.items==0 then part.status='delivered';part.knightsRetired=true end
      end
     end
     if #clean==0 then order.status='cancelled';order.knightsRetired=true end
    end
   end
  end
 end
 local requests=ModData.getOrCreate('KnightsDanDailyRequestsV1')
 for _,record in pairs(requests) do
  for key,offer in pairs(record.offers or {}) do
   local _,changed=K.cleanOrderItems(offer.items)
   if changed then record.offers[key]=nil end
  end
 end
end
