KnoxEscapeQuest = KnoxEscapeQuest or {}
local KEQ = KnoxEscapeQuest

KEQ.MODULE = "KnoxEscapeQuest"
KEQ.DATA_KEY = "KnoxEscapeQuest.WorldState"
KEQ.VERSION = 2
KEQ.DEFENSE_STAGE = 9
KEQ.FINAL_STAGE = 10
KEQ.ACTION_SECONDS = 30
-- Lua timed actions use 20 ms units in B42 (50 units per real second).
KEQ.ACTION_TIME_UNITS_PER_SECOND = 50

-- Exact anchors recovered from the administrator field survey. Interactions
-- are coordinate based, so a removed or replaced map object cannot soft-lock
-- the campaign.
KEQ.FixedTargets = {
    checkpoint = { id = "checkpoint_radio", x = 12497, y = 4189, z = 0, radius = 3 },
    substationTerminal = { id = "substation_terminal", x = 14731, y = 4084, z = 0, radius = 4 },
    lbmwTransmitter = { id = "lbmw_transmitter", x = 12475, y = 1759, z = 1, radius = 4 },
    lbmwBroadcast = { id = "lbmw_broadcast", x = 12489, y = 1778, z = 0, radius = 7 },
    bunkerAccess = { id = "bunker_access", x = 5574, y = 12488, z = 0, radius = 7 },
    caveRadio = { id = "cave_radio", x = 5689, y = 12437, z = -17, radius = 4 },
    surfaceTransmitter = { id = "surface_transmitter", x = 5542, y = 12444, z = 1, radius = 7 },
}

KEQ.HospitalCandidates = {
    { id = "hospital_sample_1", x = 12944, y = 2038, z = 0, radius = 4 },
    { id = "hospital_sample_2", x = 12946, y = 2039, z = 0, radius = 4 },
    { id = "hospital_sample_3", x = 12948, y = 2040, z = 0, radius = 4 },
    { id = "hospital_sample_4", x = 12949, y = 2040, z = 0, radius = 4 },
}

-- Four separate switch rooms; a new campaign selects three and preserves the
-- selection in GlobalModData across restarts.
KEQ.SubstationPanels = {
    { id = "substation_panel_1", x = 14768, y = 4065, z = 0, radius = 3 },
    { id = "substation_panel_2", x = 14778, y = 4065, z = 0, radius = 3 },
    { id = "substation_panel_3", x = 14769, y = 4106, z = 0, radius = 3 },
    { id = "substation_panel_4", x = 14778, y = 4106, z = 0, radius = 3 },
}

-- Thirteen surveyed laboratory rooms. The target is selected once per
-- campaign. A generous radius keeps furniture layout from blocking use.
KEQ.LabCandidates = {
    { id = "bunker_lab_01", x = 5569, y = 12420, z = -16, radius = 5 },
    { id = "bunker_lab_02", x = 5569, y = 12415, z = -16, radius = 5 },
    { id = "bunker_lab_03", x = 5571, y = 12429, z = -16, radius = 5 },
    { id = "bunker_lab_04", x = 5579, y = 12428, z = -16, radius = 5 },
    { id = "bunker_lab_05", x = 5567, y = 12440, z = -17, radius = 6 },
    { id = "bunker_lab_06", x = 5580, y = 12434, z = -16, radius = 5 },
    { id = "bunker_lab_07", x = 5571, y = 12439, z = -16, radius = 5 },
    { id = "bunker_lab_08", x = 5580, y = 12440, z = -16, radius = 5 },
    { id = "bunker_lab_09", x = 5565, y = 12429, z = -16, radius = 5 },
    { id = "bunker_lab_10", x = 5562, y = 12438, z = -17, radius = 4 },
    { id = "bunker_lab_11", x = 5559, y = 12439, z = -16, radius = 5 },
    { id = "bunker_lab_12", x = 5565, y = 12439, z = -16, radius = 5 },
    { id = "bunker_lab_13", x = 5559, y = 12429, z = -16, radius = 5 },
}

KEQ.Helipad = {
    id = "helipad",
    centerX = 5553,
    centerY = 12480,
    z = 1,
    minX = 5545,
    maxX = 5560,
    minY = 12472,
    maxY = 12487,
    -- The final wave spawns 18 tiles from the pad center.  Sixteen tiles
    -- beyond the fence covers those spawn points and nearby stragglers.
    suppressionBuffer = 16,
}

KEQ.SurveyTargets = {
    { id = "checkpoint", x = 12510, y = 4190 },
    { id = "hospital", x = 12936, y = 2047 },
    { id = "substation", x = 14765, y = 4085 },
    { id = "transmitter", x = 12466, y = 1784 },
    { id = "bunker", x = 5565, y = 12494 },
    { id = "cave", x = 5689, y = 12437 },
}

function KEQ.GetSandboxValue(name, fallback)
    local vars = SandboxVars and SandboxVars.KnoxEscapeQuest or nil
    if vars and vars[name] ~= nil then return vars[name] end
    return fallback
end

function KEQ.IsEnabled()
    return KEQ.GetSandboxValue("Enabled", true) == true
end

function KEQ.GetActionSeconds()
    local seconds = tonumber(KEQ.GetSandboxValue("InteractionSeconds", KEQ.ACTION_SECONDS)) or KEQ.ACTION_SECONDS
    return math.max(5, math.min(120, seconds))
end

function KEQ.DistanceToTarget(player, target)
    if not player or not target then return math.huge end
    local dx = (tonumber(player:getX()) or 0) - (tonumber(target.x) or 0)
    local dy = (tonumber(player:getY()) or 0) - (tonumber(target.y) or 0)
    return math.sqrt(dx * dx + dy * dy)
end

function KEQ.IsPlayerNearTarget(player, target)
    if not player or not target then return false end
    local z = tonumber(player:getZ()) or 0
    if target.z ~= nil and math.floor(z + 0.5) ~= tonumber(target.z) then return false end
    return KEQ.DistanceToTarget(player, target) <= (tonumber(target.radius) or 3)
end

function KEQ.IsPlayerInHelipad(player)
    if not player then return false end
    local zone = KEQ.Helipad
    local x, y = tonumber(player:getX()) or 0, tonumber(player:getY()) or 0
    local z = math.floor((tonumber(player:getZ()) or 0) + 0.5)
    return z == zone.z and x >= zone.minX and x <= zone.maxX and y >= zone.minY and y <= zone.maxY
end

function KEQ.IsAdmin(player)
    if not player or not player.getAccessLevel then return false end
    local level = string.lower(tostring(player:getAccessLevel() or ""))
    return level == "admin"
end

return KEQ
