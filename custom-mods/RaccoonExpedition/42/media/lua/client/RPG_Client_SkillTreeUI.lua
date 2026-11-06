require "ISUI/ISPanel"
require "ISUI/ISButton"
require "RPG_Client_Commands"
require "RPG_Client_Receiver"
local RPG_Keybinding = require "RPG_Client_Keybinding"

local Tex        = require "RPG_Client_UITextures"
local NodeData   = require "RPG_Client_UINodeData"
local LevelTable = require "RPG_Client_LevelTable"
local AmmoDrops  = require "RPG_Shared_AmmoDrops"
local BoxAdminUI={CanEdit=function()return false end}
-- RCE: jump minigame disabled.
-- RCE: world danger disabled.
local Vault = require "RPG_Shared_DimensionalVault"
local Endurance = require "RPG_Shared_EnduranceKeystone"
local ItemFind = require "RPG_Shared_ItemFindChance"

-- ✅ XPBar Toggle 저장용(서버 모듈명)
local MODULE = "RPGSkillTree"

-- ✅ XPBar 파일이 아직 로드 안되어도 에러 안나게
pcall(function() require "RPG_Client_XPBar" end)
-- Raid HUD is independent from the XP Bar; load the existing movable widget.
pcall(function() require "RPG_Client_HordeHUD" end)

RPGSkillTreeUI = ISPanel:derive("RPGSkillTreeUI")
RPGSkillTreeUI.instance = nil

local MAX_PAN        = nil
local RESET_XP_CHUNK = 90000

local SMALL_SIZE   = NodeData.SIZES.SMALL
local BIG_SIZE     = NodeData.SIZES.BIG
local SPECIAL_SIZE = NodeData.SIZES.SPECIAL

local BigNodeIds           = NodeData.BigNodeIds
local SpecialNodeIds       = NodeData.SpecialNodeIds
local NodePrerequisitesAND = NodeData.PrereqAND or {}
local NodePrerequisitesOR  = NodeData.PrereqOR  or {}

----------------------------------------------------
-- 🔹 번역용 노드 설명(여러 줄) 헬퍼
----------------------------------------------------
local function RPG_GetNodeDescriptionLines(id)
    if not id then return { "?" } end

    local lines = {}

    for i = 1, 10 do
        local key = string.format("Tooltip_RPGSkillTree_%s_%d", id, i)
        local txt = getText(key)
        if not txt or txt == key then break end
        table.insert(lines, txt)
    end

    if #lines == 0 then
        local key = "Tooltip_RPGSkillTree_" .. id
        local txt = getText(key)
        table.insert(lines, txt)
    end

    return lines
end

----------------------------------------------------
-- ✅ XPBar Visible 상태 읽기(서버 state 기반)
----------------------------------------------------
local function RPG_GetXPBarVisibleFromState()
    local st = (RPG_ClientState and RPG_ClientState.state) or {}
    local ui = st.ui or {}
    local xpbar = ui.xpbar or {}
    if type(xpbar.visible) == "boolean" then
        return xpbar.visible
    end
    return true -- 기본: 보이기
end

function RPGSkillTreeUI:updateXPBarToggleTitle()
    if not self.xpbarToggleButton then return end
    local on = RPG_GetXPBarVisibleFromState()
    if on then
        self.xpbarToggleButton:setTitle("XPBar: ON")
    else
        self.xpbarToggleButton:setTitle("XPBar: OFF")
    end
end

function RPGSkillTreeUI.onClickXPBarToggle(self, button, x, y)
    local player = self.player or getSpecificPlayer(0)
    if not player then return end

    local cur = RPG_GetXPBarVisibleFromState()
    local newVisible = (cur ~= true) and true or false

    -- ✅ 서버 저장 (SetXPBarPos에 visible만 보내기)
    if RPG_ClientCommands and RPG_ClientCommands.SaveXPBarPos then
        RPG_ClientCommands.SaveXPBarPos({ visible = newVisible })
    end

    -- 즉시 버튼 표시 갱신
    self:updateXPBarToggleTitle()
end

----------------------------------------------------
-- RaidBar visibility toggle (left of XPBar).
----------------------------------------------------
function RPGSkillTreeUI:updateRaidBarToggleTitle()
    if not self.raidbarToggleButton then return end
    local isOn = not (RPG_HordeHUD and RPG_HordeHUD.IsVisible and not RPG_HordeHUD.IsVisible())
    self.raidbarToggleButton:setTitle(isOn and "RaidBar: ON" or "RaidBar: OFF")
end

function RPGSkillTreeUI.onClickRaidBarToggle(self, button, x, y)
    if not (RPG_HordeHUD and RPG_HordeHUD.SetVisible) then return end
    local current = RPG_HordeHUD.IsVisible and RPG_HordeHUD.IsVisible()
    RPG_HordeHUD.SetVisible(not current)
    self:updateRaidBarToggleTitle()
end

----------------------------------------------------
-- Random box editor, directly to the LEFT of RaidBar.
-- Single-player is the local world owner; multiplayer requires admin.
-- Server commands independently check access before any mutation.
----------------------------------------------------
local function RPG_CanEditRandomBoxes(player)
    return BoxAdminUI.CanEdit and BoxAdminUI.CanEdit(player) == true
end

