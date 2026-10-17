local handler, reply, enabled, source
function isServer() return true end
Events = {OnClientCommand={Add=function(fn) handler=fn end}}
IsoObjectChange = {USES_EXTERNAL_WATER_SOURCE="external"}
function getGameTime() return {getWorldAgeDaysSinceBegin=function() return 40 end} end
function getSandboxOptions() return {getWaterShutModifier=function() return 90 end} end
local sq = {getRoom=function() return {} end,isNoWater=function() return false end}
local obj = {external=true,md={LGEPPiped=true,canBeWaterPiped=true},writes=0,modSync=0,flagSync=0}
function obj:getSquare() return sq end
function obj:hasModData() return true end
function obj:getModData() return self.md end
function obj:FindExternalWaterSource() return source end
function obj:getUsesExternalWaterSource() return self.external end
function obj:getSprite() return {getName=function() return "sink" end} end
function obj:getFluidAmount() return self.external and 0 or 10000 end
function obj:setUsesExternalWaterSource(on) self.external=on;self.writes=self.writes+1 end
function obj:transmitModData() self.modSync=self.modSync+1 end
function obj:sendObjectChange(key,args)
    assert(key=="external" and args.value==false)
    self.flagSync=self.flagSync+1
end
function sq:getObjects() return {size=function() return 1 end,get=function(_,i) return i==0 and obj or nil end} end
function getCell() return {getGridSquare=function(_,x,y,z) return x==10 and y==20 and z==0 and sq or nil end} end
local player = {role="admin",x=10,z=0}
function player:getAccessLevel() return self.role end
function player:getX() return self.x end
function player:getY() return 20 end
function player:getZ() return self.z end
function player:getUsername() return "test-admin" end
function sendServerCommand(p,m,c,r) assert(p==player and m=="KnightsDanPlumbing");reply=r end
LGEP = {KEY_PIPED="LGEPPiped",getOption=function() return enabled end,
    isPlumbableFixture=function(o) return o==obj end,isGhost=function() return false end}
assert(loadfile("custom-mods/KnightsDanServerPatch/42/media/lua/server/zzzzzz_KnightsDanPlumbingFixture.lua"))()
local function ask(command,patch)
    reply=nil
    local args={x=10,y=20,z=0,index=0,sprite="sink"}
    for k,v in pairs(patch or {}) do args[k]=v end
    handler("KnightsDanPlumbing",command,player,args)
    return reply
end
assert(ask("inspect").after.external and obj.writes==0)
player.role="user";assert(not ask("restore"));player.role="admin"
player.x=100;assert(not ask("restore"));player.x=10
player.z=1;assert(not ask("restore"));player.z=0
assert(not ask("restore",{sprite="changed"}))
assert(not ask("restore",{index=1}))
assert(not ask("restore",{x=0/0}))
assert(not ask("restore",{x=10.5}))
enabled=true;assert(ask("restore").reason=="Enabled" and obj.writes==0);enabled=false
source=obj;assert(ask("restore").reason=="Source" and obj.writes==0);source=nil
local result=ask("restore")
assert(result.reason=="Restored" and not result.after.external and not result.after.marker)
assert(obj.writes==1 and obj.modSync==1 and obj.flagSync==1)
assert(obj.md.canBeWaterPiped==true, "never convert a moved sink into a mains fixture")
assert(ask("restore").reason=="Unchanged" and obj.writes==1, "repeat is a no-op")
obj.external=false;obj.md.LGEPPiped=true
assert(ask("restore").reason=="Restored" and obj.md.LGEPPiped==nil, "clear stale marker even with flag already false")
return "single-fixture server guard, non-admin/distance/stale-object rejection, source preservation, synchronization and idempotency"
