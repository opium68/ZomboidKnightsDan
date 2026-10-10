-- Patch existing part definitions after scripts load; preserve models and stats.
-- Prevent inventory-item synchronization from showing all colour alternatives.
local parts = {"EngineDoor", "DoorFrontLeft", "DoorFrontRight", "DoorRearLeft", "DoorRearRight", "TrunkDoor"}
local function configure()
    local script = getScriptManager():getVehicle("Base.M998_Humvee")
    if not script then return end
    local blocks = {}
    for _, id in ipairs(parts) do
        local part = script:getPartById(id)
        if part then
            blocks[#blocks+1] = "part " .. id .. " { setAllModelsVisible = false, }"
        end
    end
    if #blocks == 0 then return end
    -- VehicleScript.Load merges named parts rather than replacing their data.
    script:Load("M998_Humvee", "vehicle M998_Humvee { " .. table.concat(blocks, " ") .. " }")
    print("[KD_HUMVEE_MODELS] colour model auto-show disabled parts=" .. tostring(#blocks))
end
Events.OnGameBoot.Add(configure)