function RPGSkillTreeUI:refreshRandomBoxEditorAccess()
    if not self.boxAdminButton then return end
    local player = (getSpecificPlayer and getSpecificPlayer(0)) or self.player
    local allowed = RPG_CanEditRandomBoxes(player)
    self.boxAdminButton.enable = allowed
    if self.jumpAdminButton then self.jumpAdminButton.enable = allowed end
    if allowed then
        self.boxAdminButton.tooltip = nil
    elseif BoxAdminUI.PermissionPending and BoxAdminUI.PermissionPending() then
        self.boxAdminButton.tooltip = 'Checking admin access with server...'
    else
        local key = 'UI_RPG_BoxAdmin_SkillTreeNoAccess'
        local translated = getText and getText(key) or key
        self.boxAdminButton.tooltip = translated ~= key and translated or 'Multiplayer: admin access required'
    end
end

function RPGSkillTreeUI.onClickJumpEditor(self)
    local player=(getSpecificPlayer and getSpecificPlayer(0)) or self.player
    if not RPG_CanEditRandomBoxes(player) then return end
    JumpAdminUI.Open(player)
end

function RPGSkillTreeUI.onClickRandomBoxEditor(self, button, x, y)
    local player = (getSpecificPlayer and getSpecificPlayer(0)) or self.player
    if not RPG_CanEditRandomBoxes(player) then return end
    BoxAdminUI.Open(player)
end

----------------------------------------------------
-- World danger panel: always available to SP and MP players.
----------------------------------------------------
function RPGSkillTreeUI.onClickWorldDanger(self)
    if not self.worldDangerPanel then return end
    local visible = self.worldDangerPanel:isVisible()
    self.worldDangerPanel:setVisible(not visible)
    self:updateWorldDangerToggleTitle()
end

function RPGSkillTreeUI:updateWorldDangerToggleTitle()
    if not self.worldDangerButton or not self.worldDangerPanel then return end
    local key = "UI_RPG_WD_Button"
    local title = getText and getText(key) or key
    if title == key then title = "World Danger" end
    self.worldDangerButton:setTitle(title)
    local toggleKey = self.worldDangerPanel:isVisible() and "UI_RPG_WD_HideTip" or "UI_RPG_WD_ShowTip"
    local tip = getText and getText(toggleKey) or toggleKey
    self.worldDangerButton.tooltip = tip ~= toggleKey and tip or nil
end

----------------------------------------------------
-- 🔹 이 노드를 찍을 수 있는지 검사 (선행 스킬 AND / OR 모두 반영)
----------------------------------------------------
function RPGSkillTreeUI:canUnlockNode(id)
    if not id or id == "Start" then return false end

    local state = self.nodeState or {}

    -- AND 조건: 전부 찍혀 있어야 함
    local reqAnd = NodePrerequisitesAND[id]
    if type(reqAnd) == "table" then
        for _, parentId in ipairs(reqAnd) do
            if not state[parentId] then
                return false
            end
        end
    end

    -- OR 조건: 하나만 찍혀 있어도 OK
    local reqOr = NodePrerequisitesOR[id]
    if type(reqOr) == "table" then
        local ok = false
        for _, parentId in ipairs(reqOr) do
            if state[parentId] then
                ok = true
                break
            end
        end
        if not ok then
            return false
        end
    end

    return true
end

----------------------------------------------------
-- ✅ UI는 st(동기 state)만 읽는다: 스냅샷 헬퍼
----------------------------------------------------
function RPGSkillTreeUI:getStateSnapshot(player)
    local st = (RPG_ClientState and RPG_ClientState.state) or {}

    local snap = {
        level       = st.level or 1,
        xp          = st.xp or 0,
        totalXP     = st.totalXP or 0,
        skillPoints = st.skillPoints or 0,
        spentPoints = st.spentPoints or 0,
        geneSpentPoints = st.geneSpentPoints or 0,
        nodes       = st.nodes or { Start = true },
        resetPoints = st.resetPoints or 0,
        factors     = st.factors or {},
    }

    if type(snap.nodes) ~= "table" then
        snap.nodes = { Start = true }
    end
    snap.nodes.Start = true

    return snap
end

function RPGSkillTreeUI:clampPan()
    -- Include all new branch extents at the current zoom.
    local extent=2064
    for _,node in ipairs(self.nodes or {}) do
        local size=SpecialNodeIds[node.id] and SPECIAL_SIZE or BigNodeIds[node.id] and BIG_SIZE or SMALL_SIZE
        extent=math.max(extent,math.abs(node.x)+size/2,math.abs(node.y)+size/2)
    end
    local max = math.max(MAX_PAN or 2000,extent*(self.zoom or 1))

    self.panX = self.panX or 0
    self.panY = self.panY or 0

    if self.panX >  max then self.panX =  max end
    if self.panX < -max then self.panX = -max end
    if self.panY >  max then self.panY =  max end
    if self.panY < -max then self.panY = -max end
end

function RPGSkillTreeUI:getNodeScreenPos(node, centerX, centerY, zoom)
    local baseSize = SMALL_SIZE
    if BigNodeIds[node.id] then baseSize = BIG_SIZE end
    if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

    local sizeMul  = node.size or 1.0
    local iconSize = baseSize * sizeMul * zoom

    local offsetX = (node.x or 0) * zoom
    local offsetY = (node.y or 0) * zoom

    local sx = centerX + offsetX
    local sy = centerY + offsetY

    return sx, sy, iconSize
