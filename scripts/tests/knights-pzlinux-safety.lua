require "knights-coop"
require "zzzz_KnightsDanSafeDelivery"
require "KnightsDan/ManhuntClient"
assert(PZLinuxDarkWebSyncPendingState==nil and PZLinuxRequestsSyncPendingState==nil,
    "tests must use real private upstream helpers, never fake public sync functions")
local function list(values)
    return {size=function() return #values end,get=function(_,i) return values[i+1] end,
        contains=function(_,v) for _,item in ipairs(values) do if item==v then return true end end return false end}
end
local available, weights, heavy, syncFailure = {}, {}, false, false
local inventory={items={}}
local function item(name)
    local data={}
    local result={getFullType=function() return name end,getModData=function() return data end,setName=function() end}
    if name=="Base.Parcel_Large" or name=="Base.Present_ExtraLarge" then
        local contents={items={}}
        function contents:getItems() return list(self.items) end
        function contents:AddItem(fullType)
            if available[fullType]==false then return nil end
            local value=item(fullType);self.items[#self.items+1]=value;return value
        end
        function result:getInventory() return contents end
    end
    return result
end
function inventory:getItems() return list(self.items) end
function inventory:AddItem(name) local result=item(name);self.items[#self.items+1]=result;return result end
function inventory:Remove(value)
    for i=#self.items,1,-1 do if self.items[i]==value then table.remove(self.items,i) end end
end
local player={name="safety",id=234,data={},getInventory=function() return inventory end}
function player:getModData() return self.data end
function PZLinuxGetPlayer(p) return p end
function PZLinuxValidateMailboxInteraction(_,ref) if ref=="valid" then return true end;return nil,"too_far" end
function PZLinuxLoadBankBalance() return 12345 end
function PZLinuxTransmitPlayerModData() end
function getScriptManager()
    return {FindItem=function(_,name)
        return {getActualWeight=function() return weights[name] or 1 end}
    end}
end
function PZLinuxDeliveryHasRoomForMoreParcels() return not heavy end
function PZLinuxDeliveryIsWithinWeightLimit() return not heavy end
function PZLinuxSyncAddedInventoryItem() return not syncFailure end
local record
function PZLinuxDeliveryGetPlayerRecord() return record end
local function reset()
    record={orders={},migrations={darkWeb=1,requests=1}}
    player.data={};inventory.items={};heavy=false;syncFailure=false
end
local function enqueue(source,id,names)
    local items={}
    for _,name in ipairs(names) do items[#items+1]={name=name,quantity=1} end
    local order=assert(PZLinuxDeliveryEnqueue(player,source,items,id))
    return order
end
reset()
enqueue("darkweb","dark",{"Base.Axe"})
assert(not PZLinuxDarkWebApplyDeliverOrders(player,"far","far").ok and #inventory.items==0)
local first=PZLinuxDarkWebApplyDeliverOrders(player,"valid","receive-dark")
assert(first.ok and first.delivered==1 and first.remaining==0 and first.balance==12345)
assert(player.data.PZLinuxDarkWebPendingCount==0 and #inventory.items==1)
assert(PZLinuxDarkWebApplyDeliverOrders(player,"valid","repeat").delivered==0 and #inventory.items==1)
enqueue("request","basic",{"Base.Axe"})
player.data.PZLinuxOnItemRequestCar=1
assert(PZLinuxRequestsApplyDelivery(player,"valid","receive-basic").delivered==1)
assert(player.data.PZLinuxRequestPendingCount==0 and player.data.PZLinuxActiveRequest==1,
    "receiving items must preserve pending vehicle status")

for _,source in ipairs({"darkweb","request","mail_reward"}) do
    reset();available["Missing.Item"]=false
    local bad=enqueue(source,"bad-"..source,{"Missing.Item"})
    local good=enqueue(source,"good-"..source,{"Base.Axe"})
    local result=PZLinuxDeliveryDeliverPending(player,source)
    assert(not result.ok and result.delivered==1 and #result.failedOrders==1 and result.remaining==1)
    assert(bad.status=="pending" and good.status=="delivered" and #inventory.items==1)
    available["Missing.Item"]=true
    local retry=PZLinuxDeliveryDeliverPending(player,source)
    assert(retry.ok and retry.delivered==1 and #inventory.items==2 and bad.knightsDeliveryError==nil)
    assert(PZLinuxDeliveryDeliverPending(player,source).delivered==0 and #inventory.items==2)
end
reset();enqueue("darkweb","heavy",{"Base.Axe"});heavy=true
assert(PZLinuxDarkWebApplyDeliverOrders(player,"valid","heavy").tooHeavy and #inventory.items==0)
heavy=false;syncFailure=true
assert(PZLinuxDarkWebApplyDeliverOrders(player,"valid","sync").error=="parcel_sync_failed" and #inventory.items==0)
syncFailure=false
assert(PZLinuxDarkWebApplyDeliverOrders(player,"valid","retry").delivered==1)
-- Preserve a delivered part of a split order while another part fails.
reset();weights["Base.Axe"]=40;available["Missing.Item"]=false;weights["Missing.Item"]=40
local split=enqueue("request","split",{"Base.Axe","Missing.Item"})
assert(#split.parcels==2)
local partial=PZLinuxDeliveryDeliverPending(player,"request")
assert(partial.delivered==1 and split.parcels[1].status=="delivered" and split.parcels[2].status=="pending")
available["Missing.Item"]=true
assert(PZLinuxDeliveryDeliverPending(player,"request").delivered==1 and #inventory.items==2)
weights={}

for _,source in ipairs({"darkweb","request"}) do
    reset()
    local migration=source=="darkweb" and "darkWeb" or "requests"
    local field=source=="darkweb" and "PZLinuxOnItemBuyOnDarkWebQueue" or "PZLinuxOnItemRequestQueue"
    local fn=source=="darkweb" and PZLinuxDarkWebMigrateLegacyQueue or PZLinuxRequestsMigrateLegacyQueue
    record.migrations[migration]=nil
    player.data[field]=source=="darkweb" and "Heavy.Item|1;Base.Axe|1" or "Heavy.Item;Base.Axe"
    weights["Heavy.Item"]=1000
    assert(fn(player)==2 and record.migrations[migration]~=1)
    assert(#record.orders==1 and #record.knightsLegacyFailures[source]==1)
    -- Simulate the native purchase callback clearing the legacy player field.
    player.data[field]=""
    assert(fn(player)==2 and #record.orders==1,"successful migrated order cannot be duplicated on retry")
    assert(record.knightsLegacyQueues[source]~="","failed original queue must survive player-field clearing")
    assert(PZLinuxDeliveryDeliverPending(player,source).delivered==1)
    record.orders={} -- simulate trimming the successfully delivered history
    assert(fn(player)==1 and #record.orders==0,"migration progress survives delivered-order history trimming")
    weights["Heavy.Item"]=1
    assert(fn(player)==1 and record.migrations[migration]==1 and #record.orders==1)
    assert(record.knightsLegacyQueues[source]==nil and #record.knightsLegacyFailures[source]==0)
end
reset();record.migrations.darkWeb=nil;player.data.PZLinuxOnItemBuyOnDarkWebQueue="invalid-legacy-entry"
assert(PZLinuxDarkWebMigrateLegacyQueue(player)==1 and record.migrations.darkWeb~=1)
assert(record.knightsLegacyQueues.darkweb=="invalid-legacy-entry","unparseable legacy data must be retained")

local moving,zombies={},{}
local square={getMovingObjects=function() return list(moving) end}
local function z(id,contract)
    return {getSquare=function() return square end,isDead=function() return false end,
        getOnlineID=function() return id end,
        getModData=function() return {PZLinuxContractId=contract,PZLinuxContractObjective="manhunt",PZLinuxManhuntVersion=4} end}
end
function getCell() return {getZombieList=function() return list(zombies) end} end
local ordinary=z(1,nil);moving={ordinary};zombies={ordinary}
local data={PZLinuxContractId="current"}
assert(KnightsDan.findManhuntTarget(data,{contractId="current",onlineId=2,x=1,y=1,z=0})==nil)
local correct=z(2,nil);moving={ordinary,correct};zombies={ordinary,correct}
assert(KnightsDan.findManhuntTarget(data,{contractId="current",onlineId=2})==correct)
assert(KnightsDan.findManhuntTarget(data,{contractId="previous",onlineId=2,zombie=correct})==nil,
    "old contract confirmations and recycled cached zombies must not match")
local tagged=z(3,"current");moving={tagged};zombies={tagged}
assert(KnightsDan.findManhuntTarget(data,nil)==tagged)
moving={};assert(KnightsDan.findManhuntTarget(data,{contractId="current",onlineId=3,zombie=tagged})==nil)
-- Compile/execute the real native event source through the production adapter.
local events={}
Events=setmetatable({}, {__index=function(t,name)
    local event={Add=function(fn) events[name]=(events[name] or 0)+1 end}
    rawset(t,name,event);return event
end})
require "Context/World/Events/PZLinuxOnEvents"
assert(KnightsDan.nativeWorldEventsLoaded and events.OnTick==2 and events.EveryTenMinutes==1)
assert(not pcall(KnightsDan.adaptManhuntClientSource,"changed upstream source"),
    "unexpected upstream interface must fail visibly rather than silently running an unsafe resolver")
return "real native parcel helpers/private functions; safe receive, failed-order isolation across three sources, partial recovery, durable migration retries, strict client identity, actual event adapter"
