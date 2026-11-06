-------------------------------------------------
-- RPG_Server_Calculate.lua
-- XP / factor calculation (SERVER ONLY)
-- ✔ 계산만 담당 (저장/브로드캐스트/레벨업은 Commands에서)
-------------------------------------------------

require 'RCE/Nodes'
local Calc = {}
local MODULE = "RPGSkillTree"
local Keystone=require 'RPG_Shared_EnduranceKeystone'

-- Sandbox option is world-owned; default nil/false keeps legacy behavior.
local function weightCalculationDisabled()
    local vars = SandboxVars and SandboxVars.RPGSkillTree
    return vars and vars.DisableWeightCalculation == true
end

local function getState(player)
    if not player then return nil end
    local md = player:getModData()
    if not md then return nil end
    return md[MODULE]
end

-------------------------------------------------
-- ✅ 노드 카운트 헬퍼
-------------------------------------------------
local function hasNode(nodes, id)
    return nodes and nodes[id] == true
end

local function countNodesByList(nodes, list)
    local n = 0
    if type(list) ~= "table" then return 0 end
    for _, id in ipairs(list) do
        if hasNode(nodes, id) then n = n + 1 end
    end
    return n
end

local function clamp(v, minV, maxV)
    if minV ~= nil and v < minV then v = minV end
    if maxV ~= nil and v > maxV then v = maxV end
    return v
end