end

function RPGSkillTreeUI:getNodeScreenRect(node, centerX, centerY, zoom)
    local baseSize = SMALL_SIZE
    if BigNodeIds[node.id] then baseSize = BIG_SIZE end
    if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

    local sizeMul  = node.size or 1.0
    local iconSize = baseSize * sizeMul * zoom

    local offsetX = (node.x or 0) * zoom
    local offsetY = (node.y or 0) * zoom

    local cx = centerX + offsetX
    local cy = centerY + offsetY

    local x = cx - iconSize / 2
    local y = cy - iconSize / 2

    return x, y, iconSize, iconSize
end

function RPGSkillTreeUI:getNodeUnderPoint(mx, my, centerX, centerY, zoom)
    if not self.nodes then return nil end

    for _, node in ipairs(self.nodes) do
        local tex = node.tex or self.startNodeTex
        if tex then
            local x, y, w, h = self:getNodeScreenRect(node, centerX, centerY, zoom)
            if mx >= x and mx <= x + w and my >= y and my <= y + h then
                return node
            end
        end
    end
    return nil
end

function RPGSkillTreeUI:drawLineRect(x1, y1, x2, y2, r, g, b, a)
    local dx = x2 - x1
    local dy = y2 - y1
    local dist = math.sqrt(dx * dx + dy * dy)

    local stepPixels = 4
    local steps = math.floor(dist / stepPixels + 0.5)
    if steps > 256 then steps = 256 end

    if steps <= 0 then
        self:drawRect(x1, y1, 2, 2, a, r, g, b)
        return
    end

    local sx = dx / steps
    local sy = dy / steps

    local x = x1
    local y = y1
    for _ = 1, steps do
        self:drawRect(x, y, 2, 2, a, r, g, b)
        x = x + sx
        y = y + sy
    end
end

------------------------------------------------
-- 🔹 \n 이 들어간 텍스트 여러 줄로 그리기 헬퍼
------------------------------------------------
function RPGSkillTreeUI:drawMultiline(text, x, y, r, g, b, a, font)
    local tm   = getTextManager()
    font       = font or UIFont.Small
    text       = tostring(text or "")
    local lineH = tm:MeasureStringY(font, "A") + 2

    for line in string.gmatch(text, "([^\n]+)") do
        self:drawText(line, x, y, r, g, b, a, font)
        y = y + lineH
    end

    return y
end

function RPGSkillTreeUI:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1 }
    o.border = true
    o.zoom = 1.0

    o.panX = 0
    o.panY = 0
    o.isPanning = false

    o._mouseDownX = 0
    o._mouseDownY = 0
    o._mouseMoved = false

    ------------------------------------------------
    -- ✅ 텍스처/노드 테이블은 외부 파일에서 로드
    ------------------------------------------------
    Tex.Load(o)

    o.nodes = NodeData.BuildNodes(o)

    o.nodeById = {}
    for _, node in ipairs(o.nodes) do
        if node.id then
            o.nodeById[node.id] = node
        end
    end

    ----------------------------------------------------
    -- 스킬 포인트 & 노드 상태
    ----------------------------------------------------
    o.skillPoints = 0
    o.nodeState   = { Start = true }

    o:initialise()

    o.tooltipCache = { id=nil, key=nil, w=0, h=0 }

    ------------------------------------------------
    -- 좌측 하단 Reset 버튼
    ------------------------------------------------
    local btnW, btnH = 120, 25
    local margin = 20

    o.resetButton = ISButton:new(
        margin,
        o.height - btnH - margin,
        btnW, btnH,
        "Reset (0)",
        o,
        RPGSkillTreeUI.onClickReset
    )
    o.resetButton:initialise()
    o.resetButton:instantiate()
    o.resetButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o:addChild(o.resetButton)

    ------------------------------------------------
    -- 우측 하단 Close 버튼
    ------------------------------------------------
    o.closeButton = ISButton:new(
        o.width - btnW - margin,
        o.height - btnH - margin,
        btnW, btnH,
        "Close",
        o,
        RPGSkillTreeUI.onClickClose
    )
    o.closeButton:initialise()
    o.closeButton:instantiate()
    o.closeButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o:addChild(o.closeButton)

    ------------------------------------------------
    -- ✅ 우측 상단 XPBar Toggle 버튼
    ------------------------------------------------
    local tW, tH = 120, 25
    o.xpbarToggleButton = ISButton:new(
        o.width - tW - margin,
        margin,
        tW, tH,
        "XPBar: ON",
        o,
        RPGSkillTreeUI.onClickXPBarToggle
    )
    o.xpbarToggleButton:initialise()
    o.xpbarToggleButton:instantiate()
    o.xpbarToggleButton.borderColor = { r = 1, g = 1, b = 1, a = 0.7 }
    o:addChild(o.xpbarToggleButton)

    -- Initial button captions.
    o:updateXPBarToggleTitle()
    o:updateRaidBarToggleTitle()

    return o
end

------------------------------------------------
-- Close 버튼
------------------------------------------------
function RPGSkillTreeUI.onClickClose(self, button, x, y)
    if self and self.close then
        self:close()
    end
end

