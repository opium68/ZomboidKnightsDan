require "KnoxEscapeQuest/Shared"

local KEQ = KnoxEscapeQuest
local suppressionUntilMs = 0
local lastSuppressionTickMs = 0

local function nowWorldHours()
    return getGameTime():getWorldAgeHours()
end

local function randomIndex(count)
    count = math.max(1, tonumber(count) or 1)
    if ZombRand then return ZombRand(count) + 1 end
    return math.random(count)
end

local function resetProgressFields(state, actor)
    state.stage = 0
    state.panelStep = 0
    state.defenseEndHour = 0
    state.lastWaveHour = -1
    state.escaped = {}
    state.lastActor = tostring(actor or "")
end

local function chooseTargets(state, force)
    if force or not KEQ.HospitalCandidates[tonumber(state.hospitalTargetIndex) or 0] then
        state.hospitalTargetIndex = randomIndex(#KEQ.HospitalCandidates)
    end
    if force or not KEQ.LabCandidates[tonumber(state.labTargetIndex) or 0] then
        state.labTargetIndex = randomIndex(#KEQ.LabCandidates)
    end

    local valid = {}
    for i = 1, 3 do
        local index = tonumber(state["panel" .. tostring(i)]) or 0
        if not KEQ.SubstationPanels[index] or valid[index] then valid = nil break end
        valid[index] = true
    end
    if force or not valid then
        local pool = { 1, 2, 3, 4 }
        for i = #pool, 2, -1 do
            local j = randomIndex(i)
            pool[i], pool[j] = pool[j], pool[i]
        end
        state.panel1, state.panel2, state.panel3 = pool[1], pool[2], pool[3]
    end
end

local function getState()
    local state = ModData.getOrCreate(KEQ.DATA_KEY)
    local previousVersion = tonumber(state.version) or 0
    state.surveys = state.surveys or {}
    state.surveySequence = tonumber(state.surveySequence) or 0

    if previousVersion < KEQ.VERSION then
        state.version = KEQ.VERSION
        state.migratedFromVersion = previousVersion
        state.migratedAtWorldHour = nowWorldHours()
        chooseTargets(state, true)
        resetProgressFields(state, "version-migration")
        print("[KnoxEscapeQuest] migrated world data from version " .. tostring(previousVersion) ..
            " to " .. tostring(KEQ.VERSION) .. "; quest progress reset, world preserved")
    else
        state.version = KEQ.VERSION
        chooseTargets(state, false)
        state.stage = math.max(0, math.min(KEQ.FINAL_STAGE, tonumber(state.stage) or 0))
        state.panelStep = math.max(0, math.min(3, tonumber(state.panelStep) or 0))
        state.defenseEndHour = tonumber(state.defenseEndHour) or 0
        state.lastWaveHour = tonumber(state.lastWaveHour) or -1
        state.escaped = state.escaped or {}
        state.lastActor = tostring(state.lastActor or "")
    end
    return state
end

local function persist()
    if ModData.transmit then pcall(ModData.transmit, KEQ.DATA_KEY) end
end

local function activeTarget(state)
    local stage = tonumber(state.stage) or 0
    if stage == 0 then return KEQ.FixedTargets.checkpoint end
    if stage == 1 then return KEQ.HospitalCandidates[tonumber(state.hospitalTargetIndex) or 1] end
    if stage == 2 then
        local step = tonumber(state.panelStep) or 0
        if step < 3 then
            local panelIndex = tonumber(state["panel" .. tostring(step + 1)]) or 1
            return KEQ.SubstationPanels[panelIndex]
        end
        return KEQ.FixedTargets.substationTerminal
    end
    if stage == 3 then return KEQ.FixedTargets.lbmwTransmitter end
    if stage == 4 then return KEQ.FixedTargets.lbmwBroadcast end
    if stage == 5 then return KEQ.FixedTargets.bunkerAccess end
    if stage == 6 then return KEQ.LabCandidates[tonumber(state.labTargetIndex) or 1] end
    if stage == 7 then return KEQ.FixedTargets.caveRadio end
    if stage == 8 then return KEQ.FixedTargets.surfaceTransmitter end
    if stage == KEQ.DEFENSE_STAGE then
        return {
            id = KEQ.Helipad.id,
            x = KEQ.Helipad.centerX,
            y = KEQ.Helipad.centerY,
            z = KEQ.Helipad.z,
            radius = 12,
        }
    end
    return nil
end

local function escapedNames(state)
    local names = {}
    for username, didEscape in pairs(state.escaped or {}) do
        if didEscape then names[#names + 1] = tostring(username) end
    end
    table.sort(names)
    return table.concat(names, ", ")
end

local function statePayload(state)
    local target = activeTarget(state)
    return {
        version = KEQ.VERSION,
        stage = tonumber(state.stage) or 0,
        defenseEndHour = tonumber(state.defenseEndHour) or 0,
        escaped = escapedNames(state),
        panelProgress = tonumber(state.panelStep) or 0,
        panelTotal = 3,
        targetId = target and target.id or "",
        targetX = target and target.x or 0,
        targetY = target and target.y or 0,
        targetZ = target and target.z or 0,
        targetRadius = target and target.radius or 0,
        actionSeconds = KEQ.GetActionSeconds(),
    }
end

local function eachOnlinePlayer(callback)
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return end
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player then callback(player) end
    end
end

local function sendState(player, command, messageKey, actor)
    local state = getState()
    local payload = statePayload(state)
    payload.messageKey = messageKey
    payload.actor = actor
    sendServerCommand(player, KEQ.MODULE, command or "state", payload)
end

local function broadcast(command, messageKey, actor)
    eachOnlinePlayer(function(player)
        sendState(player, command or "notify", messageKey, actor)
    end)
end

local function resetState(actor, reroll)
    local state = getState()
    if reroll then chooseTargets(state, true) end
    resetProgressFields(state, actor)
    persist()
    broadcast("notify", reroll and "IGUI_KEQ_Notice_Rerolled" or "IGUI_KEQ_Notice_Reset", actor)
end

local function setStage(stage, actor)
    local state = getState()
    state.stage = math.max(0, math.min(KEQ.FINAL_STAGE, tonumber(stage) or 0))
    state.defenseEndHour = 0
    state.lastWaveHour = -1
    if state.stage == 2 then state.panelStep = 0 end
    state.lastActor = tostring(actor or "")
    persist()
    broadcast("notify", "IGUI_KEQ_Notice_StageChanged", actor)
end

local completionKeys = {
    [0] = "IGUI_KEQ_Notice_Checkpoint",
    [1] = "IGUI_KEQ_Notice_Sample",
    [2] = "IGUI_KEQ_Notice_Power",
    [3] = "IGUI_KEQ_Notice_Transmitter",
    [4] = "IGUI_KEQ_Notice_Broadcast",
    [5] = "IGUI_KEQ_Notice_Access",
    [6] = "IGUI_KEQ_Notice_Analysis",
    [7] = "IGUI_KEQ_Notice_EmergencyFrequency",
    [8] = "IGUI_KEQ_Notice_Defense",
}

local function startDefense(state, actor)
    local hours = tonumber(KEQ.GetSandboxValue("FinalDefenseHours", 2)) or 2
    state.stage = KEQ.DEFENSE_STAGE
    state.defenseEndHour = nowWorldHours() + math.max(1, hours)
    state.lastWaveHour = -1
    state.lastActor = tostring(actor or "")
end

local function advanceStage(player, requestedTargetId)
    local state = getState()
    local stage = tonumber(state.stage) or 0
    if stage < 0 or stage > 8 then return false, "inactive-stage" end

    local target = activeTarget(state)
    if not target or tostring(requestedTargetId or "") ~= tostring(target.id or "") then
        return false, "stale-target"
    end
    if not KEQ.IsPlayerNearTarget(player, target) then return false, "outside-target" end

    local actor = tostring(player:getUsername() or player:getDisplayName() or "unknown")
    if stage == 2 and (tonumber(state.panelStep) or 0) < 3 then
        state.panelStep = (tonumber(state.panelStep) or 0) + 1
        state.lastActor = actor
        persist()
        broadcast("notify", "IGUI_KEQ_Notice_PanelProgress", actor)
        broadcast("announceObjective", nil, nil)
        print("[KnoxEscapeQuest] substation panel completed by " .. actor ..
            "; progress=" .. tostring(state.panelStep) .. "/3")
        return true
    end

    if stage == 8 then
        startDefense(state, actor)
    else
        state.stage = stage + 1
        state.lastActor = actor
    end
    persist()
    broadcast("notify", completionKeys[stage], actor)
    broadcast("announceObjective", nil, nil)
    print("[KnoxEscapeQuest] stage " .. tostring(stage) .. " completed by " .. actor ..
        "; next=" .. tostring(state.stage))
    return true
end

local function onlineLivingCount()
    local count = 0
    eachOnlinePlayer(function(player)
        if not player:isDead() then count = count + 1 end
    end)
    return count
end

local function emitExtractionSound()
    local zone = KEQ.Helipad
    if addSound then pcall(addSound, nil, zone.centerX, zone.centerY, zone.z, 300, 100) end
end

local function spawnDefenseWave()
    emitExtractionSound()
    if KEQ.GetSandboxValue("SpawnDefenseWaves", true) ~= true then return end
    if not addZombiesInOutfit then
        print("[KnoxEscapeQuest] addZombiesInOutfit unavailable; using sound attraction only")
        return
    end

    local base = tonumber(KEQ.GetSandboxValue("BaseWaveZombies", 6)) or 6
    local perPlayer = tonumber(KEQ.GetSandboxValue("ZombiesPerPlayer", 2)) or 2
    local maximum = tonumber(KEQ.GetSandboxValue("MaximumWaveZombies", 24)) or 24
    local total = math.max(0, math.min(maximum, base + onlineLivingCount() * perPlayer))
    if total <= 0 then return end

    local zone = KEQ.Helipad
    local points = {
        { x = zone.centerX + 18, y = zone.centerY },
        { x = zone.centerX - 18, y = zone.centerY },
        { x = zone.centerX, y = zone.centerY + 18 },
        { x = zone.centerX, y = zone.centerY - 18 },
    }
    local remaining = total
    for i = 1, #points do
        if remaining <= 0 then break end
        local slotsLeft = #points - i + 1
        local count = math.ceil(remaining / slotsLeft)
        local ok, err = pcall(addZombiesInOutfit, points[i].x, points[i].y, zone.z, count, nil, 0)
        if not ok then
            print("[KnoxEscapeQuest] defense wave spawn failed safely: " .. tostring(err))
            break
        end
        remaining = remaining - count
    end
    print("[KnoxEscapeQuest] spawned final defense wave count=" .. tostring(total))
end

local function killZombiesNearHelipad()
    local cell = getCell and getCell() or nil
    local list = cell and cell:getZombieList() or nil
    if not list then return 0, 0 end

    local zone, killed, failed = KEQ.Helipad, 0, 0
    local buffer = tonumber(zone.suppressionBuffer) or 16
    for i = list:size() - 1, 0, -1 do
        local zombie = list:get(i)
        if zombie and not zombie:isDead() then
            local x, y = tonumber(zombie:getX()) or 0, tonumber(zombie:getY()) or 0
            local z = math.floor((tonumber(zombie:getZ()) or 0) + 0.5)
            if z == zone.z and
                x >= zone.minX - buffer and x <= zone.maxX + buffer and
                y >= zone.minY - buffer and y <= zone.maxY + buffer then
                -- In B42 Kill() runs the kill callback but does not create a
                -- corpse. die() performs both Kill() and becomeCorpse(), so
                -- clients receive the completed death instead of a 0-health
                -- zombie that can remain standing.
                local ok, err = pcall(zombie.die, zombie)
                if ok then
                    killed = killed + 1
                else
                    -- Removal is a last-resort safety path: the extraction
                    -- zone must not retain an active zombie if death fails.
                    local removed, removeErr = pcall(function()
                        zombie:removeFromWorld()
                        zombie:removeFromSquare()
                    end)
                    if removed then
                        killed = killed + 1
                    else
                        failed = failed + 1
                        print("[KnoxEscapeQuest] rooftop zombie suppression failed: " ..
                            tostring(err) .. "; removal=" .. tostring(removeErr))
                    end
                end
            end
        end
    end
    return killed, failed
end

local function completeExtraction(state)
    local escapedNow, escapedSet = {}, {}
    eachOnlinePlayer(function(player)
        if not player:isDead() and KEQ.IsPlayerInHelipad(player) then
            local username = tostring(player:getUsername() or player:getDisplayName() or "unknown")
            state.escaped[username] = true
            escapedSet[username] = true
            escapedNow[#escapedNow + 1] = username
        end
    end)

    if #escapedNow == 0 then
        state.stage = 8
        state.defenseEndHour = 0
        state.lastWaveHour = -1
        persist()
        broadcast("notify", "IGUI_KEQ_Notice_DefenseFailed", nil)
        broadcast("announceObjective", nil, nil)
        print("[KnoxEscapeQuest] extraction failed: no living player inside the helipad")
        return
    end

    table.sort(escapedNow)
    state.stage = KEQ.FINAL_STAGE
    state.defenseEndHour = 0
    state.lastWaveHour = -1
    persist()

    local nowMs = getTimestampMs and getTimestampMs() or 0
    suppressionUntilMs = nowMs + 30000
    lastSuppressionTickMs = 0
    local killed, failed = killZombiesNearHelipad()
    local names = table.concat(escapedNow, ", ")

    eachOnlinePlayer(function(player)
        local username = tostring(player:getUsername() or player:getDisplayName() or "unknown")
        local payload = statePayload(state)
        payload.success = escapedSet[username] == true
        payload.escapedNow = names
        sendServerCommand(player, KEQ.MODULE, "ending", payload)
    end)
    print("[KnoxEscapeQuest] campaign complete; escaped=" .. names ..
        "; rooftop zombies suppressed=" .. tostring(killed) ..
        "; failed=" .. tostring(failed))
end

local function fortifyActiveAnchor(state)
    local target = activeTarget(state)
    if not target or not getCell then return end
    local square = getCell():getGridSquare(target.x, target.y, target.z)
    if not square then return end
    local objects = square:getObjects()
    if not objects then return end
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object then
            local data = object:getModData()
            if data then data.KEQObjectiveAnchor = target.id end
            if object.setMaxHealth then pcall(object.setMaxHealth, object, 100000) end
            if object.setHealth then pcall(object.setHealth, object, 100000) end
        end
    end
end

local function onEveryTenMinutes()
    if not KEQ.IsEnabled() then return end
    local state = getState()
    fortifyActiveAnchor(state)
    if tonumber(state.stage) ~= KEQ.DEFENSE_STAGE then return end
    local now = nowWorldHours()
    if now >= (tonumber(state.defenseEndHour) or 0) then
        completeExtraction(state)
        return
    end
    if tonumber(state.lastWaveHour or -1) < 0 or now - tonumber(state.lastWaveHour) >= (10 / 60) then
        state.lastWaveHour = now
        persist()
        spawnDefenseWave()
        broadcast("notify", "IGUI_KEQ_Notice_Wave", nil)
    end
end

local function onTick()
    if suppressionUntilMs <= 0 or not getTimestampMs then return end
    local nowMs = getTimestampMs()
    if nowMs >= suppressionUntilMs then
        suppressionUntilMs = 0
        return
    end
    if nowMs - lastSuppressionTickMs >= 1000 then
        lastSuppressionTickMs = nowMs
        killZombiesNearHelipad()
    end
end

local function safeValue(fallback, callback)
    local ok, value = pcall(callback)
    if not ok or value == nil then return fallback end
    return value
end

local function cleanLogValue(value)
    return tostring(value or ""):gsub("[\r\n|]", " ")
end

local function roomNameFromSquare(square)
    if not square then return "" end
    return cleanLogValue(safeValue("", function()
        local room = square:getRoom()
        local roomDef = room and room:getRoomDef() or nil
        return roomDef and roomDef:getName() or ""
    end))
end

local function nearestTargetId(x, y)
    local nearestId, nearestDistance = "unknown", nil
    for _, target in ipairs(KEQ.SurveyTargets) do
        local dx, dy = x - target.x, y - target.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if nearestDistance == nil or distance < nearestDistance then
            nearestId, nearestDistance = target.id, distance
        end
    end
    return nearestId, math.floor((nearestDistance or 0) + 0.5)
end

local function collectBuildingRooms(buildingDef, surveyId)
    local records = {}
    local rooms = safeValue(nil, function() return buildingDef and buildingDef:getRooms() or nil end)
    local count = safeValue(0, function() return rooms and rooms:size() or 0 end)
    count = math.min(tonumber(count) or 0, 250)

    for index = 0, count - 1 do
        local roomDef = safeValue(nil, function() return rooms:get(index) end)
        if roomDef then
            local name = cleanLogValue(safeValue("", function() return roomDef:getName() end))
            local z = safeValue("?", function() return roomDef:getZ() end)
            local x1 = safeValue("?", function() return roomDef:getX() end)
            local y1 = safeValue("?", function() return roomDef:getY() end)
            local x2 = safeValue("?", function() return roomDef:getX2() end)
            local y2 = safeValue("?", function() return roomDef:getY2() end)
            local rectCount = safeValue(0, function()
                local rects = roomDef:getRects()
                return rects and rects:size() or 0
            end)
            local record = "index=" .. tostring(index) ..
                "|name=" .. name .. "|z=" .. tostring(z) ..
                "|bounds=" .. tostring(x1) .. "," .. tostring(y1) .. "-" .. tostring(x2) .. "," .. tostring(y2) ..
                "|rects=" .. tostring(rectCount)
            records[#records + 1] = record
            print("[KnoxEscapeQuest][SURVEY][ROOM] id=" .. tostring(surveyId) .. " " .. record)
        end
    end
    return records
end

local function collectNearbyObjects(centerX, centerY, centerZ, surveyId)
    local records = {}
    local cell = safeValue(nil, function() return getCell() end)
    if not cell then return records end

    local radius = 15
    for y = centerY - radius, centerY + radius do
        for x = centerX - radius, centerX + radius do
            if #records >= 200 then return records end
            local square = safeValue(nil, function() return cell:getGridSquare(x, y, centerZ) end)
            if square then
                local objects = safeValue(nil, function() return square:getObjects() end)
                local objectCount = safeValue(0, function() return objects and objects:size() or 0 end)
                for index = 0, (tonumber(objectCount) or 0) - 1 do
                    if #records >= 200 then return records end
                    local object = safeValue(nil, function() return objects:get(index) end)
                    if object then
                        local properties = safeValue(nil, function() return object:getProperties() end)
                        local customName = cleanLogValue(safeValue("", function()
                            return properties and properties:has("CustomName") and properties:get("CustomName") or ""
                        end))
                        local groupName = cleanLogValue(safeValue("", function()
                            return properties and properties:has("GroupName") and properties:get("GroupName") or ""
                        end))
                        local container = safeValue(nil, function() return object:getContainer() end)
                        local containerType = cleanLogValue(safeValue("", function()
                            return container and container:getType() or ""
                        end))
                        local hasDevice = safeValue(false, function() return object:getDeviceData() ~= nil end)

                        if customName ~= "" or groupName ~= "" or containerType ~= "" or hasDevice then
                            local objectName = cleanLogValue(safeValue("", function() return object:getObjectName() end))
                            local spriteName = cleanLogValue(safeValue("", function()
                                local sprite = object:getSprite()
                                return sprite and sprite:getName() or ""
                            end))
                            local roomName = roomNameFromSquare(square)
                            local record = "pos=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(centerZ) ..
                                "|room=" .. roomName .. "|name=" .. objectName ..
                                "|custom=" .. customName .. "|group=" .. groupName ..
                                "|sprite=" .. spriteName .. "|container=" .. containerType ..
                                "|device=" .. tostring(hasDevice)
                            records[#records + 1] = record
                            print("[KnoxEscapeQuest][SURVEY][OBJECT] id=" .. tostring(surveyId) .. " " .. record)
                        end
                    end
                end
            end
        end
    end
    return records
end

local function surveyLocation(player)
    local square = safeValue(nil, function() return player:getCurrentSquare() end)
    if not square then return false, "current square unavailable" end

    local x = math.floor(tonumber(player:getX()) or 0)
    local y = math.floor(tonumber(player:getY()) or 0)
    local z = math.floor(tonumber(player:getZ()) or 0)
    local actor = cleanLogValue(safeValue("admin", function()
        return player:getUsername() or player:getDisplayName() or "admin"
    end))
    local currentRoom = roomNameFromSquare(square)
    local building = safeValue(nil, function() return square:getBuilding() end)
    local buildingDef = safeValue(nil, function() return building and building:getDef() or nil end)
    if not buildingDef then
        buildingDef = safeValue(nil, function()
            local world = getWorld()
            local metaGrid = world and world:getMetaGrid() or nil
            return metaGrid and metaGrid:getAssociatedBuildingAt(x, y) or nil
        end)
    end
    local buildingId = cleanLogValue(safeValue("none", function()
        if buildingDef.getIDString then return buildingDef:getIDString() end
        if buildingDef.getID then return buildingDef:getID() end
        return "unknown"
    end))

    local state = getState()
    state.surveySequence = (tonumber(state.surveySequence) or 0) + 1
    local surveyId = state.surveySequence
    local targetId, targetDistance = nearestTargetId(x, y)

    print("[KnoxEscapeQuest][SURVEY] BEGIN id=" .. tostring(surveyId) ..
        " actor=" .. actor .. " pos=" .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) ..
        " target=" .. targetId .. " targetDistance=" .. tostring(targetDistance) ..
        " building=" .. buildingId .. " currentRoom=" .. currentRoom)

    local rooms = collectBuildingRooms(buildingDef, surveyId)
    local objects = collectNearbyObjects(x, y, z, surveyId)
    state.surveys[#state.surveys + 1] = {
        id = surveyId,
        actor = actor,
        worldHour = nowWorldHours(),
        x = x, y = y, z = z,
        target = targetId,
        targetDistance = targetDistance,
        buildingId = buildingId,
        currentRoom = currentRoom,
        rooms = table.concat(rooms, "\n"),
        objects = table.concat(objects, "\n"),
    }
    while #state.surveys > 24 do table.remove(state.surveys, 1) end
    persist()

    print("[KnoxEscapeQuest][SURVEY] END id=" .. tostring(surveyId) ..
        " rooms=" .. tostring(#rooms) .. " objects=" .. tostring(#objects))
    sendServerCommand(player, KEQ.MODULE, "surveyResult", {
        surveyId = surveyId,
        room = currentRoom ~= "" and currentRoom or nil,
        roomCount = #rooms,
        objectCount = #objects,
    })
    return true
end

local function onClientCommand(module, command, player, args)
    if module ~= KEQ.MODULE or not player or not KEQ.IsEnabled() then return end
    if command == "requestState" then
        local username = tostring(player:getUsername() or player:getDisplayName() or "unknown")
        local access = player.getAccessLevel and tostring(player:getAccessLevel() or "") or ""
        print("[KnoxEscapeQuest] state requested by " .. username .. "; access=" .. access)
        sendState(player, "state", nil, nil)
        return
    end
    if command == "activateStage" then
        local state = getState()
        if tonumber(args and args.stage) ~= tonumber(state.stage) then
            sendState(player, "notify", "IGUI_KEQ_Notice_Stale", nil)
            return
        end
        local ok, reason = advanceStage(player, args and args.targetId)
        if not ok then
            local key = reason == "outside-target" and "IGUI_KEQ_Notice_TooFar" or "IGUI_KEQ_Notice_Stale"
            sendState(player, "notify", key, nil)
        end
        return
    end
    if not KEQ.IsAdmin(player) then return end
    local actor = tostring(player:getUsername() or player:getDisplayName() or "admin")
    if command == "adminSurvey" then
        local ok, completed, reason = pcall(surveyLocation, player)
        if not ok or completed ~= true then
            local failure = ok and tostring(reason or "unknown") or tostring(completed or "unknown")
            print("[KnoxEscapeQuest][SURVEY] failed actor=" .. actor .. " reason=" .. failure)
            sendServerCommand(player, KEQ.MODULE, "surveyError", { reason = failure })
        end
    elseif command == "adminReset" then
        resetState(actor, false)
    elseif command == "adminReroll" then
        resetState(actor, true)
    elseif command == "adminPrevious" then
        setStage((tonumber(getState().stage) or 0) - 1, actor)
    elseif command == "adminNext" then
        local state = getState()
        local nextStage = (tonumber(state.stage) or 0) + 1
        if tonumber(state.stage) == 8 then
            startDefense(state, actor)
            persist()
            broadcast("notify", "IGUI_KEQ_Notice_StageChanged", actor)
        else
            setStage(nextStage, actor)
        end
    end
end

local function onServerStarted()
    local state = getState()
    persist()
    print("[KnoxEscapeQuest] server module active; version=" .. tostring(KEQ.VERSION) ..
        " stage=" .. tostring(state.stage) ..
        " hospital=" .. tostring(state.hospitalTargetIndex) ..
        " panels=" .. tostring(state.panel1) .. "," .. tostring(state.panel2) .. "," .. tostring(state.panel3) ..
        " lab=" .. tostring(state.labTargetIndex))
end

Events.OnClientCommand.Add(onClientCommand)
Events.EveryTenMinutes.Add(onEveryTenMinutes)
Events.OnTick.Add(onTick)
Events.OnServerStarted.Add(onServerStarted)
