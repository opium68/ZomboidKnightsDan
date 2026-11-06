-- RPG Skill Tree / Random Box Cinematic Reveal (Build 42.21)
-- Draw-only client overlay. Never creates/removes inventory items or rolls rewards.
require "ISUI/ISPanel"
require "ISUI/ISButton"
local RandomboxLoot = require("RPG_Shared_RandomboxLoot")
local ModAudio = require("RPG_Client_ModAudio")

RPG_RandomboxRevealUI = ISPanel:derive("RPG_RandomboxRevealUI")
RPG_RandomboxRevealUI.instance = nil
RPG_RandomboxRevealUI.pending = {}
RPG_RandomboxRevealUI.queue = {}
RPG_RandomboxRevealUI.requestCounter = 0

local MODULE = "RPGSkillTree"
local function now()
    if getTimestampMs then return getTimestampMs() end
    return (os.clock and os.clock() * 1000) or 0
end
local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function tr(key, fallback)
    local text = getText and getText(key)
    if not text or text == key then return fallback end
    return text
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
local function continueLabel(count)
    return fmtText('UI_RPG_Reveal_Continue','CONTINUE (x%s)',
        tostring(math.max(0,math.floor(tonumber(count) or 0))))
end
local function play(name)
    ModAudio.play(name)
end
local TIERS = {
    Normal = { color={0.60,0.75,0.89}, glow="RPG_RevealGlow_Common.png", title="COMMON", ms=2500 },
    Rare = { color={0.68,0.48,1.0}, glow="RPG_RevealGlow_Rare.png", title="RARE", ms=3350 },
    Legendary = { color={1.0,0.74,0.25}, glow="RPG_RevealGlow_Legendary.png", title="LEGENDARY", ms=4300 },
    Mythic = { color={1.0,0.18,0.25}, glow="RPG_RevealGlow_Mythic.png", title="MYTHIC", ms=5200 },
}
-- Reel candidates come from the server's actual reward catalog, but their
-- *display frequency* is cinematic. The server determines the real prize.
-- Reel slot 18 is the actual awarded item; slots 19-21 are cosmetic trailing previews.
local PREVIEWS = RandomboxLoot.getPreviewItems()
local TEXTURE_BASE = "media/ui/RPGSkillTree/"
local ICON_FALLBACK = getTexture and getTexture(TEXTURE_BASE .. "RPG_Box.png") or nil
local GLOWS = {}
local awardTierOverrides = {}
local function glowFor(tier)
    if not getTexture then return nil end
    local name = (TIERS[tier] or TIERS.Normal).glow
    if not GLOWS[name] then GLOWS[name] = getTexture(TEXTURE_BASE .. name) end
    return GLOWS[name]
end
local function itemTier(fullType)
    return awardTierOverrides[fullType] or RandomboxLoot.getTier(fullType)
end
local function scriptItem(fullType)
    if not getScriptManager then return nil end
    local ok, it = pcall(function() return getScriptManager():FindItem(fullType) end)
    return ok and it or nil
end
local function itemName(fullType)
    if getItemNameFromFullType then
        local ok, name = pcall(getItemNameFromFullType, fullType)
        if ok and type(name) == "string" and name ~= "" and name ~= fullType then
            return name
        end
    end
    local it = scriptItem(fullType)
    if it then
        local ok, name = pcall(function() return it:getDisplayName() end)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    local base = tostring(fullType or "Unknown"):match("%.(.+)$") or tostring(fullType or "Unknown")
    return base:gsub("_", " ")
end
local ICON_CACHE = {}
local function itemTexture(fullType)
    if ICON_CACHE[fullType] ~= nil then return ICON_CACHE[fullType] or nil end
    -- Resolve the original elixir texture directly; this is the same icon
    -- registered in RPG_GrowthElixirs.txt, not a replacement illustration.
    if fullType == 'RPGSkillTree.MythicElixir' and getTexture then
        local tex = getTexture('Item_RPGMythicElixir')
            or getTexture('media/textures/Item_RPGMythicElixir.png')
        if tex then ICON_CACHE[fullType] = tex; return tex end
    end
    local it = scriptItem(fullType)
    local texture = nil
    if it and getTexture then
        local ok, icon = pcall(function() return it:getIcon() end)
        if ok and type(icon) == "string" and icon ~= "" then
            texture = getTexture("Item_" .. icon)
        end
    end
    if texture or fullType~='RPGSkillTree.MythicElixir' then ICON_CACHE[fullType]=texture or false end
    return texture
end
local function dominantReward(rewards)
    local rank = { Normal=1, Rare=2, Legendary=3, Mythic=4 }
    local best, bestRank = nil, 0
    for _,fullType in ipairs(rewards) do
        local r = rank[itemTier(fullType)] or 1
        if r > bestRank then best,bestRank = fullType,r end
    end
    return best or "", bestRank
