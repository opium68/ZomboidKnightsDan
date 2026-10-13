require "PZLinux/PZLinuxDarkWeb"
require "KnightsDan/Market"
local build = PZLinuxDarkWebBuildBuyOffers
PZLinuxDarkWebBuildBuyOffers = function(player, requestId)
    local result = build(player, requestId)
    if isClient() then return result end
    local market = ModData.getOrCreate("PZLinuxDarkWebMarket")
    if market.knightsCategoryVersion ~= 1 or market.knightsCategoryGeneration ~= market.generation then
        KnightsDan.generateCategoryMarket(market)
        PZLinux.darkWebBuySessions = {}
        ModData.transmit("PZLinuxDarkWebMarket")
    elseif market.knightsCategoryEmpty then
        market.offers = {}
    else
        return result
    end
    local refreshed = build(player, requestId)
    -- Native EnsureMarket refills empty lists: retain a valid all-zero draw.
    if market.knightsCategoryEmpty then
        refreshed.offers = {}; market.offers = {}
        PZLinux.darkWebBuySessions = {}
    end
    return refreshed
end
