-- Override this entry point, while loading all unrelated native events from
-- the installed Workshop source. No upstream source is redistributed.
require "KnightsDan/Upstream"
require "KnightsDan/ManhuntClient"
if KnightsDan.nativeWorldEventsLoaded then return end
KnightsDan.loadPzLinuxSource("media/lua/client/Context/World/Events/PZLinuxOnEvents.lua",
    KnightsDan.adaptManhuntClientSource)
KnightsDan.nativeWorldEventsLoaded=true
