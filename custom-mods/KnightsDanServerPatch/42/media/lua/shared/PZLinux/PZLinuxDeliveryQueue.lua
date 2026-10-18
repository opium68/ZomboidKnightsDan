require "KnightsDan/Upstream"
if KnightsDan.nativeDeliveryLoaded then return end
KnightsDan.loadPzLinuxSource("media/lua/shared/PZLinux/PZLinuxDeliveryQueue.lua", function(source)
    local helpers = {"EnsureParcelPlan", "FindParcel", "CreateParcel", "RemoveTemporaryParcel",
        "AllPartsDelivered", "TrimHistory", "WorldHour"}
    local exports = {}
    for _, name in ipairs(helpers) do
        local fullName = "PZLinuxDelivery" .. name
        assert(source:find("local function " .. fullName .. "(", 1, true),
            "PZLinux delivery interface changed: " .. fullName)
        exports[#exports + 1] = name .. "=" .. fullName
    end
    return source .. "\nKnightsDan.deliveryNative={" .. table.concat(exports, ",") .. "}\n"
end)
KnightsDan.nativeDeliveryLoaded = true
