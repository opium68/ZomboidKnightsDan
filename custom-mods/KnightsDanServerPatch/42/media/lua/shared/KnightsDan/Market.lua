require "KnightsDan/ClothingSets"
local K = KnightsDan
K.marketCategories = {"firearms","melee","ammunition","attachments","clothing",
    "bags","equipment","repair","rations","food","medical","tools","supplies"}
function K.marketCategory(id, script)
    local key = id:lower()
    if K.clothingSets[id] then return "clothing" end
    if key:find("^bdtmre%.bdtmre%d") then return "rations" end
    if key:find("repair") or key:find("gunlub") or key:find("gunparts") or key:find("gunclean") then return "repair" end
    local category = tostring(script:getDisplayCategory() or ""):lower()
    local kind = tostring(script:getItemType() or ""):lower()
    if category:find("ammo") or key:find("carton") or key:find("magazine") or key:find("ammobox") then return "ammunition" end
    if kind:find("weaponpart") then return "attachments" end
    if kind:find("weapon") then return script:isRanged() and "firearms" or "melee" end
    if kind:find("food") then return "food" end
    if kind:find("clothing") then return "equipment" end
    if kind:find("container") then return "bags" end
    if category:find("medical") or category:find("firstaid") then return "medical" end
    if category:find("tool") then return "tools" end
    return "supplies"
end
function K.generateCategoryMarket(market)
    local groups, seen = {}, {}
    for _,name in ipairs(K.marketCategories) do groups[name] = {} end
    for index, entry in ipairs(PZLinuxDarkWebItemsTable) do
        local id = PZLinuxDarkWebGetFirstItemId(entry)
        local script = id and getScriptManager():FindItem(id)
        if script and not seen[id] then
            seen[id] = true
            table.insert(groups[K.marketCategory(id, script)], index)
        end
    end
    local offers = {}
    for _,name in ipairs(K.marketCategories) do
        local group = groups[name]
        local count = ZombRand(0, math.min(3, #group) + 1)
        for position=1,count do
            local choice = ZombRand(position, #group + 1)
            group[position],group[choice] = group[choice],group[position]
            local index = group[position]
            local entry = PZLinuxDarkWebItemsTable[index]
            local scarcity = PZLinuxDarkWebGetHourMultiplier and PZLinuxDarkWebGetHourMultiplier() or 1
            local multiplier = PZLinuxDarkWebGetPurchaseMultiplier and PZLinuxDarkWebGetPurchaseMultiplier() or 1
            local reference = math.max(1, math.floor((tonumber(entry.Price) or 0) * scarcity * multiplier))
            local minimum,maximum = PZLinuxDarkWebGetStockRange(reference)
            local stock = ZombRand(minimum, maximum + 1)
            table.insert(offers,{id=tostring(market.generation)..":"..index,sourceIndex=index,
                item={id=PZLinuxDarkWebGetItemIds(entry)},stock=stock,initialStock=stock,
                referencePrice=reference,knightsCategory=name})
        end
    end
    market.offers = offers
    market.knightsCategoryVersion = 1
    market.knightsCategoryGeneration = market.generation
    market.knightsCategoryEmpty = #offers == 0
end
