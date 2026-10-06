require "ISPZLinuxVariablesTables"
require "KnightsDan/Core"
local K = KnightsDan
-- Original modules remain installed through Workshop; hooks are applied after
-- their definitions and depend on the audited PZLinux 1.0.20 interface.
PZLinux.Economy.scarcityMultiplier = function() return 1 end
local function disabledAtm(_, _, _, requestId)
    return {ok=false, error="knights_atm_disabled", requestId=requestId}
end
PZLinuxApplyAtmWithdrawal = disabledAtm
PZLinuxApplyAtmDeposit = disabledAtm
PZLinuxGetAtmState = function(_, _, requestId)
    return {ok=false, error="knights_atm_disabled", requestId=requestId}
end
PZLinuxContractsApplyAtmRefillDeposit = PZLinuxGetAtmState
-- Remove the ATM delivery job without changing existing accounts or cash.
for index=#PZLinuxContractDefinitions,1,-1 do
    if tonumber(PZLinuxContractDefinitions[index].id)==13 then
        table.remove(PZLinuxContractDefinitions,index)
    end
end
local buildContract = PZLinuxContractsBuildContract
PZLinuxContractsBuildContract = function(definition)
    local contract = buildContract(definition)
    contract.reward = PZLinux.Economy.roundPrice(definition.reward, "nearest")
    return contract
end
local getBoard = PZLinuxContractsGetBoardData
PZLinuxContractsGetBoardData = function()
    local board = getBoard()
    for index=#(board.contracts or {}),1,-1 do
        if tonumber(board.contracts[index].id)==13 then
            table.remove(board.contracts,index)
            PZLinux.contractPreviews = {}
        end
    end
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
print("[KnightsDan] economy patch " .. K.version .. " loaded; stock trading enabled; inflation and ATM disabled")
