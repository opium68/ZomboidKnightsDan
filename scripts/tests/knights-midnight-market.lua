assert(loadfile("scripts/tests/native-knights-loader.lua"))()
require "knights-coop"
require "KnightsDan/Market"
require "PZLinux/PZLinuxDarkWeb"
local day,month,year,hour=20,7,1993,1019.9
function getGameTime() return {getWorldAgeHours=function() return hour end,getYear=function() return year end,
    getMonth=function() return month end,getDay=function() return day end} end
local hourly
Events.EveryHours.Add=function(fn) hourly=fn end
local market={}
ModData={getOrCreate=function() return market end,transmit=function() end}
PZLinuxDarkWebItemsTable={{id={"Base.Food1"},Price=100},{id={"Base.Food2"},Price=100},{id={"Base.Food3"},Price=100}}
function getScriptManager() return {FindItem=function() return {getDisplayCategory=function() return "Food" end,
    getItemType=function() return "Food" end,isRanged=function() return false end} end} end
function PZLinuxDarkWebLoadCustomItems() end
function PZLinuxDarkWebGetStockRange() return 2,2 end
local zero=false
function ZombRand(a,b) return zero and a or b-1 end
local prices=0
function PZLinuxDarkWebCalculateBuyPrice() prices=prices+1;return prices*10 end
function PZLinuxDarkWebCalculateSellPrice() return 1 end
function PZLinuxLoadBankBalance() return 100000 end
local p={kind="IsoPlayer",name="midnight",md={}}
function p:getUsername() return self.name end
function p:getModData() return self.md end
function p:transmitModData() end
function p:getInventory() return {getItems=function() return {size=function() return 0 end} end} end
function PZLinuxTransmitPlayerModData() end
local orders,charges={},0
function PZLinuxDeliveryFindOrderByRequest(_,_,id) return orders[id] end
function PZLinuxDeliveryGetPlayerRecord() return {migrations={darkWeb=1}} end
function PZLinuxDeliveryPendingCount() return 1 end
function PZLinuxDeliveryEnqueue(_,_,items,id,metadata) local r={id=id,metadata=metadata};orders[id]=r;return r,true end
function PZLinuxApplyBankDebit(_,amount) charges=charges+amount;return {ok=true,previousBalance=100000} end
addXp=nil
local failSell=false
local nativeSellOffers=PZLinuxDarkWebBuildSellOffers
PZLinuxDarkWebBuildSellOffers=function(...)
    if failSell then error("injected sell failure") end
    return nativeSellOffers(...)
end
require "zzz_KnightsDanSupply"
local first=PZLinuxDarkWebBuildBuyOffers(p,"first")
assert(#first.offers==3)
local firstId=first.offers[1].offerId
local oldGeneration=market.generation
day=21;hour=1020.1;hourly()
assert(market.generation==oldGeneration and market.offers[1].id~=firstId,
    "calendar midnight rerolls even when elapsed-hour generation did not change")
local expired=PZLinuxDarkWebApplyBuy(p,1,1,"stale")
assert(not expired.ok and charges==0,"midnight invalidates old quotes before payment")
local current=PZLinuxDarkWebBuildBuyOffers(p,"current")
local stockId=current.offers[1].offerId
local quoted=current.offers[1].price
local priceCount=prices
hour=1032.1 -- elapsed-hour boundary, still the SAME calendar day
local stable=PZLinuxDarkWebBuildBuyOffers(p,"stable")
assert(stable.offers[1].offerId==stockId and stable.offers[1].price==quoted and prices==priceCount,
    "world-age boundary must not reroll stock or price")
local paid=PZLinuxDarkWebApplyBuy(p,1,1,"paid")
assert(paid.ok and market.offers[1].stock==1 and charges==quoted,"native purchase keeps stock/payment/delivery")
PZLinux.darkWebBuySessions={};PZLinux.darkWebSellSessions={}
local again=PZLinuxDarkWebBuildBuyOffers(p,"restart")
assert(again.offers[1].offerId==stockId and again.offers[1].stock==1,"restart keeps saved stock")
zero=true;day=22;hour=1044.1;hourly()
assert(market.knightsCategoryEmpty and #market.offers==0)
assert(#PZLinuxDarkWebBuildBuyOffers(p,"empty").offers==0)
PZLinuxDarkWebBuildSellOffers(p,"sell-empty")
assert(#market.offers==0,"native sell listing cannot refill an all-zero day")
failSell=true
assert(not pcall(PZLinuxDarkWebBuildSellOffers,p,"failed-sell") and #market.offers==0,
    "native errors must restore the empty market")
failSell=false
local replay=PZLinuxDarkWebApplyBuy(p,1,1,"paid")
assert(replay.ok and replay.replayed and charges==quoted,"already paid order replay survives midnight/empty day")
assert(#market.offers==0,"temporary empty guard is removed after replay")
local emptyBuy=PZLinuxDarkWebApplyBuy(p,1,1,"new-empty")
assert(not emptyBuy.ok and charges==quoted)
zero=false;year=1994;month=0;day=0;hour=2000;hourly()
assert(market.knightsCalendarDay=="1994:0:0" and #market.offers==3,"year/month/date changes are distinct")
local tableBefore=market.offers
market.knightsMidnightVersion=nil;hour=2001
KnightsDan.ensureMidnightMarket()
assert(market.offers==tableBefore,"one-time migration preserves an already generated list")
return "native dark market: calendar midnight, elapsed-boundary stock/quotes, restart, stale buys, purchase/replay, empty days and date rollover"
