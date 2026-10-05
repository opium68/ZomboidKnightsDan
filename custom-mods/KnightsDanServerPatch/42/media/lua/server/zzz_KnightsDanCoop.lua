require "zzz_KnightsDanEconomy"
require "KnightsDan/Core"
local K = KnightsDan
local original = {
    accept=PZLinuxContractsApplyAccept, complete=PZLinuxContractsApplyComplete,
    lookup=PZLinuxContractsGetPlayerWorldRecord, active=PZLinuxContractsGetActiveState,
    sync=PZLinuxContractsSyncRecordToParticipants, reconcile=PZLinuxContractsReconcilePlayerZombieKills,
    death=PZLinuxContractsApplyServerZombieDeath, cancel=PZLinuxContractsApplyCancel,
    world=PZLinuxContractsApplyWorldEvent, deposit=PZLinuxContractsApplyDeposit,
    bank=PZLinuxLoadBankBalance,
}
local function username(p) return PZLinuxGetPlayerKey(p) end
local function terminal(record) return record.status=="completed" or record.status=="cancelled" end
local function idle(p) return (tonumber(p:getModData().PZLinuxActiveContract) or 0)==0 end
local function nearby(a,b)
    return a:getZ()==b:getZ() and math.abs(a:getX()-b:getX())<=10 and math.abs(a:getY()-b:getY())<=10
end
local function notify(p,message)
    sendServerCommand(p,"KnightsDan","notice",{message=message})
end
function K.settle(player)
    if K.settling then return end
    K.settling=true
    local key=K.key(player)
    local pending=K.store().payouts[key] or {}
    for id, entry in pairs(pending) do
        if not entry.paid then
            local credit=PZLinuxApplyBankCredit(player,entry.amount,"knights-coop-contract",id)
            if credit.ok then
                -- Credit and receipt mutate the same synchronous server tick;
                -- both are persisted with the world/player mod-data save.
                entry.paid=true
                local _,data=PZLinuxGetModData(player)
                data.contracts=data.contracts or {}
                data.contracts.pendingCompletion={id=id,worldContractId=id,contractId=entry.contractId,
                    amount=entry.amount,moneyEarned=entry.amount,zombieCount=entry.zombieCount,
                    completedHour=entry.hour}
                PZLinuxApplyReputationDelta(player,PZLinux.Economy.contractCompleteReward())
                PZLinuxContractsRemoveContractNote(player)
                PZLinuxContractsClearState(player:getModData())
                PZLinuxTransmitPlayerModData(player)
            end
        end
    end
    K.settling=false
end
PZLinuxLoadBankBalance=function(player)
    local balance=original.bank(player)
    local p=PZLinuxGetPlayer(player)
    if p and not K.settling then K.settle(p); balance=original.bank(p) end
    return balance
end
PZLinuxContractsGetPlayerWorldRecord=function(player,expected)
    local p=PZLinuxGetPlayer(player)
    local record=p and K.active(p)
    if K.member(record,p) and not terminal(record) and tonumber(record.contractId)==tonumber(expected) then return record end
    local fallback=original.lookup(player,expected)
    if fallback and fallback.knightsMembers and not K.member(fallback,p) then return nil end
    return fallback
end
PZLinuxContractsSyncRecordToParticipants=function(record)
    if not record.knightsMembers then return original.sync(record) end
    K.players(function(p)
        if K.member(record,p) and not terminal(record) then
            PZLinuxContractsSyncWorldRecordToPlayer(p,record)
        end
    end)
end
PZLinuxContractsGetActiveState=function(player,requestId)
    local p=PZLinuxGetPlayer(player)
    if p then
        K.settle(p)
        local world=PZLinuxContractsGetWorldData()
        local record=K.active(p) or PZLinuxContractsGetWorldContract(world.byPlayer[username(p)])
        if record and record.knightsMembers and not K.member(record,p) then
            -- A replacement character must not inherit its predecessor's job.
            if world.byPlayer[username(p)]==record.id then world.byPlayer[username(p)]=nil end
            PZLinuxContractsClearState(p:getModData())
        end
    end
    return original.active(player,requestId)
