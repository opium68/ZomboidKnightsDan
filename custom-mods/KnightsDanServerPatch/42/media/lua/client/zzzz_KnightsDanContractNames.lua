require "ISPZLinuxVariablesTables"
require "KnightsDan/ContractNames"

-- Translate display text after receipt; item IDs, counts and rewards stay intact.
local dispatch = PZLinuxDispatchCallback
PZLinuxDispatchCallback = function(args)
    if args then
        local name = KnightsDanContractNames.name(args.info)
        if name then args.infoName = name end
        if args.note then args.note = KnightsDanContractNames.note(args.note) end
        if args.fullNote then args.fullNote = KnightsDanContractNames.note(args.fullNote) end
    end
    return dispatch(args)
end

-- Existing contract notes were authored in the server's language. Refresh their
-- visible pages locally, including notes accepted before this patch.
local ticks = 0
Events.OnTick.Add(function()
    ticks = ticks + 1
    if ticks < 300 then return end
    ticks = 0
    local player = getPlayer()
    local inventory = player and player:getInventory()
    if not inventory then return end
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getType() == "Note" and item:getName() == "Contract" then
            local original = item:seePage(1)
            local translated = KnightsDanContractNames.note(original)
            if translated ~= original then item:addPage(1, translated) end
        end
    end
end)
