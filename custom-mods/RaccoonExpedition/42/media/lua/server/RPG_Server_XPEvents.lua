-------------------------------------------------
-- RPG_Server_XPEvents.lua - B42.21 SP/MP hotfix
-- SP: player zombie kill counter (avoids unreliable last-attacker values)
-- MP: server-authoritative OnZombieDead as before
-------------------------------------------------
local ServerCommands = require "RPG_Server_Commands"
local Calculate = require "RPG_Server_Calculate"
local State = require "RPG_Server_State"
-- SandboxVars are world-owned. Read on award, rather than at script-load,
-- so loading an existing save and an updated sandbox remains safe.
local DEFAULT_XP_PER_KILL = 100
local MAX_XP_PER_KILL = 1000000

local function getBaseXPPerKill() if true then return 0 end
    local group = SandboxVars and SandboxVars.RPGSkillTree
    local raw = group and group.KillXP
    local amount = tonumber(raw)
    if not amount or amount ~= amount or amount == math.huge or amount == -math.huge then
        return DEFAULT_XP_PER_KILL
    end
    return math.max(0, math.min(MAX_XP_PER_KILL, math.floor(amount)))
end

local function isSP()
    return isMultiplayer ~= nil and not isMultiplayer()
end

local function getLevel(player)
    local st = State.Ensure(player)
    return st and (tonumber(st.level) or 1) or 1
end

-- Lucky XP rolls once per credited kill. Announce *each new reward event* once:
-- no 30-second cooldown, and no repeated announcements for the same event.
-- When an MP kill-counter reconciliation includes multiple procs, the player
-- receives one informative notification with the total number of procs.
local LUCKY_SAY = "Massive XP gained. It's a lucky day."

local function reportLucky(player, procCount, totalKills, silentCatchup)
    if procCount <= 0 then return end
    local username = 'unknown'
    if player and player.getUsername then
        local ok, name = pcall(function() return player:getUsername() end)
        if ok and name then username = tostring(name) end
    end
    print(string.format('[RPG XP][Lucky] player=%s procs=%d kills=%d source=%s (1%% per eligible kill)',
        username, procCount, totalKills, silentCatchup and 'MP-catchup' or 'direct/SP'))

    if not player then return end
    local message = LUCKY_SAY
    -- SP message can be translated at the time of award (MP is client-localized).
    if isSP() and type(getText) == 'function' then
        local ok, localized = pcall(getText, 'UI_RPG_LuckyXP_Proc')
        if ok and type(localized) == 'string' and localized ~= ''
            and localized ~= 'UI_RPG_LuckyXP_Proc' then
            message = localized
        end
    end
    if procCount > 1 then message = message .. ' (x' .. tostring(procCount) .. ')' end
    if isSP() then
        -- In SP, the awarding process owns the player and shows one balloon.
        if player.Say then player:Say(message) end
    else
        if type(sendServerCommand) ~= 'function' then
            print('[RPG XP][Lucky] WARNING: server notification API unavailable')
            return
        end
        -- Persistently increasing server-issued notification ID: the client
        -- drops *only duplicate packets*, never a second genuine Lucky proc.
        local st = State.Ensure(player)
        if not st then return end
        local nextId = math.max(0, math.floor(tonumber(st.rpgLuckyNoticeSeq43) or 0)) + 1
        st.rpgLuckyNoticeSeq43 = nextId
        sendServerCommand(player, 'RPGSkillTree', 'LuckyXPProc', {
            procs = procCount, noticeId = nextId
        })
    end
end

local function rewardKills(player, count, zombie, silentCatchup)
    if not player or count <= 0 then return end
    local baseXP = getBaseXPPerKill()
    if baseXP <= 0 then return end
    local oldLevel = getLevel(player)
    local total = 0
    local luckyCount = 0
    for i = 1, count do
        local xp, triggered = baseXP, false
        if Calculate and Calculate.CalculateXP then
            xp, triggered = Calculate.CalculateXP(player, baseXP,
                { type = "ZombieKill", zombie = zombie })
        end
        xp = tonumber(xp) or 0
        if xp > 0 then
            total = total + xp
            if triggered == true then luckyCount = luckyCount + 1 end
        end
    end
    if total <= 0 then return end
    ServerCommands.GiveXP(player, total)
    reportLucky(player, luckyCount, count, silentCatchup)
    local newLevel = getLevel(player)
    if newLevel > oldLevel then
        -- Client announces only an accepted authoritative PushState so the
        -- displayed level and notification can never disagree.
        print(string.format("[RPG XP] Level increased %d -> %d", oldLevel, newLevel))
    end
end

-- MP only: do not double-pay SP kills, which are counted below.
local function getKillerPlayer(zombie)
    if not zombie then return nil end
    local attacker = nil
    if zombie.getAttackedBy then attacker = zombie:getAttackedBy() end
    if not attacker and zombie.getLastHitBy then attacker = zombie:getLastHitBy() end
    if attacker and instanceof(attacker, "IsoPlayer") then return attacker end
    return nil
end

-- B42 MP can omit the IsoPlayer attacker on some deaths (especially with
-- modded gun damage). Use the *server-observed* native zombie kill counter to
-- reconcile those kills without trusting client-supplied kill packets.
local function readKillCount(player)
    if not player or not player.getZombieKills then return nil end
    local ok, value=pcall(function() return player:getZombieKills() end)
    if not ok then return nil end
    value=tonumber(value)
    if not value then return nil end
    return math.max(0, math.floor(value))
