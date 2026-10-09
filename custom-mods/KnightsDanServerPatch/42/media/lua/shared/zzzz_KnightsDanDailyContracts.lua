require "zzz_KnightsDanEconomy"
PZLinux.Config.Contracts.boardRefreshHours = 24
local nativeBoard = PZLinuxContractsGetBoardData

function PZLinuxContractsGetBoardData()
    if not KnightsDan.authoritative() then return nativeBoard() end
    local clock = getGameTime()
    local hour = clock:getWorldAgeHours()
    local today = tostring(clock:getYear()) .. ":" .. tostring(clock:getMonth()) .. ":" .. tostring(clock:getDay())
    local board = ModData.getOrCreate("PZLinuxContractsBoard")
    if board.knightsDailyVersion ~= 1 or board.knightsCalendarDay ~= today or type(board.contracts) ~= "table" then
        local pool = {}
        for _, definition in ipairs(PZLinuxContractDefinitions or {}) do
            if tonumber(definition.id) ~= 13 then
                pool[#pool + 1] = PZLinuxContractsBuildContract(definition)
            end
        end
        PZLinuxContractsShuffle(pool)
        local selected = {}
        local count = math.min(#pool, ZombRand(3, 6))
        for i = 1, count do selected[i] = pool[i] end
        board.contracts = selected
        board.adminForcedContracts = {}
        board.generatedHour = hour
        board.nextRefreshHour = hour + 24 - clock:getTimeOfDay()
        board.scheduleVersion = 2
        board.knightsDailyVersion = 1
        board.knightsCalendarDay = today
        board.knightsEconomyVersion = 1
        PZLinux.contractPreviews = {}
        if isServer() then ModData.transmit("PZLinuxContractsBoard") end
        print("[KnightsDan] daily contracts: " .. today .. ", offers=" .. tostring(count))
    end
    local consumed = {}
    for _, record in pairs(PZLinuxContractsGetWorldData().active or {}) do
        if record.boardContractId and tonumber(record.boardGeneratedHour) == board.generatedHour then
            consumed[tonumber(record.boardContractId)] = true
        end
    end
    local changed = false
    for i = #board.contracts, 1, -1 do
        local id = tonumber(board.contracts[i].id)
        if consumed[id] and not (board.adminForcedContracts or {})[tostring(id)] then
            table.remove(board.contracts, i)
            changed = true
        end
    end
    if changed then
        PZLinux.contractPreviews = {}
        if isServer() then ModData.transmit("PZLinuxContractsBoard") end
    end
    return board
end

-- Poll on game-hour boundaries so a new board exists at midnight even if no
-- computer is open. Requests also check the date, including after a restart.
Events.EveryHours.Add(function()
    if KnightsDan.authoritative() then PZLinuxContractsGetBoardData() end
end)
