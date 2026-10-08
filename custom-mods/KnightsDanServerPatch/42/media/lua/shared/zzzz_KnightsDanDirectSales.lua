require "ISPZLinuxVariablesTables"
require "PZLinux/PZLinuxDarkWeb"

local function deposit(player, result, reason)
    if not result or not result.ok then return result end
    local playerObj = PZLinuxGetPlayer(player)
    local receiptId = result.receiptId
    if not playerObj or not receiptId or receiptId == "" then return result end
    if not PZLinuxDeliveryIsReceiptRedeemed(receiptId) then
        local amount = result.total or result.amount
        local credit = PZLinuxApplyBankCredit(playerObj, amount, reason, receiptId)
        if not credit or not credit.ok then
            -- Retain the original sale parcel and receipt if credit fails.
            result.ok = false
            result.error = credit and credit.error or "sale_credit_failed"
            return result
        end
        PZLinuxDeliveryMarkReceiptRedeemed(receiptId, playerObj)
    end
    -- Remove only this sale's parcel; unrelated or old parcels are preserved.
    local items = playerObj:getInventory():getItems()
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        if item and item:getFullType() == "Base.SuspiciousPackage"
            and item:getModData().PZLinuxSaleReceiptId == receiptId then
            PZLinuxRemoveInventoryItem(playerObj, item)
        end
    end
    result.balance = PZLinuxLoadBankBalance(playerObj)
    result.knightsDirectDeposit = true
    PZLinuxTransmitPlayerModData(playerObj)
    return result
end

local surplus = PZLinuxSellApplySell
PZLinuxSellApplySell = function(player, itemName, requestId)
    return deposit(player, surplus(player, itemName, requestId), "knights-surplus-direct")
end
local darkweb = PZLinuxDarkWebApplySell
PZLinuxDarkWebApplySell = function(player, offerIndex, quantity, requestId)
    return deposit(player, darkweb(player, offerIndex, quantity, requestId), "knights-darkweb-direct")
end
