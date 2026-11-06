-------------------------------------------------
-- RPG_Server_ApplyFactors.lua
-- SERVER ONLY: apply st.factors to real stats & carry weight & specials
--  - Calc(RPG_Server_Calculate)는 "계산+st.factors 저장"만
--  - Apply(이 파일)는 "틱마다 실제 스탯 반영"만
-------------------------------------------------

local MODULE = "RPGSkillTree"
local _pcall = pcall
local Keystone=require 'RPG_Shared_EnduranceKeystone'

local function weightCalculationDisabled()
    local vars = SandboxVars and SandboxVars.RPGSkillTree
    return vars and vars.DisableWeightCalculation == true
end

-------------------------------------------------
-- ✅ 서버 전용 가드
-------------------------------------------------
local function isServerSide()
    local c = (type(isClient) == "function") and isClient() or false
    local s = (type(isServer) == "function") and isServer() or false
    return s or (not c) -- 전용서버/싱글 true
end

if not isServerSide() then
    return true
end

-------------------------------
-- 안전장치(주기적 싱크)
-------------------------------
local RESYNC_EVERY_TICKS = 300  -- 대충 5초 근처(환경 따라 조절)
local syncTick = 0

local function ResyncPlayerState(player)
    if not player then return end
    if player.transmitModData then
        player:transmitModData()
    end
end

-------------------------------------------------
-- ✅ 주기 조절 (프레임 드랍 오면 숫자만 올리면 됨)
-------------------------------------------------
local APPLY_EVERY_TICKS = 30

-------------------------------------------------
-- per-player last stat snapshots (증가분만 factor 적용)
-------------------------------------------------
local last = {
    hunger  = {},
    thirst  = {},
    stress  = {},
    panic   = {},
    boredom = {},
    unhappy = {},
    foodSickness = {},
    endurance = {},
    pain = {},
    wet = {},
}

-------------------------------------------------
-- 공용 유틸
-------------------------------------------------
local function getKey(player)
    local id = player and player.getOnlineID and player:getOnlineID()
    if id and id ~= -1 then return id end
    return tostring(player)
end

local function getState(player)
    local md = player and player:getModData()
    if not md then return nil end
    return md[MODULE]
end

-- ✅ factors 없으면 Calc를 호출해 강제로 만들어줌(안전장치)
local function ensureFactors(player, st)
    if not st then return nil end
    if st.factors then return st.factors end

    local ok, Calc = _pcall(require, "RPG_Server_Calculate")
    if ok and Calc and Calc.CalculateAndStoreFactors then
        Calc.CalculateAndStoreFactors(player)
    end
    return st.factors
end

-------------------------------------------------
-- ✅ XP 배수(책 버프 방식) 적용 헬퍼
--  - small 노드: +1
--  - big 노드  : +6
--  - 최종 합계를 multiplier로 한번만 설정 (0~10 구간)
-------------------------------------------------
local function RPG_ApplyXpMul_FromNodes(player, nodes, perk, smallList, bigId)
    if not player or not nodes or not perk then return end
    local xp = player.getXp and player:getXp()
    if not xp then return end

    local map = xp.getMultiplierMap and xp:getMultiplierMap()
    if map and map.remove then
        map:remove(perk) -- 기존 배수 초기화
    end

    local total = 0

    -- small 합산 (+1씩)
    if type(smallList) == "table" then
        for _, id in ipairs(smallList) do
            if nodes[id] == true then
                total = total + 1
            end
        end
    end

    -- big (+6)
    if bigId and nodes[bigId] == true then
        total = total + 6
    end

    -- 총합이 0이면 배수 없음
    if nodes.XPMixedBig and (bigId=="NimbleBig" or bigId=="RunningBig") then total=total+6 end; if total <= 0 then return end

    -- 0~10 레벨 구간에 “한 번만” 적용
    xp:addXpMultiplier(perk, math.min(10, 1 + total), 0, 10)
end

