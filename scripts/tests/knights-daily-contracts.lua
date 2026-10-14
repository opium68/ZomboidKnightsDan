-- Reuse the real PZLinux/KnightsDan cooperative regression fixture.
require "knights-coop"
local hour = 23.9
local clock = getGameTime()
clock.getWorldAgeHours = function() return hour end
clock.getTimeOfDay = function() return hour % 24 end
clock.getYear = function() return 1993 end
clock.getMonth = function() return 0 end
clock.getDay = function() return math.floor(hour / 24) end
require "zzzz_KnightsDanDailyContracts"
local world = PZLinuxContractsGetWorldData()
local active = world.active
local board = PZLinuxContractsGetBoardData()
assert(#board.contracts >= 3 and #board.contracts <= 5)
assert(math.abs(board.nextRefreshHour - 24) < 0.0001)
local first = board.contracts
assert(PZLinuxContractsGetBoardData().contracts == first, "same day does not reroll")
hour = 24
board = PZLinuxContractsGetBoardData()
assert(board.contracts ~= first and board.nextRefreshHour == 48, "midnight replaces expired offers")
assert(world.active == active, "accepted/completed world records preserved")
local id = board.contracts[1].id
world.active.dailyTest = {boardContractId = id, boardGeneratedHour = board.generatedHour}
local count = #board.contracts
assert(#PZLinuxContractsGetBoardData().contracts == count - 1, "consumed offer stays consumed after reload")
hour = 47.99
local second = board.contracts
assert(PZLinuxContractsGetBoardData().contracts == second, "no early refresh from rounded hours")
hour = 96
board = PZLinuxContractsGetBoardData()
assert(board.contracts ~= second and board.nextRefreshHour == 120, "multiple missed days generate only today's batch")
assert(world.active.dailyTest ~= nil, "old accepted record survives later dates")
local generation = board.generatedHour
assert(PZLinuxContractsGetBoardData().generatedHour == generation, "restart-style repeated access retains generation")
for _, offer in ipairs(board.contracts) do assert(offer.id ~= 13, "ATM remains excluded") end
return "actual PZLinux builds, coop regression, midnight expiry, no early refresh, missed days, persistence and accepted-record preservation"
