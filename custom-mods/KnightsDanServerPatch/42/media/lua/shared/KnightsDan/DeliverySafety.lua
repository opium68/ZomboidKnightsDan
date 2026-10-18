require "ISPZLinuxVariablesTables"
require "PZLinux/PZLinuxDarkWeb"
require "KnightsDan/Retirement"
local K = KnightsDan
local native = assert(K.deliveryNative, "PZLinux delivery helper overlay was not loaded")

local sources = {
    darkweb = {migration="darkWeb", field="PZLinuxOnItemBuyOnDarkWebQueue",
        decode=PZLinuxDarkWebQueueDecode},
    request = {migration="requests", field="PZLinuxOnItemRequestQueue",
        decode=PZLinuxRequestsQueueDecode},
}

function K.syncDeliveryPending(player, source)
    local data = player:getModData()
    local record = PZLinuxDeliveryGetPlayerRecord(player)
    local failures = record.knightsLegacyFailures and record.knightsLegacyFailures[source] or {}
    local pending = PZLinuxDeliveryPendingCount(player, source) + #failures
    if source == "darkweb" then
        data.PZLinuxOnItemBuyOnDarkWebStatus = pending > 0 and 1 or 0
        data.PZLinuxDarkWebPendingCount = pending
    elseif source == "request" then
        data.PZLinuxActiveRequest = (pending > 0 or tonumber(data.PZLinuxOnItemRequestCar) == 1) and 1 or 0
        data.PZLinuxRequestPendingCount = pending
    end
    local config = sources[source]
    if config and tonumber(record.migrations[config.migration]) == 1 then data[config.field] = "" end
    PZLinuxTransmitPlayerModData(player)
    return pending
end

local function migrate(player, source)
    local p = PZLinuxGetPlayer(player)
    if not p then return 0 end
    local config = sources[source]
    local record = PZLinuxDeliveryGetPlayerRecord(p)
    if tonumber(record.migrations[config.migration]) == 1 then return K.syncDeliveryPending(p, source) end
    record.knightsLegacyQueues = record.knightsLegacyQueues or {}
    record.knightsLegacyFailures = record.knightsLegacyFailures or {}
    record.knightsLegacyDone = record.knightsLegacyDone or {}
    local done = record.knightsLegacyDone[source] or {}
    record.knightsLegacyDone[source] = done
    -- Keep the original complete string in the persistent ledger. Native buy
    -- callbacks may clear the player's legacy field even after a failed enqueue.
    local original = record.knightsLegacyQueues[source]
    if original == nil then
        original = p:getModData()[config.field] or ""
        record.knightsLegacyQueues[source] = original
    end
    local failures = {}
    local decoded = config.decode(original)
    local expectedEntries = 0
    if type(original) == "string" then
        for _ in original:gmatch("[^;]+") do expectedEntries=expectedEntries+1 end
    end
    if type(original) ~= "string" or #decoded ~= expectedEntries then
        failures[#failures+1]={requestId="legacy-parse",error="legacy_queue_invalid"}
    end
    for index, entry in ipairs(decoded) do
        local items, requestId
        if source == "darkweb" then
            items = {{name=entry.name, quantity=entry.quantity}}
            requestId = "legacy-darkweb-" .. tostring(index) .. "-" .. tostring(entry.name)
        else
            items = {}
            for _, item in ipairs(entry.items or {}) do items[#items+1] = {name=item.name,quantity=1} end
            requestId = "legacy-request-" .. tostring(index)
        end
        if not done[requestId] then
            items=K.cleanOrderItems(items)
            if #items==0 then done[requestId]=true
            else
                local order, _, failure = PZLinuxDeliveryEnqueue(p, source, items, requestId)
                if order then done[requestId]=true
                else failures[#failures+1] = {requestId=requestId,error=failure or "enqueue_failed"} end
            end
        end
    end
    record.knightsLegacyFailures[source] = failures
    if #failures == 0 then
        record.migrations[config.migration] = 1
        record.knightsLegacyQueues[source] = nil
        record.knightsLegacyDone[source] = nil
    end
    return K.syncDeliveryPending(p, source)
end
PZLinuxDarkWebMigrateLegacyQueue = function(player) return migrate(player, "darkweb") end
PZLinuxRequestsMigrateLegacyQueue = function(player) return migrate(player, "request") end

local function processOrder(player, order, result)
    local parts, planError = native.EnsureParcelPlan(order)
    if not parts then order.status="pending"; return planError or "parcel_plan_failed" end
    for _, part in ipairs(parts) do
        if part.status == "pending" or part.status == "materializing" then
            local existing = native.FindParcel(player, order, part, #parts)
            if existing then
                part.status="delivered"
                part.deliveredHour=native.WorldHour()
                result.recovered=result.recovered+1
            else
                if PZLinuxDeliveryHasRoomForMoreParcels and not PZLinuxDeliveryHasRoomForMoreParcels(player) then
                    order.status="pending"; result.tooHeavy=true; return
                end
                order.status="materializing"; part.status="materializing"
                local parcel, added, failure = native.CreateParcel(player, order, part)
                if not parcel then
                    order.status="pending"; part.status="pending"
                    if failure == "too_heavy" then result.tooHeavy=true; return end
                    return failure or "parcel_creation_failed"
                end
                if PZLinuxSyncAddedInventoryItem and not PZLinuxSyncAddedInventoryItem(player, parcel) then
                    native.RemoveTemporaryParcel(player:getInventory(), parcel)
                    order.status="pending"; part.status="pending"
                    return "parcel_sync_failed"
                end
                part.status="delivered"; part.deliveredHour=native.WorldHour()
                result.delivered=result.delivered+added
                result.parcels=result.parcels+1
            end
        end
    end
    if native.AllPartsDelivered(parts) then
        order.status="delivered"; order.deliveredHour=native.WorldHour()
        order.knightsDeliveryError=nil
    else order.status="pending" end
end

PZLinuxDeliveryDeliverPending = function(player, source)
    local p = PZLinuxGetPlayer(player)
    if not p then return {ok=false,error="no_player"} end
    local record = PZLinuxDeliveryGetPlayerRecord(p)
    local result = {ok=true,delivered=0,parcels=0,recovered=0,tooHeavy=false,failedOrders={}}
    for _, order in ipairs(record.orders) do
        if order.source == source and (order.status == "pending" or order.status == "materializing") then
            local failure = processOrder(p, order, result)
            if failure then
                -- Keep the paid order retryable and continue with later orders.
                order.knightsDeliveryError=failure
                result.failedOrders[#result.failedOrders+1]={orderId=order.id,error=failure}
                result.ok=false; result.error=result.error or failure
            end
            if result.tooHeavy then break end
        end
    end
    native.TrimHistory(record)
    local config = PZLinux.Config and PZLinux.Config.Deliveries or {}
    result.maxCarryWeight=math.max(1,tonumber(config.maxCarryWeight) or 80)
    result.remaining=PZLinuxDeliveryPendingCount(p,source)
    result.pendingItems=0
    for _,order in ipairs(record.orders) do
        if order.source==source and (order.status=="pending" or order.status=="materializing") then
            if order.parcels and #order.parcels>0 then
                for _,part in ipairs(order.parcels) do if part.status~="delivered" then
                    for _,item in ipairs(part.items or {}) do result.pendingItems=result.pendingItems+(tonumber(item.quantity) or 0) end
                end end
            else for _,item in ipairs(order.items or {}) do result.pendingItems=result.pendingItems+(tonumber(item.quantity) or 0) end end
        end
    end
    return result
end
