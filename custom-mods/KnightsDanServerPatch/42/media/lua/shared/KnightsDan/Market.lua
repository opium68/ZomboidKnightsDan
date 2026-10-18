require "KnightsDan/ClothingSets"
require "KnightsDan/Supply"
local K = KnightsDan
K.marketCategories = {"firearms","melee","ammunition","attachments","clothing",
    "bags","equipment","repair","rations","food","medical","tools","supplies"}
function K.marketCategory(id, script)
    if K.supplyProducts[id] then return K.supplyProducts[id].category end
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
    for _,name in ipairs({"cartons","magazines","vehicle","vehicleHE"}) do groups[name]={} end
    for index, entry in ipairs(PZLinuxDarkWebItemsTable) do
        local id = PZLinuxDarkWebGetFirstItemId(entry)
        local script = id and getScriptManager():FindItem(id)
        if script and not seen[id] and not entry.knightsSellOnly then
            seen[id] = true
            table.insert(groups[K.marketCategory(id, script)], index)
        end
    end
    local offers = {}
    local categories={};for _,name in ipairs(K.marketCategories) do categories[#categories+1]=name end
    for _,name in ipairs({"cartons","magazines","vehicle","vehicleHE"}) do categories[#categories+1]=name end
    for _,name in ipairs(categories) do
        local group = groups[name]
        local count = ZombRand(0, math.min(3, #group) + 1)
        if name=="cartons" then count=math.min(5,#group)
        elseif name=="magazines" then count=ZombRand(0, math.min(3,#group)+1)
        elseif name=="vehicle" then count=math.min(1,#group)
        elseif name=="vehicleHE" then count=ZombRand(0,4)==0 and math.min(1,#group) or 0 end
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
            if name=="cartons" or name=="vehicle" or name=="vehicleHE" then stock=ZombRand(1,6)
            elseif name=="magazines" then stock=ZombRand(1,6) end
            table.insert(offers,{id=tostring(market.knightsCalendarDay or market.generation)..":"..index,sourceIndex=index,
                item={id=PZLinuxDarkWebGetItemIds(entry)},stock=stock,initialStock=stock,
                referencePrice=reference,knightsCategory=name})
        end
    end
    market.offers = offers
    market.knightsCategoryVersion = K.supplyReady and 3 or 1
    market.knightsCategoryGeneration = market.generation
    market.knightsCategoryEmpty = #offers == 0
end

-- Calendar date decides stock. Align only the native compatibility counter
-- so its private EnsureMarket cannot replace stock at a world-age boundary.
function K.ensureMidnightMarket()
    if isClient() then return nil end
    local clock=getGameTime()
    local today=tostring(clock:getYear())..":"..tostring(clock:getMonth())..":"..tostring(clock:getDay())
    local hour=clock:getWorldAgeHours()
    local nativeGeneration=math.floor(math.max(0,hour)/math.max(1,tonumber((PZLinuxDarkWebMarketConfig or {}).refreshHours) or 24))
    local market=ModData.getOrCreate("PZLinuxDarkWebMarket")
    local first=market.knightsMidnightVersion~=1
    local newDay=not first and market.knightsCalendarDay~=today
    local valid=market.knightsCategoryVersion==(K.supplyReady and 3 or 1) and type(market.offers)=="table"
    local oldGeneration=market.generation
    market.generation=nativeGeneration
    market.knightsCategoryGeneration=nativeGeneration
    market.knightsCalendarDay=today
    market.knightsMidnightVersion=1
    if newDay or not valid then
        if PZLinuxDarkWebLoadCustomItems then PZLinuxDarkWebLoadCustomItems() end
        K.generateCategoryMarket(market)
        PZLinux.darkWebBuySessions={}
        PZLinux.darkWebSellSessions={}
        print("[KnightsDan] midnight dark market: "..today..", offers="..tostring(#market.offers))
    elseif oldGeneration~=nativeGeneration then
        -- Preserve existing quotes as well as stock within the same date.
        for _,sessions in ipairs({PZLinux.darkWebBuySessions or {},PZLinux.darkWebSellSessions or {}}) do
            for _,session in pairs(sessions) do session.generation=nativeGeneration end
        end
    end
    if (first or newDay or not valid or oldGeneration~=nativeGeneration) and isServer() then
        ModData.transmit("PZLinuxDarkWebMarket")
    end
    return market
end
