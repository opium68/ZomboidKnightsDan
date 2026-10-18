-- Native game objects are mocked; PZLinux source and KnightsDan hooks are real.
require "knights-native-reader"
local events={}
Events=setmetatable({}, {__index=function(t,name)
    local value={Add=function(f) events[name]=events[name] or {}; table.insert(events[name],f) end,Remove=function() end}
    rawset(t,name,value); return value
end})
function isClient() return false end
function isServer() return true end
SandboxVars={PZLinux={},bdtmre={nutritionmode=2}}
local world={}
ModData={getOrCreate=function(key) world[key]=world[key] or {}; return world[key] end,transmit=function() end}
local time={getWorldAgeHours=function() return 1000 end}
function getGameTime() return time end
function getText(key,...) return key end
function getTextOrNull() return nil end
function ZombRand(a,b) if b then return a else return 0 end end
function ZombRandFloat(a,b) return a end
function getTimestampMs() return 1000000 end
function getTimestamp() return 1000 end
function instanceof(value,kind) return value and value.kind==kind end
function sendServerCommand() end
function sendAddItemToContainer() end
function sendRemoveItemFromContainer() end
local function list(t)
    return {size=function() return #t end,get=function(_,i) return t[i+1] end}
end
local players={}
function getOnlinePlayers() return list(players) end
local function player(name,id,kills)
    local p={name=name,id=id,kills=kills or 0,md={PZLinuxActiveContract=0},inventory={},kind="IsoPlayer"}
    function p:getModData() return self.md end
    function p:getUsername() return self.name end
    function p:getOnlineID() return self.id end
    function p:getZombieKills() return self.kills end
    function p:getX() return 100 end
    function p:getY() return 100 end
    function p:getZ() return 0 end
    function p:isDead() return false end
    function p:transmitModData() end
    function p:getInventory() return {getItems=function() return list(self.inventory) end,
        AddItem=function(_,name) local item={getFullType=function() return name end,getModData=function() return {} end}; table.insert(self.inventory,item);return item end} end
    return p
end
require "ISPZLinuxVariablesTables"
local nativeBuy=PZLinuxTradingApplyBuy
local nativeSell=PZLinuxTradingApplySell
local nativeCompanyPrice=PZLinuxContractsUpdateCompanyPrice
-- Exercise real lookup, kill reconciliation, bank and completion paths. The
-- board acceptance fixture avoids native map-item and note creation APIs.
local nextId=1
PZLinuxContractsApplyAccept=function(p,state,request)
    local id=tostring(nextId);nextId=nextId+1
    local record={id=id,contractId=1,status="accepted",acceptedBy=p:getUsername(),owner=p:getUsername(),
        reward=5000,zombieToKill=10,zombieCount=0,acceptedHour=1000}
    local data=PZLinuxContractsGetWorldData();data.active[id]=record;data.byPlayer[p:getUsername()]=id
    PZLinuxContractsSyncWorldRecordToPlayer(p,record)
    return {ok=true}
end
PZLinuxContractsEnsureContractNote=function() end
PZLinuxContractsRemoveContractNote=function() end
PZLinuxContractsUpdateKillNote=function() return true end
PZLinuxContractsReplaceContractNote=function() return true end
-- Stable native-character fixtures: the production module uses UUID identity.
PZLinuxGetCharacterKey=function(p) return p.name..":"..tostring(p.id) end
PZLinuxBankGetCharacterIdentity=nil
-- Bank fixture preserves the real credit function's load/set interface.
local balances={}
PZLinuxLoadBankBalance=function(p) return balances[PZLinuxGetCharacterKey(p)] or 0 end
PZLinuxSetBankBalance=function(p,n) balances[PZLinuxGetCharacterKey(p)]=n;return n end
PZLinuxBankCharacterCannotMutate=function() return false end
-- PZLinuxApplyBankCredit closes over a native death guard; use the same public
-- credit contract to keep tests independent of Java player serialization.
PZLinuxApplyBankCredit=function(p,n)
    if n<=0 then return {ok=false} end
    local balance=PZLinuxLoadBankBalance(p)+n
    PZLinuxSetBankBalance(p,balance)
    return {ok=true,balance=balance}
end
require "zzz_KnightsDanCoop"
local a=player("leader",1,50);local b=player("buddy",2,500);local stranger=player("stranger",3,0)
players={a,b,stranger}
local K=KnightsDan
K.store().parties[K.key(a)]={[K.key(a)]=a.name,[K.key(b)]=b.name}
assert(not PZLinuxContractsApplyAccept(b,{},"wrong-leader").ok,"registered buddy cannot accept another contract")
assert(PZLinuxContractsApplyAccept(a,{},"accept").ok)
local r=K.active(a)
assert(K.active(b)==r,"same world contract")
assert(PZLinuxContractsGetPlayerWorldRecord(b,1)==r,"participant lookup")
assert(PZLinuxContractsGetPlayerWorldRecord(stranger,1)==nil,"unregistered lookup denied")
local successor=player("leader",99,0)
assert(PZLinuxContractsGetPlayerWorldRecord(successor,1)==nil,"same username with a new character is not a participant")
a.kills=52;assert(PZLinuxContractsReconcilePlayerZombieKills(a,r));assert(r.zombieCount==2)
b.kills=503;assert(PZLinuxContractsReconcilePlayerZombieKills(b,r));assert(r.zombieCount==5,"separate character kill counters")
assert(not PZLinuxContractsReconcilePlayerZombieKills(a,r));assert(r.zombieCount==5,"polling cannot credit twice")
r.status="ready_to_complete"
PZLinuxContractsSyncRecordToParticipants(r)
players={a,stranger} -- buddy goes offline before completion
local done=PZLinuxContractsApplyComplete(a,{},"complete")
assert(done.ok and done.amount==25125)
assert(balances[K.key(a)]==25125)
assert(balances[K.key(b)]==nil,"offline payout stays pending")
assert(not PZLinuxContractsApplyComplete(a,{},"duplicate").ok)
K.settle(a);assert(balances[K.key(a)]==25125,"repeat settlement cannot double pay")
local replacement=player("buddy",22,0)
players={a,replacement,stranger}
K.settle(replacement);assert(balances[K.key(replacement)]==nil,"new character cannot claim predecessor reward")
players={a,b,stranger}
assert(PZLinuxLoadBankBalance(b)==25125,"offline participant paid on bank access")
assert(PZLinuxLoadBankBalance(b)==25125,"reconnect payout is idempotent")
assert(PZLinux.Economy.scarcityMultiplier(999999)==1,"inflation disabled")
assert(PZLinuxTradingApplyBuy==nativeBuy and PZLinuxTradingApplySell==nativeSell,"native stock transactions restored")
assert(PZLinuxContractsUpdateCompanyPrice==nativeCompanyPrice,"native company price updates restored")
assert(PZLinuxApplyAtmWithdrawal(a,{},10,"withdraw").error=="knights_atm_disabled")
assert(PZLinuxApplyAtmDeposit(a,{},10,"deposit").error=="knights_atm_disabled")
assert(PZLinuxGetAtmState(a,{},"sync").error=="knights_atm_disabled")
assert(PZLinuxContractsApplyAtmRefillDeposit(a,{},"refill").error=="knights_atm_disabled")
for _,definition in ipairs(PZLinuxContractDefinitions) do assert(definition.id~=13,"ATM refill removed from pool") end
local board=PZLinuxContractsGetBoardData()
table.insert(board.contracts,{id=13,reward=2000})
for _,offer in ipairs(PZLinuxContractsGetBoardData().contracts) do assert(offer.id~=13,"cached ATM offer removed") end
assert(PZLinuxContractsBuildContract(PZLinuxContractDefinitions[1]).reward==PZLinux.Economy.roundPrice(PZLinuxContractDefinitions[1].reward,"nearest")*5,"reward is 5x and does not depend on stock prices")
PZLinuxTradingSyncToWorldHour=function() end
PZLinuxTradingGetCompanyByCode=function(code) return {code=code,price=100} end
PZLinuxTradingGetCompanyHistory=function() return {100} end
PZLinuxTradingBuildSnapshot=function() return {} end
PZLinuxApplyBankDebit=function(p,amount)
    local before=PZLinuxLoadBankBalance(p)
    if before<amount then return {ok=false,error="not_enough_balance"} end
    PZLinuxSetBankBalance(p,before-amount)
    return {ok=true,balance=before-amount,previousBalance=before}
end
local before=PZLinuxLoadBankBalance(a)
local buy=PZLinuxTradingApplyBuy(a,"TEST",2,"buy")
assert(buy.ok and buy.walletQuantity==2 and PZLinuxLoadBankBalance(a)==before-buy.netAmount,"stock buy debits personal bank")
local sell=PZLinuxTradingApplySell(a,"TEST",2,"sell")
assert(sell.ok and sell.walletQuantity==0 and PZLinuxLoadBankBalance(a)==before-buy.netAmount+sell.netAmount,"stock sell credits personal bank")
-- Exercise the actual native decapitation handler, including its private
-- resolver and evidence-bag creation (Java inventory/world APIs are mocked).
assert(PZLinuxContractsFindManhuntRecordForBody==nil,"native resolver is private, never supply a fake global")
local function inventory(items)
    return {getItems=function() return list(items) end,AddItem=function(_,fullType)
        local md,contents={},{}
        local item={getFullType=function() return fullType end,getModData=function() return md end,
            setName=function(self,name) self.name=name end,getInventory=function() return inventory(contents) end}
        table.insert(items,item);return item
    end}
end
function b:getInventory() return inventory(self.inventory) end
PZLinuxSyncAddedInventoryItem=function() end
PZLinuxContractsRemoveWorldEntity=function(body) body.removed=true end
K.store().parties[K.key(a)]={[K.key(a)]=a.name,[K.key(b)]=b.name}
assert(PZLinuxContractsApplyAccept(a,{},"manhunt-accept").ok)
local hunt=K.active(a)
hunt.contractId=3;hunt.status="target_down";hunt.targetDeathX=100;hunt.targetDeathY=100;hunt.targetDeathZ=0
local square={getX=function() return 100 end,getY=function() return 100 end,getZ=function() return 0 end}
local bodyData={PZLinuxContractId=hunt.id}
local body={getSquare=function() return square end,getModData=function() return bodyData end,isZombie=function() return true end}
PZLinuxValidateWorldInteraction=function(_,target) return target end
local args={target=body}
local denied=PZLinuxContractsApplyWorldEvent(stranger,"decapitate",args,"stranger-cut")
assert(not denied.ok and denied.error=="knights_not_participant" and not body.removed,"outsider cannot take tagged evidence")
bodyData.PZLinuxContractId=nil -- Native fallback matches a body at the recorded death location.
denied=PZLinuxContractsApplyWorldEvent(stranger,"decapitate",args,"stranger-fallback")
assert(not denied.ok and denied.error=="knights_not_participant","untagged target also enforces membership")
local beforeItems=#b.inventory
local cut=PZLinuxContractsApplyWorldEvent(b,"decapitate",args,"buddy-cut")
assert(cut.ok and hunt.status=="objective_taken" and body.removed,"participant can finish native decapitation")
assert(#b.inventory==beforeItems+1,"exactly one evidence bag reaches the cutting participant")
local parcel=b.inventory[#b.inventory]
assert(parcel:getFullType()=="Base.Bag_Mail" and parcel.name=="Cut target")
assert(parcel:getModData().PZLinuxContractId==hunt.id,"evidence belongs to the contract")
assert(parcel:getInventory():getItems():get(0):getFullType()=="Base.CorpseMale","native evidence contents preserved")
assert(not PZLinuxContractsApplyWorldEvent(b,"decapitate",args,"duplicate-cut").ok and #b.inventory==beforeItems+1,"completed cut cannot create duplicate evidence")
return "coop payouts, bank/stock, ATM guards; native manhunt decapitation, evidence creation, outsider denial and duplicate prevention"
