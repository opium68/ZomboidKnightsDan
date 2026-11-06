local NPC = require 'RPG_Shared_NPCCompat'
-- Project RPG 1.00.67: world-age-driven threat scaling.
-- Stage 1 at world creation; +1 stage per configured 30 in-game days, max 5.
-- The server owns zombie health; client syncs movement class for visible zombies.
local Danger = {}
local DEFAULTS = {
    {slow=30,fast=70,sprint=0,hp=100,raid=1},
    {slow=20,fast=80,sprint=0,hp=110,raid=2},
    {slow=10,fast=89,sprint=1,hp=120,raid=3},
    {slow=0,fast=95,sprint=5,hp=130,raid=4},
    {slow=0,fast=90,sprint=10,hp=150,raid=5},
}
local function option(key,fallback,minimum,maximum)
    local tab=SandboxVars and SandboxVars.RPGSkillTree or nil
    local n=tab and tonumber(tab[key]) or nil
    if not n or n~=n then n=fallback end
    return math.max(minimum,math.min(maximum,n))
end
function Danger.enabled() if true then return false end
    local tab=SandboxVars and SandboxVars.RPGSkillTree or nil
    local v=tab and tab.WorldDangerEnabled
    if v==nil then return true end
    return not (v==false or v==0 or v=='false')
end
function Danger.worldHours()
    local gt=getGameTime and getGameTime() or nil
    return (gt and gt.getWorldAgeHours and tonumber(gt:getWorldAgeHours())) or 0
end
function Danger.daysPerStage()
    return math.floor(option('WorldDangerDaysPerStage',30,1,365))
end
function Danger.stage()
    if not Danger.enabled() then return 0 end
    local worldDays=math.max(0,Danger.worldHours()/24)
    return math.min(5,1+math.floor(worldDays/Danger.daysPerStage()))
end
function Danger.stats(stage)
    local n=math.max(1,math.min(5,math.floor(tonumber(stage) or 1)))
    local preset=DEFAULTS[n]
    local prefix='WorldDangerS'..n
    local slow=option(prefix..'Slow',preset.slow,0,100)
    local fast=option(prefix..'Fast',preset.fast,0,100)
    local sprint=option(prefix..'Sprint',preset.sprint,0,100)
    local sum=slow+fast+sprint
    if sum<=0 then slow,fast,sprint,sum=preset.slow,preset.fast,preset.sprint,100 end
    return {
        slow=slow/sum*100, fast=fast/sum*100, sprint=sprint/sum*100,
        health=option(prefix..'HealthPercent',preset.hp,10,1000)/100,
        raid=option(prefix..'RaidMultiplier',preset.raid,0.1,10),
    }
end
function Danger.raidMultiplier()
    local stage=Danger.stage()
    if stage<=0 then return 1 end
    return Danger.stats(stage).raid
end
-- Roll is based on zombie network ID if available. Position is fallback for
-- zombies not assigned a network ID yet. No per-frame random re-rolls.
local function zombieRoll(zombie)
    local id=nil
    if zombie.getOnlineID then
        local ok,number=pcall(function()return zombie:getOnlineID()end)
        if ok then id=tonumber(number) end
    end
    if id and id>=0 then return (id*7193+1277)%10000/100 end
    local x=(zombie.getX and tonumber(zombie:getX())) or 0
    local y=(zombie.getY and tonumber(zombie:getY())) or 0
    return ((math.floor(x)*191+math.floor(y)*307+157)%10000)/100
end
function Danger.chooseSpeed(stats,roll)
    if roll<stats.slow then return 3 end -- vanilla: Shambler
    if roll<stats.slow+stats.fast then return 2 end -- Fast Shambler
    return 1 -- Sprinter
end
-- Use the vanilla IsoZombie movement-category methods.  Writing to the Java
-- speedType field via Lua causes Kahlua errors in Build 42.21 and does not
-- initialize the matching walk animation/speed modifiers.
local function applySpeed(zombie,desired)
    if desired~=1 and desired~=2 and desired~=3 then return false end
    -- Keep vanilla crawler movement intact. Apply the assigned category once
    -- the zombie stands up, rather than forcing a crawler to run on its feet.
    if zombie.isCrawling then
        local ok,crawling=pcall(function()return zombie:isCrawling()end)
        if ok and crawling then return false end
    end
    local ok,current=pcall(function()return zombie:getSpeedType()end)
    if ok and tonumber(current)==desired then
        -- B42 can reset the walk variant while leaving speedType unchanged.
        local walkOK,walkType=pcall(function()return zombie:getWalkType()end)
        if not walkOK or type(walkType)~='string' then return true end
        local prefix=string.lower(walkType)
        local category=prefix:find('^sprint') and 1 or (prefix:find('^slow') and 3 or 2)
        if category==desired then return true end
    end
    local worked,err=pcall(function()
        if desired==1 then
            zombie:doSprinter()
        elseif desired==2 then
            zombie:doFastShambler()
        else
            zombie:doShambler()
        end
    end)
    if not worked then
        if not Danger._speedWarning then
            Danger._speedWarning=true
            print('[Project RPG Danger] vanilla zombie speed method failed: '..tostring(err))
        end
        return false
    end
    return true
end
function Danger.applyZombie(zombie,authority)
    local stage=Danger.stage()
    if stage<=0 or not zombie or (zombie.isDead and zombie:isDead()) then return false end
    if not zombie.getModData then return false end
    -- Leave Bandits NPCs and The Mutants' special zombie speed/HP under their mods' control.
    -- Both integrations are optional; ordinary zombies keep the original danger scaling.
    if NPC.isExcluded(zombie) then return false end
    -- MP server may observe freshly created zombies before they have a valid
    -- network ID. Avoid sending speed/animation changes at ID=-1.
    if authority and type(isServer)=='function' and isServer() and zombie.getOnlineID then
        local idOK,id=pcall(function() return zombie:getOnlineID() end)
        if not idOK or not tonumber(id) or tonumber(id)<0 then return false end
    end
    local ok,md=pcall(function()return zombie:getModData()end)
    if not ok or not md then return false end
    -- Preserve saved classifications from 1.00.67/68: no additional HP scaling.
    if md.RPGWorldDangerStage67~=nil then
        applySpeed(zombie,tonumber(md.RPGWorldDangerSpeed67))
        return false
    end
    local stats=Danger.stats(stage)
    local speed=Danger.chooseSpeed(stats,zombieRoll(zombie))
    if not authority then
        -- In MP, the server alone writes persistent zombie classification and
        -- health. Clients may apply the same deterministic vanilla movement
        -- type for the locally simulated zombie without tagging its ModData.
        -- This prevents a client-side OnZombieCreate event from marking a
        -- zombie "processed" before the server has multiplied its health.
        applySpeed(zombie,speed)
        return false
    end
    md.RPGWorldDangerStage67=stage
    md.RPGWorldDangerSpeed67=speed
    if authority and zombie.getHealth and zombie.setHealth then
        local healthOK,health=pcall(function()return zombie:getHealth()end)
        health=tonumber(health)
        if healthOK and health and health>0 then
            local good,err=pcall(function()zombie:setHealth(health*stats.health)end)
            if not good and not Danger._healthWarning then
                Danger._healthWarning=true
                print('[Project RPG Danger] health adjust error: '..tostring(err))
            end
        end
    end
    applySpeed(zombie,speed)
    return true
end
return Danger