-- ✅ Perks 키가 빌드마다 다를 수 있어 방어적으로 선택
local function RPG_GetPerkSafe(primaryKey, fallbackKey)
    if not Perks then return nil end
    if primaryKey and Perks[primaryKey] then return Perks[primaryKey] end
    if fallbackKey and Perks[fallbackKey] then return Perks[fallbackKey] end
    return nil
end

-------------------------------------------------
-- ✅ "증가분만" factor 적용 헬퍼
-------------------------------------------------
local function applyDeltaFactor(player, keyTable, statEnum, factor, minV, maxV)
    if type(factor) ~= "number" then return end

    local stats = player and player.getStats and player:getStats() or nil
    if not stats then return end

    local ok1, cur = _pcall(function() return stats:get(statEnum) end)
    if not ok1 or cur == nil then return end

    local key = getKey(player)
    if keyTable[key] == nil then
        keyTable[key] = cur
        return
    end

    local prev = keyTable[key]
    local change = cur - prev

    local newV = cur
    if change > 0 and factor ~= 1.0 then
        newV = prev + (change * factor)
    end

    if minV ~= nil and newV < minV then newV = minV end
    if maxV ~= nil and newV > maxV then newV = maxV end

    _pcall(function() stats:set(statEnum, newV) end)
    keyTable[key] = newV
end

-------------------------------------------------
-- ✅ 0~100 clamp
-------------------------------------------------
local function clamp0_100(v)
    if v == nil then return nil end
    if v < 0 then v = 0 end
    if v > 100 then v = 100 end
    return v
end

-------------------------------------------------
-- ✅ Boredom getter/setter (0~100 가정)
-------------------------------------------------
local function getBoredom(player)
    if not player then return nil, nil end

    local body = player.getBodyDamage and player:getBodyDamage() or nil
    if body then
        local ok, v = _pcall(function()
            if body.getBoredomLevel then return body:getBoredomLevel()
            elseif body.getBoredom then return body:getBoredom()
            end
            return nil
        end)
        if ok and v ~= nil then return v, "BodyDamage" end
    end

    local stats = player.getStats and player:getStats() or nil
    if stats and CharacterStat and CharacterStat.BOREDOM then
        local ok, v = _pcall(function() return stats:get(CharacterStat.BOREDOM) end)
        if ok and v ~= nil then return v, "Stats" end
    end

    return nil, nil
end

local function setBoredom(player, v, src)
    if not player then return end
    v = clamp0_100(v)
    if v == nil then return end

    if src == "BodyDamage" then
        local body = player.getBodyDamage and player:getBodyDamage() or nil
        if not body then return end
        _pcall(function()
            if body.setBoredomLevel then body:setBoredomLevel(v)
            elseif body.SetBoredomLevel then body:SetBoredomLevel(v)
            elseif body.setBoredom then body:setBoredom(v)
            end
        end)
        return
    end

    if src == "Stats" then
        local stats = player.getStats and player:getStats() or nil
        if not stats then return end
        _pcall(function() stats:set(CharacterStat.BOREDOM, v) end)
        return
    end
end

local function applyBoredomRecovery(player, factors)
    if not player or not factors then return end
    local factor = factors.boredomRecovery
    if type(factor) ~= "number" or factor <= 1.0 then return end

    local cur, src = getBoredom(player)
    if cur == nil or src == nil then return end
    cur = clamp0_100(cur)
    if not cur or cur <= 0 then return end

    local newV = cur / factor
    if newV < 0 then newV = 0 end
    if newV > cur then newV = cur end
    setBoredom(player, newV, src)
end

-------------------------------------------------
-- ✅ Unhappiness getter/setter (0~100)
-------------------------------------------------
local function getUnhappy(player)
    if not player then return nil, nil end
    local body = player.getBodyDamage and player:getBodyDamage() or nil
    if not body then return nil, nil end

    local ok, v = _pcall(function()
        if body.getUnhappynessLevel then return body:getUnhappynessLevel()
        elseif body.getUnhappinessLevel then return body:getUnhappinessLevel()
        end
        return nil
    end)

    if ok and v ~= nil then return v, "BodyDamage" end
    return nil, nil
