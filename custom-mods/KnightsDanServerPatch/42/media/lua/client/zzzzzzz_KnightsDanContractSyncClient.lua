require "ISPZLinuxVariablesTables"
require "KnightsDan/ContractSync"
local sessions={}
local function request(index, force)
    local player=getSpecificPlayer(index)
    if not player then return end
    local session=sessions[index] or {sequence=0,lastAt=-10000,applied=0}
    sessions[index]=session
    local now=getTimestampMs()
    if not force and now-session.lastAt<2000 then return end
    session.lastAt=now;session.sequence=session.sequence+1
    sendClientCommand(player,"KnightsDanContractSync","sync",{
        sequence=session.sequence,knownId=player:getModData().PZLinuxContractId or ""})
end
Events.OnCreatePlayer.Add(function(index) sessions[index]=nil;request(index,true) end)
Events.OnFillWorldObjectContextMenu.Add(function(index,context,objects,test)
    if not test then request(index,false) end
end)
Events.OnServerCommand.Add(function(module,command,result)
    if module~="KnightsDanContractSync" or command~="state" or type(result)~="table"
        or not result.ok or type(result.state)~="table" then return end
    for index,session in pairs(sessions) do
        local player=getSpecificPlayer(index)
        if player and player:getUsername()==result.username
            and tonumber(result.sequence) and result.sequence>session.applied then
            local key=PZLinuxGetCharacterKey(player,false)
            if key and key~=result.characterKey then return end
            local md=player:getModData()
            local state=result.state
            -- Do not let an older empty response erase a newly accepted job.
            if state.PZLinuxContractId=="" and tostring(md.PZLinuxContractId or "")~=result.requestedId then return end
            local before=tonumber(md.PZLinuxContractProtect) or 0
            for field,default in pairs(KnightsDan.contractSyncFields) do
                local value=state[field]
                if type(value)==type(default) then md[field]=value end
            end
            session.applied=result.sequence
            if before~=(tonumber(md.PZLinuxContractProtect) or 0) then
                print("[KD_CONTRACT_SYNC] client record="..tostring(md.PZLinuxContractId)
                    .." protect="..tostring(before).."->"..tostring(md.PZLinuxContractProtect))
            end
        end
    end
end)