------------------------------------------------
-- ✅ Render
------------------------------------------------
function RPGSkillTreeUI:render()
    ISPanel.render(self)

    local player = self.player or getSpecificPlayer(0)
    if not player then return end

    local S = self:getStateSnapshot(player)

    local availableSP = (S.skillPoints or 0) - (S.spentPoints or 0) - (S.geneSpentPoints or 0)
    if availableSP < 0 then availableSP = 0 end

    self.skillPoints = availableSP
    self.nodeState   = S.nodes or { Start = true }

    -- Refresh both button captions from their respective HUD states.
    self:updateXPBarToggleTitle()
    self:updateRaidBarToggleTitle()
    -- A server permission reply can arrive after creation; keep the button
    -- state and tooltip in sync with the latest authoritative response.
    self:refreshRandomBoxEditorAccess()

    local factors = S.factors or {}

    ------------------------------------------------
    -- 상단 중앙 SP
    ------------------------------------------------
    local tm   = getTextManager()
    local font = UIFont.Large
    local spText = "Skill Points : " .. tostring(self.skillPoints or 0)

    local textW = tm:MeasureStringX(font, spText)
    local tx = (self.width - textW) / 2
    self:drawText(spText, tx, 10, 1, 0.9, 0.2, 1, font)

    self:drawText("SP: " .. tostring(self.skillPoints or 0), 20, 20, 0, 1, 0, 1, UIFont.Small)

    ------------------------------------------------
    -- LV / XP
    ------------------------------------------------
    local lvl = S.level or 1
    local xp  = S.xp or 0

    local xpNext = 0
    if LevelTable and LevelTable.GetRequiredXP then
        xpNext = LevelTable.GetRequiredXP(lvl) or 0
    end

    self:drawText("LV: " .. tostring(lvl), 20, 35, 1, 1, 1, 1, UIFont.Small)
    self:drawText("XP: " .. tostring(xp) .. " / " .. tostring(xpNext), 20, 50, 1, 1, 1, 1, UIFont.Small)

    do
        local total   = S.totalXP or 0
        local chunk   = RESET_XP_CHUNK or 90000
        local inChunk = total % chunk
        local remain  = chunk - inChunk
        if remain == chunk then remain = 0 end
        self:drawText("ResetPointXP: " .. tostring(remain), 20, 65, 1, 1, 1, 1, UIFont.Small)
    end

    if self.resetButton then
        local resetPts = S.resetPoints or 0
        self.resetButton:setTitle("Reset (" .. tostring(resetPts) .. ")")
        self.resetButton.enable = (resetPts > 0)
    end

    ------------------------------------------------
    -- 우측 상단 스테이터스
    ------------------------------------------------
	local statusX = self.width - 260

	-- ✅ XPBar 토글 버튼 바로 아래로 스테이터스 시작 위치 이동
	local margin = 20
	local tH = 25
	local statusY = margin + tH + 10  -- 버튼 아래 10px 여백

	local lineH   = tm:MeasureStringY(UIFont.Small, "A") + 2

    self:drawText(getText("UI_RPG_Status"), statusX, statusY, 1, 1, 0.8, 1, UIFont.Small)
    statusY = statusY + lineH

    local function drawFactorLine(labelKey, factor)
        if factor == nil then return end
        factor = factor or 1.0
        if math.abs(factor - 1.0) < 0.001 then return end

        local label = getText(labelKey)
        local txt
        if factor < 1.0 then
            local pct = math.floor((1.0 - factor) * 100 + 0.5)
            txt = string.format("%s -%d%%", label, pct)
        else
            local pct = math.floor((factor - 1.0) * 100 + 0.5)
            txt = string.format("%s +%d%%", label, pct)
        end

        statusY = self:drawMultiline(txt, statusX, statusY, 1, 1, 1, 1, UIFont.Small)
    end

    drawFactorLine("UI_RPG_Status_HungerGain",   factors.hungerGain)
    drawFactorLine("UI_RPG_Status_ThirstGain",   factors.thirstGain)
    drawFactorLine("UI_RPG_Status_StaminaDrain", factors.staminaDrain)
    drawFactorLine("UI_RPG_Status_StaminaRegen", factors.staminaRegen)
    drawFactorLine("UI_RPG_Status_StressGain",   factors.stressGain)
    drawFactorLine("UI_RPG_Status_PanicGain",    factors.panicGain)
    drawFactorLine("UI_RPG_Status_XPGain",       factors.xpGain)
    drawFactorLine("UI_RPG_Status_CarryWeight",  factors.carryWeightMul)
    drawFactorLine("UI_RPG_Status_BoredomRecovery",  factors.boredomRecovery)
    drawFactorLine("UI_RPG_Status_UnhappyRecovery",  factors.unhappyRecovery)
    drawFactorLine("UI_RPG_Status_FoodSicknessRes",  factors.foodSicknessGain)
    drawFactorLine("UI_RPG_Status_PainGain",  factors.painGain)
    drawFactorLine("UI_RPG_Status_Wet",  factors.wetGain)

    local function drawXpMulPoints(label, points)
        points = tonumber(points or 0) or 0
        if points <= 0 then return end
        local txt = string.format("%s x%d", label, points)
        statusY = self:drawMultiline(txt, statusX, statusY, 1, 1, 1, 1, UIFont.Small)
    end
    drawXpMulPoints("Strength XP", factors.strengthXP)
    drawXpMulPoints("Fitness XP",  factors.fitnessXP)
    drawXpMulPoints("Nimble XP",   factors.nimbleXP)
    drawXpMulPoints("Running XP",  factors.runningXP)

    do
        local nodes = self.nodeState or {}

        local procMul = 1.0

        local ver2Small = 0
        if nodes.XPVer21 then ver2Small = ver2Small + 1 end
        if nodes.XPVer22 then ver2Small = ver2Small + 1 end
        if nodes.XPVer23 then ver2Small = ver2Small + 1 end
        if nodes.XPVer24 then ver2Small = ver2Small + 1 end
        if ver2Small > 0 then
            procMul = procMul + (ver2Small * 5.0)
        end

        local ver2Big = 0
        if nodes.XPVer2Big1 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big2 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big3 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big4 then ver2Big = ver2Big + 1 end
        if nodes.XPVer2Big5 then ver2Big = ver2Big + 1 end
        if ver2Big > 0 then
            procMul = procMul + (ver2Big * 30.0)
        end

        if nodes.XPMixedBig then
            procMul = procMul + 15.0
        end

        if procMul > 1.0 then
            local label = getText("UI_RPG_Status_XPBonus2")
            if not label or label == "XP(1%Chance) * " then
                label = "XP Proc"
            end

            local txt = string.format("%s x%d (1%%)", label, math.floor(procMul + 0.5))
            statusY = self:drawMultiline(txt, statusX, statusY, 1, 1, 1, 1, UIFont.Small)
        end
    end

    if RPG_ZOMBIE_XP_FACTOR then
        drawFactorLine("UI_RPG_Status_XPGain", RPG_ZOMBIE_XP_FACTOR)
    end
    if RPG_LOOT_CHANCE_FACTOR then
        drawFactorLine("UI_RPG_Status_LootChance", RPG_LOOT_CHANCE_FACTOR)
    end
    if RPG_BOX_RARE_CHANCE_FACTOR then
        drawFactorLine("UI_RPG_Status_BoxRareChance", RPG_BOX_RARE_CHANCE_FACTOR)
    end
    if RPG_WORK_SPEED_FACTOR then
        drawFactorLine("UI_RPG_Status_WorkSpeed", RPG_WORK_SPEED_FACTOR)
    end

    ------------------------------------------------
    -- ✅ 스페셜 노드 상태 표시
    ------------------------------------------------
    local nodes = self.nodeState or {}

    if nodes.EnduranceKeystone then
        local chance=math.floor(Endurance.chance(nodes)*100+0.5)
        local status=getText("UI_RPG_Status_EnduranceKeystone"):gsub("{chance}",tostring(chance))
        statusY=self:drawMultiline(status,
            statusX,statusY,0.3,0.68,1,1,UIFont.Small)
    end
    if nodes.DimensionalVault then
        local limits=Vault.limits(nodes)
        local label=getText("UI_RPG_Status_DimensionalVault")..'\n'
            ..string.format('%d / %d / %d',limits.weight,limits.count,limits.tabs)
        statusY=self:drawMultiline(label,statusX,statusY,0.3,0.68,1,1,UIFont.Small)
    end

    local findBonus=(1+ItemFind.bonus(nodes))*(1+ItemFind.chokerBonus(player))-1
    if findBonus>0 then
        local status=getText('UI_RPG_Status_ItemFind'):gsub('{pct}',function() return '%' end)
        statusY=self:drawMultiline(status:gsub('{percent}',string.format('%.2f',findBonus*100)),
            statusX,statusY,0.77,0.4,1.0,1,UIFont.Small)
    end

    -- ✅ MemoryStone 노드 상태 표시(기존 유지)
    if nodes.MemoryStone then
        statusY = self:drawMultiline(
            getText("UI_RPG_Status_MemoryStone"),
            statusX, statusY,
            0.63, 0.25, 1.0, 1,
            UIFont.Small
        )
    end

    -- v51: Gene Editing node opens the trait editor when clicked.
    if nodes.GeneEditing then
        statusY = self:drawMultiline(
            getText("UI_RPG_Status_GeneEditing"),
            statusX, statusY,
            0.22, 0.86, 0.65, 1,
            UIFont.Small
        )
    end

    ------------------------------------------------
    -- ✅ Collector 노드 상태 표시 (Blood / Soul / Sacrifice) - 파란색
    ------------------------------------------------
    local function drawCollectorStatus(nodeId, textKey)
        if nodes and nodes[nodeId] then
            statusY = self:drawMultiline(
                getText(textKey),
                statusX, statusY,
                0.25, 0.55, 1.0, 1,  -- 파란색
                UIFont.Small
            )
        end
    end

    drawCollectorStatus("BloodCollector",     "UI_RPG_Status_BloodCollector")
    drawCollectorStatus("SoulCollector",      "UI_RPG_Status_SoulCollector")
    drawCollectorStatus("SacrificeCollector", "UI_RPG_Status_SacrificeCollector")

    ------------------------------------------------
    -- v38: Ammo Collector and all unlocked caliber-specific drop chances
    -- shown in the same Applied Effects panel. Use the shared roll table
    -- to avoid discrepancies between UI and actual reward probabilities.
    ------------------------------------------------
    if nodes.AmmoCollector then
        statusY = self:drawMultiline(
            getText("UI_RPG_Status_AmmoCollector"),
            statusX, statusY, 0.25, 0.65, 1.0, 1, UIFont.Small
        )
        local ammoNames = {
            Ammo9mm = "9mm", Ammo38 = ".38", Ammo45 = ".45",
            Ammo357 = ".357", Ammo44 = ".44", Ammo12g = "12G",
            Ammo3030 = ".30-30", Ammo308 = "7.62", Ammo556 = "5.56",
        }
        for _, entry in ipairs(AmmoDrops.entries or {}) do
            if nodes[entry.node] == true then
                local label = ammoNames[entry.node] or entry.node
                local txt = string.format("  %s: %s %g%%",
                    getText("UI_RPG_Status_AmmoDrop"), label, math.min(100,(tonumber(entry.percent) or 0)*(1+findBonus)))
                statusY = self:drawMultiline(
                    txt, statusX, statusY, 0.45, 0.82, 1.0, 1, UIFont.Small
                )
            end
        end
    end

    ------------------------------------------------
    -- 아래: 팬/선/노드/툴팁
    ------------------------------------------------
    if not self.startNodeTex then
        self:drawText("NO TEX", 20, 40, 1, 0, 0, 1, UIFont.Medium)
        return
    end
    if not self.nodes then
        self:drawText("NO NODES", 20, 60, 1, 0, 0, 1, UIFont.Medium)
        return
    end

    self:clampPan()

    local zoom = self.zoom or 1.0
    local centerX = self.width  / 2 + (self.panX or 0)
    local centerY = self.height / 2 + (self.panY or 0)

    local state    = self.nodeState or {}
    local nodeById  = self.nodeById or {}

    for childId, parents in pairs(NodePrerequisitesAND) do
        local child = nodeById[childId]
        if child then
            local cx, cy = self:getNodeScreenPos(child, centerX, centerY, zoom)
            local unlocked = state[childId]
            local r, g, b = 1, 1, 1
            if childId == "MemoryStone" or childId == "GeneEditing" or childId == "ItemFind1" or childId == "ItemFind2" or childId == "ItemFind3" then
                r, g, b = unlocked and 0.78 or 0.48, unlocked and 0.31 or 0.24, unlocked and 1.0 or 0.62
            elseif unlocked then r, g, b = 1.0, 0.84, 0.0 end

            for _, parentId in ipairs(parents) do
                local parent = nodeById[parentId]
                if parent then
                    local px, py = self:getNodeScreenPos(parent, centerX, centerY, zoom)
                    self:drawLineRect(px, py, cx, cy, r, g, b, 1.0)
                end
            end
        end
    end

    for childId, parents in pairs(NodePrerequisitesOR) do
        local child = nodeById[childId]
        if child then
            local cx, cy = self:getNodeScreenPos(child, centerX, centerY, zoom)
            local unlocked = state[childId]
            local r, g, b = 1, 1, 1
            if unlocked then r, g, b = 1.0, 0.84, 0.0 end

            for _, parentId in ipairs(parents) do
                local parent = nodeById[parentId]
                if parent then
                    local px, py = self:getNodeScreenPos(parent, centerX, centerY, zoom)
                    self:drawLineRect(px, py, cx, cy, r, g, b, 1.0)
                end
            end
        end
    end

    for _, node in ipairs(self.nodes) do
        local id = node.id
        local isUnlocked = (state and state[id]) and true or false

        local canUnlock = false
        if (not isUnlocked) and (self.skillPoints or 0) > 0 then
            if self.canUnlockNode and self:canUnlockNode(id) then
                canUnlock = true
            end
        end

        local baseSize = SMALL_SIZE
        if BigNodeIds[node.id] then baseSize = BIG_SIZE end
        if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

        local sizeMul  = node.size or 1.0
        local iconSize = baseSize * sizeMul * zoom
        local offsetX  = (node.x or 0) * zoom
        local offsetY  = (node.y or 0) * zoom
        local drawX = centerX + offsetX - iconSize / 2
        local drawY = centerY + offsetY - iconSize / 2

        local tex = node.tex or self.startNodeTex
        if tex then
            if isUnlocked then
                self:drawTextureScaled(tex, drawX, drawY, iconSize, iconSize, 1, 1, 1, 1)
            else
                self:drawTextureScaled(tex, drawX, drawY, iconSize, iconSize, 1, 0.35, 0.35, 0.35)
            end
        end

        if canUnlock and (not isUnlocked) then
            if id == "MemoryStone" or id == "GeneEditing" or id == "ItemFind1" or id == "ItemFind2" or id == "ItemFind3" then
                self:drawRectBorder(drawX - 3, drawY - 3, iconSize + 6, iconSize + 6, 1.0, 0.67, 0.34, 1.0)
            else
                self:drawRectBorder(drawX - 3, drawY - 3, iconSize + 6, iconSize + 6, 1.0, 1.0, 0.84, 0.0)
            end
        end
    end

    local absX = self:getAbsoluteX()
    local absY = self:getAbsoluteY()
    local mx   = getMouseX() - absX
    local my   = getMouseY() - absY

    local hovered = self:getNodeUnderPoint(mx, my, centerX, centerY, zoom)
    self.hoveredNode = hovered

    if hovered then
        local cache = self.tooltipCache or {}
        local lines = RPG_GetNodeDescriptionLines(hovered.id)

        local fontTip = UIFont.Small
        local concatKey = table.concat(lines, "\n")

        if cache.id ~= hovered.id or cache.key ~= concatKey then
            local maxW = 0
            local totalH = 0
            local lineH2 = tm:MeasureStringY(fontTip, "A")
            for _, line in ipairs(lines) do
                local w = tm:MeasureStringX(fontTip, line)
                if w > maxW then maxW = w end
                totalH = totalH + lineH2
            end
            local pad = 4
            cache.id  = hovered.id
            cache.key = concatKey
            cache.w   = maxW + pad * 2
            cache.h   = totalH + pad * 2
            self.tooltipCache = cache
        end

        local pad  = 4
        local boxW = cache.w
        local boxH = cache.h
        local tipX = mx + 16
        local tipY = my + 16

        if tipX + boxW > self.width then tipX = self.width - boxW - 5 end
        if tipY + boxH > self.height then tipY = self.height - boxH - 5 end

        self:drawRect(tipX, tipY, boxW, boxH, 0.8, 0, 0, 0)
        self:drawRectBorder(tipX, tipY, boxW, boxH, 1, 1, 1, 0.8)

        local lineH3 = tm:MeasureStringY(fontTip, "A")
        local drawY2 = tipY + pad
        for _, line in ipairs(lines) do
            self:drawText(line, tipX + pad, drawY2, 1, 1, 1, 1, fontTip)
            drawY2 = drawY2 + lineH3
        end
    end
