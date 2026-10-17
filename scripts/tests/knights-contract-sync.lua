local handlers={}
Events=setmetatable({}, {__index=function(t,k)
    local e={Add=function(fn) handlers[k]=handlers[k] or {};handlers[k][#handlers[k]+1]=fn end}
    rawset(t,k,e);return e
end})
function require(name)
    if name=="KnightsDan/ContractSync" then assert(loadfile("custom-mods/KnightsDanServerPatch/42/media/lua/shared/KnightsDan/ContractSync.lua"))() end
end
KnightsDan={}
function isServer() return true end
local player={md={},name="Gogi"}
function player:getModData() return self.md end
function player:getUsername() return self.name end
function getSpecificPlayer(i) return i==0 and player end
function PZLinuxGetCharacterKey() return "Gogi:character1" end
function KnightsDan.key() return PZLinuxGetCharacterKey() end
function KnightsDan.member(r,p) return r.knightsMembers[KnightsDan.key(p)]~=nil end
local record={id="job22",status="accepted",contractId=8,reward=42000,
    acceptedBy="Gogi",knightsMembers={["Gogi:character1"]="Gogi"}}
local world={active={job22=record},byPlayer={Gogi="job22"}}
function PZLinuxContractsGetWorldData() return world end
function PZLinuxContractsSyncWorldRecordToPlayer(p,r)
    p.md.PZLinuxContractId=r.id;p.md.PZLinuxActiveContract=1;p.md.PZLinuxContractProtect=1;p.md.PZLinuxOnReward=r.reward
end
function PZLinuxContractsEnsureContractNote() end
local reply,request
function sendServerCommand(p,m,c,r) reply=r end
assert(loadfile("custom-mods/KnightsDanServerPatch/42/media/lua/server/zzzzzzz_KnightsDanContractSyncServer.lua"))()
handlers.OnClientCommand[1]("KnightsDanContractSync","sync",player,{sequence=1,knownId=""})
assert(reply.ok and reply.state.PZLinuxContractProtect==1 and reply.state.PZLinuxContractId=="job22")
player.md={PZLinuxActiveContract=0,PZLinuxContractProtect=0,PZLinuxContractId=""}
local now=0
function getTimestampMs() return now end
function sendClientCommand(p,m,c,args) request=args end
assert(loadfile("custom-mods/KnightsDanServerPatch/42/media/lua/client/zzzzzzz_KnightsDanContractSyncClient.lua"))()
handlers.OnCreatePlayer[1](0)
assert(request.sequence==1,"join must sync even with active state zero")
handlers.OnServerCommand[1]("KnightsDanContractSync","state",reply)
assert(player.md.PZLinuxContractProtect==1 and player.md.PZLinuxOnReward==42000)
handlers.OnFillWorldObjectContextMenu[1](0,{}, {}, false)
assert(request.sequence==1,"right-click requests are rate limited")
now=2001;handlers.OnFillWorldObjectContextMenu[1](0,{}, {}, false)
assert(request.sequence==2)
-- An old empty reply must not erase an accept that arrived in the meantime.
handlers.OnServerCommand[1]("KnightsDanContractSync","state",{ok=true,sequence=2,requestedId="",username="Gogi",
    characterKey="Gogi:character1",state={PZLinuxContractId="",PZLinuxActiveContract=0,PZLinuxContractProtect=0}})
assert(player.md.PZLinuxContractId=="job22")
record.knightsMembers={}
handlers.OnClientCommand[1]("KnightsDanContractSync","sync",player,{sequence=3,knownId="job22"})
assert(not reply.ok and reply.error=="not_participant","replacement characters/outsiders must not inherit the job")
return "direct owned-contract snapshot restores zero client state; throttling, old-empty-reply and participant guards"
