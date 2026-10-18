require "ISPZLinuxVariablesTables"
require "KnightsDan/Core"
local K = KnightsDan
if K.dailyRequestsInstalled then return end
K.dailyRequestsInstalled = true

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = copy(entry) end
    return result
end
local function store(player)
    -- Server global data cannot be overwritten by a client's player modData sync.
    local data = ModData.getOrCreate("KnightsDanDailyRequestsV1")
    local key = K.key(player)
    local day = PZLinuxRequestsCurrentGameDay()
    local record = data[key]
    if not record or record.day ~= day then
        record = {day=day, offers={}}
        data[key] = record
    end
    return record
end
local function generate(player, id, day)
    local pool = PZLinuxRequestsGetOfferPool(id)
    if #pool == 0 then return nil end
    local offer = {contractId=id, day=day, offerId=tostring(day)..":"..tostring(id), items={}}
    local unit = PZLinuxRequestsCalculateUnitPrice(player, PZLinuxRequestsGetDefinition(id))
    if id == 9 then
        local locations = PZLinuxGetMissionLocationPool("vehicles") or {}
        if #locations == 0 then return nil end
        local vehicle = pool[ZombRand(1, #pool+1)]
        local location = locations[ZombRand(1, #locations+1)]
        offer.vehicleName = vehicle.baseName
        offer.locationX, offer.locationY, offer.locationZ = location.x, location.y, location.z or 0
        offer.locationName = PZLinuxGetMissionLocationDescription(location)
        offer.amount = math.ceil(unit*(tonumber(vehicle.delta) or 1))
    else
        local count, weight, amount = ZombRand(4,7), 0, 0
        while weight <= 9.5 and #offer.items < count do
            local item = pool[ZombRand(1, #pool+1)]
            offer.items[#offer.items+1] = {name=item.baseName}
            weight = weight + (tonumber(item.weight) or 1)
            amount=amount+math.ceil(unit*(tonumber(item.delta) or 1))
        end
        offer.amount = amount
    end
    return offer
end
local categories = PZLinuxRequestsGetAvailableCategories
PZLinuxRequestsGetAvailableCategories = function(player, requestId)
    local result = categories(player, requestId)
    if not result.ok or not K.authoritative() then return result end
    local p = PZLinuxGetPlayer(player)
    local record = store(p)
    result.knightsOffers = {}
    for _, id in ipairs(result.available or {}) do
        local key = tostring(id)
        if not record.offers[key] then record.offers[key] = generate(p, id, record.day) end
        if record.offers[key] then result.knightsOffers[key] = copy(record.offers[key]) end
    end
    return result
end
local build = PZLinuxRequestsBuildOrder
PZLinuxRequestsBuildOrder = function(player, state, requestId)
    if not K.authoritative() then return build(player, state, requestId) end
    local p = PZLinuxGetPlayer(player)
    if not p then return {ok=false,error="no_player",requestId=requestId} end
    state = state or {}
    local record = store(p)
    local offer = record.offers[tostring(tonumber(state.contractId))]
    if not offer or state.knightsOfferId ~= offer.offerId then
        return {ok=false,error="stale_daily_offer",requestId=requestId,balance=PZLinuxLoadBankBalance(p)}
    end
    -- The client supplies only a reference. Contents, location and price come
    -- from the saved offer, never from the submitted item/price fields.
    local result = build(p, copy(offer), requestId)
    if result.ok then result.amount = offer.amount end
    return result
end

-- Declining is reversible for cars as well as goods now that neither rerolls.
PZLinuxRequestsRejectCategory = function(player, contractId, requestId)
    return {ok=true,requestId=requestId,contractId=tonumber(contractId)}
end
