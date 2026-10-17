require "KnightsDan/Core"
require "KnightsDan/ContractSync"
if not isServer() then return end
local K=KnightsDan
Events.OnClientCommand.Add(function(module, command, player, args)
    if module~="KnightsDanContractSync" or command~="sync" or not player or type(args)~="table" then return end
    if type(args.sequence)~="number" or args.sequence~=args.sequence then return end
    local world=PZLinuxContractsGetWorldData()
    local md=player:getModData()
    local record=world.active[tostring(md.PZLinuxContractId or "")]
        or world.active[tostring(world.byPlayer[player:getUsername()] or "")]
    local result={sequence=args.sequence, requestedId=args.knownId or "", username=player:getUsername(),
        characterKey=K.key(player), ok=true, state={}}
    if record and record.status~="completed" and record.status~="cancelled" then
        if (record.knightsMembers and not K.member(record,player))
            or (not record.knightsMembers and record.acceptedBy~=player:getUsername()) then
            result.ok=false; result.error="not_participant"
        else
            local previous=tonumber(md.PZLinuxActiveContract) or 0
            local previousProtect=tonumber(md.PZLinuxContractProtect) or 0
            PZLinuxContractsSyncWorldRecordToPlayer(player,record)
            PZLinuxContractsEnsureContractNote(player,record)
            for key,default in pairs(K.contractSyncFields) do
                result.state[key]=md[key]~=nil and md[key] or default
            end
            if previous~=md.PZLinuxActiveContract or previousProtect~=md.PZLinuxContractProtect then
                print("[KD_CONTRACT_SYNC] "..player:getUsername().." record="..record.id
                    .." active="..tostring(previous).."->"..tostring(md.PZLinuxActiveContract)
                    .." protect="..tostring(previousProtect).."->"..tostring(md.PZLinuxContractProtect))
            end
        end
    elseif (tonumber(md.PZLinuxActiveContract) or 0)>0 and not record then
        result.ok=false;result.error="record_missing"
    else
        for key,default in pairs(K.contractSyncFields) do result.state[key]=default end
    end
    sendServerCommand(player,"KnightsDanContractSync","state",result)
end)
