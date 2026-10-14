require "KnightsDan/ProtectChase"
local C=KnightsDan.protectChase
local nextSweep=0
Events.OnTick.Add(function()
    local now=getTimestampMs()
    if now<nextSweep then return end
    nextSweep=now+2000
    C.sweep(now)
end)
