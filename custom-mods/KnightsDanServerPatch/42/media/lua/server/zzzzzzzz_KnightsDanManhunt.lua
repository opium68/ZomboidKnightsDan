require "zzz_KnightsDanCoop"

-- Keep native contract authorization, death/evidence and reward transitions.
-- Only repair the spawn boundary and reject cached objects outside the world.
local originalRestore = PZLinuxContractsRestoreNearbyManhuntTarget
local originalMaintain = PZLinuxContractsMaintainManhuntTargets
local originalWorld = PZLinuxContractsApplyWorldEvent
local attempts = {}
local function now() return getTimestampMs() end
local function tagged(zombie, id)
    local data = zombie and zombie.getModData and zombie:getModData()
    return data and tostring(data.PZLinuxContractId or "") == tostring(id)
        and data.PZLinuxContractObjective == "manhunt"
end
local function registered(zombie)
    if not zombie or zombie:isDead() then return false end
    local square = zombie:getSquare()
    local cell = getCell()
    -- isExistInTheWorld uses the base 'square' field in 42.21, whereas
    -- getSquare prefers 'current'. Check actual membership at the current tile.
    return square and cell
        and square:getMovingObjects():contains(zombie)
        and cell:getZombieList():contains(zombie)
        and cell:getObjectList():contains(zombie)
        and (not isServer() or zombie:getOnlineID() >= 0)
end
local function prune(id)
    local key = tostring(id)
    local targets = PZLinux.ManhuntTargets or {}
    local cached = targets[key]
    if cached and (not tagged(cached, id) or not registered(cached)) then
        targets[key] = nil
        -- Never remove a pooled zombie that has been reused by another job.
        if tagged(cached, id) and not cached:isDead() then
            PZLinuxContractsRemoveWorldEntity(cached)
        end
        print("[KnightsDan Manhunt] discarded stale cache contract=" .. key)
    end
    local zombies = getCell() and getCell():getZombieList()
    if not zombies then return end
    -- Removal mutates the native list; traverse backwards.
    for index = zombies:size() - 1, 0, -1 do
        local zombie = zombies:get(index)
        if tagged(zombie, id) and not zombie:isDead() and not registered(zombie) then
            PZLinuxContractsRemoveWorldEntity(zombie)
        end
    end
end
local function findSquare(x, y, z)
    local cell = getCell()
    if not cell then return nil end
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local radius = tonumber(PZLinux.Config.Contracts.objectiveSpawnSearchRadius) or 15
    for distance = 0, math.max(5, math.min(30, math.floor(radius))) do
        for dx = -distance, distance do
            for dy = -distance, distance do
                if distance == 0 or math.abs(dx) == distance or math.abs(dy) == distance then
                    local square = cell:getGridSquare(x + dx, y + dy, z)
                    if square and square:isFree(false) then return square end
                end
            end
        end
    end
end

PZLinuxContractsSpawnZombieAt = function(x, y, z, id, objective)
    local key, time = tostring(id), now()
    -- Defense waves intentionally create many zombies in one synchronous call.
    -- Only the single-target manhunt path uses a per-contract retry cooldown.
    if objective == "manhunt" then
        if attempts[key] and time - attempts[key] < 5000 then return false end
        attempts[key] = time
    end
    local square = findSquare(x, y, z)
    if not square then return false end
    -- The native 42.21 overload accepts six arguments; the upstream eleven
    -- argument call has no implementation. Do not fall back to a ghost object.
    local ok, spawned = pcall(addZombiesInOutfit,
        square:getX(), square:getY(), square:getZ(), 1, nil, nil)
    local zombie = ok and spawned and spawned:size() > 0 and spawned:get(0) or nil
    if not zombie then
        print("[KnightsDan Manhunt] spawn failed contract=" .. key .. " error=" .. tostring(spawned))
        return false
    end
    if not registered(zombie) then
        PZLinuxContractsRemoveWorldEntity(zombie)
        print("[KnightsDan Manhunt] rejected unregistered spawn contract=" .. key)
        return false
    end
    PZLinuxContractsTagEntity(zombie, id, objective or "zombie", objective ~= "manhunt")
    if objective == "manhunt" then
        zombie:getModData().PZLinuxManhuntVersion = 4
        zombie:setTarget(nil)
        zombie:setUseless(false)
        zombie:setCanWalk(false)
        zombie:setAlwaysKnockedDown(true)
        zombie:setSitAgainstWall(true)
    end
    print("[KnightsDan Manhunt] registered spawn contract=" .. key
        .. " onlineId=" .. tostring(zombie:getOnlineID()))
    return true, zombie, square, "addZombiesInOutfit-6"
end

PZLinuxContractsMaintainManhuntTargets = function()
    local ids = {}
    for id in pairs(PZLinux.ManhuntTargets or {}) do table.insert(ids, id) end
    for _, id in ipairs(ids) do prune(id) end
    for id in pairs(attempts) do
        local record = PZLinuxContractsGetWorldContract(id)
        if not record or (record.status ~= "accepted" and record.status ~= "spawned") then attempts[id] = nil end
    end
    return originalMaintain()
end
local function prepare(player)
    local p = PZLinuxGetPlayer(player)
    local record = p and PZLinuxContractsGetPlayerWorldRecord(p, 3)
    if record and (record.status == "accepted" or record.status == "spawned")
        and PZLinuxIsPlayerNearPosition(p, record.locationX, record.locationY, record.locationZ,
            tonumber(PZLinux.Config.Contracts.objectiveActivationRadius) or 80) then
        prune(record.id)
    end
end
PZLinuxContractsRestoreNearbyManhuntTarget = function(player)
    prepare(player)
    return originalRestore(player)
end
PZLinuxContractsApplyWorldEvent = function(player, event, args, requestId)
    if event == "spawnManhunt" then prepare(player) end
    return originalWorld(player, event, args, requestId)
end
