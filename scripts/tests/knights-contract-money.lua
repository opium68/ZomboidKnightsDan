require "knights-coop"
local offer=PZLinuxContractsBuildContract(PZLinuxContractDefinitions[1])
assert(offer.reward==2250)
local mission=PZLinuxContractsBuildMission(offer)
assert(mission.reward==5250, "kill objective bonus also gets threefold scaling")
assert(string.find(mission.note,"$5250",1,true), "note matches scaled reward")
local p={kind="IsoPlayer",name="solo-money-test",id=45,md={PZLinuxActiveContract=9,
    PZLinuxContractId="solo-money-test",PZLinuxOnReward=1000,PZLinuxOnZombieDead=3}}
function p:getModData() return self.md end
function p:getUsername() return self.name end
function p:getOnlineID() return self.id end
function p:transmitModData() end
local world=PZLinuxContractsGetWorldData()
world.active[p.name]={id=p.name,contractId=1,status="ready_to_complete",owner=p.name,
    acceptedBy=p.name,reward=1000,zombieCount=3,note="for $1000",fullNote="for $1000"}
local record=PZLinuxContractsGetWorldContract(p.name)
assert(record.reward==3000 and record.note=="for $3000")
assert(PZLinuxContractsGetWorldContract(p.name).reward==3000,"migration is idempotent")
local result=PZLinuxContractsApplyComplete(p,{},"solo-money-complete")
assert(result.ok and result.amount==3045, "solo reward and kill bonus are both 3x")
assert(result.completionReceipt.amount==3045 and PZLinuxLoadBankBalance(p)==3045)
assert(not PZLinuxContractsApplyComplete(p,{},"solo-repeat").ok,"no second payout")
assert(record.reward==3000,"completed records are not multiplied again")
local m={reward=5250,knightsRewardMultiplier=3,note="for $5250",fullNote="for $5250"}
local created=PZLinuxContractsCreateWorldContract(p,{id=1},1,m)
assert(created.reward==5250 and created.knightsRewardMultiplier==3,"native creation/transmit cannot double-scale")
print("Contract 3x offers/mission bonuses/notes/legacy/solo/coop/idempotency PASS")

local previous={reward=17500,knightsRewardMultiplier=10,note="for $17500",fullNote="for $17500"}
KnightsDan.scaleContractReward(previous)
assert(previous.reward==5250 and previous.knightsRewardMultiplier==3 and previous.note=="for $5250","migrate 10x to 3x by ratio")
KnightsDan.scaleContractReward(previous)
assert(previous.reward==5250,"migration repeats safely")
local oldOffer={id=1,reward=7500,knightsRewardMultiplier=10}
assert(PZLinuxContractsBuildMission(oldOffer).reward==5250,"old 10x board offer builds a 3x mission")
world.active.finished={status="completed",reward=10000,knightsRewardMultiplier=10}
world.active.cancelled={status="cancelled",reward=10000,knightsRewardMultiplier=10}
PZLinuxContractsGetWorldData()
assert(world.active.finished.reward==10000 and world.active.cancelled.reward==10000,"historical completed/cancelled rewards are preserved")