-------------------------------------------------
-- ✅ 노드 기반 "팩터" 계산 + State에 저장
--    (UI는 st.factors만 읽게 설계)
--    ✅ 최종은 전부 "합연산" 누적
-------------------------------------------------
function Calc.CalculateAndStoreFactors(player)
    local st = getState(player)
    if not st then return nil end

    local nodes = st.nodes or {}
    st.factors = st.factors or {}
    local skipWeight = weightCalculationDisabled()

    -------------------------------------------------
    -- ✅ Hunger Gain Factor (ADD)
    -------------------------------------------------
    local hungerSmall = countNodesByList(nodes, { "Hunger1", "Hunger2", "Hunger3", "Hunger4" })
	local hungerFactor = 1.0 - (hungerSmall * 0.025)

	if hasNode(nodes, "HungerBig") then
		hungerFactor = hungerFactor - 0.10
	end

	------------------------------------------------
	-- ✅ Mastery 디버프: 노드 1개당 배고픔 +10%
	------------------------------------------------
	local masteryCount = countNodesByList(nodes, {
		"BloodCollector",
		"SoulCollector",
		"SacrificeCollector",
	})

	if masteryCount > 0 then
		hungerFactor = hungerFactor + (masteryCount * 0.10)
	end

	------------------------------------------------
	-- 최종 클램프
	------------------------------------------------
	hungerFactor = clamp(hungerFactor, 0.05, 5.0)
	st.factors.hungerGain = hungerFactor

    -------------------------------------------------
    -- ✅ Thirst Gain Factor (ADD)
    -------------------------------------------------
    local thirstSmall = countNodesByList(nodes, { "Thirst1", "Thirst2", "Thirst3", "Thirst4" })
    local thirstFactor = 1.0 - (thirstSmall * 0.025)
    if hasNode(nodes, "ThirstBig") then
        thirstFactor = thirstFactor - 0.10
    end
    thirstFactor = clamp(thirstFactor, 0.05, 5.0)
    st.factors.thirstGain = thirstFactor

    -------------------------------------------------
    -- ✅ Wet Gain Factor (ADD)
    -------------------------------------------------
    local wetGain = 1.0
    local wSmall = countNodesByList(nodes, { "Wet1", "Wet2", "Wet3", "Wet4" })
    wetGain = wetGain - (wSmall * 0.025)
    if hasNode(nodes, "WetBig") then
        wetGain = wetGain - 0.10
    end
    wetGain = clamp(wetGain, 0.05, 5.0)
    st.factors.wetGain = wetGain

    -------------------------------------------------
    -- ✅ Stress Gain Factor (ADD)
    -------------------------------------------------
    local stressSmall = countNodesByList(nodes, { "Stress1", "Stress2", "Stress3", "Stress4" })
    local stressFactor = 1.0 - (stressSmall * 0.025)
    if hasNode(nodes, "StressBig") then
        stressFactor = stressFactor - 0.10
    end
    if hasNode(nodes, 'DimensionalVault') then
        stressFactor = stressFactor * 1.30 -- +30% stress gain while learned
    end
    stressFactor = clamp(stressFactor, 0.05, 5.0)
    st.factors.stressGain = stressFactor

    -------------------------------------------------
    -- ✅ Panic Gain Factor (ADD)
    -------------------------------------------------
    local panicSmall = countNodesByList(nodes, { "Panic1", "Panic2", "Panic3", "Panic4" })
    local panicFactor = 1.0 - (panicSmall * 0.025)
    if hasNode(nodes, "PanicBig") then
        panicFactor = panicFactor - 0.10
    end
    panicFactor = clamp(panicFactor, 0.05, 5.0)
    st.factors.panicGain = panicFactor

    -------------------------------------------------
    -- ✅ FoodSickness Gain Factor (ADD)
    -------------------------------------------------
    local fsSmall = countNodesByList(nodes, { "FoodSickness1", "FoodSickness2", "FoodSickness3", "FoodSickness4" })
    local fsFactor = 1.0 - (fsSmall * 0.025)
    if hasNode(nodes, "FoodSicknessBig") then
        fsFactor = fsFactor - 0.10
    end
    fsFactor = clamp(fsFactor, 0.05, 5.0)
    st.factors.foodSicknessGain = fsFactor

    -------------------------------------------------
    -- ✅ Stamina Drain Factor (ADD)
    -------------------------------------------------
    local staminaDrain = 1.0
    local sdSmall = countNodesByList(nodes, { "Stamina1", "Stamina2", "Stamina3", "Stamina4" })
    staminaDrain = staminaDrain - (sdSmall * 0.025)
    if hasNode(nodes, "StaminaBig") then
        staminaDrain = staminaDrain - 0.10
    end

    local spSmall = countNodesByList(nodes, { "StaPain1", "StaPain2", "StaPain3", "StaPain4" })
    staminaDrain = staminaDrain - (spSmall * 0.01)
    if hasNode(nodes, "StaPainBig") then
        staminaDrain = staminaDrain - 0.06
    end

    staminaDrain = clamp(staminaDrain, 0.05, 5.0)
    st.factors.staminaDrain = staminaDrain

    -------------------------------------------------
    -- ✅ Boredom Recovery Factor (ADD)
    -------------------------------------------------
    local boredomSmall = countNodesByList(nodes, { "Boredom1", "Boredom2", "Boredom3", "Boredom4" })
    local boredomFactor = 1.0 + (boredomSmall * 0.025)
    if hasNode(nodes, "BoredomBig") then
        boredomFactor = boredomFactor + 0.10
    end
    boredomFactor = clamp(boredomFactor, 0.10, 10.0)
    st.factors.boredomRecovery = boredomFactor

    -------------------------------------------------
    -- ✅ Unhappiness Recovery Factor (ADD)
    -------------------------------------------------
    local unhappySmall = countNodesByList(nodes, { "Unhappy1", "Unhappy2", "Unhappy3", "Unhappy4" })
    local unhappyFactor = 1.0 + (unhappySmall * 0.025)
    if hasNode(nodes, "UnhappyBig") then
        unhappyFactor = unhappyFactor + 0.10
    end
    unhappyFactor = clamp(unhappyFactor, 0.10, 10.0)
    st.factors.unhappyRecovery = unhappyFactor

    -------------------------------------------------
    -- ✅ Stamina Regen Factor (ADD)
    -------------------------------------------------
    local srSmall = countNodesByList(nodes, { "StaminaRegen1", "StaminaRegen2", "StaminaRegen3", "StaminaRegen4" })
    local staminaRegen = 1.0 + (srSmall * 0.10)
    if hasNode(nodes, "StaminaRegenBig") then
        staminaRegen = staminaRegen + 0.60
    end
    staminaRegen = clamp(staminaRegen, 0.10, 10.0)
    st.factors.staminaRegen = staminaRegen

    -------------------------------------------------
    -- ✅ Pain Gain Factor (ADD)
    -------------------------------------------------
    local painGain = 1.0
    local pSmall = countNodesByList(nodes, { "Pain1", "Pain2", "Pain3", "Pain4" })
    painGain = painGain - (pSmall * 0.025)
    if hasNode(nodes, "PainBig") then
        painGain = painGain - 0.10
    end

    local spSmall2 = countNodesByList(nodes, { "StaPain1", "StaPain2", "StaPain3", "StaPain4" })
    painGain = painGain - (spSmall2 * 0.01)
    if hasNode(nodes, "StaPainBig") then
        painGain = painGain - 0.06
    end

    painGain = clamp(painGain, 0.05, 5.0)
    st.factors.painGain = painGain

    -------------------------------------------------
    -- ✅ Carry Weight Factor (ADD)
    -------------------------------------------------
    if skipWeight then
        st.factors.carryWeightMul = 1.0
    else
        local carryWeightMul = 1.0
        local wSmall2 = countNodesByList(nodes, { "Weight1", "Weight2", "Weight3", "Weight4" })
        carryWeightMul = carryWeightMul + (wSmall2 * 0.025)
    
        local wBig = countNodesByList(nodes, { "WeightBig1", "WeightBig2", "WeightBig3" })
        carryWeightMul = carryWeightMul + (wBig * 0.10)
    
        if hasNode(nodes, "XPWeightBig") then
            carryWeightMul = carryWeightMul + 0.05
        end
    
        if hasNode(nodes, "GravityAdaptation") then
            carryWeightMul = carryWeightMul + 0.30
        end
    
        carryWeightMul = clamp(carryWeightMul, 0.10, 10.0)
        st.factors.carryWeightMul = carryWeightMul
    end

    -------------------------------------------------
    -- ✅ XP Gain Factor (ADD)
    -------------------------------------------------
    do
        local xpGain = 1.0

        local small = countNodesByList(nodes, { "XPgain1","XPgain2","XPgain3","XPgain4" })
        xpGain = xpGain + (small * 0.05)

        local big = countNodesByList(nodes, { "XPgainBig1","XPgainBig2","XPgainBig3","XPgainBig4","XPgainBig5" })
        xpGain = xpGain + (big * 0.30)

        if hasNode(nodes, "XPMixedBig") then
            xpGain = xpGain + 0.15
        end

        if hasNode(nodes, "XPWeightBig") then
            xpGain = xpGain + 0.15
        end

        xpGain = clamp(xpGain, 0.10, 10.0)
        st.factors.xpGain = xpGain
    end
	
	-------------------------------------------------
    -- ✅ Skill XP Multiplier Points (for UI display)
    --  - small: +1, big: +6  (same as ApplyFactors)
    -------------------------------------------------
    local function xpMulPoints(smallList, bigId)
        local total = 0
        if type(smallList) == "table" then
            for _, id in ipairs(smallList) do
                if nodes[id] == true then total = total + 1 end
            end
        end
        if bigId and nodes[bigId] == true then
            total = total + 6
        end
        return total
    end
	
    -------------------------------------------------
    -- ✅ 장비 itemFactors를 우리 시스템(st.factors)에 반영
    -------------------------------------------------
    RCE.applyNodeFactors(st,skipWeight)
    local itf = st.itemFactors or {}

    local xpMul    = tonumber(itf.xpMul) or 1.0
    local hMul     = tonumber(itf.hungerGainMul) or 1.0
    local tMul     = tonumber(itf.thirstGainMul) or 1.0
    local pMul     = tonumber(itf.painGainMul) or 1.0   -- ✅ 추가

    -- xpGain은 "증가 배율"이므로 곱해줌
    st.factors.xpGain = clamp((tonumber(st.factors.xpGain) or 1.0) * xpMul, 0.10, 10.0)

    -- carryWeightMul도 곱
    if not skipWeight then
        st.factors.carryWeightMul = clamp((tonumber(st.factors.carryWeightMul) or 1.0) * (tonumber(itf.carryMul) or 1.0), 0.10, 10.0)
    end

    -- hungerGain/thirstGain은 "증가 팩터(작을수록 덜 닳음)"라서 곱
    st.factors.hungerGain = clamp((tonumber(st.factors.hungerGain) or 1.0) * hMul, 0.05, 5.0)
    st.factors.thirstGain = clamp((tonumber(st.factors.thirstGain) or 1.0) * tMul, 0.05, 5.0)
    -- Apply the penalty AFTER all existing thirst reductions/equipment.
    st.factors.enduranceNullChance=Keystone.chance(nodes)
    if Keystone.active(nodes) then
        st.factors.thirstGain=clamp(st.factors.thirstGain*Keystone.THIRST,0.05,5.0)
    end

    -- ✅ painGain도 "증가 팩터(작을수록 덜 오름)"라서 곱
    st.factors.painGain = clamp((tonumber(st.factors.painGain) or 1.0) * pMul, 0.05, 5.0)

    st.factors.strengthXP = xpMulPoints({ "Strength1","Strength2","Strength3","Strength4" }, "StrengthBig")
    st.factors.fitnessXP  = xpMulPoints({ "Fitness1","Fitness2","Fitness3","Fitness4" }, "FitnessBig")
    st.factors.nimbleXP   = xpMulPoints({ "Nimble1","Nimble2","Nimble3","Nimble4" }, "NimbleBig")
    st.factors.runningXP  = xpMulPoints({ "Running1","Running2","Running3","Running4" }, "RunningBig")
	
    
    local itf = st.itemFactors or {}
    local sdMul = tonumber(itf.staminaDrainMul) or 1.0

    st.factors.staminaDrain =
        clamp((tonumber(st.factors.staminaDrain) or 1.0) * sdMul, 0.05, 5.0)

    if nodes.XPMixedBig then st.factors.nimbleXP=st.factors.nimbleXP+6;st.factors.runningXP=st.factors.runningXP+6 end
    return st.factors
