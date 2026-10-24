-- USMC P19A only. Keep exit checks (offset) and final placement (area)
-- aligned, with clearance from the 2.7556-wide chassis.
local overlay = [[vehicle 86oshkoshUSMC {
    area KD_P19AExitFL { xywh = 2.1000 3.1000 0.6000 0.6000, }
    area KD_P19AExitFR { xywh = -2.1000 3.1000 0.6000 0.6000, }
    area KD_P19AExitRL { xywh = -2.1000 2.6111 0.6000 0.6000, }
    area KD_P19AExitRR { xywh = 2.1000 -3.4000 0.6000 0.6000, }
    passenger FrontLeft {
        position outside { offset = 1.9200 -1.3000 3.1000, area = KD_P19AExitFL, }
    }
    passenger FrontRight {
        position outside { offset = -1.9200 -1.3000 3.1000, area = KD_P19AExitFR, }
    }
    passenger RearLeft {
        position outside { offset = -1.9200 -1.3000 2.6111, area = KD_P19AExitRL, }
    }
    passenger RearRight {
        position outside { offset = 1.9200 -1.3000 -3.4000, area = KD_P19AExitRR, }
    }
}]]

local function configure()
    local script = getScriptManager():getVehicle("Base.86oshkoshUSMC")
    if not script then return end
    for _, id in ipairs({"FrontLeft", "FrontRight", "RearLeft", "RearRight"}) do
        if not script:getPassengerById(id) then
            print("[KD_P19A_EXITS] skipped: missing passenger " .. id)
            return
        end
    end
    -- Native Load merges named positions and areas without replacing seats/parts.
    script:Load("86oshkoshUSMC", overlay)
    print("[KD_P19A_EXITS] configured four USMC exit positions")
end
Events.OnGameBoot.Add(configure)
