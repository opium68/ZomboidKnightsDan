--***********************************************************
--**                     Papa_Chad                         **
--***********************************************************
require "Vehicles/Papa_Chad_FastTick_Event"

local DEBUG = false
local MIN_ARMOR_CONDITION = 5

-- local: não vaza para o escopo global
local VehicleArmorHistory = {}

local function mulPct(amount, pctInt)
    return math.floor((amount * pctInt + 50) / 100)
end

-----------------------------------------------------
-- Pré-calcula percentuais do VehicleArmorConfig
-- Os valores de absorbPercent/wearPerDamage são constantes
-- em runtime — não faz sentido converter a cada tick
-----------------------------------------------------
local function precalcArmorConfig()
    for _, armorData in pairs(VehicleArmorConfig) do
        for _, partCfg in pairs(armorData.protectedParts) do
            local a = partCfg.absorbPercent
            local w = partCfg.wearPerDamage
            -- normaliza para inteiro 0..100
            partCfg._absorbPct = math.floor((a <= 1 and a * 100 or a) + 0.5)
            partCfg._wearPct   = math.floor((w <= 1 and w * 100 or w) + 0.5)
        end
    end
end

Events.OnGameStart.Add(precalcArmorConfig)

-----------------------------------------------------
-- Tick principal de absorção de blindagem
-----------------------------------------------------
local function vehicleArmorTick(player)
    if not player then return end

    local vehicle = player:getVehicle()
    if not vehicle then return end

    -- Knights Dan: multiplayer Humvee armor is authoritative on the server.
    if isClient() and vehicle:getScript():getFullName() == 'Base.M998_Humvee' then return end

    -- evita duplo processamento quando mais de um jogador está no veículo
    -- apenas o motorista (assento 0) processa
    if vehicle:getSeat(player) ~= 0 then return end

    local vehicleID = vehicle:getId()
    VehicleArmorHistory[vehicleID] = VehicleArmorHistory[vehicleID] or {}

    for armorName, armorData in pairs(VehicleArmorConfig) do
        local armorPart = vehicle:getPartById(armorData.requiredItem)

        if armorPart and armorPart:getInventoryItem() and armorPart:getCondition() >= MIN_ARMOR_CONDITION then
            for partId, partCfg in pairs(armorData.protectedParts) do
                local vehPart = vehicle:getPartById(partId)
                if vehPart then
                    if not vehPart:getInventoryItem() then
                        -- peça removida: limpa histórico
                        VehicleArmorHistory[vehicleID][partId] = nil
                        if DEBUG then
                            print(string.format("[VehicleArmor] Resetando histórico de %s (sem peça instalada)", partId))
                        end
                    else
                        local prevCond    = VehicleArmorHistory[vehicleID][partId] or vehPart:getCondition()
                        local currentCond = vehPart:getCondition()
                        local diff        = prevCond - currentCond

                        if diff > 0 then
                            -- usa percentuais pré-calculados (evita toPct a cada tick)
                            local absorbPct = partCfg._absorbPct
                            local wearPct   = partCfg._wearPct

                            local absorbed = mulPct(diff, absorbPct)

                            -- restaura parte com absorção
                            local newPartCond = math.min(100, math.max(0, currentCond + absorbed))
                            vehPart:setCondition(newPartCond)
                            vehicle:transmitPartCondition(vehPart)

                            -- desgasta armadura
                            local wear = mulPct(absorbed, wearPct)
                            local newArmorCond = math.max(0, armorPart:getCondition() - wear)
                            armorPart:setCondition(newArmorCond)
                            vehicle:transmitPartCondition(armorPart)

                            if DEBUG then
                                print(string.format(
                                    "[VehicleArmor] %s -> %s | diff=%d absorbed=%d part=%d armor=%d",
                                    armorName, partId, diff, absorbed,
                                    vehPart:getCondition(), armorPart:getCondition()
                                ))
                            end
                        end

                        -- atualiza histórico com condição atual
                        VehicleArmorHistory[vehicleID][partId] = vehPart:getCondition()
                    end
                end
            end

        elseif DEBUG and armorPart then
            print(string.format("[VehicleArmor] %s não protege: condição baixa (%d)",
                armorName, armorPart:getCondition()))
        end
    end
end

FastTick.Add(vehicleArmorTick)

-----------------------------------------------------
-- Limpeza do histórico ao sair do veículo
-----------------------------------------------------
Events.OnExitVehicle.Add(function(player)
    if not player then return end
    -- OnExitVehicle dispara antes do vínculo ser removido
    -- então getVehicle() ainda retorna o veículo que estava
    local vehicle = player:getVehicle()
    if vehicle then
        VehicleArmorHistory[vehicle:getId()] = nil
    end
end)