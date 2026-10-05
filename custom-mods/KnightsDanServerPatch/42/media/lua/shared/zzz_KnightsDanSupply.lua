require "PZLinux/PZLinuxDarkWeb"
require "KnightsDan/Catalog"
local build=PZLinuxDarkWebBuildBuyOffers
PZLinuxDarkWebBuildBuyOffers=function(player,requestId)
    local result=build(player,requestId)
    if isClient() then return result end
    local market=ModData.getOrCreate("PZLinuxDarkWebMarket")
    if market.knightsSupplyGeneration==market.generation then return result end
    local meals={}
    local indexes={}
    for index,entry in ipairs(PZLinuxDarkWebItemsTable) do
        for _,id in ipairs(entry.id or {}) do
            indexes[id]=index
            if id:find("^bdtmre.bdtmre%d") then table.insert(meals,id) end
        end
    end
    table.sort(meals)
    local guaranteed={"GunRepairKit.GunRepairKit","GunRepairKit.GunRepairKitAdvanced"}
    if #meals>0 then
        for i=0,2 do table.insert(guaranteed,meals[((tonumber(market.generation) or 0)+i)%#meals+1]) end
    end
    local existing={}
    for _,offer in ipairs(market.offers or {}) do existing[offer.sourceIndex]=true end
    for _,id in ipairs(guaranteed) do
        local index=indexes[id]
        if index and not existing[index] then
            local stock=id:find("^bdtmre") and 12 or 3
            table.insert(market.offers,{id=tostring(market.generation)..":"..tostring(index),sourceIndex=index,
                item={id={id}},stock=stock,initialStock=stock,referencePrice=PZLinuxDarkWebItemsTable[index].Price})
        end
    end
    market.knightsSupplyGeneration=market.generation
    ModData.transmit("PZLinuxDarkWebMarket")
    return build(player,requestId)
end
