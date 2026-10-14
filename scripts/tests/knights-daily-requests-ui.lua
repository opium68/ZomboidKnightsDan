local ticks={}
Events={OnGameBoot={Add=function(f) f() end},OnGameStart={Add=function() end},
    OnTick={Add=function(f) ticks[f]=true end,Remove=function(f) ticks[f]=nil end}}
local function panel()
    return {initialise=function() end,instantiate=function() end,setVisible=function() end,
        paginate=function() end,getScrollHeight=function() return 0 end,getHeight=function() return 100 end,
        setYScroll=function() end,setName=function() end,setEnable=function(self,value) self.enabled=value end}
end
ISPanel={derive=function() return {} end}
UIFont={Small="Small"}
ISLabel={new=function() return panel() end}
ISRichTextPanel={new=function() return panel() end}
ISButton={new=function() return panel() end}
local md={}
local player={getUsername=function() return "tester" end,getSquare=function() return {} end,getModData=function() return md end}
function PZLinuxGetPlayer() return player end
function PZLinuxGetModData() return md end
PZLinuxRequestDefinitions={{baseName="Food"}}
PZLinuxRequestCategoryTextKeys={[1]="food",[9]="vehicle"}
local texts={SellerItemOffer="Selling %s items.",Total="Total: %s",SellerVehicleOffer="Selling %s: %s",VehicleLocation="Location: %s"}
function PZLinuxGetText(key) return texts[key:gsub("IGUI_PZLinux_Request_","")] or key end
function PZLinuxRequestsGetOfferPool() error("client must never generate a random offer") end
function getCore() return {getOptionSoundVolume=function() return 10 end} end
function ZombRand() error("native random conversation must never execute") end
function getSoundManager() return {PlayWorldSound=function() return {setVolume=function() end} end} end
function generateUsername() return "seller" end
function generatePseudo() return "tester" end
function PZLinuxFormatIRCName(s) return "["..s.."] " end
PZLinux={Typing={waitProfile=function() return true end,typeLabel=function() return true end}}
local categoryCallbacks={}
function PZLinuxRequestGetCategories(_,callback) categoryCallbacks[#categoryCallbacks+1]=callback end
function loadAtmBalance() return 1000000 end
function saveAtmBalance(value) md.balance=value end
local orderCalls,orderCallback,lastState=0
function PZLinuxRequestOrder(_,state,callback) orderCalls=orderCalls+1;lastState=state;orderCallback=callback end
local notices=0
HaloTextHelper={addBadText=function() notices=notices+1 end,addGoodText=function() end}
function getScriptManager() return {FindItem=function(_,id) return {getDisplayName=function() return id=="Base.Beans" and "Beans" or "Apple" end} end,
    getVehicle=function() return {getName=function() return "SportsCar" end} end} end
function getText(key) return key end
local marker
function contractsDrawOnMap(x,y) marker={x,y} end
function requestMenu_ShowUI() end
require "Context/World/Features/PZLinuxRequest"
require "zzzz_KnightsDanRequestPreview"
require "zzzzz_KnightsDanDailyRequestsUI"
function requestMenu_ShowUI() end
local function ui()
    return setmetatable({player=player,width=1000,height=800,topBar={addChild=function() end},
        removeFromUIManager=function() end},{__index=requestUI})
end
local offer={contractId=1,offerId="1:1",amount=1234,items={{name="Base.Beans"},{name="Base.Beans"},{name="Base.Apple"}}}
local a=ui()
a:onContractId(1)
assert(a.terminalCoroutine==nil,"native random coroutine is cancelled before its first tick")
categoryCallbacks[#categoryCallbacks]({ok=true,knightsOffers={["1"]=offer}})
assert(coroutine.resume(a.terminalCoroutine))
assert(a.loadingMessage.text:find("Beans x2",1,true) and a.loadingMessage.text:find("Apple x1",1,true))
assert(a.loadingMessage.text:find("Total: 1234",1,true) and a.yesButton and a.noButton)
a:onYesButton(a.yesButton);a:onYesButton(a.yesButton)
assert(orderCalls==1 and lastState.knightsOfferId==offer.offerId and lastState.items==nil,"double click guarded; only offer reference submitted")
orderCallback({ok=false,error="stale_daily_offer"})
assert(not a.knightsOrderPending and notices==1 and a.yesButton.enabled)
a:onYesButton(a.yesButton)
orderCallback({ok=true,contractId=1,balance=999})
assert(a.isClosing and md.balance==999 and md.PZLinuxUIOpenMenu==8)
local b=ui();b:onContractId(9)
local car={contractId=9,offerId="1:9",amount=12345,vehicleName="Base.SportsCar",locationX=10,locationY=20,locationZ=0,locationName="Garage"}
categoryCallbacks[#categoryCallbacks]({ok=true,knightsOffers={["9"]=car}})
assert(coroutine.resume(b.terminalCoroutine))
assert(b.loadingMessage.text:find("Garage",1,true) and b.loadingMessage.text:find("SportsCar",1,true))
b:onYesButton(b.yesButton)
orderCallback({ok=true,contractId=9,balance=1,vehicleName=car.vehicleName,locationX=10,locationY=20,locationZ=0,deliveryId="paid-car"})
assert(md.PZLinuxOnItemRequestCarName==car.vehicleName and md.PZLinuxRequestVehicleDeliveryId=="paid-car" and marker[1]==10)
local c=ui();c:onContractId(1);c.isClosing=true
categoryCallbacks[#categoryCallbacks]({ok=true,knightsOffers={["1"]=offer}})
assert(c.terminalCoroutine==nil,"late response after closing creates no UI coroutine")
return "actual native UI lazy construction, server contents/quantities/price, car/location, stale rejection, double-click and late-response handling PASS"
