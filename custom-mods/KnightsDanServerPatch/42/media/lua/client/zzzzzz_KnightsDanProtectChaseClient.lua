require "KnightsDan/ProtectChase"
local C=KnightsDan.protectChase
if isClient() then
    Events.OnZombieUpdate.Add(function(zombie) C.clientStep(zombie) end)
    Events.OnZombieDead.Add(function(zombie) C.release(zombie) end)
    -- Discard only Lua bookkeeping, never animation buffers or zombie state.
    Events.EveryOneMinute.Add(function() C.pruneRuntime(getTimestampMs()) end)
end
