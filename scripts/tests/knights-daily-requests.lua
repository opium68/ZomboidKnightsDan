-- Native PZLinux pricing, sanitization and paid delivery code; mock game objects.
require "knights-coop"
require "KnightsDan/DailyRequests"
Perks={PlantScavenging="PlantScavenging"}
local hours, randomCalls, variant = 240,0,0
function getGameTime() return {getWorldAgeHours=function() return hours end} end
function ZombRand(a,b)
    randomCalls=randomCalls+1
    if b then return math.min(b-1,a+variant) end
    return 0
end
local md={PZLinuxRequestCategoryDay=10,PZLinuxRequestCategoryAvailable={["1"]=1,["9"]=1,["10"]=1},PZLinuxRequestCategoryConsumed={}}
local p={kind="IsoPlayer",name="daily",id=75}
function p:getModData() return md end
function p:getUsername() return self.name end
function p:getOnlineID() return self.id end
function p:getPerkLevel() return 0 end
function p:transmitModData() end
local balance, debits = 10000000,0
PZLinuxLoadBankBalance=function() return balance end
PZLinuxApplyBankDebit=function(_,amount) balance=balance-amount;debits=debits+1;return {ok=true,balance=balance} end
PZLinuxRequestsMigrateLegacyQueue=function() return 0 end
PZLinuxDeliveryPendingCount=function() return 1 end
local deliveries={}
PZLinuxDeliveryFindOrderByRequest=function(_,_,request) return deliveries[request] end
PZLinuxDeliveryEnqueue=function(_,kind,items,request,metadata)
    local order={id=request,items=items,metadata=metadata};deliveries[request]=order;return order
end
function getScriptManager() return {FindItem=function() return {getDisplayName=function() return "Item" end} end} end
local first=PZLinuxRequestsGetAvailableCategories(p,"first")
local offer=first.knightsOffers["1"]
assert(offer and #offer.items==4 and first.knightsOffers["9"].vehicleName)
local calls=randomCalls
variant=2
function p:getPerkLevel() return 10 end
first.knightsOffers["1"].items[1].name="Base.Tampered"
local second=PZLinuxRequestsGetAvailableCategories(p,"reopen")
assert(randomCalls==calls and second.knightsOffers["1"].items[1].name~="Base.Tampered","reentry uses persisted deep copies")
offer=second.knightsOffers["1"]
assert(PZLinuxRequestsRejectCategory(p,1,"decline").ok)
assert(PZLinuxRequestsIsCategoryAvailable(p,1),"declining keeps offer")
assert(PZLinuxRequestsRejectCategory(p,9,"decline-car").ok and PZLinuxRequestsIsCategoryAvailable(p,9))
local bad=PZLinuxRequestsBuildOrder(p,{contractId=1,knightsOfferId="old"},"bad")
assert(not bad.ok and debits==0)
local built=PZLinuxRequestsBuildOrder(p,{contractId=1,knightsOfferId=offer.offerId,items={{name="Base.Diamond"}},amount=1},"valid")
assert(built.ok and built.amount==offer.amount and built.items[1].name==offer.items[1].name,"canonical contents/price override client fields")
local car=second.knightsOffers["9"]
local carBuilt=PZLinuxRequestsBuildOrder(p,{contractId=9,knightsOfferId=car.offerId,vehicleName="Base.Tampered",locationX=0},"car")
assert(carBuilt.ok and carBuilt.vehicleName==car.vehicleName and carBuilt.locationX==car.locationX and carBuilt.amount==car.amount)
local paid=PZLinuxRequestsApplyOrder(p,{contractId=1,knightsOfferId=offer.offerId},"pay")
assert(paid.ok and debits==1 and deliveries.pay.items[1].name==offer.items[1].name)
assert(PZLinuxRequestsApplyOrder(p,{contractId=1,knightsOfferId=offer.offerId},"pay").replayed and debits==1)
assert(not PZLinuxRequestsApplyOrder(p,{contractId=1,knightsOfferId=offer.offerId},"double").ok and debits==1,"category is consumed once")
-- A saved server record is reused by a reconnecting instance with same identity.
local reconnected={kind="IsoPlayer",name=p.name,id=p.id,getModData=p.getModData,getUsername=p.getUsername,getOnlineID=p.getOnlineID,getPerkLevel=p.getPerkLevel,transmitModData=p.transmitModData}
local reconnect=PZLinuxRequestsGetAvailableCategories(reconnected,"reconnect")
assert(reconnect.knightsOffers["9"].offerId==car.offerId and reconnect.knightsOffers["9"].vehicleName==car.vehicleName)
local other={kind="IsoPlayer",name="another",id=76,getModData=p.getModData,getUsername=p.getUsername,getOnlineID=p.getOnlineID,getPerkLevel=p.getPerkLevel,transmitModData=p.transmitModData}
local personal=PZLinuxRequestsGetAvailableCategories(other,"another-player")
assert(#personal.knightsOffers["9"].items==0 and #personal.knightsOffers["10"].items==6,"another character gets its own saved offers")
assert(PZLinuxRequestsGetAvailableCategories(p,"still-fixed").knightsOffers["9"].vehicleName==car.vehicleName,"other player's draw cannot alter own offer")
hours=264
local expired=PZLinuxRequestsBuildOrder(p,{contractId=9,knightsOfferId=car.offerId},"expired")
assert(not expired.ok and debits==1,"old-day confirmation never charges")
local nextDay=PZLinuxRequestsGetAvailableCategories(p,"next-day")
assert(nextDay.knightsOffers["1"] and nextDay.knightsOffers["1"].day==11 and nextDay.knightsOffers["1"].offerId~=offer.offerId)
assert(deliveries.pay and balance==10000000-offer.amount,"daily refresh preserves paid deliveries and bank")
return "daily goods/vehicle/location/price, decline/reentry/reconnect, canonical order, duplicate/stale rejection, next-day refresh PASS"