end
PZLinuxContractsApplyAccept=function(player,state,requestId)
    local p=PZLinuxGetPlayer(player)
    if not p then return {ok=false,error="no_player",requestId=requestId} end
    local key=K.key(p)
    for leader,registered in pairs(K.store().parties) do
        if leader~=key and registered[key] then return {ok=false,error="knights_party_leader_accepts",requestId=requestId} end
    end
    local party=K.store().parties[key] or {[key]=username(p)}
    -- Validate every registered character before consuming the board offer.
    for member in pairs(party) do
        local buddy=K.online(member)
        if not buddy or not idle(buddy) or not nearby(p,buddy) then
            return {ok=false,error="knights_party_not_ready",requestId=requestId}
        end
    end
    local result=original.accept(player,state,requestId)
    if not result.ok then return result end
    local record=K.active(p)
    if not record then error("KnightsDan: accepted contract has no world record") end
    record.knightsMembers={}
    record.knightsLeader=key
    record.knightsKills={}
    record.claimableBy="participants"
    local world=PZLinuxContractsGetWorldData()
    for member,name in pairs(party) do
        local buddy=K.online(member)
        record.knightsMembers[member]=name
        record.knightsKills[member]={kills=buddy:getZombieKills(),pending=0}
        world.byPlayer[name]=record.id
        K.store().parties[member]=nil
    end
    K.store().parties[key]=nil
    PZLinuxContractsSyncRecordToParticipants(record)
    K.players(function(buddy)
        if K.member(record,buddy) then PZLinuxContractsEnsureContractNote(buddy,record) end
    end)
    PZLinuxContractsTransmitWorldData()
    return result
end
PZLinuxContractsReconcilePlayerZombieKills=function(player,record)
    local p=PZLinuxGetPlayer(player)
    record=record or (p and K.active(p))
    if not record or not record.knightsMembers then return original.reconcile(player,record) end
    if not K.member(record,p) then return false end
    local member=record.knightsKills[K.key(p)]
    -- The original algorithm absorbs native-death credits when the player's
    -- kill counter catches up. Keep both counters separately for each member.
    record.playerZombieKills=member.kills
    record.pendingZombieKillCredits=member.pending
    local result=original.reconcile(p,record)
    member.kills=record.playerZombieKills
    member.pending=record.pendingZombieKillCredits
    return result
end
PZLinuxContractsApplyServerZombieDeath=function(zombie)
    local attacker=PZLinuxContractsResolveZombieKiller(zombie)
    local record=attacker and K.active(attacker)
    local member=K.member(record,attacker) and record.knightsKills[K.key(attacker)]
    if member then
        record.playerZombieKills=member.kills
        record.pendingZombieKillCredits=member.pending
    end
    local result=original.death(zombie)
    if member then member.kills=record.playerZombieKills; member.pending=record.pendingZombieKillCredits end
    return result
end
PZLinuxContractsApplyComplete=function(player,state,requestId)
    local p=PZLinuxGetPlayer(player)
    local record=p and K.active(p)
    if not record or not record.knightsMembers then return original.complete(player,state,requestId) end
    if not K.member(record,p) or terminal(record) then
        return {ok=false,error="contract_not_completed",requestId=requestId}
    end
    local status=PZLinuxContractsCanonicalActiveState(record.status)
    if status~=9 and status~=10 then return {ok=false,error="contract_not_completed",requestId=requestId} end
    local store=K.store()
    local amount=PZLinuxNormalizeMoney(record.reward)+PZLinuxNormalizeMoney(record.zombieCount)*5
    local id=tostring(record.id)
    for member in pairs(record.knightsMembers) do
        store.payouts[member]=store.payouts[member] or {}
        store.payouts[member][id]=store.payouts[member][id] or {
            amount=amount,contractId=record.contractId,zombieCount=record.zombieCount or 0,
            hour=getGameTime():getWorldAgeHours(),paid=false,
        }
    end
    PZLinuxContractsMarkWorldContract(record.id,"completed",p)
    local world=PZLinuxContractsGetWorldData()
    for _,name in pairs(record.knightsMembers) do if world.byPlayer[name]==record.id then world.byPlayer[name]=nil end end
    K.players(function(buddy) if K.member(record,buddy) then K.settle(buddy) end end)
    PZLinuxContractsTransmitWorldData()
    local _,data=PZLinuxGetModData(p)
    return {ok=true,requestId=requestId,amount=amount,zombieCount=record.zombieCount,
        balance=PZLinuxLoadBankBalance(p),reputation=data.player.reputation,
        completionReceipt=data.contracts and data.contracts.pendingCompletion}
