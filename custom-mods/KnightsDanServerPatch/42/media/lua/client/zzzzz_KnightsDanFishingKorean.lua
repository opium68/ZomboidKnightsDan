-- B42's AtomUIText uses a Latin SDF atlas and substitutes '?' for Hangul.
-- Render only fishing-panel text through the game's Korean bitmap font.
require "PZAPI/ui/organisms/FishWindow"
local UI = PZAPI.UI

local function inFishing(node)
    local current = node
    while current do
        if current.knightsFishingWindow then return true end
        current = current.parent
    end
    local parent = node.parent
    return parent and parent.fish and parent.width == 316 and
        parent.children and parent.children.text == node
end

local function lines(text)
    local result = {}
    text = tostring(text or ""):gsub("<[bB][rR]%s*/?>", "\n")
    for line in (text .. "\n"):gmatch("(.-)\n") do result[#result + 1] = line end
    return result
end

local function patch(node)
    if node.knightsFishingText or node._ATOM_UI_CLASS ~= AtomUIText or not inFishing(node) then return end
    node.knightsFishingText = true
    node.knightsText = node.text or ""
    node.text = ""
    node.setText = function(self, text)
        self.knightsText = text or ""
        -- Empty native text prevents the SDF renderer from emitting '?' glyphs.
        if self.javaObj then self.javaObj:setText("") end
    end
    local oldRender = node.renderUpdate
    node.renderUpdate = function(self)
        if oldRender then oldRender(self) end
        local tm = getTextManager()
        local position = self.javaObj:getLuaAbsolutePosition(0, 0)
        local unit = self.javaObj:getLuaAbsolutePosition(1, 0)
        local scale = math.abs(unit.x - position.x) *
            tm:getFontHeight(UIFont.SdfRegular) / tm:getFontHeight(UIFont.Medium)
        local rows = lines(self.knightsText)
        local widest = 0
        for _, row in ipairs(rows) do widest = math.max(widest, tm:MeasureStringX(UIFont.Medium, row)) end
        local height = tm:getFontHeight(UIFont.Medium)
        local x = position.x - (self.pivotX or 0) * widest * scale
        local y = position.y - (self.pivotY or 0) * #rows * height * scale
        for i, row in ipairs(rows) do
            tm:DrawString(UIFont.Medium, x, y + (i - 1) * height * scale,
                scale, row, self.r or 1, self.g or 1, self.b or 1, self.a or 1)
        end
    end
    -- The tooltip's native height calculation uses the now-empty SDF text.
    if node.parent and node.parent.fish then
        local function sizeTooltip(self)
            local tm = getTextManager()
            local height = #lines(self.knightsText) * tm:getFontHeight(UIFont.SdfRegular)
            self.parent:setHeight(height * (self.scaleY or 0.5) + 16)
        end
        local oldInit, oldUpdate = node.init, node.update
        node.init = function(self) if oldInit then oldInit(self) end; sizeTooltip(self) end
        node.update = function(self) if oldUpdate then oldUpdate(self) end; sizeTooltip(self) end
    end
end

local function install()
    if UI.knightsFishingKoreanInstalled then return end
    local language = Translator.getLanguage()
    if language:name() ~= "KO" then return end
    UI.knightsFishingKoreanInstalled = true
    UI.FishWindow.knightsFishingWindow = true
    local original = UI._applyHooks
    UI._applyHooks = function(node)
        patch(node)
        original(node)
    end
end

Events.OnGameStart.Add(install)
