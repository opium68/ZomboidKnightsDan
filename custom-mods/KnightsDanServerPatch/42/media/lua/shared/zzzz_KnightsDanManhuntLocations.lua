require "PZLinux/PZLinuxMissionLocations"

-- Enable registered manhunt coordinates only. Keep existing boards/contracts
-- intact; their city and target were already chosen before this hook loaded.
local pool = PZLinux.MissionLocations.pools.manhunt
local added, total = 0, 0
for _, locations in pairs(pool.byCityId or {}) do
    for _, location in ipairs(locations) do
        if tonumber(location.x) and tonumber(location.y)
            and tonumber(location.x) > 0 and tonumber(location.y) > 0 then
            if location.enabled == false then
                location.enabled = true
                added = added + 1
            end
            if location.enabled ~= false then total = total + 1 end
        end
    end
end
print("[KD_MANHUNT_LOCATIONS] enabled=" .. tostring(total) .. " newlyEnabled=" .. tostring(added))
