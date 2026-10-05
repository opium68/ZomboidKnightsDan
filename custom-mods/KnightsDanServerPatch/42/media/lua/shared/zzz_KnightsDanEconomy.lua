require "ISPZLinuxVariablesTables"
require "KnightsDan/Core"
local K = KnightsDan
-- Original modules remain installed through Workshop; hooks are applied after
-- their definitions and depend on the audited PZLinux 1.0.20 interface.
PZLinux.Economy.scarcityMultiplier = function() return 1 end
local function disabled(_, _, _, requestId)
    return {ok=false, error="knights_stock_trading_disabled", requestId=requestId}
end
PZLinuxTradingApplyBuy = disabled
PZLinuxTradingApplySell = disabled
PZLinuxContractsUpdateCompanyPrice = function() end
local buildContract = PZLinuxContractsBuildContract
PZLinuxContractsBuildContract = function(definition)
    local contract = buildContract(definition)
    contract.reward = PZLinux.Economy.roundPrice(definition.reward, "nearest")
    return contract
end
local getBoard = PZLinuxContractsGetBoardData
PZLinuxContractsGetBoardData = function()
    local board = getBoard()
    if board.knightsEconomyVersion ~= 1 and K.authoritative() then
        for _, offer in ipairs(board.contracts or {}) do
            local def = PZLinuxContractsGetDefinition(offer.id)
            if def then offer.reward=PZLinux.Economy.roundPrice(def.reward,"nearest") end
        end
        PZLinux.contractPreviews = {}
        board.knightsEconomyVersion=1
    end
    return board
end
print("[KnightsDan] economy patch " .. K.version .. " loaded; inflation and stock trading disabled")