end

function RPGSkillTreeUI:onNodeClicked(node)
    local id = node.id
    if not id then return end
    if id == "Start" then return end

    -- Only the learned skill node opens the character-bound vault.
    if id==Vault.NODE and ((self.nodeState and self.nodeState[id]) or Vault.hasSavedItems(self.player)) then
        local success,ui=pcall(require,'RPG_Client_DimensionalVaultUI')
        if success and ui and ui.open then ui.open(self.player) end
        return
    end

    if id == "GeneEditing" and self.nodeState and self.nodeState.GeneEditing then
        local success,ui=pcall(require,"RPG_Client_GeneEditingUI")
        if success and ui and ui.open then ui.open(self.player) end
        return
    end
    if self.nodeState and self.nodeState[id] then return end
    if (self.skillPoints or 0) <= 0 then return end
    if not self:canUnlockNode(id) then return end

    if RPG_ClientCommands and RPG_ClientCommands.ToggleNode then
        RPG_ClientCommands.ToggleNode(id)
    end
end

------------------------------------------------
-- Reset 버튼
------------------------------------------------
function RPGSkillTreeUI.onClickReset(self, button, x, y)
    local player = self.player or getSpecificPlayer(0)
    if not player then return end

    local st = (RPG_ClientState and RPG_ClientState.state) or {}
    local rp = st.resetPoints or 0

    if rp <= 0 then
        if player.Say then player:Say("No Skill Reset Points.") end
        return
    end

    if RPG_ClientCommands and RPG_ClientCommands.ResetNodes then
        RPG_ClientCommands.ResetNodes()
    end
