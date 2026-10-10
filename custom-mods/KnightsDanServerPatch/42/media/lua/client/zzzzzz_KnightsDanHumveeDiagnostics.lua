-- Humvee repair diagnostics, loaded after the existing repair-pose hook.
-- Reads animation state only. Never releases tracks, changes models, or repairs parts.
require "TimedActions/VRO_DoFixAction"
require "VRO/Core"
KnightsDanHumveeDiagnostics = KnightsDanHumveeDiagnostics or {}
local D = KnightsDanHumveeDiagnostics
if D.installed then return end
D.installed = true
local watched, nextSample, remaining

local function call(obj, method, ...)
    if not obj then return nil end
    local args = {...}
    local ok, value = pcall(function()
        local fn = obj[method]
        if fn then return fn(obj, unpack(args)) end
    end)
    if ok then return value end
end

local function collectionSize(list)
    return call(list, "size") or (type(list) == "table" and #list) or 0
end
local function collectionGet(list, i)
    return call(list, "get", i) or (type(list) == "table" and list[i + 1])
end

local function field(obj, name)
    if not obj then return nil end
    -- Public Lua-visible fields only. Reflection is forbidden in normal MP.
    local ok, value = pcall(function() return obj[name] end)
    if ok then return value end
end

local function inspect(label, player)
    local list = call(call(player, "getMultiTrack"), "getTracks")
    if not list then return label .. "=unavailable" end
    local count = collectionSize(list)
    local names, order, active = {}, {}, 0
    -- Bound inspection even when thousands of tracks have accumulated.
    for i = 0, math.min(count, 256) - 1 do
        local track = collectionGet(list, i)
        local weight = call(track, "getBlendWeight") or 0
        local layer = call(track, "getLayerIdx") or -1
        if weight >= 0.001 and layer >= 0 and layer < 16
            and not (layer > 0 and call(track, "isFinished")) then active = active + 1 end
        local name = tostring(call(track, "getName") or "unknown")
        if names[name] then names[name] = names[name] + 1
        elseif #order < 32 then names[name] = 1; order[#order + 1] = name end
    end
    local summary = {}
    for _, name in ipairs(order) do summary[#summary + 1] = name .. ":" .. names[name] end
    return label .. " tracks=" .. count .. " activeInFirst256=" .. active
        .. " names=" .. table.concat(summary, ",")
end

local function existingPlayer(obj)
    local instance = call(obj, "getModelInstance")
    if not instance then
        local slot = field(call(obj, "getSprite"), "modelSlot")
        instance = field(slot, "model")
    end
    -- ModelInstance.animPlayer is public; IsoGameCharacter's private field
    -- is inherited by IsoPlayer and cannot be read with declared-field helpers.
    return field(instance, "animPlayer") or field(obj, "animPlayer")
end

function D.snapshot(action, phase)
    local vehicle = call(action.part, "getVehicle")
    local script = call(vehicle, "getScript")
    if call(script, "getFullName") ~= "Base.M998_Humvee" then return end
    local models = field(vehicle, "models")
    local fields = {"[KD_HUMVEE_DIAG] phase=" .. phase,
        "vehicle=" .. tostring(call(vehicle, "getId")),
        "part=" .. tostring(call(action.part, "getId")),
        "condition=" .. tostring(call(action.part, "getCondition")),
        "action=" .. tostring(action.actionAnim),
        inspect("character", existingPlayer(action.character)),
        inspect("vehicle", existingPlayer(vehicle))}
    if models then
        fields[#fields + 1] = "modelCount=" .. collectionSize(models)
        for i = 0, math.min(collectionSize(models), 48) - 1 do
            local info = collectionGet(models, i)
            local part = field(info, "part")
            local model = field(info, "scriptModel")
            fields[#fields + 1] = inspect("model" .. i .. "/"
                .. tostring(call(part, "getId")) .. "/" .. tostring(call(model, "getId")),
                field(info, "animPlayer"))
        end
    else
        fields[#fields + 1] = "modelCollection=unavailable"
    end
    print(table.concat(fields, " | "))
end

local function safeSnapshot(action, phase)
    pcall(D.snapshot, action, phase)
end
local start, perform, stop = VRO.DoFixAction.start, VRO.DoFixAction.perform, VRO.DoFixAction.stop
VRO.DoFixAction.start = function(self, ...)
    safeSnapshot(self, "before-start")
    local result = start(self, ...)
    safeSnapshot(self, "after-start")
    return result
end
VRO.DoFixAction.perform = function(self, ...)
    safeSnapshot(self, "before-perform")
    local result = perform(self, ...)
    safeSnapshot(self, "after-perform")
    local vehicle = call(self.part, "getVehicle")
    if call(call(vehicle, "getScript"), "getFullName") == "Base.M998_Humvee" then
        watched, nextSample, remaining = self, getTimestampMs() + 1000, 12
    end
    return result
end
VRO.DoFixAction.stop = function(self, ...)
    safeSnapshot(self, "before-stop")
    local result = stop(self, ...)
    safeSnapshot(self, "after-stop")
    return result
end
Events.OnTick.Add(function()
    if watched and getTimestampMs() >= nextSample then
        safeSnapshot(watched, "post-complete-" .. (13 - remaining))
        remaining = remaining - 1
        if remaining == 0 then watched = nil else nextSample = getTimestampMs() + 1000 end
    end
end)
