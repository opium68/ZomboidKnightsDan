require "KnightsDan/Core"
local K=KnightsDan
if K.protectChase then return K.protectChase end
local C={}
K.protectChase=C
local runtime={}
local bucket,paths=-1,0
local function alive(p) return p and not p:isDead() end
local function distance(a,b)
    local x,y,z=a:getX()-b:getX(),a:getY()-b:getY(),a:getZ()-b:getZ()
    return x*x+y*y+z*z*100
end
function C.eligible(record,p)
    if not alive(p) then return false end
    if record.knightsMembers then return K.member(record,p) end
    return tostring(p:getModData().PZLinuxContractId or "")==tostring(record.id)
        and (p:getUsername()==record.owner or p:getUsername()==record.acceptedBy)
end
function C.nearest(zombie,players)
    local chosen,best
    for _,p in ipairs(players or {}) do
        if alive(p) then
            local d=distance(zombie,p)
            if not best or d<best then chosen,best=p,d end
        end
    end
    return chosen
end
function C.active(record)
    return record and tonumber(record.contractId)==8 and record.status~="completed" and record.status~="cancelled"
end
function C.release(zombie)
    local previous=runtime[zombie]
    if previous and zombie:getTarget()==previous.target then zombie:setTarget(nil) end
    runtime[zombie]=nil
end
function C.drive(zombie,target,now)
    if not alive(target) or zombie:isDead() then C.release(zombie);return end
    local state=runtime[zombie]
    local changed=not state or state.target~=target
    if not state then state={};runtime[zombie]=state end
    state.lastSeen=now
    state.target=target
    if zombie:getTarget()~=target then zombie:setTarget(target) end
    -- Native repath delay remains intact. Avoid interrupting close-range attacks.
    if distance(zombie,target)<=2.25 then return end
    local moved=not state.x or (state.x-target:getX())^2+(state.y-target:getY())^2>=9 or state.z~=target:getZ()
    if not changed and state.pathAt and now-state.pathAt<6000 then return end
    if not changed and not moved and state.pathAt and now-state.pathAt<12000 then return end
    -- Limit extra path requests across a whole local horde, including first aggro.
    local current=math.floor(now/125)
    if bucket~=current then bucket,paths=current,0 end
    if paths>=4 then return end
    paths=paths+1
    zombie:pathToCharacter(target)
    state.pathAt,state.x,state.y,state.z=now,target:getX(),target:getY(),target:getZ()
end
function C.assign(zombie,target,now)
    local md=zombie:getModData()
    local id=target and target:getOnlineID() or -1
    local key=target and K.key(target) or ""
    if md.knightsProtectTargetId~=id or md.knightsProtectTargetKey~=key then
        md.knightsProtectTargetId,md.knightsProtectTargetKey=id,key
        md.knightsProtectChase=target~=nil
        if zombie.transmitModData then zombie:transmitModData() end
    end
    -- A client-owned zombie must be driven by that client's local simulation.
    if not isServer() or not zombie:getOwner() then
        if target then C.drive(zombie,target,now) else C.release(zombie) end
    end
end
function C.sweep(now)
    local rosters={}
    local world=PZLinuxContractsGetWorldData()
    for id,record in pairs(world.active or {}) do
        if C.active(record) then
            local members={}
            K.players(function(p) if C.eligible(record,p) then members[#members+1]=p end end)
            rosters[tostring(id)]=members
        end
    end
    local cell=getCell()
    local zombies=cell and cell:getZombieList()
    if not zombies then return end
    local seen={}
    for i=0,zombies:size()-1 do
        local zombie=zombies:get(i)
        local md=zombie:hasModData() and zombie:getModData()
        if md and md.PZLinuxContractObjective=="protect" then
            seen[zombie]=true
            local target=not zombie:isDead() and C.nearest(zombie,rosters[tostring(md.PZLinuxContractId)]) or nil
            C.assign(zombie,target,now)
        end
    end
    -- Release references to dead/unloaded zombies; do not keep the map loaded.
    for zombie in pairs(runtime) do if not seen[zombie] then runtime[zombie]=nil end end
end
function C.clientStep(zombie,now)
    if zombie:isRemoteZombie() then runtime[zombie]=nil;return end
    if not zombie:hasModData() then return end
    local md=zombie:getModData()
    if not md.knightsProtectChase or md.PZLinuxContractObjective~="protect" then C.release(zombie);return end
    now=now or getTimestampMs()
    local state=runtime[zombie]
    if state and state.nextAt and now<state.nextAt then return end
    local target=getPlayerByOnlineID(tonumber(md.knightsProtectTargetId) or -1)
    if not alive(target) or PZLinuxGetCharacterKey(target,false)~=md.knightsProtectTargetKey then C.release(zombie);return end
    C.drive(zombie,target,now)
    state=runtime[zombie]
    if state then state.nextAt=now+2000+(math.abs(zombie:getOnlineID())%10)*25 end
end
function C.pruneRuntime(now)
    for zombie,state in pairs(runtime) do
        if zombie:isDead() or now-(state.lastSeen or 0)>15000 then runtime[zombie]=nil end
    end
end
return C