end

function RPGSkillTreeUI:onMouseDown(x, y)
    ISPanel.onMouseDown(self, x, y)
    self.isPanning = true
    self._mouseDownX = x
    self._mouseDownY = y
    self._mouseMoved = false
end

function RPGSkillTreeUI:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)

    if self.isPanning then
        self.panX = (self.panX or 0) + dx
        self.panY = (self.panY or 0) + dy
        self:clampPan()

        if math.abs(dx) + math.abs(dy) > 0 then
            self._mouseMoved = true
        end
    end
end

function RPGSkillTreeUI:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    self.isPanning = false

    local dx = math.abs((x or 0) - (self._mouseDownX or 0))
    local dy = math.abs((y or 0) - (self._mouseDownY or 0))
    local moved = (dx + dy) >= 6 or self._mouseMoved

    if moved then
        local zoom    = self.zoom or 1.0
        local centerX = self.width  / 2 + (self.panX or 0)
        local centerY = self.height / 2 + (self.panY or 0)

        local node = self:getNodeUnderPoint(x, y, centerX, centerY, zoom)
        if node then
            self:onNodeClicked(node)
        end
        return
    end

    if not self.nodes then return end

    local zoom    = self.zoom or 1.0
    local centerX = self.width  / 2 + (self.panX or 0)
    local centerY = self.height / 2 + (self.panY or 0)

    for _, node in ipairs(self.nodes) do
        local tex = node.tex or self.startNodeTex
        if tex then
            local baseSize = SMALL_SIZE
            if BigNodeIds[node.id] then baseSize = BIG_SIZE end
            if SpecialNodeIds[node.id] then baseSize = SPECIAL_SIZE end

            local sizeMul  = node.size or 1.0
            local iconSize = baseSize * sizeMul * zoom

            local offsetX = (node.x or 0) * zoom
            local offsetY = (node.y or 0) * zoom
            local drawX   = centerX + offsetX - iconSize / 2
            local drawY   = centerY + offsetY - iconSize / 2

            if x >= drawX and x <= drawX + iconSize and y >= drawY and y <= drawY + iconSize then
                self:onNodeClicked(node)
                break
            end
        end
    end
