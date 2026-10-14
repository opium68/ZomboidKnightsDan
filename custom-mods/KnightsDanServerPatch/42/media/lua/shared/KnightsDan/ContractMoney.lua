-- Scale complete mission rewards after all native location/quantity modifiers.
require "ISPZLinuxVariablesTables"
require "KnightsDan/Core"
local K = KnightsDan
if K.contractMoneyInstalled then return end
K.contractMoneyInstalled = true
local multiplier = 3
local creating = false
local function scaleNote(note, old, value)
    if type(note) ~= "string" then return note end
    return (note:gsub("for %$" .. tostring(old) .. "(%D)", "for $" .. tostring(value) .. "%1")
        :gsub("for %$" .. tostring(old) .. "$", "for $" .. tostring(value)))
end
local function scale(record)
    if record.knightsRewardMultiplier == multiplier then return end
    local old = PZLinuxNormalizeMoney(record.reward)
    local prior = math.max(1, tonumber(record.knightsRewardMultiplier) or 1)
    record.reward = PZLinuxNormalizeMoney(old/prior*multiplier)
    record.note = scaleNote(record.note, old, record.reward)
    record.fullNote = scaleNote(record.fullNote, old, record.reward)
    record.knightsRewardMultiplier = multiplier
end
local build = PZLinuxContractsBuildMission
function K.scaleContractReward(record) scale(record) end
local buildOffer = PZLinuxContractsBuildContract
PZLinuxContractsBuildContract = function(...)
    local offer = buildOffer(...)
    if offer then scale(offer) end
    return offer
end
PZLinuxContractsBuildMission = function(...)
    local args = {...}
    local selected = args[1]
    if selected and tonumber(selected.knightsRewardMultiplier) then
        local original = {}
        for key,value in pairs(selected) do original[key]=value end
        original.reward = selected.reward/math.max(1, tonumber(selected.knightsRewardMultiplier))
        original.knightsRewardMultiplier = nil
        args[1] = original
    end
    local mission, err = build(unpack(args))
    if mission then scale(mission) end
    return mission, err
end
local world = PZLinuxContractsGetWorldData
PZLinuxContractsGetWorldData = function(...)
    local data = world(...)
    if K.authoritative() and not creating then
        for _, record in pairs(data.active or {}) do
            if record.status ~= "completed" and record.status ~= "cancelled" then scale(record) end
        end
    end
    return data
end
local create = PZLinuxContractsCreateWorldContract
PZLinuxContractsCreateWorldContract = function(player, selected, id, mission)
    creating = true
    local ok, record = pcall(create, player, selected, id, mission)
    creating = false
    if not ok then error(record) end
    if record then
        record.knightsRewardMultiplier = mission and mission.knightsRewardMultiplier
        -- If an upstream path supplied an unscaled mission, migrate once.
        if record.knightsRewardMultiplier ~= multiplier then scale(record) end
        PZLinuxContractsTransmitWorldData()
    end
    return record
end
function K.contractPayout(record)
    return PZLinuxNormalizeMoney(record.reward)+PZLinuxNormalizeMoney(record.zombieCount)*5*multiplier
end
local complete = PZLinuxContractsApplyComplete
PZLinuxContractsApplyComplete = function(player, state, requestId)
    local p = PZLinuxGetPlayer(player)
    if not p then return complete(player, state, requestId) end
    local md = p:getModData()
    if tonumber(md.PZLinuxActiveContract) ~= 9 and tonumber(md.PZLinuxActiveContract) ~= 10 then
        return complete(player, state, requestId)
    end
    local record = md.PZLinuxContractId and PZLinuxContractsGetWorldContract(md.PZLinuxContractId)
    local previous = md.PZLinuxOnReward
    local reward = record and record.reward or PZLinuxNormalizeMoney(previous)*multiplier
    -- Native completion adds five per kill; add only the multiplier remainder.
    md.PZLinuxOnReward = reward+PZLinuxNormalizeMoney(md.PZLinuxOnZombieDead)*5*(multiplier-1)
    local ok, result = pcall(complete, player, state, requestId)
    if not ok or not result or not result.ok then md.PZLinuxOnReward = previous end
    if not ok then error(result) end
    return result
end
