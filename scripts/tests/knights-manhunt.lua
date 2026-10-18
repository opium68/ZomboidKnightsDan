-- Execute the real PZLinux local ensure/restore functions in native Kahlua.
require "knights-coop"
local function list()
    local t = {values={}}
    function t:size() return #self.values end
    function t:get(i) return self.values[i+1] end
    function t:contains(v) for _, item in ipairs(self.values) do if item == v then return true end end return false end
    function t:add(v) table.insert(self.values, v) end
    function t:remove(v) for i=#self.values,1,-1 do if self.values[i]==v then table.remove(self.values,i) end end end
    return t
end
local moving, zombies, objects = list(), list(), list()
local square = {getX=function() return 10609 end,getY=function() return 9221 end,getZ=function() return 0 end,
    isFree=function() return true end,getMovingObjects=function() return moving end}
local loaded, time, nextId, spawnCalls = true, 1000000, 100, 0
local cell = {getGridSquare=function() if loaded then return square end end,
    getZombieList=function() return zombies end,getObjectList=function() return objects end}
function getCell() return cell end
function getTimestampMs() return time end
local current = {id="manhunt-regression",contractId=3,status="spawned",locationX=10609,locationY=9221,locationZ=0}
local p = {}
function PZLinuxGetPlayer(player) return player end
function PZLinuxContractsGetPlayerWorldRecord(player, expected) assert(expected==3); return current end
function PZLinuxIsPlayerNearPosition() return true end
function PZLinuxContractsGetWorldContract(id) if current and id==current.id then return current end end
function PZLinuxContractsSyncWorldRecordToPlayer(player,record) assert(record==current) end
function PZLinuxContractsTransmitWorldData() end
local function zombie(id, registered)
    local z={id=id,data={},dead=false}
    function z:getModData() return self.data end
    function z:isDead() return self.dead end
    function z:getSquare() return square end
    function z:getX() return 10609.5 end
    function z:getY() return 9221.5 end
    function z:getZ() return 0 end
    function z:getOnlineID() return self.id end
    function z:isExistInTheWorld() return false end -- stale base square is not sufficient to reject a real target
    function z:setTarget(value) self.target=value end
    function z:setUseless(value) self.useless=value end
    function z:setCanWalk(value) self.canWalk=value end
    function z:setAlwaysKnockedDown(value) self.knocked=value end
    function z:setSitAgainstWall(value) self.sitting=value end
    function z:removeFromWorld() zombies:remove(self);objects:remove(self);self.removed=true end
    function z:removeFromSquare() moving:remove(self) end
    if registered then moving:add(z);zombies:add(z);objects:add(z) end
    return z
end
local mode="good"
function addZombiesInOutfit(...)
    assert(select('#',...)==6,"must use a supported native 42.21 overload")
    spawnCalls=spawnCalls+1
    if mode=="throw" then error("native failure") end
    local z=zombie(nextId,mode~="ghost")
    if mode=="no-id" then z.id=-1 end
    nextId=nextId+1
    local result=list();result:add(z);return result
end
function createZombie() error("unvalidated fallback must never run") end
local stale=zombie(20,false)
stale.data={PZLinuxContractId=current.id,PZLinuxContractObjective="manhunt",PZLinuxManhuntVersion=4}
PZLinux.ManhuntTargets={[current.id]=stale}
require "zzzzzzzz_KnightsDanManhunt"
assert(PZLinuxContractsRestoreNearbyManhuntTarget(p))
local target=PZLinux.ManhuntTargets[current.id]
assert(stale.removed and target~=stale and spawnCalls==1,"stale cache repaired without cancelling the job")
assert(current.status=="spawned" and current.spawnEntityId==100)
for i=1,10 do assert(PZLinuxContractsRestoreNearbyManhuntTarget(p)) end
assert(spawnCalls==1 and not target.removed,"registered target reused even when base-square inWorld is false")
-- An object recycled for another contract must never be removed by stale cache cleanup.
target.data.PZLinuxContractId="another-job"
time=time+5000
assert(PZLinuxContractsRestoreNearbyManhuntTarget(p))
assert(not target.removed and spawnCalls==2,"foreign pooled zombie preserved")
local function removeTarget()
    local z=PZLinux.ManhuntTargets[current.id]
    if z then z:removeFromWorld();z:removeFromSquare() end
end
removeTarget();mode="ghost";time=time+5000
assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p),"unregistered spawn cannot advance objective")
local failedCalls=spawnCalls
for i=1,10 do assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p)) end
assert(spawnCalls==failedCalls,"failed attempts throttled across native maintenance and client requests")
mode="no-id";time=time+5000
assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p),"networkless spawn rejected")
mode="throw";time=time+5000
assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p),"native exceptions become retryable failures")
mode="good";loaded=false;time=time+5000
assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p),"unloaded map does not invent targets")
loaded=true;time=time+5000
assert(PZLinuxContractsRestoreNearbyManhuntTarget(p),"loaded area can recover same accepted mission")
current.status="target_down";removeTarget();time=time+5000
local before=spawnCalls
assert(not PZLinuxContractsRestoreNearbyManhuntTarget(p) and spawnCalls==before,"dead targets never respawn")
-- The same corrected API must allow every zombie in one defense wave.
mode="good"
for i=1,3 do
    local ok,z=PZLinuxContractsSpawnZombieAt(10609,9221,0,"defense","protect")
    assert(ok and z:getModData().PZLinuxContractObjective=="protect")
    assert(z.canWalk==nil and z.knocked==nil,"normal defense zombies retain native movement")
end
assert(spawnCalls==before+3,"defense wave must not be throttled as one manhunt target")
return "native ensure/restore: six-argument spawn, ghost repair/rejection, valid reuse, pooled-object safety, retry throttle, map reload, death preservation"
