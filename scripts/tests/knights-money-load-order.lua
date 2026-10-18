-- LuaTestRunner supplies the owned and installed native module search roots.
Events=setmetatable({}, {__index=function(t,k)
    local e={Add=function() end,Remove=function() end};rawset(t,k,e);return e
end})
function isClient() return false end
function isServer() return true end
function getText(k) return k end
function getTextOrNull() return nil end
function ZombRand(a,b) return b and a or 0 end
function ZombRandFloat(a,b) return a end
function getGameTime() return {getWorldAgeHours=function() return 1000 end} end
ModData={getOrCreate=function() return {} end}
-- Reproduce shared-folder autoload BEFORE the economy wrapper captures it.
require "KnightsDan/ContractMoney"
require "zzz_KnightsDanEconomy"
local definition=PZLinuxContractsGetDefinition(8)
local offer=PZLinuxContractsBuildContract(definition)
assert(offer.reward==70000 and offer.knightsRewardMultiplier==5,
    "early autoload must not leave a 5x marker attached to $14000")
local location=PZLinuxGetRandomPoolLocation
PZLinuxGetRandomPoolLocation=function() return {id="test",x=12616,y=2080,z=0,city="Louisville"} end
local mission=PZLinuxContractsBuildMission(offer)
assert(mission.reward==70000,"ground-floor protection preview must be $70000")
local bad={id="PZLinuxContract-22",contractId=8,reward=13950,knightsRewardMultiplier=3,
    locationZ=0,note="Protect the building for $13950",fullNote="for $13950"}
KnightsDan.scaleContractReward(bad)
assert(bad.reward==70000 and bad.note=="Protect the building for $70000")
KnightsDan.scaleContractReward(bad)
assert(bad.reward==70000,"repair is idempotent")
local oldOffer={id=8,reward=14000,knightsRewardMultiplier=3}
KnightsDan.scaleContractReward(oldOffer)
assert(oldOffer.reward==70000,"repair malformed saved board offers")
PZLinuxGetRandomPoolLocation=location
return "early autoload/economy ordering, $70000 live-case preview, malformed board and active reward repair"
