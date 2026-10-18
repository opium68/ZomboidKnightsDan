function isClient() return false end
function isServer() return true end
function PZLinuxGetCharacterKey(p) return p.key end
function getTimestampMs() return 0 end
local players,world,zombies={}, {active={}},{}
local function list(t) return {size=function() return #t end,get=function(_,i) return t[i+1] end} end
function getOnlinePlayers() return list(players) end
function getCell() return {getZombieList=function() return list(zombies) end} end
function PZLinuxContractsGetWorldData() return world end
function getPlayerByOnlineID(id) for _,p in ipairs(players) do if p.id==id then return p end end end
local function player(key,id,x)
    local p={key=key,id=id,x=x,y=0,z=0,dead=false,md={}}
    function p:getX() return self.x end
    function p:getY() return self.y end
    function p:getZ() return self.z end
    function p:getOnlineID() return self.id end
    function p:getUsername() return self.key end
    function p:getModData() return self.md end
    function p:isDead() return self.dead end
    return p
end
local nextId=0
local function zombie(md)
    nextId=nextId+1
    local z={md=md,x=0,y=0,z=0,id=nextId,paths=0,transmits=0,targets=0}
    function z:hasModData() return self.md~=nil end
    function z:getModData() assert(self.md,"must not create modData for ordinary zombies");return self.md end
    function z:getX() return self.x end
    function z:getY() return self.y end
    function z:getZ() return self.z end
    function z:isDead() return self.dead or false end
    function z:isRemoteZombie() return self.remote or false end
    function z:getOnlineID() return self.id end
    function z:getOwner() return self.owner end
    function z:getTarget() return self.target end
    function z:setTarget(p) self.target=p;self.targets=self.targets+1 end
    function z:setTargetSeenTime(t) self.seen=t end
    function z:pathToCharacter(p) self.paths=self.paths+1;self.pathTarget=p end
    function z:transmitModData() self.transmits=self.transmits+1 end
    return z
end
require "KnightsDan/ProtectChase"
local C=KnightsDan.protectChase
local a,b,outsider=player("a",1,100),player("b",2,10),player("outsider",3,1)
players={a,b,outsider}
world.active.job={id="job",contractId=8,status="protect_started",knightsMembers={a="a",b="b"}}
local z=zombie({PZLinuxContractId="job",PZLinuxContractObjective="protect"})
local ordinary=zombie(nil)
local manhunt=zombie({PZLinuxContractId="job",PZLinuxContractObjective="manhunt"})
zombies={z,ordinary,manhunt}
C.sweep(0)
assert(z.target==b and z.pathTarget==b and z.md.knightsProtectTargetId==2,"nearest registered member, not nearer outsider")
assert(ordinary.targets==0 and manhunt.targets==0,"ordinary and other mission zombies untouched")
C.sweep(2000)
assert(z.paths==1 and z.transmits==1,"no repeated network state or path request for same target")
b.x=200;C.sweep(4000)
assert(z.target==a and z.pathTarget==a,"retargets nearest participant")
a.dead=true;C.sweep(6000)
assert(z.target==b,"dead player replaced")
players={outsider};C.sweep(8000)
assert(z.target==nil and not z.md.knightsProtectChase,"all participants offline releases forced target")
players={a,b,outsider};a.dead=false
world.active.job.status="protect_clear";C.sweep(10000)
assert(z.target==a,"continues after kill threshold until contract completion")
world.active.job.status="completed";C.sweep(12000)
assert(z.target==nil and not z.md.knightsProtectChase,"completed contract releases pursuit")
world.active.job.status="cancelled";C.sweep(14000)
assert(z.target==nil)
world.active.job.status="protect_started";z.owner={};C.sweep(16000)
assert(z.md.knightsProtectChase and z.target==nil,"server assigns but does not drive a client-owned zombie")
z.remote=true;C.clientStep(z,16000)
assert(z.target==nil,"remote replica is untouched")
z.remote=false;C.clientStep(z,18000)
assert(z.target==a,"owning client follows server assignment")
local count=z.paths;C.clientStep(z,18100)
assert(z.paths==count,"client handler throttles updates")
z.md.knightsProtectChase=false;C.clientStep(z,18200)
assert(z.target==nil,"client releases after server clears assignment")
z.md.knightsProtectChase=true;z.md.knightsProtectTargetKey="previous-character";C.clientStep(z,20000)
assert(z.target==nil,"reused online ID cannot target a different character")
local horde={}
for i=1,50 do local n=zombie({});n.x=500;horde[i]=n;C.drive(n,a,30000) end
local paths=0;for _,n in ipairs(horde) do paths=paths+n.paths end
assert(paths==4,"burst pathfinding requests are capped at four per 125 ms")
C.pruneRuntime(60000)
KnoxEscapeQuest={DATA_KEY='test.escape',DEFENSE_STAGE=9}
local escapeState={stage=9,defenseEndHour=99,escaped={}}
ModData={getOrCreate=function() return escapeState end}
local wave=zombie({knightsEscapeWave='99'})
local hunt=zombie({PZLinuxContractObjective='manhunt',PZLinuxContractId='job'})
zombies={wave,hunt};players={a,b};a.dead=false;b.dead=false;b.x=10
C.sweep(70000);assert(wave.target==b and hunt.target==nil,'escape wave tracks; manhunt stays fixed')
b.dead=true;C.sweep(72000);assert(wave.target==a,'escape death retarget')
escapeState.stage=10;C.sweep(74000);assert(wave.target==nil,'escape completion releases pursuit')
return "protect-only nearest participant, dead/disconnect retarget, complete/cancel release, server/client ownership, character identity, throttled pathfinding PASS"
