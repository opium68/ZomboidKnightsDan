-------------------------------------------------
-- RPG_Client_RandomboxContextMenu.lua
-- ✅ B42 인벤 우클릭 메뉴 등록 + fullType 기반 오픈
-------------------------------------------------

require 'RCE/Forge'
local MODULE = "RPGSkillTree"

require "TimedActions/ISTimedActionQueue"
require "RPG_Shared_OpenRandomboxAction"
require "RPG_Client_RandomboxOddsUI"
local Catalog = require("RPG_Shared_BoxCatalog")

local function dbg(msg)
    print("[RPG Randombox][CM] " .. tostring(msg))
end

-------------------------------------------------
-- B42 items 파라미터 호환: InventoryItem 리스트로 추출
-------------------------------------------------
local function ExtractInventoryItems(items)
    local out = {}
    if not items then return out end

    if type(items) ~= "table" and items.size and items.get then
        for i = 0, items:size() - 1 do
            local v = items:get(i)
            if instanceof(v, "InventoryItem") then
                table.insert(out, v)
            elseif type(v) == "table" then
                if v.item and instanceof(v.item, "InventoryItem") then
                    table.insert(out, v.item)
                elseif v.items and type(v.items) == "table" then
                    for _, it in ipairs(v.items) do
                        if instanceof(it, "InventoryItem") then
                            table.insert(out, it)
                        end
                    end
                end
            end
        end
        return out
    end

    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            table.insert(out, v)
        elseif type(v) == "table" then
            if v.item and instanceof(v.item, "InventoryItem") then
                table.insert(out, v.item)
            end
            if v.items and type(v.items) == "table" then
                for _, it in ipairs(v.items) do
                    if instanceof(it, "InventoryItem") then
                        table.insert(out, it)
                    end
                end
            end
        end
    end

    return out
end

-------------------------------------------------
-- 박스 타입 → tier 매핑
-------------------------------------------------
local function getTierFromItem(item)
    if not item then return nil end
    local t = item:getType()
    if t == "Randombox_Normal" then return "Normal" end
    if t == "Randombox_Rare" then return "Rare" end
    if t == "Randombox_Legendary" then return "Legendary" end
    return nil
end

local function isRandombox(item)
    if not item then return false end
    local t = item:getType()
    return t == "Randombox_Normal" or t == "Randombox_Rare" or t == "Randombox_Legendary"
end

-------------------------------------------------
-- ✅ 인벤 우클릭 메뉴
-------------------------------------------------
local function OnFillInventoryObjectContextMenu(playerNum, context, items)
    local pl = getSpecificPlayer(playerNum)
    if not pl or (pl.isDead and pl:isDead()) then return end

    local list = ExtractInventoryItems(items)
    if not list or #list == 0 then return end

    local box = nil
    for _, it in ipairs(list) do
        if isRandombox(it) then
            box = it
            break
        end
    end
    if not box then return end
    if not RCE.Forge.unlocked(pl) then
        local option=context:addOption(getText('UI_RCE_Forge_Locked'),box,nil)
        option.notAvailable=true;return
    end

    local tier = getTierFromItem(box)
    if not tier then return end

    local fullType = box:getFullType()
    local boxId = 'default'

    -------------------------------------------------
    -- Read-only reward odds window. Safe for legacy box item types.
    -------------------------------------------------
    context:addOption(
        getText("UI_RPG_BoxOdds_Context"),
        box,
        function() RPG_RandomboxOddsUI.Open(boxId) end
    )

    -------------------------------------------------
    -- Open 1
    -------------------------------------------------
    context:addOption(
        getText("UI_RPG_Randombox_Open"),
        box,
        function()
            dbg("Open 1 -> " .. tostring(fullType) .. " tier=" .. tostring(tier))
            ISTimedActionQueue.add(
                RPG_OpenRandomboxAction:new(pl, fullType, tier, 1, false, boxId)
            )
        end
    )

    -------------------------------------------------
    -- Open All
    -------------------------------------------------
    local inv = pl:getInventory()
    local cnt = 1
    if inv and inv.getCountTypeRecurse then
        cnt = inv:getCountTypeRecurse(fullType)
    end
    if boxId ~= 'default' and inv and inv.getItems then
        cnt=0
        local its=inv:getItems()
        for i=0,its:size()-1 do
            local it=its:get(i)
            if it and it:getFullType()==fullType and Catalog.itemId(it)==boxId then cnt=cnt+1 end
        end
    end
    if cnt < 1 then cnt = 1 end
    if cnt > 200 then cnt = 200 end

    context:addOption(
        getText("UI_RPG_Randombox_OpenAll", cnt),
        box,
        function()
            dbg("Open All -> " .. tostring(fullType) .. " tier=" .. tostring(tier) .. " cnt=" .. tostring(cnt))
            ISTimedActionQueue.add(
                RPG_OpenRandomboxAction:new(pl, fullType, tier, cnt, true, boxId)
            )
        end
    )
end

Events.OnFillInventoryObjectContextMenu.Add(OnFillInventoryObjectContextMenu)

dbg("context menu loaded")

-- RCE: ember forging presentation, legacy physical IDs retained.