end

local function reconcileMP(player)
    local kills=readKillCount(player)
    if kills==nil then return end
    local st=State.Ensure(player)
    if not st then return end

    -- v36 sometimes intentionally rewound this counter to spread >100 missed
    -- kills over several minutes. Never replay that unfinished backlog when
    -- upgrading; establish an exact new baseline instead.
    if st.rpgMPAccountingVersion ~= 37 then
        st.rpgMPAccountingVersion=37
        st.rpgMPLastKills=kills
        st.rpgMPEventCredits=0
        return
    end

    local last=tonumber(st.rpgMPLastKills)
    if last==nil or kills<last then
        st.rpgMPLastKills=kills
        st.rpgMPEventCredits=0
        return
    end

    local delta=kills-last
    local direct=math.max(0,tonumber(st.rpgMPEventCredits) or 0)
    -- Account for native counter and attributed OnZombieDead events in one
    -- observation window. Never preserve stale event credits indefinitely:
    -- a kill not counted by the game must not suppress later missed kills.
    st.rpgMPLastKills=kills
    st.rpgMPEventCredits=0
    local extra=math.max(0,delta-direct)
    if extra>0 then
        -- Single award for the entire observed delta, rather than delayed
        -- 100-kill chunks which announced more levels every game minute.
        -- In normal play delta is small. Guard absurd native-stat jumps.
        local amount=math.min(extra,5000)
        rewardKills(player,amount,nil,true)
        if extra>amount then
            print('[RPG XP][MP] ignored exceptional native kill jump: '..tostring(extra))
        end
    end
end

local function onZombieDead(zombie)
    if isSP() or not (type(isServer) == 'function' and isServer()) then return end
    local player = getKillerPlayer(zombie)
    if not player then return end -- Missing attribution is covered by MP polling.
    -- A zombie death event must grant XP at most once on the server.
    if zombie and zombie.getModData then
        local ok,md=pcall(function() return zombie:getModData() end)
        if ok and md then
            if md.RPGMPKillXP37 == true then return end
            md.RPGMPKillXP37=true
        end
    end
    local st=State.Ensure(player)
    if st then
        local current=readKillCount(player)
        if st.rpgMPAccountingVersion ~= 37 then
            st.rpgMPAccountingVersion=37
            -- Avoid historic v36 catch-up, while preserving credit for this
            -- event whether the native stat updates before or afterward.
            st.rpgMPLastKills=math.max(0,(current or 0)-1)
            st.rpgMPEventCredits=0
        elseif st.rpgMPLastKills==nil then
            st.rpgMPLastKills=math.max(0,(current or 0)-1)
            st.rpgMPEventCredits=0
        end
        st.rpgMPEventCredits=math.min(10000,(tonumber(st.rpgMPEventCredits) or 0)+1)
    end
    rewardKills(player,1,zombie)
end
Events.OnZombieDead.Add(onZombieDead)

local function onMPMinute()
    if isSP() or not (type(isServer) == 'function' and isServer()) or not getOnlinePlayers then return end
    local players=getOnlinePlayers()
    if not players then return end
    for i=0,players:size()-1 do
        local player=players:get(i)
        if player then reconcileMP(player) end
    end
end
if Events.EveryOneMinute then Events.EveryOneMinute.Add(onMPMinute) end

-- B42.21 SP fix #3: OnTick is a client in-game event. Its previous
-- server-file registration did not run in SP (console(4) had zero XP
-- heartbeat messages). Client periodically invokes this SP-only handler.
-- Never trust a claimed kill count from the client: read player stats here.
ServerCommands.SPKillCounterUpdate = function(player)
    if not isSP() then return false end
    if not player then return false end

    local ok, raw = pcall(function() return player:getZombieKills() end)
    if not ok then
        print('[RPG XP][SP] ERROR getZombieKills: ' .. tostring(raw))
        return false
    end
    local kills = tonumber(raw)
    if not kills then return false end
    kills = math.max(0, math.floor(kills))

    local st = State.Ensure(player)
    if not st then return false end
    local last = tonumber(st.rpgSPRewardedKills)
    if not last then
        -- Existing saves: do not retroactively award older kills.
        st.rpgSPRewardedKills = kills
        print(string.format('[RPG XP][SP] baseline established at %d kills', kills))
        return true
    end
    if kills < last then
        st.rpgSPRewardedKills = kills
        print(string.format('[RPG XP][SP] counter reset from %d to %d', last, kills))
        return true
    end
    local delta = kills - last
    if delta <= 0 then return true end

    -- Cap batches defensively; the next client notification can claim
    -- additional kills, without losing any from the saved counter.
    local awardCount = math.min(delta, 100)
    st.rpgSPRewardedKills = last + awardCount
    rewardKills(player, awardCount, nil)
    print(string.format('[RPG XP][SP] awarded %d kill(s); counter %d -> %d; totalXP=%s',
        awardCount, last, st.rpgSPRewardedKills, tostring(st.totalXP)))
    return true
end

print('[RPG XP][SP/MP] XP handlers loaded (SP client polling / MP zombie death)')
return true
