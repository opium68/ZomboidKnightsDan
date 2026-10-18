KnightsDan = KnightsDan or {}
local K = KnightsDan
function K.findManhuntTarget(data, state)
    local cell = getCell and getCell()
    local zombies = cell and cell:getZombieList()
    if not zombies then return nil end
    local contract = tostring(data.PZLinuxContractId or "")
    if contract == "" then return nil end
    local onlineId = state and tostring(state.contractId or "") == contract
        and tonumber(state.onlineId) or -1
    local function matches(zombie)
        if not zombie or zombie:isDead() or not zombies:contains(zombie) then return false end
        local square = zombie:getSquare()
        if not square or not square:getMovingObjects():contains(zombie) then return false end
        local tag = zombie:getModData()
        return (onlineId and onlineId >= 0 and tonumber(zombie:getOnlineID()) == onlineId)
            or (tostring(tag.PZLinuxContractId or "") == contract
                and tag.PZLinuxContractObjective == "manhunt"
                and tonumber(tag.PZLinuxManhuntVersion) == 4)
    end
    if state and matches(state.zombie) then return state.zombie end
    for index=0,zombies:size()-1 do
        local zombie=zombies:get(index)
        if matches(zombie) then return zombie end
    end
end

function K.adaptManhuntClientSource(source)
    local startAt = assert(source:find("local function PZLinuxFindVisibleManhuntTarget(",1,true),
        "PZLinux manhunt client resolver changed")
    local endAt = assert(source:find("local function checkAndSpawnZombie(",startAt,true),
        "PZLinux manhunt client event boundary changed")
    source = source:sub(1,startAt-1)
        .. "local function PZLinuxFindVisibleManhuntTarget(data,state) return KnightsDan.findManhuntTarget(data,state) end\n\n"
        .. source:sub(endAt)
    local count
    source,count=source:gsub("PZLinuxManhuntTargetState%[playerKey%] = {",
        'PZLinuxManhuntTargetState[playerKey] = {\n contractId = tostring(result.worldContractId or ""),')
    assert(count==1,"PZLinux manhunt confirmation shape changed")
    return source
end