end

function Calc.CalculateXP(player, baseXP, context)
    local xp = tonumber(baseXP) or 0
    if xp <= 0 then return 0 end

    local st = getState(player)
    local factors = nil
    local nodes = nil

    if st then
        factors = Calc.CalculateAndStoreFactors(player)
        nodes = st.nodes
    end

    -------------------------------------------------
    -- 1) 항상 적용되는 XP 배율
    -------------------------------------------------
    local gain = 1.0
    if factors and factors.xpGain then
        gain = tonumber(factors.xpGain) or 1.0
    end

    xp = xp * gain

    -------------------------------------------------
    -- 2) 확률형 XP 배수 노드 (1% 확률, 발동 시 배수 합산)
    -------------------------------------------------
    local procMultiplier = 1.0

    if nodes then
        local ver2Small = 0
        if nodes.XPVer21 then ver2Small = ver2Small + 1 end
        if nodes.XPVer22 then ver2Small = ver2Small + 1 end
        if nodes.XPVer23 then ver2Small = ver2Small + 1 end
        if nodes.XPVer24 then ver2Small = ver2Small + 1 end
        if ver2Small > 0 then
            procMultiplier = procMultiplier + (ver2Small * 5.0)
        end

        local ver2Big = 0
        if nodes.XPVer2Big1 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big2 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big3 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big4 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big5 then ver2Big = ver2Big + 1 end
        if ver2Big > 0 then
            procMultiplier = procMultiplier + (ver2Big * 30.0)
        end

        if nodes.XPMixedBig then
            procMultiplier = procMultiplier + 15.0
        end
    end

    -------------------------------------------------
    -- 3) 1% 확률 판정 (한 번만)
    -------------------------------------------------
    local procTriggered = false
    if procMultiplier > 1.0 then
        if ZombRand and ZombRand(100) < 1 then
            xp = xp * procMultiplier
            procTriggered = true
        end
    end

    -- v39: CalculateXP is calculation-only. Return the actual proc result
    -- so the XP award path can batch and rate-limit player announcements.
    -- The 1% ZombRand(100) roll and XP multiplier are unchanged.
    if xp < 0 then xp = 0 end
    return math.floor(xp + 0.5), procTriggered
end

return Calc
