require 'RCE/Logic'
RCE.Server={pending={},ready=false,lastTick=0,pinsEveryTick=true}
local S,C=RCE.Server,RCE.Config
function S.store() return ModData.getOrCreate('RaccoonExpedition') end
function S.now() return getTimestampMs()/1000 end
function S.hour() return getGameTime():getWorldAgeHours() end
function S.reply(p,code,remaining)
    sendServerCommand(p,C.module,'Status',{code=code,remaining=remaining or 0})
end
local function players()
    local out={};local online=getOnlinePlayers()
    for i=0,online:size()-1 do out[#out+1]=online:get(i) end
    return out
end
local function bridgeReady()
    return RCENativeKeep and RCENativeLoaded and RCENativeSafe and RCENativeClear and RCENativeTeleport
end
local function keep(p,r) return RCENativeKeep(p.x,p.y,r or 17) end
local function safe(p,zr) return RCENativeSafe(p.x,p.y,p.z,zr or 0) end
local function samePoint(a,b) return a.z==b.z and RCE.distance2(a,b)<=4 end
function S.terminal(p)
    local pos=RCE.position(p)
    for dx=-2,2 do for dy=-2,2 do
        local sq=getCell():getGridSquare(math.floor(pos.x)+dx,math.floor(pos.y)+dy,pos.z)
        if sq then
            local objects=sq:getObjects()
            for i=0,objects:size()-1 do
                local o=objects:get(i);local sprite=o:getSprite()
                local name=sprite and sprite:getName() or ''
                if name=='appliances_com_01_72' or name=='appliances_com_01_73'
                    or name=='appliances_com_01_74' or name=='appliances_com_01_75' then
                    local condition=o:getModData().PZLinuxComputerCondition
                    if condition==nil or condition>0 then return true end
                end
            end
        end
    end end
    return false
end
function S.cancel(p,reason)
    local key=RCE.key(p);local pending=S.pending[key]
    if pending and pending.entry then S.store().reservations[pending.entry.id]=nil end
    S.pending[key]=nil;S.reply(p,reason or 'Cancelled')
end
function S.command(p,cmd,args)
    if not S.ready or not p or p:isDead() then return end
    local key=RCE.key(p);local now=S.now()
    if cmd=='Cancel' then S.cancel(p);return end
    if S.pending[key] then S.reply(p,'Busy');return end
    if not bridgeReady() then S.reply(p,'BridgeMissing');return end
    if p:getVehicle() then S.reply(p,'LeaveVehicle');return end
    local pos=RCE.position(p);local state=S.store()
    if cmd=='Enter' then
        if RCE.inside(pos.x,pos.y) then S.reply(p,'AlreadyInside');return end
        if not S.terminal(p) then S.reply(p,'ComputerRequired');return end
        local online={};for _,other in ipairs(players()) do online[#online+1]=RCE.position(other) end
        local entry=RCE.Logic.chooseEntry(state,ZombRand,online)
        if not entry then S.reply(p,'NoEntry');return end
        state.reservations[entry.id]=key
        S.pending[key]={kind='entry',entry=entry,origin=pos,at=now,deadline=now+C.entrySeconds,player=p}
        keep(entry);S.reply(p,'Preparing',C.entrySeconds)
    elseif cmd=='Exit' then
        local exit=RCE.exitAt(pos);local participant=state.participants[key]
        if not exit then S.reply(p,'NotAtExit');return end
        if not participant or not participant.origin then S.reply(p,'NoReturnPosition');return end
        S.pending[key]={kind='exit',exit=exit,origin=participant.origin,at=now,deadline=now+C.exitSeconds,player=p,health=p:getBodyDamage():getOverallBodyHealth()}
        keep(participant.origin);S.reply(p,'Extracting',C.exitSeconds)
    end
end
function S.tick()
    if not S.ready then return end
    -- ServerMap relevance expires each frame. Pin remote destinations even
    -- while the slower countdown/safety processing is throttled.
    for _,pending in pairs(S.pending) do keep(pending.entry or pending.origin) end
    if S.now()-S.lastTick<0.25 then return end
    S.lastTick=S.now();local state=S.store();local now=S.now()
    local connected={};for _,p in ipairs(players()) do connected[RCE.key(p)]=p end
    for key,pending in pairs(S.pending) do
        local p=connected[key]
        if not p or p~=pending.player or p:isDead() then
            if pending.entry then state.reservations[pending.entry.id]=nil end
            S.pending[key]=nil
        else
            local pos=RCE.position(p)
            local valid=true;local reason
            if p:getVehicle() then valid,reason=false,'LeaveVehicle'
            elseif pending.kind=='entry' then
                valid=not RCE.inside(pos.x,pos.y) and samePoint(pos,pending.origin) and S.terminal(p)
                reason='EntryCancelled'
            else
                valid,reason=RCE.Logic.validExit(pos,pending.exit,pending.hit or p:getBodyDamage():getOverallBodyHealth()<pending.health)
            end
            if not valid then S.cancel(p,reason)
            elseif now-pending.at>C.preparationTimeout then S.cancel(p,'PreparationTimeout')
            else
                local target=pending.entry or pending.origin;keep(target)
                local remaining=math.max(0,math.ceil(pending.deadline-now))
                if remaining~=pending.lastRemaining then
                    pending.lastRemaining=remaining;S.reply(p,pending.kind=='entry' and 'Preparing' or 'Extracting',remaining)
                end
                if now>=pending.deadline and RCENativeLoaded(target.x,target.y,target.z,17) then
                    local destination
                    if pending.kind=='entry' then
                        if safe(target) then
                            -- Do not erase a fight that moved into the reserved area.
                            local near=false
                            for _,other in ipairs(players()) do
                                if other~=p then local op=RCE.position(other)
                                    if op.z==target.z and RCE.distance2(op,target)<=(C.clearRadius+2)^2 then near=true;break end
                                end
                            end
                            if near then S.cancel(p,'NoEntry') else
                                RCENativeClear(target.x,target.y,target.z,C.clearRadius)
                                if safe(target,2) then destination=target end
                            end
                        end
                    else
                        destination=RCE.Logic.findReturn(target,
                            function(point) return safe(point,3) end,
                            function(a,b) return RCENativeReachable(math.floor(a.x),math.floor(a.y),b.x,b.y,a.z) end,C.fallback)
                        if not destination then S.cancel(p,'NoSafeReturn') end
                    end
                    if destination and S.pending[key] then
                        if pending.kind=='entry' then
                            -- Persist origin BEFORE sending a teleport, so disconnecting
                            -- during transfer cannot lose a character's return location.
                            state.participants[key]={origin=RCE.copy(pending.origin),cycle=state.cycle,inside=true}
                            p:getModData().RCEOrigin=RCE.copy(pending.origin)
                            p:transmitModData()
                        end
                        if RCENativeTeleport(p,destination.x,destination.y,destination.z) then
                            if pending.entry then state.reservations[pending.entry.id]=nil end
                            -- Do not clear the participant until observed outside. This
                            -- deliberately treats interrupted transfers conservatively.
                            S.pending[key]=nil;S.reply(p,'Transferred')
                        else S.cancel(p,'TransferFailed') end
                    end
                end
            end
        end
    end
    for key,record in pairs(state.participants) do
        local p=connected[key]
        if p and not S.pending[key] and not RCE.inside(p:getX(),p:getY()) then
            record.outsideObserved=(record.outsideObserved or 0)+1
            if record.outsideObserved>=20 then record.inside=false end
        elseif p and RCE.inside(p:getX(),p:getY()) then record.inside=true;record.outsideObserved=0 end
    end
end
function S.prepare()
    if S.prepared then return end
    local state=S.store()
    if S.applyResetInstruction then S.applyResetInstruction() end
    RCE.Logic.initialize(state,S.hour(),ZombRand);state.reservations={}
    S.prepared=true
    if RCE.Loot then RCE.Loot.initialize() end
end
function S.start()
    S.prepare();local state=S.store()
    S.ready=true
    print('[RCE] Server started; cycle='..state.cycle..' ampoules='..state.totalAmpoules)
    if S.checkpoint then S.checkpoint() end
end
Events.OnServerStarted.Add(S.start)
Events.OnTick.Add(S.tick)
Events.OnClientCommand.Add(function(module,command,p,args)
    if module==C.module then S.command(p,command,args or {}) end
end)
Events.OnWeaponHitCharacter.Add(function(attacker,victim)
    if not victim or not victim.getUsername then return end
    local pending=S.pending[RCE.key(victim)]
    if pending and pending.kind=='exit' then pending.hit=true end
end)
Events.OnPlayerDeath.Add(function(p)
    if not p then return end
    S.cancel(p,'Dead');local participant=S.store().participants[RCE.key(p)]
    if participant then participant.inside=false;participant.dead=true end
    p:getModData().ProjectRPGDimensionalVault=nil
    if RCE.Persistence then RCE.Persistence.save(p,true) end
end)