end

function RPGSkillTreeUI:onMouseWheel(del)
    local zoomStep = 0.1

    self.zoom = self.zoom or 1.0
    local oldZoom = self.zoom
    local newZoom = self.zoom - del * zoomStep

    if newZoom < 0.2 then newZoom = 0.2 end
    if newZoom > 2.0 then newZoom = 2.0 end
    if math.abs(newZoom - oldZoom) < 0.0001 then return true end

    local absX = self:getAbsoluteX()
    local absY = self:getAbsoluteY()
    local mx   = getMouseX() - absX
    local my   = getMouseY() - absY

    self.panX = self.panX or 0
    self.panY = self.panY or 0

    local centerX = self.width  / 2 + self.panX
    local centerY = self.height / 2 + self.panY

    local worldX = (mx - centerX) / oldZoom
    local worldY = (my - centerY) / oldZoom

    self.zoom = newZoom

    local newCenterX = mx - worldX * self.zoom
    local newCenterY = my - worldY * self.zoom

    self.panX = newCenterX - self.width  / 2
    self.panY = newCenterY - self.height / 2

    self:clampPan()
    return true
end

function RPGSkillTreeUI:onKeyPress(key)
    if key == Keyboard.KEY_ESCAPE then
        self:close()
        return true
    end
    return false
