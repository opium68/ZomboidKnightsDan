require "ISPZLinuxVariablesTables"
require "PZLinux/PZLinuxDarkWeb"

-- Keep the native validated delivery queue, without the random theft branch.
-- No global RNG override; existing lost orders are not recreated.
local function deliver(player, mailboxRef, requestId, source, migrate, sync)
    local playerObj = PZLinuxGetPlayer(player)
    if not playerObj then
        return {ok=false, error="no_player", requestId=requestId}
    end
    local _, mailboxError = PZLinuxValidateMailboxInteraction(playerObj, mailboxRef)
    if mailboxError then
        return {ok=false, error=mailboxError, requestId=requestId,
            balance=PZLinuxLoadBankBalance(playerObj)}
    end
    local pending = migrate(playerObj)
    print("[KnightsDan Delivery] RECEIVE player=" .. tostring(PZLinuxGetPlayerKey(playerObj))
        .. " source=" .. source .. " pending=" .. tostring(pending)
        .. " requestId=" .. tostring(requestId))
    if pending <= 0 then
        return {ok=true, requestId=requestId, delivered=0, parcels=0,
            lost=false, remaining=0, balance=PZLinuxLoadBankBalance(playerObj)}
    end
    local result = PZLinuxDeliveryDeliverPending(playerObj, source)
    result.requestId = requestId
    result.lost = false
    result.balance = PZLinuxLoadBankBalance(playerObj)
    sync(playerObj)
    return result
end

PZLinuxDarkWebApplyDeliverOrders = function(player, mailboxRef, requestId)
    return deliver(player, mailboxRef, requestId, "darkweb",
        PZLinuxDarkWebMigrateLegacyQueue, PZLinuxDarkWebSyncPendingState)
end
PZLinuxRequestsApplyDelivery = function(player, mailboxRef, requestId)
    return deliver(player, mailboxRef, requestId, "request",
        PZLinuxRequestsMigrateLegacyQueue, PZLinuxRequestsSyncPendingState)
end