end
if original.cancel then
    PZLinuxContractsApplyCancel=function(player,requestId)
        local p=PZLinuxGetPlayer(player); local record=p and K.active(p)
        if record and record.knightsMembers and record.knightsLeader~=K.key(p) then
            return {ok=false,error="knights_leader_only",requestId=requestId}
        end
        local result=original.cancel(player,requestId)
        if result.ok and record and record.knightsMembers then
            local world=PZLinuxContractsGetWorldData()
            for _,name in pairs(record.knightsMembers) do if world.byPlayer[name]==record.id then world.byPlayer[name]=nil end end
            K.players(function(buddy)
                if K.member(record,buddy) then PZLinuxContractsRemoveContractNote(buddy); PZLinuxContractsClearState(buddy:getModData()); PZLinuxTransmitPlayerModData(buddy) end
            end)
        end
        return result
    end
end
PZLinuxContractsApplyWorldEvent=function(player,event,args,requestId)
    local p=PZLinuxGetPlayer(player)
    local id=args and (args.contractWorldId or args.worldContractId)
    local record=id and PZLinuxContractsGetWorldContract(id) or (p and K.active(p))
    if event=="decapitate" and p then
        local body=PZLinuxValidateWorldInteraction(p,args and args.target,"body",2)
        local target=body and PZLinuxContractsFindManhuntRecordForBody(body)
        if target and target.knightsMembers and not K.member(target,p) then return {ok=false,error="knights_not_participant",requestId=requestId} end
        record=target or record
    end
    if record and record.knightsMembers and not K.member(record,p) then
        return {ok=false,error="knights_not_participant",requestId=requestId}
    end
    local result=original.world(player,event,args,requestId)
    if result.ok and record and record.knightsMembers then PZLinuxContractsSyncRecordToParticipants(record) end
    return result
end
if original.deposit then
    PZLinuxContractsApplyDeposit=function(player,state,requestId)
        local p=PZLinuxGetPlayer(player); local record=p and K.active(p)
        if record and record.knightsMembers and not K.member(record,p) then return {ok=false,error="knights_not_participant",requestId=requestId} end
        if p then
            local items=p:getInventory():getItems()
            for i=0,items:size()-1 do
                local tagged=PZLinuxContractsGetWorldContract(PZLinuxContractsGetEntityContractId(items:get(i)))
                if tagged and tagged.knightsMembers and not K.member(tagged,p) then return {ok=false,error="knights_not_participant",requestId=requestId} end
            end
        end
        local result=original.deposit(player,state,requestId)
        if result.ok and record and record.knightsMembers then PZLinuxContractsSyncRecordToParticipants(record) end
        return result
    end
end
local function commands(module,command,player,args)
    if module~="KnightsDan" then return end
    args=args or {}
    local store=K.store(); local key=K.key(player)
    if command=="invite" then
        if not idle(player) then return notify(player,"진행 중인 의뢰에는 참가자를 추가할 수 없습니다.") end
        local target
        K.players(function(p) if username(p)==args.username then target=p end end)
        if not target or target==player or not idle(target) or not nearby(player,target) then return end
        store.invites[K.key(target)]={leader=key,hour=getGameTime():getWorldAgeHours()}
        notify(target,username(player).."님의 협동 의뢰 초대: 우클릭 메뉴에서 수락하세요.")
    elseif command=="join" then
        local invite=store.invites[key]
        local leader=invite and K.online(invite.leader)
        if not leader or not idle(leader) or not idle(player) or not nearby(leader,player)
            or getGameTime():getWorldAgeHours()-invite.hour>1 then return end
        -- A character can be registered in only one pending party.
        for partyLeader,party in pairs(store.parties) do
            if party[key] or (partyLeader==key and partyLeader~=invite.leader) then return notify(player,"기존 참가 등록을 먼저 취소하세요.") end
        end
        local party=store.parties[invite.leader] or {[invite.leader]=username(leader)}
        party[key]=username(player); store.parties[invite.leader]=party; store.invites[key]=nil
        notify(leader,username(player).."님 참가 등록 완료. 모두 근처에 있을 때 컴퓨터에서 의뢰를 수락하세요.")
        notify(player,"참가 등록 완료. 의뢰 수락 후에는 참가자가 고정됩니다.")
    elseif command=="leave" and idle(player) then
        for leader,party in pairs(store.parties) do
            if leader==key then store.parties[leader]=nil else party[key]=nil end
        end
        store.invites[key]=nil; notify(player,"협동 의뢰 참가 등록을 취소했습니다.")
    end
end
Events.OnClientCommand.Add(commands)
print("[KnightsDan] server cooperative contracts loaded")
