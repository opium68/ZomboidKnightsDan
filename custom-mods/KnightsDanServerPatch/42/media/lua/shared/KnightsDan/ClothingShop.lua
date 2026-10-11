require "KnightsDan/ClothingSets"
local K=KnightsDan
for id in pairs(K.jgItems) do K.rewardItems[id]=true end
for name in pairs(K.jgRecipes) do K.blockedRecipes[name]=true end

-- A real container item travels through the existing server-validated purchase
-- and durable delivery queue; its contents are not a list of random alternatives.
function K.createClothingSet(package)
    local definition=K.clothingSets[package:getFullType()]
    if not definition then return end
    local data=package:getModData()
    if data.knightsClothingSetFilled then return end
    local inventory=package:getInventory()
    local created={}
    for _,id in ipairs(definition.items) do
        local item=inventory:AddItem(id)
        if not item then
            for _,added in ipairs(created) do inventory:Remove(added) end
            error("KnightsDan clothing set component missing: "..id)
        end
        created[#created+1]=item
        local visual=item:getVisual()
        if visual then visual:setTextureChoice(0) end
    end
    data.knightsClothingSetFilled=true
end

-- Generated from the audited price catalog rather than relying on a broad
-- name prefix that could also hide bags, holsters, night vision or lamps.
local clothing=K.individualClothingItems or {}
local filtered={}
for _,entry in ipairs(K.shopItems) do
    if not clothing[entry.id] then filtered[#filtered+1]=entry end
end
K.shopItems=filtered
for id,definition in pairs(K.clothingSets) do
    K.rewardItems[id]=true
    K.shopItems[#K.shopItems+1]={id=id,price=definition.price}
end

function K.removeIndividualClothingOffers()
    if not PZLinuxDarkWebItemsTable then return end
    for index=#PZLinuxDarkWebItemsTable,1,-1 do
        local offer=PZLinuxDarkWebItemsTable[index]
        for n=#(offer.id or {}),1,-1 do
            if clothing[offer.id[n]] or K.jgItems[offer.id[n]] then table.remove(offer.id,n) end
        end
        if #(offer.id or {})==0 then table.remove(PZLinuxDarkWebItemsTable,index) end
    end
end
