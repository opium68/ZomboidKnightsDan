-- RPG Skill Tree / Random Box Odds (Build 42.21)
-- Read-only localized client window. Exact rates come from the SAME shared
-- probability pool as server-side Loot.roll(); no separate percentages.
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "RPG_Client_BoxAdminUI"
local Loot = require("RPG_Shared_RandomboxLoot")
local BoxChance = require("RPG_Shared_RandomboxChance")
local Catalog = require("RPG_Shared_BoxCatalog")

RPG_RandomboxOddsUI = ISPanel:derive("RPG_RandomboxOddsUI")
RPG_RandomboxOddsUI.instance = nil

local COLORS = {
    Normal = { 0.59, 0.78, 0.97 },
    Rare = { 0.76, 0.54, 1.00 },
    Legendary = { 1.00, 0.77, 0.33 },
    Mythic = { 1.00, 0.18, 0.25 },
}
local TIERS = { "Normal", "Rare", "Legendary", "Mythic" }
local DATA = { Normal = {}, Rare = {}, Legendary = {}, Mythic = {} }
local TOTALS = { Normal = 0, Rare = 0, Legendary = 0, Mythic = 0 }
local function distinctCount(entries)
    local n,seen=0,{}
    for _,entry in ipairs(entries or {}) do
        if not seen[entry.type] then seen[entry.type]=true;n=n+1 end
    end
    return n
end

local function tierOf(fullType)
    return Loot.getTier(fullType)
end
local currentBox='default'
local currentName=getText('UI_RPG_Status_MemoryStone')
local currentDrop=BoxChance.getRate()
-- Reserve an exclusive footer strip for pagination controls. The previous
-- 9-row layout painted its final reward rows underneath Prev/Next.
local function rewardsPerPage(height)
    local listTop, rowHeight = 251, 25
    local pagerTop = height - 128
    return math.max(1, math.floor((pagerTop - listTop) / rowHeight))
