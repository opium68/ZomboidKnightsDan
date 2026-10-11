-- Multiplayer Humvee armor: server computes and broadcasts both protection and wear.
if not isServer() then return end
require "KnightsDanHumveeArmorConfig"
require "VRO_VehicleCommands"
KnightsDanHumveeArmor = KnightsDanHumveeArmor or {}
local A = KnightsDanHumveeArmor
if A.installed then return end
A.installed = true
local history = {}
local nextRun = 0
local function pct(v) return math.floor((v <= 1 and v*100 or v)+0.5) end
local function mul(amount, percent) return math.floor((amount*percent+50)/100) end
local function humvee(vehicle)
    return vehicle and vehicle:getScript():getFullName() == "Base.M998_Humvee"
end

function A.reset(vehicle)
    if not humvee(vehicle) then return end
    history[vehicle:getId()] = nil
end

function A.process(vehicle)
    if not humvee(vehicle) then return end
    local id = vehicle:getId()
    local state = history[id]
    if not state or state.vehicle ~= vehicle then
        state = {vehicle=vehicle, parts={}}
        history[id] = state
    end
    local changed = false
    local observed, processed = {}, {}
    for _, config in pairs(KnightsDanHumveeArmorConfig) do
        local armor = vehicle:getPartById(config.requiredItem)
        local active = armor and armor:getInventoryItem() and armor:getCondition() >= 5
        for partId, protection in pairs(config.protectedParts) do
            local part = vehicle:getPartById(partId)
            local item = part and part:getInventoryItem()
            local previous = state.parts[partId]
            if not item then
                observed[partId] = nil
            else
                local current = part:getCondition()
                -- Replaced items and the first observation establish a fresh baseline.
                local damage = previous and previous.item == item and previous.condition-current or 0
                if active and not processed[partId] and damage > 0 then
                    local absorbed = mul(damage, pct(protection.absorbPercent))
                    local restored = math.min(100, current+absorbed)
                    local worn = math.max(0, armor:getCondition()-mul(absorbed,pct(protection.wearPerDamage)))
                    if restored ~= current then
                        part:setCondition(restored)
                        vehicle:transmitPartCondition(part)
                        changed = true
                    end
                    if worn ~= armor:getCondition() then
                        armor:setCondition(worn)
                        vehicle:transmitPartCondition(armor)
                        changed = true
                    end
                end
                if active then processed[partId] = true end
                observed[partId] = {item=item, condition=part:getCondition()}
            end
        end
    end
    state.parts = observed
    if changed then vehicle:updatePartStats(); vehicle:updateBulletStats() end
end

-- Repair/replacement must establish a new baseline, not be treated as collision damage.
Events.OnClientCommand.Add(function(module, command, player, args)
    if type(args) ~= "table" then return end
    if module == "VRO_vehicle" and command == "doFix" then
        A.reset(args.vehicleId and getVehicleById(args.vehicleId))
    elseif module == "vehicle" and (command == "fixPart" or command == "setPartCondition") then
        A.reset(args.vehicle and getVehicleById(args.vehicle))
    end
end)

Events.OnTick.Add(function()
    local now = getTimeInMillis()
    if now < nextRun then return end
    nextRun = now+166
    local players = getOnlinePlayers()
    local seen = {}
    for i=0,players:size()-1 do
        local player = players:get(i)
        local vehicle = player:getVehicle()
        if humvee(vehicle) and vehicle:getSeat(player) == 0 then
            seen[vehicle:getId()] = true
            A.process(vehicle)
        end
    end
    for id in pairs(history) do if not seen[id] then history[id] = nil end end
end)
