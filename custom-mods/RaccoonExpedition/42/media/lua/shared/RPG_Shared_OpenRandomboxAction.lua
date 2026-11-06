-------------------------------------------------
-- TimedActions/RPG_OpenRandomboxAction.lua
-- ✅ "모두 열기"를 1회 액션으로 처리 (한 번에 count 전송)
-------------------------------------------------

require "TimedActions/ISBaseTimedAction"
-- ISTimedActionQueue is a client-side module; load it in the context-menu script.

RPG_OpenRandomboxAction = ISBaseTimedAction:derive("RPG_OpenRandomboxAction")

local MODULE = "RPGSkillTree"

local function dbg(msg)
    print("[RPG Randombox][TA] " .. tostring(msg))
end

local function safeCount(v)
    v = tonumber(v) or 1
    if v < 1 then v = 1 end
    if v > 200 then v = 200 end
    return v
end

-- remaining = 이번 액션에서 서버에 요청할 count (한 번에 처리)
function RPG_OpenRandomboxAction:new(character, boxType, tier, remaining, openAll, boxId)
    local o = ISBaseTimedAction.new(self, character)

    o.character = character
    o.boxType   = tostring(boxType or "")
    o.tier      = tostring(tier or "Normal")
    o.remaining = safeCount(remaining)
    o.openAll   = openAll == true
    o.boxId     = tostring(boxId or "default")

    o.stopOnWalk = true
    o.stopOnRun  = true
    o.maxTime    = o:getDuration()

    return o
end

function RPG_OpenRandomboxAction:getDuration()
    if self.character and self.character.isTimedActionInstant and self.character:isTimedActionInstant() then
        return 1
    end
    -- ✅ "모두 열기"도 1회 연출만 (0.75초)
    return math.max(1, math.floor(0.75 / 0.02))
end

function RPG_OpenRandomboxAction:isValid()
    if not self.character then return false end
    if self.character.isDead and self.character:isDead() then return false end
    if self.boxType == "" then return false end

    local inv = self.character:getInventory()
    if not inv then return false end

    -- 최소 1개는 있어야 진행 (count 부족해도 서버가 가능한 만큼 열어줌)
    return inv:getCountTypeRecurse(self.boxType) > 0
end

function RPG_OpenRandomboxAction:start()
    dbg("start tier="..self.tier.." boxType="..self.boxType.." count="..tostring(self.remaining).." openAll="..tostring(self.openAll))
    -- 연출 넣고 싶으면 여기
    -- self:setActionAnim("Loot")
end

function RPG_OpenRandomboxAction:perform()
    -- B42 MP: perform() runs on the acting client; send requests from here.
    -- Never sendClientCommand in complete(), which runs on the server.
    dbg("perform -> SEND count="..tostring(self.remaining).." tier="..self.tier.." boxType="..self.boxType)
    local requestId = ""
    -- This UI is purely cosmetic: the server still consumes boxes and rolls.
    if RPG_RandomboxRevealUI and RPG_RandomboxRevealUI.BeginRequest then
        requestId = RPG_RandomboxRevealUI.BeginRequest(self.tier, self.remaining) or ""
    end
    local payload = {
        tier = self.tier,
        boxType = self.boxType,
        boxId = self.boxId,
        count = self.remaining,
        requestId = requestId,
    }
    local single = isMultiplayer and not isMultiplayer()
    if single and RPG_SP_OpenRandombox then
        RPG_SP_OpenRandombox(self.character, payload)
    elseif self.character and sendClientCommand then
        sendClientCommand(self.character, MODULE, "RandomboxOpen", payload)
    end
    ISBaseTimedAction.perform(self)
    return true
end

function RPG_OpenRandomboxAction:complete()
    -- NetTimedAction.perform expects the server callback to return a boolean.
    -- Inventory removal and rewards are handled by RPG_Server_Randombox.
    return true
end

-- RCE: ember forging presentation, legacy physical IDs retained.
