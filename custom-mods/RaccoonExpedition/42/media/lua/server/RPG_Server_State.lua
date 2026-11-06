
local LevelTable = require "RPG_Server_LevelTable"

local RPG_State = {}

local MODULE = "RPGSkillTree"
RPG_State.SAVE_VERSION = 1

-- (옵션) UI 악용 방지 범위
local XPBAR_MIN = -5000
local XPBAR_MAX =  5000

-- World-controlled starting SP; never accept a client-supplied amount.
-- Default() is called only for a character whose RPG state does not exist.
local function getStartingSkillPoints()
    local group = SandboxVars and SandboxVars.RPGSkillTree
    local value = tonumber(group and group.StartingSkillPoints)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return 0
    end
    return math.max(0, math.min(1000, math.floor(value)))
end

function RPG_State.Default()
    return {
        saveVersion = RPG_State.SAVE_VERSION,

        level       = 1,
        xp          = 0,     -- 현재 보유 XP
        totalXP     = 0,     -- 누적 XP (추천)

        skillPoints = getStartingSkillPoints(),
        resetPoints = 0,
        spentPoints = 0,     -- 정합성 체크용(추천)
        geneSpentPoints = 0,
        geneEdits = {},
		resetEarnedTotal = 0,  -- ✅ 누적 XP로 "지급 처리된" 리셋포인트 총량 (소비와 분리)

        nodes = {},          -- 찍힌 노드: nodes["Weight1"]=true

        ui = {
		xpbar = { x = nil, y = nil, locked = false, scale = 1.0 },
		},
    }
end

-- ✅ 외부에서 쓰기 좋게: xpbar 값 정리/클램프
function RPG_State.ClampXPBar(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then return nil, nil end

    if x < XPBAR_MIN then x = XPBAR_MIN end
    if y < XPBAR_MIN then y = XPBAR_MIN end
    if x > XPBAR_MAX then x = XPBAR_MAX end
    if y > XPBAR_MAX then y = XPBAR_MAX end

    return x, y
end

-- Some equipment-effect handlers create an empty RPGSkillTree mod-data shell
-- before the first client RequestSync. Initialize such shells as *new* RPG
-- characters instead of silently setting skillPoints to zero.
-- Completed saves (saveVersion/level/xp/sp/skill purchases present) are NEVER
-- awarded starting SP again.
function RPG_State.Ensure(pl)
    if pl and RCE and RCE.Persistence and RCE.Server.ready then RCE.Persistence.restore(pl) end
    if not pl then return nil end
    local md = pl:getModData()
    if not md then return nil end
    local d = md[MODULE]
    if type(d) ~= "table" then
        d = RPG_State.Default()
        md[MODULE] = d
        print('[Project RPG][StartingSP] New character initialized with '..tostring(d.skillPoints)..' SP')
    elseif d.saveVersion == nil and d.level == nil and d.xp == nil
       and d.totalXP == nil and d.skillPoints == nil
       and d.spentPoints == nil and d.nodes == nil then
        -- Preserve early itemFactors or any unknown mod-data keys.
        local fresh = RPG_State.Default()
        for key, value in pairs(fresh) do
            if d[key] == nil then d[key] = value end
        end
        print('[Project RPG][StartingSP] Recovered incomplete character data; granted '..tostring(d.skillPoints)..' SP')
    end

    -- 방어/복구(세이브 손상/업데이트 대비)
    if type(d.saveVersion) ~= "number" then d.saveVersion = RPG_State.SAVE_VERSION end
    if type(d.level) ~= "number" then d.level = 1 end
    if type(d.xp) ~= "number" then d.xp = 0 end
    if type(d.totalXP) ~= "number" then d.totalXP = 0 end
    if type(d.skillPoints) ~= "number" then d.skillPoints = 0 end
    if type(d.resetPoints) ~= "number" then d.resetPoints = 0 end
    if type(d.spentPoints) ~= "number" then d.spentPoints = 0 end
    if type(d.nodes) ~= "table" then d.nodes = {} end
    if type(d.geneSpentPoints) ~= "number" then d.geneSpentPoints = 0 end
    if type(d.geneEdits) ~= "table" then d.geneEdits = {} end
    if type(d.geneEditSeq) ~= "number" then d.geneEditSeq = 0 end
    if type(d.ui) ~= "table" then d.ui = {} end

    -- xpbar 기본값
    if type(d.ui.xpbar) ~= "table" then
        d.ui.xpbar = { x = 200, y = 200, locked = false, scale = 1.0 }
    end

    -- ✅ resetEarnedTotal 보정 (기존 세이브 호환)
    if type(d.resetEarnedTotal) ~= "number" then
        -- 기존 세이브에 totalXP가 있으면 그 기준으로 "지급된 총량"만 세팅(추가 지급은 하지 않음)
        local total = tonumber(d.totalXP) or 0
        d.resetEarnedTotal = math.floor(total / 90000)
    end

    -- Keep the derived next-level requirement aligned with the actual
    -- server level table rather than an old 500+100*level fallback.
    d.xpNext = LevelTable.GetRequiredXP(d.level)


    -- xpbar x/y가 이상한 값이면 클램프
    do
        local xb = d.ui.xpbar
        local x, y = RPG_State.ClampXPBar(xb.x, xb.y)
        if x and y then
            xb.x, xb.y = x, y
        else
            xb.x, xb.y = 200, 200
        end

        if type(xb.locked) ~= "boolean" then xb.locked = false end
        if type(xb.scale) ~= "number" then xb.scale = 1.0 end
        if xb.scale < 0.5 then xb.scale = 0.5 end
        if xb.scale > 2.0 then xb.scale = 2.0 end
    end

    return d
end


if Events and Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(function(_, player)
        if player then RPG_State.Ensure(player) end
    end)
end

return RPG_State