end
local function refreshData()
    DATA={Normal={},Rare={},Legendary={},Mythic={}}
    TOTALS={Normal=0,Rare=0,Legendary=0,Mythic=0}
    local boxes=RPG_BoxAdminUI and RPG_BoxAdminUI.catalog or nil
    if (not boxes or #boxes==0) and type(isMultiplayer)=='function' and not isMultiplayer() then
        boxes=Catalog.list()
    end
    local picked
    for _,box in ipairs(boxes or {}) do
        if box.id==currentBox then picked=box;break end
    end
    local entries=Loot.POOL
    currentName=getText('UI_RPG_Status_MemoryStone')
    currentDrop=BoxChance.getRate()
    if picked then
        entries={}
        currentName=getText('UI_RPG_Status_MemoryStone')
        currentDrop=tonumber(picked.drop) or currentDrop
        for _,entry in ipairs(picked.rewards or {}) do
            entries[#entries+1]={type=entry.type,count=entry.count or 1,chance=(tonumber(entry.chance) or 0)/100,tier=Catalog.rewardTier(entry)}
        end
    end
    for _,entry in ipairs(entries) do
        local tier=entry.tier or tierOf(entry.type)
        DATA[tier][#DATA[tier]+1]=entry
        TOTALS[tier]=TOTALS[tier]+entry.chance
    end
end
refreshData()

local function T(key, fallback)
    local value = getText and getText(key)
    if not value or value == key then return fallback end
    return value
end
local function itemName(fullType)
    if getItemNameFromFullType then
        local ok, name = pcall(getItemNameFromFullType, fullType)
        if ok and type(name) == "string" and name ~= "" and name ~= fullType then return name end
    end
    if getScriptManager then
        local ok, name = pcall(function()
            local it = getScriptManager():FindItem(fullType)
            return it and it:getDisplayName()
        end)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    return fullType:match("%.(.+)$") or fullType
end
local ICONS = {}
local function itemIcon(fullType)
    if ICONS[fullType] ~= nil then return ICONS[fullType] or nil end
    -- Use the EXISTING Mythic Elixir inventory icon, even when FindItem is
    -- temporarily unavailable while the random-box UI is being initialized.
    -- Do not cache a missed elixir texture: retry when assets finish loading.
    if fullType == 'RPGSkillTree.MythicElixir' and getTexture then
        local tex = getTexture('Item_RPGMythicElixir')
            or getTexture('media/textures/Item_RPGMythicElixir.png')
        if tex then ICONS[fullType] = tex; return tex end
    end
    local tex
    if getScriptManager and getTexture then
        local ok, icon = pcall(function()
            local it = getScriptManager():FindItem(fullType)
            return it and it:getIcon()
        end)
        if ok and type(icon) == "string" and icon ~= "" then
            tex = getTexture("Item_" .. icon)
        end
    end
    if tex or fullType~='RPGSkillTree.MythicElixir' then ICONS[fullType]=tex or false end
    return tex
end
local function labelFor(tier)
    -- The old BoxOdds_Tier_* translations include fixed 5/9/10 counts.
    -- Use the count-free rarity translations, so no stale count is appended.
    return T('UI_RPG_Rarity_'..tier, tier)
end
-- B42's getText formats translation placeholders immediately. Always pass
-- the replacement values in the getText call to avoid translation warnings.
local function fmtText(key, fallback, ...)
    if getText then
        local ok, value = pcall(getText, key, ...)
        if ok and type(value)=="string" and value~=key and value~="" then return value end
    end
    local ok, value = pcall(string.format, fallback, ...)
    return ok and value or fallback
end
local function tierCountLabel(tier)
    return fmtText('UI_RPG_BoxOdds_ItemCount','%s · %s items',
        labelFor(tier), tostring(distinctCount(DATA[tier])))
end

function RPG_RandomboxOddsUI:new()
    local core = getCore and getCore()
    local sw = core and core:getScreenWidth() or 1280
    local sh = core and core:getScreenHeight() or 720
    local w = math.max(390, math.min(690, sw-35))
    local h = math.max(375, math.min(582, sh-35))
    local o = ISPanel:new(math.max(0, (sw-w)/2), math.max(0, (sh-h)/2), w, h)
    setmetatable(o, self); self.__index = self
    o.backgroundColor = {r=0.038,g=0.052,b=0.085,a=0.985}
    o.borderColor = {r=0.66,g=0.51,b=0.24,a=1}
    o.moveWithMouse = true
    o.tier = "Normal"
    o.page = 1
    return o
end

function RPG_RandomboxOddsUI:createChildren()
    ISPanel.createChildren(self)
    self.closeButton = ISButton:new(self.width-112, self.height-48, 92, 30,
        T("UI_RPG_BoxOdds_Close", "Close"), self, RPG_RandomboxOddsUI.onClose)
    self.closeButton:initialise(); self.closeButton:instantiate()
    self:addChild(self.closeButton)
    self.closeButton.backgroundColor = {r=0.18,g=0.20,b=0.26,a=0.95}
    self.closeButton.borderColor = {r=0.68,g=0.56,b=0.37,a=0.7}
    -- Allow users to inspect ALL server-defined random boxes, not only the
    -- inventory box that opened this view. Read-only; opening a box still
    -- uses the actual item's immutable boxId on the server.
    self.boxChooser=ISComboBox:new(165,54,self.width-190,27,self,RPG_RandomboxOddsUI.onChooseBox)
    self.boxChooser:initialise();self.boxChooser:instantiate();self:addChild(self.boxChooser)
    self:refreshBoxChooser()
    -- Upper-right dismiss button, independent of the existing footer button.
    self.closeX = ISButton:new(self.width-46, 16, 29, 29, "X", self, RPG_RandomboxOddsUI.onClose)
    self.closeX:initialise(); self.closeX:instantiate(); self:addChild(self.closeX)
    self.closeX.backgroundColor = {r=0.68,g=0.08,b=0.10,a=0.98}
    self.closeX.borderColor = {r=1.0,g=0.38,b=0.40,a=1.0}
    self.closeX.textColor = {r=1.0,g=1.0,b=1.0,a=1.0}
    self.tabs = {}
    local left, gap = 20, 7
    local bw = math.floor((self.width-40-3*gap)/4)
    for i, tier in ipairs(TIERS) do
        local btn = ISButton:new(left+(i-1)*(bw+gap), 151, bw, 32,
            tierCountLabel(tier), self, RPG_RandomboxOddsUI.onTier)
        btn.internal = tier
        btn:initialise(); btn:instantiate(); self:addChild(btn)
        self.tabs[tier] = btn
    end
    self.prevPage = ISButton:new(22, self.height-128, 85, 27,
        'Prev', self, RPG_RandomboxOddsUI.onPrevPage)
    self.prevPage:initialise();self.prevPage:instantiate();self:addChild(self.prevPage)
    self.nextPage = ISButton:new(self.width-107, self.height-128, 85, 27,
        'Next', self, RPG_RandomboxOddsUI.onNextPage)
    self.nextPage:initialise();self.nextPage:instantiate();self:addChild(self.nextPage)
    self:refreshTabs()
end

function RPG_RandomboxOddsUI:refreshBoxChooser()
    if not self.boxChooser then return end
    local chooser=self.boxChooser
    chooser:clear()
    local boxes=RPG_BoxAdminUI and RPG_BoxAdminUI.catalog
    if (not boxes or #boxes==0) and type(isMultiplayer)=='function' and not isMultiplayer() then
        boxes=Catalog.list()
    end
    if not boxes or #boxes==0 then boxes={Catalog.defaultBox()} end
    local selected=1
    for i,box in ipairs(boxes) do
        chooser:addOptionWithData(tostring(box.name or box.id)..' ['..tostring(box.id)..']',box.id)
        if box.id==currentBox then selected=i end
    end
    chooser.selected=selected
end
function RPG_RandomboxOddsUI:onChooseBox(combo)
    local chooser=combo or self.boxChooser
    local id=chooser and chooser.getOptionData and chooser:getOptionData(chooser.selected)
    if not id or id==currentBox then return end
    currentBox=id
    refreshData()
    self.tier='Normal';self.page=1
    self:refreshTabs()
end

function RPG_RandomboxOddsUI:onPrevPage()
    self.page=math.max(1,(self.page or 1)-1)
end
function RPG_RandomboxOddsUI:onNextPage()
    self.page=math.min(math.max(1,math.ceil(#DATA[self.tier]/rewardsPerPage(self.height))),(self.page or 1)+1)
end

function RPG_RandomboxOddsUI:refreshTabs()
    for tier, btn in pairs(self.tabs or {}) do
        btn:setTitle(tierCountLabel(tier))
        local c = COLORS[tier]
        local active = self.tier == tier
        btn.backgroundColor = active and {r=c[1]*0.24,g=c[2]*0.24,b=c[3]*0.24,a=1}
            or {r=0.10,g=0.12,b=0.18,a=0.94}
        btn.borderColor = {r=c[1],g=c[2],b=c[3],a=active and 1 or 0.46}
    end
end
function RPG_RandomboxOddsUI:onTier(button)
    if button and COLORS[button.internal] then
        self.tier = button.internal
        self.page=1
        self:refreshTabs()
    end
end
function RPG_RandomboxOddsUI:onClose()
    self:removeFromUIManager()
    if RPG_RandomboxOddsUI.instance == self then RPG_RandomboxOddsUI.instance = nil end
end

local function draw(self, value, x, y, font, color)
    local c = color or {0.93,0.94,0.98}
    self:drawText(value, x, y, c[1], c[2], c[3], 1, font or UIFont.Small)
end
local function right(self, value, xRight, y, font, color)
    font = font or UIFont.Small
    local width = getTextManager():MeasureStringX(font, value)
    draw(self, value, xRight-width, y, font, color)
end

function RPG_RandomboxOddsUI:prerender()
    ISPanel.prerender(self)
    local w,h = self.width,self.height
    self:drawRect(0,0,w,7,1,0.69,0.48,0.19)
    draw(self,T("UI_RPG_BoxOdds_Title","RANDOM BOX / DROP RATES"),23,18,UIFont.Large,{1.0,0.82,0.50})
    draw(self,T("UI_RPG_BoxOdds_BoxSelect","Box"),24,59,UIFont.Small,{0.73,0.79,0.87})
    local rate = currentDrop
    draw(self,T("UI_RPG_BoxOdds_ZombieDrop","Zombie drop chance"),24,79,UIFont.Small,{0.72,0.79,0.86})
    right(self,string.format("%.2f%%",rate),w-25,79,UIFont.Small,{0.96,0.83,0.57})

    local totalWidth = w-48
    local barY = 114
    local bx = 24
    for _, tier in ipairs(TIERS) do
        local col = COLORS[tier]
        local bw = totalWidth*TOTALS[tier]
        self:drawRect(bx,barY,math.max(0,bw),11,0.98,col[1],col[2],col[3])
        bx = bx+bw
    end
    self:drawRectBorder(24,barY,totalWidth,11,0.85,0.5,0.53,0.61)
    draw(self,tierCountLabel('Normal')..'  |  '..tierCountLabel('Rare')..'  |  '..tierCountLabel('Legendary')..'  |  '..tierCountLabel('Mythic'),
        24,130,UIFont.Small,{0.83,0.89,0.94})
    local tier=self.tier
    local accent=COLORS[tier]
    self:drawRect(20,194,w-40,45,0.89,0.095,0.12,0.19)
    self:drawRect(20,194,4,45,1,accent[1],accent[2],accent[3])
    draw(self,labelFor(tier),36,201,UIFont.Medium,accent)
    right(self,string.format("%.5f%%",TOTALS[tier]*100),w-35,205,UIFont.Medium,accent)

    local entries = DATA[tier]
    local top, rowH = 251, 25
    local perPage = rewardsPerPage(h)
    local pagerY = h - 128
    -- Move header labels slightly downward and give them their own strip so
    -- tall Korean glyphs are never clipped.
    self:drawRect(20,238,w-40,18,1,0.038,0.052,0.085)
    draw(self,T("UI_RPG_BoxOdds_ColumnItem","Item"),43,244,UIFont.Small,{0.56,0.64,0.74})
    right(self,T("UI_RPG_BoxOdds_ColumnChance","Chance"),w-36,244,UIFont.Small,{0.56,0.64,0.74})
    local pages=math.max(1,math.ceil(#entries/perPage))
    self.page=math.max(1,math.min(self.page or 1,pages))
    local startIndex=(self.page-1)*perPage+1
    local endIndex=math.min(#entries,self.page*perPage)
    -- Entire pager is rendered on its own opaque strip, below the last row.
    self:drawRect(20,pagerY-2,w-40,32,1,0.038,0.052,0.085)
    draw(self,string.format('Page %d / %d',self.page,pages),self.width/2-43,pagerY+4,UIFont.Small,{0.78,0.81,0.87})
    for index=startIndex,endIndex do
        local entry=entries[index]
        local y=top+(index-startIndex)*rowH+4
        -- Opaque alternating rows avoid text remnants in all theme variants.
        if (index-startIndex)%2==1 then
            self:drawRect(25,y-3,w-50,rowH,1,0.07,0.09,0.14)
        else
            self:drawRect(25,y-3,w-50,rowH,1,0.038,0.052,0.085)
        end
        local icon=itemIcon(entry.type)
        if icon then
            self:drawTextureScaledAspect(icon,34,y-2,21,21,1,1,1,1)
        else
            self:drawRect(37,y,14,14,1,accent[1],accent[2],accent[3])
        end
        draw(self,itemName(entry.type)..((entry.count or 1)>1 and (' x'..entry.count) or ''),65,y,UIFont.Small,{0.90,0.93,0.97})
        right(self,string.format("%.5f%%",entry.chance*100),w-37,y,UIFont.Small,accent)
    end
    if self.prevPage then self.prevPage.enable=self.page>1 end
    if self.nextPage then self.nextPage.enable=self.page<pages end
    self:drawRect(20,h-87,w-40,1,0.58,0.57,0.57,0.64)
    draw(self,T("UI_RPG_BoxOdds_Note","Odds per opened box. All displayed rewards are actual items."),24,h-77,UIFont.Small,{0.71,0.79,0.87})
end

function RPG_RandomboxOddsUI.Open(boxId)
    currentBox=tostring(boxId or 'default')
    refreshData()
    local win=RPG_RandomboxOddsUI.instance
    if win then
        win.tier='Normal'
        win.page=1
        win:refreshBoxChooser()
        win:refreshTabs()
        win:bringToTop()
        return win
    end
    win=RPG_RandomboxOddsUI:new()
    win:initialise(); win:createChildren()
    win:addToUIManager(); win:bringToTop()
    RPG_RandomboxOddsUI.instance=win
    return win
end
Events.OnServerCommand.Add(function(module,cmd,args)
    if module=='RPGSkillTree' and cmd=='BoxAdminData' then
        -- BoxAdminUI has already normalized the server packet (including
        -- string-numbered list entries). Never overwrite its catalog with
        -- an unnormalized raw packet: that can hide every editor box.
        if type(args)=='table' and type(args.boxes)=='table' then
            refreshData()
            if RPG_RandomboxOddsUI.instance then
                RPG_RandomboxOddsUI.instance:refreshBoxChooser()
                RPG_RandomboxOddsUI.instance:refreshTabs()
            end
        end
    end
end)
Events.OnGameStart.Add(function() RPG_RandomboxOddsUI.instance=nil end)
return RPG_RandomboxOddsUI

-- RCE: ember forging presentation, legacy physical IDs retained.