end

----------------------------------------------------------------
-- UI 열고/닫을 때 게임 일시정지 연동
----------------------------------------------------------------
function RPGSkillTreeUI:close()
    if self.pausedGame then
        setGameSpeed(self.prevGameSpeed or 1)
        self.pausedGame = false
    end

    self:removeFromUIManager()
    RPGSkillTreeUI.instance = nil
end

function RPGSkillTreeUI.open(player)
    player = (getSpecificPlayer and getSpecificPlayer(0)) or player
    if not player then return end
    -- Always recheck with the server when opening/reopening the skill tree.
    -- This catches an admin role granted or revoked without reconnecting.
    if BoxAdminUI.RequestPermission then BoxAdminUI.RequestPermission(player) end
    if RPGSkillTreeUI.instance then
        RPGSkillTreeUI.instance:refreshRandomBoxEditorAccess()
        return
    end

    if RPG_ClientCommands and RPG_ClientCommands.RequestSync then
        RPG_ClientCommands.RequestSync(player)
    end

    local core = getCore()
    local ui = RPGSkillTreeUI:new(0, 0, core:getScreenWidth(), core:getScreenHeight())
    ui.player = player

    local st = (RPG_ClientState and RPG_ClientState.state) or {}
    ui.skillPoints = (st.skillPoints or 0) - (st.spentPoints or 0) - (st.geneSpentPoints or 0)
    ui.nodeState   = st.nodes or { Start = true }
    if type(ui.nodeState) ~= "table" then ui.nodeState = { Start = true } end
    ui.nodeState.Start = true

    ui:addToUIManager()
    ui:setVisible(true)
    ui:setWantKeyEvents(true)

    local multiplayer = (type(isMultiplayer) == "function" and isMultiplayer())
        or (type(isClient) == "function" and isClient())
        or (type(isServer) == "function" and isServer())
    if not multiplayer then
        ui.prevGameSpeed = getGameSpeed() or 1
        ui.pausedGame = true
        setGameSpeed(0)
    end

    RPGSkillTreeUI.instance = ui
    ui:refreshRandomBoxEditorAccess()
end

----------------------------------------------------------------
-- 채팅/텍스트 입력 중이면 단축키 무시
----------------------------------------------------------------
local function RPG_IsTypingInTextEntry()
    local ok, focused = pcall(function()
        if ISChat and ISChat.instance and ISChat.instance.textEntry then
            return ISChat.instance.textEntry:isFocused()
        end
        return false
    end)
    if ok and focused then return true end

    return false
end

----------------------------------------------------------------
-- 사용자 지정 스킬트리 단축키 토글
----------------------------------------------------------------
local function RPGSkillTreeUI_onKeyPressed(key)
    if RPG_IsTypingInTextEntry() then
        return
    end

    if key == Keyboard.KEY_ESCAPE then
        if RPGSkillTreeUI.instance then
            RPGSkillTreeUI.instance:close()
        end
        return
    end

    -- Direct vault shortcut (default F10, customizable in Options > Key Bindings).
    -- Access is identical to clicking the learned vault node; a character with
    -- old stored items can still withdraw them after resetting the skill.
    if RPG_Keybinding.isVaultToggle(key) then
        local player=getSpecificPlayer(0)
        if not player or (player.isDead and player:isDead()) then return end
        local ok, ui=pcall(require,'RPG_Client_DimensionalVaultUI')
        if not ok or not ui then return end
        if ui.instance and ui.instance.player==player then
            ui.instance:onClose()
            return
        end
        local state=RPG_ClientState and RPG_ClientState.state
        local nodes=state and state.nodes or {}
        if Vault.limits(nodes).active or Vault.hasSavedItems(player) then
            ui.open(player)
        end
        return
    end

    if not RPG_Keybinding.isToggle(key) then
        return
    end

    local player = getSpecificPlayer(0)
    if not player then return end

    if RPGSkillTreeUI.instance then
        RPGSkillTreeUI.instance:close()
    else
        RPGSkillTreeUI.open(player)
    end
end

Events.OnKeyPressed.Add(RPGSkillTreeUI_onKeyPressed)
