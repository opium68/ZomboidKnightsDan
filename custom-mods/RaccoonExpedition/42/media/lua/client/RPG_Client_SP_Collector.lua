-- RPG Skill Tree B42.21: SP collection passives.
-- Kill-counter based, identical attribution strategy to SP RPG XP.
-- Server OnZombieDead remains authoritative ONLY for MP.
local MODULE = 'RPGSkillTree'
local EvilChance = require('RPG_Shared_EvilDropChance')
local ItemFind = require('RPG_Shared_ItemFindChance')
local tick=0
local previousKillCount
local currentPlayer
local announced=false
local function isSP() return type(isMultiplayer)=='function' and not isMultiplayer() end
local function node(player,name)
    local md=player:getModData()
    local st=md and md[MODULE]
    return st and st.nodes and st.nodes[name] == true
end
local function randomChance(chance)
    if ZombRand then return ZombRand(1000000) < chance*1000000 end
    return math.random() < chance
end
local function sayDrop(player, textKey, englishFallback)
    local text = englishFallback
    if type(getText) == 'function' then
        local ok, translated = pcall(getText, textKey)
        if ok and type(translated) == 'string' and translated ~= '' and translated ~= textKey then
            text = translated
        end
    end
    if player and player.Say then pcall(function() player:Say(text) end) end
end
local function give(player, fullType)
    local inv=player and player.getInventory and player:getInventory()
    if not inv then return end
    local ok, item=pcall(function() return inv:AddItem(fullType) end)
    if ok and item then
        print('[RPG Collector][SP] drop='..fullType)
        return item
    end
end
-- B42.21 sandbox option: total chance in percent, original total = 0.18%.
-- Read per roll so existing saves without the new option preserve old behavior.
local function memoryStoneDropPercent()
    local group = SandboxVars and SandboxVars.RPGSkillTree
    local value = tonumber(group and group.MemoryStoneDropPercent)
    if not value or value ~= value or value == math.huge or value == -math.huge then
        return 0.18
    end
    return math.max(0, math.min(100, value))
end
local function wearingBoneEarring(player)
    local md = player and player.getModData and player:getModData()
    local st = md and md[MODULE]
    return st and st.itemFactors and st.itemFactors.boneDrop == true
end
local function roll(player)
    -- Mirrors the existing server-side BoneCollector's Earring 10% roll.
    -- Random box, memory-stone and skill-based collector chances are unchanged.
    if wearingBoneEarring(player) and randomChance(0.10) then
        give(player,'RPGSkillTree.Evil_Bone')
    end
    if node(player,'BloodCollector') and randomChance(ItemFind.boost(EvilChance.getProbability('Evil_Blood'),player)) then
        give(player,'RPGSkillTree.Evil_Blood')
    end
    if node(player,'SoulCollector') and randomChance(ItemFind.boost(EvilChance.getProbability('Evil_Soul'),player)) then
        if give(player,'RPGSkillTree.Evil_Soul') then
            sayDrop(player, 'UI_RPG_Drop_SP_EvilSoul', 'You obtained an Evil Soul.')
        end
    end
    if node(player,'SacrificeCollector') and randomChance(ItemFind.boost(EvilChance.getProbability('Evil_Sacrifice'),player)) then
        if give(player,'RPGSkillTree.Evil_Sacrifice') then
            sayDrop(player, 'UI_RPG_Drop_SP_EvilSacrifice', 'You obtained an Evil Sacrifice.')
        end
    end
    if false then -- RCE: old stone drops retired
        -- Keep original 1:7:10 tier weights (legendary/rare/normal).
        -- At the default 0.18%, thresholds are exactly 100/800/1800 as before.
        local total = ItemFind.boost(memoryStoneDropPercent()/100,player) * 1000000 -- boosted probability -> per-million
        if total > 0 then
            local r=ZombRand and ZombRand(1000000) or math.floor(math.random()*1000000)
            local ft=nil
            if r < total / 18 then ft='RPGSkillTree.Memory_Stone_Legendary'
            elseif r < total * 8 / 18 then ft='RPGSkillTree.Memory_Stone_Rare'
            elseif r < total then ft='RPGSkillTree.Memory_Stone_Normal' end
            if ft and give(player,ft) then
                sayDrop(player, 'UI_RPG_Drop_SP_Memory', 'You obtained a Memory Stone.')
            end
        end
    end
end
local function poll()
    if not isSP() then return end
    tick=tick+1
    if tick % 15 ~= 0 then return end
    local player=getPlayer and getPlayer()
    if not player or (player.isDead and player:isDead()) then return end
    if player ~= currentPlayer then
        currentPlayer=player
        previousKillCount=nil
    end
    if not player.getZombieKills then return end
    local ok,count=pcall(function() return player:getZombieKills() end)
    if not ok or type(count)~='number' then return end
    count=math.max(0,math.floor(count))
    if previousKillCount==nil then
        previousKillCount=count
        if not announced then print('[RPG Collector][SP] kill counter baseline='..count);announced=true end
        return
    end
    if count < previousKillCount then previousKillCount=count;return end
    local gained=count-previousKillCount
    if gained<=0 then return end
    -- Persistent cursor avoids re-rolling already counted kills after a save/reload.
    previousKillCount=count
    for i=1,math.min(gained,100) do roll(player) end
end
if Events and Events.OnTick then
    Events.OnTick.Add(poll)
    print('[RPG Collector][SP] watcher registered')
end
return true