end

local function setUnhappy(player, v, src)
    if not player then return end
    v = clamp0_100(v)
    if v == nil then return end

    if src == "BodyDamage" then
        local body = player.getBodyDamage and player:getBodyDamage() or nil
        if not body then return end
        _pcall(function()
            if body.setUnhappynessLevel then body:setUnhappynessLevel(v)
            elseif body.SetUnhappynessLevel then body:SetUnhappynessLevel(v)
            elseif body.setUnhappinessLevel then body:setUnhappinessLevel(v)
            elseif body.SetUnhappinessLevel then body:SetUnhappinessLevel(v)
            end
        end)
    end
end

local function applyUnhappyRecovery(player, factors)
    if not player or not factors then return end
    local factor = factors.unhappyRecovery
    if type(factor) ~= "number" or factor <= 1.0 then return end

    local cur, src = getUnhappy(player)
    if cur == nil or src == nil then return end
    cur = clamp0_100(cur)
    if not cur or cur <= 0 then return end

    local newV = cur / factor
    if newV < 0 then newV = 0 end
    if newV > cur then newV = cur end
    setUnhappy(player, newV, src)
end

-------------------------------------------------
-- ✅ CarryWeight 적용 (base 저장 + factors 반영)
-------------------------------------------------
local function applyCarryWeight(player, st, factors)
    -- Never read, cache or write player capacity while disabled.
    -- This also prevents clobbering a third-party mod's carry-weight value.
    if weightCalculationDisabled() then return end
    if not player or not st or not factors then return end
    local md = player:getModData()
    if not md then return end

    if not md.RPG_BaseMaxWeight then
        md.RPG_BaseMaxWeight = player:getMaxWeightBase()
    end

    local baseWeight = md.RPG_BaseMaxWeight or player:getMaxWeightBase()
    st.baseMaxWeight = st.baseMaxWeight or baseWeight
    if not baseWeight then return end

    local carryMul = factors.carryWeightMul or 1.0
    local itemMul  = RPG_ITEM_WEIGHT_MUL or 1.0
    -- B42.21 API: setMaxWeightBase accepts int, not float.
    local finalWeight = math.max(1, math.min(100, math.floor(baseWeight * carryMul)))

    local cur = player:getMaxWeightBase()
    if cur ~= finalWeight then
        player:setMaxWeightBase(finalWeight)
    end
end

-------------------------------------------------
-- ✅ Pain (0~100) - B42.13: stats:get(CharacterStat.PAIN)/set(CharacterStat.PAIN,v)
-------------------------------------------------
local function getPain(player)
    local stats = player and player.getStats and player:getStats() or nil
    if not stats then return nil end
    if not CharacterStat or not CharacterStat.PAIN then return nil end

    local ok, v = _pcall(function()
        return stats:get(CharacterStat.PAIN)
    end)

    if ok and type(v) == "number" then return v end
    return nil
end

local function setPain(player, v)
    local stats = player and player.getStats and player:getStats() or nil
    if not stats then return end
    if not CharacterStat or not CharacterStat.PAIN then return end

    v = clamp0_100(v)
    if v == nil then return end

    _pcall(function()
        stats:set(CharacterStat.PAIN, v)
    end)
end

local function applyPainGain(player, factors, keyTable)
    if not player or not factors then return end
    local factor = factors.painGain
    if type(factor) ~= "number" or factor == 1.0 then return end

    local cur = getPain(player)
    if cur == nil then return end
    cur = clamp0_100(cur)

    local key = getKey(player)
    if keyTable[key] == nil then
        keyTable[key] = cur
        return
    end

    local prev = keyTable[key]
    local change = cur - prev

    local newV = cur
    if change > 0 then
        newV = prev + (change * factor)
    end

    newV = clamp0_100(newV)
    setPain(player, newV)
    keyTable[key] = newV
