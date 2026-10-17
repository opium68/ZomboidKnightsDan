require "PZLinux/PZLinuxDarkWeb"
require "KnightsDan/Market"
local K=KnightsDan
if K.midnightMarketInstalled then return end
K.midnightMarketInstalled=true

-- Native EnsureMarket refills empty arrays. This inert zero-stock entry is
-- present only during synchronous native sell/replay calls, never displayed.
local function nativeCall(fn,market,...)
    if not market or not market.knightsCategoryEmpty then return fn(...) end
    local saved=market.offers
    market.offers={{id="knights-empty",sourceIndex=1,item={id={}},stock=0,initialStock=0,referencePrice=1}}
    local result={pcall(fn,...)}
    market.offers=saved
    if not result[1] then error(result[2]) end
    return unpack(result,2)
end

local buyOffers=PZLinuxDarkWebBuildBuyOffers
PZLinuxDarkWebBuildBuyOffers=function(player,requestId)
    local market=K.ensureMidnightMarket()
    if market and market.knightsCategoryEmpty then
        return {ok=true,requestId=requestId,offers={},balance=PZLinuxLoadBankBalance(player)}
    end
    return buyOffers(player,requestId)
end
for _,name in ipairs({"PZLinuxDarkWebApplyBuy","PZLinuxDarkWebBuildSellOffers","PZLinuxDarkWebApplySell"}) do
    local native=_G[name]
    if native then
        _G[name]=function(...)
            return nativeCall(native,K.ensureMidnightMarket(),...)
        end
    end
end
Events.EveryHours.Add(function() if not isClient() then K.ensureMidnightMarket() end end)