end
local function displayCounts(rewards)
    local result, keys = {}, {}
    for _,item in ipairs(rewards) do
        if not result[item] then result[item] = 0; keys[#keys+1] = item end
        result[item] = result[item] + 1
    end
    table.sort(keys, function(a,b)
        local priority={Normal=1,Rare=2,Legendary=3,Mythic=4}
        local ap,bp=priority[itemTier(a)] or 1,priority[itemTier(b)] or 1
        if ap~=bp then return ap>bp end
        return a < b
    end)
    return result, keys
end
local function safeResults(args)
    local result = {}
    if type(args.rewards) ~= "table" then return result end
    for i=1,math.min(#args.rewards,2000) do
        local s = args.rewards[i]
        if type(s)=="string" and #s<130 then result[#result+1]=s end
    end
    return result
end
local function createSequence(poolTier,winner,winnerTier,requestId,serverEntries,serverCandidates)
    local pool={}
    if type(serverEntries)=='table' then
        for i=1,math.min(#serverEntries,80) do
            local row=serverEntries[i]
            if type(row)=='table' and type(row.type)=='string' and #row.type<130 then
                local rarity=(row.tier=='Normal' or row.tier=='Rare' or row.tier=='Legendary' or row.tier=='Mythic') and row.tier or itemTier(row.type)
                local chance=tonumber(row.chance) or 0
                if chance>0 and chance<=100 then
                    pool[#pool+1]={type=row.type,tier=rarity,chance=chance}
                end
            end
        end
    end
    -- Old servers send only the candidate IDs. No phantom item IDs are used.
    if #pool==0 then
        local legacy=type(serverCandidates)=='table' and #serverCandidates>0 and serverCandidates or PREVIEWS
        for _,ft in ipairs(legacy) do
            if type(ft)=='string' then pool[#pool+1]={type=ft,tier=itemTier(ft),chance=1} end
        end
    end
    -- A sparse/legacy server can omit preview entries. Still build a
    -- complete reel around its authoritative prize instead of a single card.
    if #pool==0 then pool[1]={type=winner,tier=winnerTier,chance=1} end

    -- Cosmetic reel: 17 previews, server-confirmed prize at slot 18,
    -- and 3 trailing previews. The pointer still stops on slot 18.
    -- Tail cards cannot affect server grants, reward odds, or the stop target.
    local seed=1
    local id=tostring(requestId or '')
    for i=1,#id do seed=(seed*31+string.byte(id,i))%2147483647 end
    local function rand()
        seed=(seed*16807+17)%2147483647
        return seed/2147483647
    end
    local groups={Normal={},Rare={},Legendary={},Mythic={}}
    local sums={Normal=0,Rare=0,Legendary=0,Mythic=0}
    for _,row in ipairs(pool) do
        local tier=groups[row.tier] and row.tier or 'Normal'
        groups[tier][#groups[tier]+1]=row
        sums[tier]=sums[tier]+row.chance
    end
    local order={'Normal','Rare','Legendary','Mythic'}
    -- 8 common, 4 rare, 3 legendary, 2 mythic visual slots, when available.
    -- A custom box with no reward of a tier will not display that tier.
    local desired={Normal=8,Rare=4,Legendary=3,Mythic=2}
    local tierSlots={}
    local extras=0
    local available={}
    for _,tier in ipairs(order) do
        if #groups[tier]>0 then
            available[#available+1]=tier
            for _=1,desired[tier] do tierSlots[#tierSlots+1]=tier end
        else
            extras=extras+desired[tier]
        end
    end
    for i=1,extras do
        tierSlots[#tierSlots+1]=available[((i-1)%#available)+1]
    end
    -- Vary the order between openings; keep the quantity of rare visuals.
    for i=#tierSlots,2,-1 do
        local j=1+math.floor(rand()*i)
        tierSlots[i],tierSlots[j]=tierSlots[j],tierSlots[i]
    end
    -- A higher-rarity prize can visibly slip past the pointer just before
    -- the *real* reward stops. This affects only which previews are shown.
    local nearTiers={}
    for _,tier in ipairs({'Rare','Legendary','Mythic'}) do
        if #groups[tier]>0 then nearTiers[#nearTiers+1]=tier end
    end
    if #nearTiers>0 then
        local nearTier=nearTiers[1+math.floor(rand()*#nearTiers)]
        for i=1,17 do
            if tierSlots[i]==nearTier then
                tierSlots[i],tierSlots[17]=tierSlots[17],tierSlots[i]
                break
            end
        end
        -- A second high-rarity flash in the approach, where available.
        local secondTier=nil
        if nearTier~='Mythic' and #groups.Mythic>0 then secondTier='Mythic'
        elseif nearTier~='Legendary' and #groups.Legendary>0 then secondTier='Legendary'
        elseif nearTier~='Rare' and #groups.Rare>0 then secondTier='Rare' end
        if secondTier then
            for i=1,16 do
                if tierSlots[i]==secondTier then
                    tierSlots[i],tierSlots[16]=tierSlots[16],tierSlots[i]
                    break
                end
            end
        end
    end
    local seq={}
    for i=1,17 do
        local tier=tierSlots[i]
        local bucket=groups[tier]
        local roll=rand()*sums[tier]
        local cumulative=0
        local chosen=bucket[#bucket]
        for _,row in ipairs(bucket) do
            cumulative=cumulative+row.chance
            if roll<cumulative then chosen=row;break end
        end
        seq[i]={type=chosen.type,tier=chosen.tier}
    end
    -- The reel ALWAYS stops on the actual server-authoritative result.
    seq[18]={type=winner,tier=winnerTier}

    -- The next three items remain visible to the right of the winner,
    -- preventing the reel from looking like it simply ran out of cards.
    -- Only use entries really present in this box's preview catalog.
    local trailingTiers={}
    for _,tier in ipairs({'Mythic','Legendary','Rare'}) do
        if #groups[tier]>0 then trailingTiers[#trailingTiers+1]=tier end
    end
    while #trailingTiers<3 do
        trailingTiers[#trailingTiers+1]=available[1+math.floor(rand()*#available)]
    end
    for i=#trailingTiers,2,-1 do
        local j=1+math.floor(rand()*i)
        trailingTiers[i],trailingTiers[j]=trailingTiers[j],trailingTiers[i]
    end
    for i=1,3 do
        local tier=trailingTiers[i]
        local bucket=groups[tier]
        local roll=rand()*sums[tier]
        local cumulative=0
        local chosen=bucket[#bucket]
        for _,row in ipairs(bucket) do
            cumulative=cumulative+row.chance
            if roll<cumulative then chosen=row; break end
        end
        seq[18+i]={type=chosen.type,tier=chosen.tier}
    end
    return seq
end

function RPG_RandomboxRevealUI:new()
    local core = getCore and getCore()
    local sw,sh=core and core:getScreenWidth() or 1280, core and core:getScreenHeight() or 720
    local o = ISPanel:new(0,0,sw,sh)
    setmetatable(o,self); self.__index=self
    o.backgroundColor={r=0,g=0,b=0,a=0}
    o.borderColor={r=0,g=0,b=0,a=0}
    o.moveWithMouse=false
    o.stage="waiting"
    o.began=now()
    o.revealAt=0
    o.lastTick=-1
    o.rolling=0
    o.reward=""
    o.rewardTier="Normal"
    o.rewards={}
    o.opened=0
    o.boxTier="Normal"
    o.requestId=""
    o.boxType="RPGSkillTree.Randombox_Normal"
    o.remainingNormal=0
    o.remainingRare=0
    o.remainingLegendary=0
    o.remainingTotal=0
    o.awaitingResult=false
    o.itemCounts={}
    o.itemKeys={}
    o.sequence={}
    return o
end
function RPG_RandomboxRevealUI:createChildren()
    ISPanel.createChildren(self)
    -- Keep this full-screen cinematic as one paint/input layer: the game draws
    -- ISButton children beneath the custom render() foreground on some B42 UIs.
    -- Instead paint our two controls LAST and hit-test their exact rectangles.
    local w=math.min(900,self.width-30)
    local h=math.min(565,self.height-30)
    self.cx,self.cy,self.pw,self.ph=(self.width-w)/2,(self.height-h)/2,w,h
end
local function hitRect(x,y,rx,ry,rw,rh)
    return x>=rx and x<rx+rw and y>=ry and y<ry+rh
end
function RPG_RandomboxRevealUI:buttonRects()
    local X,Y,W,H=self.cx,self.cy,self.pw,self.ph
    return X+W-48,Y+18,30,29,X+(W-248)/2,Y+H-62,248,38
end

function RPG_RandomboxRevealUI:present(tier,count,requestId)
    self.requestId=requestId or ""
    self.boxTier=TIERS[tier] and tier or "Normal"
    self.waitCount=count or 1
    self.stage="waiting"
    self.began=now()
end
function RPG_RandomboxRevealUI:accept(payload)
    self.requestId=tostring(payload.requestId or self.requestId or "")
    self.boxType=tostring(payload.boxType or self.boxType or "RPGSkillTree.Randombox_Normal")
    self.boxId=tostring(payload.boxId or "default")
    -- Server-authoritative count; no speculative client subtraction in MP.
    self.remainingNormal=clamp(math.floor(tonumber(payload.remainingNormal) or 0),0,999999)
    self.remainingRare=clamp(math.floor(tonumber(payload.remainingRare) or 0),0,999999)
    self.remainingLegendary=clamp(math.floor(tonumber(payload.remainingLegendary) or 0),0,999999)
    self.remainingTotal=clamp(math.floor(tonumber(payload.remainingMatching) or 0),0,999999)
    self.awaitingResult=false
    self.boxTier=TIERS[payload.tier] and payload.tier or "Normal"
    self.summaryPage=1; self.showSummary=false
    self.opened=clamp(math.floor(tonumber(payload.opened) or 0),0,200)
    self.rewards=safeResults(payload)
    -- Custom box rarity is assigned by the admin, not guessed from item name.
    -- Legacy servers without rewardTiers retain original item-name inference.
    awardTierOverrides={}
    if type(payload.rewardTiers)=='table' then
        local order={Normal=1,Rare=2,Legendary=3,Mythic=4}
        for i,ft in ipairs(self.rewards) do
            local tier=payload.rewardTiers[i]
            if order[tier] and order[tier]>(order[awardTierOverrides[ft]] or 0) then
                awardTierOverrides[ft]=tier
            end
        end
    end
    self.itemCounts,self.itemKeys=displayCounts(self.rewards)
    -- Keep each awarded (type,tier) pair: the same vanilla axe can legitimately
    -- be Normal in one box and Legendary in another.
    self.reward='';self.rewardTier='Normal'
    local rank={Normal=1,Rare=2,Legendary=3,Mythic=4}
    local highest=0
    for i,ft in ipairs(self.rewards) do
        local tier=type(payload.rewardTiers)=='table' and payload.rewardTiers[i] or nil
        if not rank[tier] then tier=itemTier(ft) end
        if rank[tier]>highest then
            self.reward=ft;self.rewardTier=tier;highest=rank[tier]
        end
    end
    self.boxTier=self.rewardTier
    if self.opened<=0 or self.reward=="" then
        self.stage="empty"; self.revealAt=now()
    else
        self.sequence=createSequence(self.boxTier,self.reward,self.rewardTier,self.requestId,payload.previewEntries,payload.previewItems)
        self.stage="rolling"; self.began=now(); self.lastTick=-1
        play("RPG_BoxStart")
    end
end
function RPG_RandomboxRevealUI:finish()
    if self.stage=="rolling" then
        self.stage="reveal"; self.revealAt=now()
        local tier=self.rewardTier
        if tier=="Mythic" then play("RPG_BoxMythic")
        elseif tier=="Legendary" then play("RPG_BoxLegendary")
        elseif tier=="Rare" then play("RPG_BoxRare")
        else play("RPG_BoxCommon") end
    end
end
function RPG_RandomboxRevealUI:onCloseX()
    -- X cancels only the display; server-side item grants already completed.
    -- If a continuation response arrives later, do not reopen this screen.
    if self.stage=="waiting" and self.requestId~="" then
        RPG_RandomboxRevealUI.pending[self.requestId]=nil
    end
    self:removeFromUIManager()
    if RPG_RandomboxRevealUI.instance==self then RPG_RandomboxRevealUI.instance=nil end
    RPG_RandomboxRevealUI.showNext()
end
-- Continuation opens exactly ONE additional box. The server consumes/rolls
-- it using the same RandomboxOpen handler as the inventory context menu.
-- Never roll or add any item from the UI.
local function currentInventoryCount(self)
    local player=(getPlayer and getPlayer()) or (getSpecificPlayer and getSpecificPlayer(0))
    local inv=player and player.getInventory and player:getInventory()
    local items=inv and inv.getItems and inv:getItems()
    if not items then return 0 end
    local boxes=0
    local id=self.boxId or 'default'
    for i=0,items:size()-1 do
        local it=items:get(i)
        local ft=it and it.getFullType and it:getFullType()
        if ft=='RPGSkillTree.Randombox_Normal' or ft=='RPGSkillTree.Randombox_Rare' or ft=='RPGSkillTree.Randombox_Legendary' then
            local itemId=(it.getModData and it:getModData().rpgBoxId) or 'default'
            if type(itemId)~='string' or itemId=='' then itemId='default' end
            if itemId==id then boxes=boxes+1 end
        end
    end
    return boxes
end
local function nextBoxType(self)
    local types={
        {"RPGSkillTree.Randombox_Normal",self.remainingNormal},
        {"RPGSkillTree.Randombox_Rare",self.remainingRare},
        {"RPGSkillTree.Randombox_Legendary",self.remainingLegendary},
    }
    for _,entry in ipairs(types) do
        if entry[1]==self.boxType and entry[2]>0 then return entry[1] end
    end
    for _,entry in ipairs(types) do
        if entry[2]>0 then return entry[1] end
    end
    return nil
end
function RPG_RandomboxRevealUI:onContinue()
    if self.stage~="reveal" and self.stage~="empty" then return end
    if self.awaitingResult then return end
    -- The player may have moved boxes since the last server reply.
    -- The server still verifies and consumes an actual matching box.
    self.remainingTotal=currentInventoryCount(self)
    if self.remainingTotal<=0 then return end
    local boxType=self.boxId and self.boxId~="default" and self.boxType or nextBoxType(self)
    if not boxType then return end
    local player=(getPlayer and getPlayer()) or (getSpecificPlayer and getSpecificPlayer(0))
    if not player or (player.isDead and player:isDead()) then return end
    local single=isMultiplayer and not isMultiplayer()
    if single and type(RPG_SP_OpenRandombox)~="function" then return end
    if not single and type(sendClientCommand)~="function" then return end
    local id=RPG_RandomboxRevealUI.BeginRequest("Normal",1)
    self.requestId=id
    self.stage="waiting"
    self.awaitingResult=true
    self.began=now()
    self.lastTick=-1
    self.waitCount=1
    self.showSummary=false
    self.summaryPage=1
    local args={boxType=boxType,boxId=self.boxId or "default",tier="Normal",count=1,requestId=id}
    -- Set waiting before dispatch: SP can synchronously reply in this call.
    if single then RPG_SP_OpenRandombox(player,args)
    else sendClientCommand(player,MODULE,"RandomboxOpen",args) end
end
function RPG_RandomboxRevealUI.onSkip(self)
    if self.stage=="rolling" then self:finish(); return end
    if self.stage=="reveal" or self.stage=="empty" then self:onContinue() end
end
function RPG_RandomboxRevealUI:onMouseDown(x,y)
    local closeX,closeY,closeW,closeH,skipX,skipY,skipW,skipH=self:buttonRects()
    -- Clicks work in exactly the same rectangle drawn by render().
    if hitRect(x,y,closeX,closeY,closeW,closeH) then
        self:onCloseX()
        return true
    end
    if hitRect(x,y,skipX,skipY,skipW,skipH) then
        if self.stage=="rolling" or self.stage=="reveal" or self.stage=="empty" then
            self:onSkip()
        end
        return true
    end
    if self.stage=="reveal" and #self.rewards>1 then
        local X,Y,W,H=self.cx,self.cy,self.pw,self.ph
        if y>=Y+H-75 and y<Y+H-28 and x<X+W-188 then
            self.showSummary=not self.showSummary
            self.summaryPage=1
            play("RPG_BoxTick")
            return true
        end
        if self.showSummary and y>=Y+H-133 and y<Y+H-99 then
            local pages=math.max(1,math.ceil(#self.itemKeys/10))
            if x<X+W/2 then self.summaryPage=math.max(1,self.summaryPage-1)
            else self.summaryPage=math.min(pages,self.summaryPage+1) end
            return true
        end
    end
    return ISPanel.onMouseDown(self,x,y)
end
local function txt(self,str,x,y,font,color)
    local c=color or {1,1,1}
    self:drawText(str,x,y,c[1],c[2],c[3],1,font or UIFont.Small)
end
local function centered(self,str,y,font,color)
    local tm=getTextManager()
    local tw=tm:MeasureStringX(font or UIFont.Medium,str)
    txt(self,str,(self.width-tw)/2,y,font,color)
end
local function trimText(str,max)
    str=tostring(str or "")
    if #str>max then return str:sub(1,max-3).."..." end
    return str
end
function RPG_RandomboxRevealUI:drawCard(entry,x,y,w,h,selected,alpha)
    local fullType=type(entry)=='table' and entry.type or entry
    local rarity=type(entry)=='table' and entry.tier or itemTier(fullType)
    if not TIERS[rarity] then rarity=itemTier(fullType) end
    local c=(TIERS[rarity] or TIERS.Normal).color
    alpha=alpha or 1
    self:drawRect(x,y,w,h,alpha*0.92,0.075,0.09,0.15)
    self:drawRect(x+3,y+3,w-6,h-6,alpha*0.36,c[1],c[2],c[3])
    self:drawRect(x+6,y+6,w-12,h-12,alpha*0.93,0.06,0.075,0.115)
    self:drawRectBorder(x,y,w,h,alpha*(selected and 1 or 0.7),c[1],c[2],c[3])
    local texture=itemTexture(fullType) or ICON_FALLBACK
    if texture then
        local sz=math.min(73,h-60)
        self:drawTextureScaled(texture,x+(w-sz)/2,y+20,sz,sz,alpha,1,1,1)
    end
    local name=trimText(itemName(fullType),18)
    local tm=getTextManager()
    local tw=tm:MeasureStringX(UIFont.Small,name)
    txt(self,name,x+(w-tw)/2,y+h-41,UIFont.Small,{0.94,0.94,0.96})
    local title=tr("UI_RPG_Rarity_" .. rarity, (TIERS[rarity] or TIERS.Normal).title)
    local ww=tm:MeasureStringX(UIFont.Small,title)
    txt(self,title,x+(w-ww)/2,y+h-23,UIFont.Small,c)
end
function RPG_RandomboxRevealUI:drawParticles(time,tier)
    local c=(TIERS[tier] or TIERS.Normal).color
    local X,Y,W,H=self.cx,self.cy,self.pw,self.ph
    for i=1,50 do
        local fx=((i*97)%1000)/1000
        local fy=((i*59)%991)/991
        local phase=(i*13.7+time*0.00017*(0.6+i%4))
        local dy=(fy+phase%1)%1
        local px=X+24+fx*(W-48)
        local py=Y+35+dy*(H-76)
        local a=0.16+0.45*math.abs(math.sin(phase*2.15))
        self:drawRect(px,py,(i%5==0) and 3 or 2,(i%5==0) and 3 or 2,a,c[1],c[2],c[3])
    end
end
function RPG_RandomboxRevealUI:render()
    local core=getCore and getCore()
    if core and (self.width~=core:getScreenWidth() or self.height~=core:getScreenHeight()) then
        self:setWidth(core:getScreenWidth());self:setHeight(core:getScreenHeight())
        local w=math.min(900,self.width-30);local h=math.min(565,self.height-30)
        self.cx,self.cy,self.pw,self.ph=(self.width-w)/2,(self.height-h)/2,w,h
    end
    ISPanel.render(self)
    local t=now()
    self:drawRect(0,0,self.width,self.height,0.91,0.007,0.012,0.030)
    local X,Y,W,H=self.cx,self.cy,self.pw,self.ph
    for i=0,3 do self:drawRect(X-i*2,Y-i*2,W+i*4,H+i*4,0.045,0.9,0.66,0.25) end
    self:drawRect(X,Y,W,H,0.98,0.034,0.044,0.079)
    self:drawRectBorder(X,Y,W,H,0.9,0.60,0.51,0.32)
    self:drawRect(X+12,Y+12,W-24,44,0.94,0.088,0.10,0.15)
    self:drawRect(X+12,Y+57,W-24,2,0.63,0.75,0.59,0.30)
    local color=(TIERS[self.boxTier] or TIERS.Normal).color
    centered(self,tr("UI_RPG_Reveal_Title","FATE'S TREASURE"),Y+22,UIFont.Large,{1,0.84,0.54})
    local typeName=tr("UI_RPG_Reveal_Box_Unified","RANDOM BOX")
    centered(self,typeName,Y+72,UIFont.Medium,color)
    if self.stage=="waiting" then
        local timer=t-self.began
        centered(self,tr("UI_RPG_Reveal_Wait","The box is opening..."),Y+240,UIFont.Large,{0.9,0.9,0.92})
        local phase=timer*0.005
        for i=1,12 do
            local a=(i/12)*math.pi*2+phase
            self:drawRect(X+W/2+math.cos(a)*90,Y+315+math.sin(a)*35,6,6,0.35+0.5*i/12,color[1],color[2],color[3])
        end
        if timer>12000 then
            if self.awaitingResult then
                centered(self,tr("UI_RPG_Reveal_ServerDelay","Waiting for server response..."),Y+370,UIFont.Small,{0.85,0.76,0.61})
            else
                self.stage="empty";self.revealAt=t
            end
        end
    elseif self.stage=="rolling" then
        -- Use the shortened duration for BOTH the reel and its gauge.
        -- Previously the UI ended 300ms early but its progress only reached
        -- (duration-300)/duration, so it looked unfinished.
        local duration=(TIERS[self.boxTier] or TIERS.Normal).ms-300
        local elapsed=t-self.began
        local progress=clamp(elapsed/duration,0,1)
        -- smooth quintic ease-out: rapid initial movement and dramatic final deceleration
        local ease=1-(1-progress)^5
        local position=17*ease
        if math.floor(position)~=self.lastTick then
            if self.lastTick>=0 then play("RPG_BoxTick") end
            self.lastTick=math.floor(position)
        end
        local glow=glowFor(self.boxTier)
        if glow then self:drawTextureScaled(glow,X+W/2-228,Y+90,456,360,0.5,1,1,1) end
        self:drawRect(X+18,Y+138,W-36,196,0.92,0.016,0.020,0.043)
        self:drawRectBorder(X+18,Y+138,W-36,196,0.6,color[1],color[2],color[3])
        local space=150
        for i=1,#self.sequence do
            local cx=X+W/2 + (i-1-position)*space
            local px=cx-62
            if px>=X+24 and px+124<=X+W-24 then
                self:drawCard(self.sequence[i],px,Y+158,124,158,math.abs(i-1-position)<0.6,1)
            end
        end
        self:drawRect(X+W/2-2,Y+126,4,24,0.95,1,0.84,0.38)
        self:drawRect(X+W/2-2,Y+328,4,18,0.95,1,0.84,0.38)
        self:drawRect(X+W/2-4,Y+149,8,168,0.17,1,0.82,0.28)
        centered(self,tr("UI_RPG_Reveal_Rolling","DESTINY IS DECIDING..."),Y+365,UIFont.Medium,{1,0.86,0.60})
        local bw=W-110
        self:drawRect(X+55,Y+408,bw,9,0.7,0.15,0.17,0.23)
        self:drawRect(X+55,Y+408,bw*progress,9,0.94,color[1],color[2],color[3])
        -- The centered prize (slot 18) and 100% gauge now complete
        -- together, 300ms earlier than the original unreduced duration.
        if elapsed>=duration then self:finish() end
    elseif self.stage=="reveal" then
        local rarity=self.rewardTier
        local c=(TIERS[rarity] or TIERS.Normal).color
        local t0=(t-self.revealAt)/1000
        local burst=math.max(0,1-t0/1.3)
        local glow=glowFor(rarity)
        if glow then
            local size=400+burst*175
            self:drawTextureScaled(glow,X+(W-size)/2,Y+240-size/2,size,size,0.65+burst*0.2,1,1,1)
        end
        for i=1,32 do
            local a=i*2.39996
            local d=40+(1-burst)*265+(i%3)*11
            local px=X+W/2+math.cos(a)*d
            local py=Y+225+math.sin(a)*d*0.54
            self:drawRect(px,py,3+(i%3),3+(i%3),burst*0.9,c[1],c[2],c[3])
        end
        centered(self,tr("UI_RPG_Reveal_Obtained","REWARD UNLOCKED"),Y+120,UIFont.Large,c)
        local scale=1+0.17*burst
        local cw,ch=math.floor(166*scale),math.floor(187*scale)
        self:drawCard({type=self.reward,tier=self.rewardTier},X+(W-cw)/2,Y+155-(ch-187)/2,cw,ch,true,1)
        if #self.rewards>1 then
            centered(self,fmtText("UI_RPG_Reveal_OpenCount","OPENED: %s BOXES",tostring(self.opened)),Y+361,UIFont.Medium,{0.91,0.90,0.85})
            -- One line of condensed loot totals; all rewards are in the inventory.
            local lines={}
            for i=1,math.min(#self.itemKeys,4) do
                local ft=self.itemKeys[i]
                lines[#lines+1]=trimText(itemName(ft),18).." x"..self.itemCounts[ft]
            end
            centered(self,table.concat(lines,"     "),Y+395,UIFont.Small,{0.75,0.79,0.87})
            if #self.itemKeys>4 then
                centered(self,fmtText("UI_RPG_Reveal_More","+%s MORE TYPES IN INVENTORY",tostring(#self.itemKeys-4)),Y+423,UIFont.Small,{0.80,0.73,0.57})
            end
        else
            centered(self,tr("UI_RPG_Reveal_Stored","Added to your inventory"),Y+378,UIFont.Medium,{0.85,0.88,0.94})
        end
    else
        centered(self,tr("UI_RPG_Reveal_Empty","No boxes were opened"),Y+260,UIFont.Medium,{0.85,0.88,0.94})
    end
    self:drawParticles(t,self.stage=="reveal" and self.rewardTier or self.boxTier)
    if self.stage=="reveal" and #self.rewards>1 then
        self:drawRect(X+30,Y+H-73,190,29,0.95,0.12,0.15,0.22)
        self:drawRectBorder(X+30,Y+H-73,190,29,0.8,0.65,0.52,0.27)
        txt(self, self.showSummary and tr("UI_RPG_Reveal_Back","BACK TO REVEAL")
            or tr("UI_RPG_Reveal_List","ALL REWARDS (TAB)"),X+39,Y+H-69,UIFont.Small,{0.97,0.84,0.63})
    end
    if self.showSummary then
        self:drawRect(X+21,Y+100,W-42,H-195,0.98,0.030,0.044,0.078)
        self:drawRectBorder(X+21,Y+100,W-42,H-195,0.8,0.55,0.52,0.42)
        centered(self,tr("UI_RPG_Reveal_Summary","ALL ITEMS ACQUIRED"),Y+113,UIFont.Large,{1,0.82,0.52})
        local offset=(self.summaryPage-1)*10
        for i=1,10 do
            local ft=self.itemKeys[offset+i]
            if ft then
                local iy=Y+155+(i-1)*28
                local rarity=itemTier(ft)
                local c=(TIERS[rarity] or TIERS.Normal).color
                if i%2==0 then self:drawRect(X+52,iy-2,W-104,25,0.55,0.095,0.12,0.17) end
                self:drawRect(X+62,iy+5,6,10,0.94,c[1],c[2],c[3])
                txt(self,trimText(itemName(ft),54),X+81,iy,UIFont.Small,{0.92,0.92,0.95})
                txt(self,"x"..tostring(self.itemCounts[ft]),X+W-119,iy,UIFont.Small,c)
            end
        end
        local pages=math.max(1,math.ceil(#self.itemKeys/10))
        centered(self,string.format("<  %d / %d  >",self.summaryPage,pages),Y+H-126,UIFont.Medium,{0.9,0.81,0.61})
    end
    self:drawRect(X+12,Y+H-78,W-24,1,0.42,0.84,0.68,0.35)
    -- B42: draw controls at the end of render(), never beneath the overlay.
    -- The red X is available even while waiting for the server's result.
    local bx,by,bw,bh,sx,sy,sw,sh=self:buttonRects()
    self:drawRect(bx,by,bw,bh,0.98,0.72,0.075,0.10)
    self:drawRectBorder(bx,by,bw,bh,1,1,0.43,0.43)
    local xfont=UIFont.Medium
    local xText="X"
    local xw=getTextManager():MeasureStringX(xfont,xText)
    txt(self,xText,bx+(bw-xw)/2,by+4,xfont,{1,1,1})

    if self.stage=="reveal" or self.stage=="empty" then
        self.remainingTotal=currentInventoryCount(self)
    end
    local available=self.stage=="rolling" or
        ((self.stage=="reveal" or self.stage=="empty") and self.remainingTotal>0)
    if available then
        self:drawRect(sx,sy,sw,sh,0.98,0.48,0.30,0.09)
        self:drawRectBorder(sx,sy,sw,sh,1,1,0.78,0.37)
    else
        self:drawRect(sx,sy,sw,sh,0.98,0.19,0.21,0.24)
        self:drawRectBorder(sx,sy,sw,sh,0.65,0.50,0.51,0.54)
    end
    local label=self.stage=="rolling" and tr("UI_RPG_Reveal_Skip","SKIP")
        or continueLabel(self.remainingTotal)
    local font=UIFont.Medium
    local tw=getTextManager():MeasureStringX(font,label)
    txt(self,label,sx+(sw-tw)/2,sy+9,font,available and {1,0.95,0.80} or {0.68,0.70,0.72})
end

function RPG_RandomboxRevealUI.showNext()
    if RPG_RandomboxRevealUI.instance then return end
    if #RPG_RandomboxRevealUI.queue==0 then return end
    local packet=table.remove(RPG_RandomboxRevealUI.queue,1)
    local win=RPG_RandomboxRevealUI:new()
    win:initialise(); win:createChildren()
    win:addToUIManager(); win:bringToTop()
    -- The reveal UI is controlled by visible buttons only.
    RPG_RandomboxRevealUI.instance=win
    win:present(packet.tier,packet.opened,packet.requestId)
    win:accept(packet)
end
function RPG_RandomboxRevealUI.BeginRequest(tier,count)
    RPG_RandomboxRevealUI.requestCounter=RPG_RandomboxRevealUI.requestCounter+1
    local id=tostring(now()).."-"..tostring(RPG_RandomboxRevealUI.requestCounter)
    RPG_RandomboxRevealUI.pending[id]=true
    return id
end
function RPG_RandomboxRevealUI.OnResult(args)
    if type(args)~="table" then return end
    local id=tostring(args.requestId or "")
    if id~="" and not RPG_RandomboxRevealUI.pending[id] then return end
    RPG_RandomboxRevealUI.pending[id]=nil
    -- Reuse the open cinematic for the next individually drawn box.
    local active=RPG_RandomboxRevealUI.instance
    if active and active.stage=="waiting" and active.requestId==id then
        active:accept(args)
        return
    end
    RPG_RandomboxRevealUI.queue[#RPG_RandomboxRevealUI.queue+1]=args
    RPG_RandomboxRevealUI.showNext()
end
Events.OnServerCommand.Add(function(module,cmd,args)
    if module==MODULE and cmd=="RandomboxReveal" then
        RPG_RandomboxRevealUI.OnResult(args)
    end
end)
Events.OnGameStart.Add(function()
    RPG_RandomboxRevealUI.pending={}
    RPG_RandomboxRevealUI.queue={}
    RPG_RandomboxRevealUI.instance=nil
end)
return RPG_RandomboxRevealUI

-- RCE: ember forging presentation, legacy physical IDs retained.
