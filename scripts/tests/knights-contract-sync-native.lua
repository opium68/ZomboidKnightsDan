-- LuaTestRunner supplies the owned and installed native module search roots.
require "knights-coop"
local handler,reply
Events.OnClientCommand.Add=function(fn) handler=fn end
function sendServerCommand(p,m,c,r) if m=="KnightsDanContractSync" then reply=r end end
local p={name="Gogi",id=99,kind="IsoPlayer",md={PZLinuxActiveContract=0,PZLinuxContractProtect=0}}
function p:getUsername() return self.name end
function p:getModData() return self.md end
function p:getZombieKills() return 0 end
function p:transmitModData() end
local record={id="native-job22",contractId=8,status="accepted",reward=13950,knightsRewardMultiplier=3,
    acceptedBy="Gogi",locationX=12616,locationY=2080,locationZ=0,
    note="for $13950",fullNote="for $13950",knightsMembers={[KnightsDan.key(p)]="Gogi"}}
local world=PZLinuxContractsGetWorldData()
world.active[record.id]=record;world.byPlayer.Gogi=record.id
require "zzzzzzz_KnightsDanContractSyncServer"
handler("KnightsDanContractSync","sync",p,{sequence=1,knownId=""})
assert(reply and reply.ok and reply.state.PZLinuxContractProtect==1 and reply.state.PZLinuxActiveContract==1)
assert(reply.state.PZLinuxContractLocationX==12616 and reply.state.PZLinuxOnReward==70000)
assert(record.reward==70000 and record.status=="accepted", "repair retains accepted progress and fixes underpayment")
return "actual PZLinux SyncWorldRecordToPlayer restores accepted defense flags and corrected $70000 snapshot"