end

-------------------------------------------------
-- ✅ last 스냅샷 초기화
-------------------------------------------------
local function resetPlayer(player)
    -- ✅ OnCreatePlayer에서 playerIndex(숫자)가 들어올 수 있음
    if type(player) == "number" then
        player = getSpecificPlayer(player) or getPlayer()
    end
    if not player then return end
    if player.isDead and player:isDead() then return end

    local key = getKey(player)

    last.hunger[key]  = nil
    last.thirst[key]  = nil
    last.stress[key]  = nil
    last.foodSickness[key] = nil
    last.panic[key]   = nil
    last.boredom[key] = nil
    last.unhappy[key] = nil
    last.endurance[key] = nil
    last.pain[key] = nil
    last.wet[key] = nil

    local md = player:getModData()
    if md then
        md.RPG_BaseMaxWeight = nil
    end
end

Events.OnCreatePlayer.Add(resetPlayer)
Events.OnPlayerDeath.Add(resetPlayer)

-------------------------------------------------
-- ✅ 핵심: factors + specials 적용
-------------------------------------------------
local function applyToPlayer(player)
    if not player or (player.isDead and player:isDead()) then return end

    local st = getState(player)
    if not st then return end

    local factors = ensureFactors(player, st) or {}

    -- SP book multipliers are registered by RPG_Client_SP_Passives.
    -- MP keeps its existing authoritative server-side book multiplier code.
    if not (type(isMultiplayer) == 'function' and not isMultiplayer()) then
    -------------------------------------------------
    -- ✅ Strength / Fitness / Nimble / Running XP 배수 적용
    -- small *1 + big *6 (최대 10이 되도록 설계)
    -------------------------------------------------
    local nodes = (st and st.nodes) or {}

    local perkStrength = RPG_GetPerkSafe("Strength", "Strength")  -- 보통 존재
    local perkFitness  = RPG_GetPerkSafe("Fitness",  "Fitness")   -- 보통 존재
    local perkNimble   = RPG_GetPerkSafe("Nimble",   "Nimble")    -- 보통 존재

    -- Running은 빌드/버전에 따라 키가 다를 수 있음:
    -- 네 예전 코드는 Sprinting을 썼으니 fallback으로 Sprinting도 넣음
    local perkRunning  = RPG_GetPerkSafe("Running", "Sprinting")

    RPG_ApplyXpMul_FromNodes(player, nodes, perkStrength,
        { "Strength1","Strength2","Strength3","Strength4" }, "StrengthBig")

    RPG_ApplyXpMul_FromNodes(player, nodes, perkFitness,
        { "Fitness1","Fitness2","Fitness3","Fitness4" }, "FitnessBig")

    RPG_ApplyXpMul_FromNodes(player, nodes, perkNimble,
        { "Nimble1","Nimble2","Nimble3","Nimble4" }, "NimbleBig")

    RPG_ApplyXpMul_FromNodes(player, nodes, perkRunning,
        { "Running1","Running2","Running3","Running4" }, "RunningBig")

    end

    -- SP has a dedicated client OnTick watcher for these effects.
    -- MP remains authoritative on the server (only one delta-correction loop).
    local singleplayer = type(isMultiplayer) == 'function' and not isMultiplayer()
    if not singleplayer then
        local hungerFactor = factors.hungerGain or 1.0
        if CharacterStat and CharacterStat.HUNGER then
            applyDeltaFactor(player, last.hunger, CharacterStat.HUNGER, hungerFactor, 0, 1)
        end
        local thirstFactor = factors.thirstGain or 1.0
        if CharacterStat and CharacterStat.THIRST and not Keystone.active(st.nodes) then
            applyDeltaFactor(player, last.thirst, CharacterStat.THIRST, thirstFactor, 0, 1)
        elseif Keystone.active(st.nodes) then
            last.thirst[getKey(player)]=nil -- selected node's local watcher owns thirst in MP
        end
    end

    -- Endurance
    do
        local srFactor = factors.staminaRegen or 1.0
        local sdFactor = factors.staminaDrain or 1.0

        if Keystone.active(st.nodes) then
            -- Native player stats live on the owning client. The new watcher
            -- applies the factors once; multiplayer chance stays server-owned.
            last.endurance[getKey(player)]=nil
        elseif (type(srFactor) == "number" and srFactor ~= 1.0)
            or (type(sdFactor) == "number" and sdFactor ~= 1.0) then

            local stats = player.getStats and player:getStats() or nil
            if stats and CharacterStat and CharacterStat.ENDURANCE then
                local ok1, cur = _pcall(function()
                    return stats:get(CharacterStat.ENDURANCE)
                end)
                if ok1 and cur ~= nil then
                    local key = getKey(player)

                    if last.endurance[key] == nil then
                        last.endurance[key] = cur
                    else
                        local prev = last.endurance[key]
                        local change = cur - prev
                        local newV = cur

                        if change > 0 and type(srFactor) == "number" and srFactor ~= 1.0 then
                            newV = prev + (change * srFactor)
                        elseif change < 0 and type(sdFactor) == "number" and sdFactor ~= 1.0 then
                            newV = prev + (change * sdFactor)
                        end

                        if newV < 0 then newV = 0 end
                        if newV > 1 then newV = 1 end

                        _pcall(function()
                            stats:set(CharacterStat.ENDURANCE, newV)
                        end)

                        last.endurance[key] = newV
                    end
                end
            end
        end
    end

    -- Stress
    local stressFactor = factors.stressGain or 1.0
    if CharacterStat and CharacterStat.STRESS then
        applyDeltaFactor(player, last.stress, CharacterStat.STRESS, stressFactor, 0, 1)
    end

    -- FoodSickness
    local fsFactor = factors.foodSicknessGain or 1.0
    if CharacterStat and CharacterStat.FOOD_SICKNESS then
        applyDeltaFactor(player, last.foodSickness, CharacterStat.FOOD_SICKNESS, fsFactor, 0, 100)
    end

    -- Wet
    do
        local wetFactor = factors.wetGain or 1.0
        if CharacterStat and CharacterStat.WETNESS then
            applyDeltaFactor(player, last.wet, CharacterStat.WETNESS, wetFactor, 0, 100)
        end
    end

    -- Panic
    local panicFactor = factors.panicGain or 1.0
    if CharacterStat and CharacterStat.PANIC then
        applyDeltaFactor(player, last.panic, CharacterStat.PANIC, panicFactor, 0, 100)
    end

    applyBoredomRecovery(player, factors)
    applyUnhappyRecovery(player, factors)
    applyPainGain(player, factors, last.pain)
    if not (type(isMultiplayer) == 'function' and not isMultiplayer()) then
        applyCarryWeight(player, st, factors)
    end
end

-------------------------------------------------
-- ✅ OnTick 루프 + 주기 적용
-------------------------------------------------
local tickCounter = 0

local function OnTick()
    -- 주기적 ModData transmit (상태 갱신)
    syncTick = (syncTick + 1) % RESYNC_EVERY_TICKS
    if syncTick == 0 then
        local ops = getOnlinePlayers()
        if ops then
            for i=0, ops:size()-1 do ResyncPlayerState(ops:get(i)) end
        else
            ResyncPlayerState(getPlayer())
        end
    end

    tickCounter = (tickCounter + 1) % (APPLY_EVERY_TICKS or 10)
    if tickCounter ~= 0 then
        return
    end

    local ops = getOnlinePlayers()
    if ops then
        for i = 0, ops:size() - 1 do
            applyToPlayer(ops:get(i))
        end
    else
        applyToPlayer(getPlayer())
    end

end

Events.OnTick.Add(OnTick)

return true
