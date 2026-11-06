-------------------------------------------------
-- RPG_Server_Commands.lua
-- Single authoritative server router (NO shared)
-- XP is SERVER-ONLY (no client AddXP command)
-- v51: authoritative B42 Gene Editing trait purchase/removal
-------------------------------------------------

local MODULE = "RPGSkillTree"

local WeaponEnhance = require "RPG_Server_WeaponEnhance"
local State      = require "RPG_Server_State"
local Broadcast  = require "RPG_Server_Broadcast"
local LevelTable = require "RPG_Server_LevelTable"
local Calc       = require "RPG_Server_Calculate"
local Gene       = require "RPG_Shared_GeneTraits"
local Vault      = require "RPG_Shared_DimensionalVault"

-------------------------------------------------
-- Command names
-------------------------------------------------
local CMD_REQUEST_SYNC  = "RequestSync"
local CMD_PUSH_STATE    = "PushState"

local CMD_SET_XPBAR_POS = "SetXPBarPos"
local CMD_TOGGLE_NODE   = "ToggleNode"
local CMD_RESET_NODES   = "ResetNodes"

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function clamp(n, min, max)
    if n < min then return min end
    if n > max then return max end
    return n
end

-------------------------------------------------
-- State push
-------------------------------------------------
local function pushState(player, d)
    if player and d and Calc and Calc.CalculateAndStoreFactors then
        Calc.CalculateAndStoreFactors(player)
    end
    if d then
        -- Ordered revision allows clients to reject stale/out-of-order state.
        d.rpgSyncSeq = (tonumber(d.rpgSyncSeq) or 0) + 1
    end
    Broadcast.ToPlayer(player, CMD_PUSH_STATE, { state = d })
end

-------------------------------------------------
-- Reset points (누적 totalXP 기반)
-------------------------------------------------
local RESET_XP_CHUNK = 90000

local function recalcResetPoints(d)
    local total  = tonumber(d.totalXP) or 0
    local earned = math.floor(total / RESET_XP_CHUNK)

    local prev = tonumber(d.resetEarnedTotal) or 0
    if earned > prev then
        d.resetPoints = (tonumber(d.resetPoints) or 0) + (earned - prev)
        d.resetEarnedTotal = earned
    else
        d.resetEarnedTotal = prev
    end
end

-------------------------------------------------
-- Level rollover (d.xp 기반)
-------------------------------------------------
local function recalcLevel(d)
    d.level = tonumber(d.level) or 1
    d.xp    = tonumber(d.xp) or 0

    while d.level < LevelTable.MAX_LEVEL do
        local need = LevelTable.GetRequiredXP(d.level)
        if d.xp < need then break end

        d.xp = d.xp - need
        d.level = d.level + 1
        d.skillPoints = (tonumber(d.skillPoints) or 0) + 1
    end
end

-------------------------------------------------
-- Commands table
-------------------------------------------------
local Commands = {}

-------------------------------------------------
-- Weapon Enhance / Soul Imbue (ROUTED)
-------------------------------------------------
Commands.EnhanceWeapon = function(player, args)
    if WeaponEnhance and WeaponEnhance.EnhanceWeapon then
        WeaponEnhance.EnhanceWeapon(player, args)
    end
end

Commands.SoulImbueWeapon = function(player, args)
    if WeaponEnhance and WeaponEnhance.SoulImbueWeapon then
        WeaponEnhance.SoulImbueWeapon(player, args)
    end
end

-------------------------------------------------
-- Sync (접속 / 수동 요청)
-------------------------------------------------
Commands[CMD_REQUEST_SYNC] = function(player)
    local d = State.Ensure(player)
    pushState(player, d)
end

-------------------------------------------------
-- Give XP (SERVER ONLY)
-------------------------------------------------
function Commands.GiveXP(player, amt) if true then return end
    amt = tonumber(amt)
    if not player or not amt or amt <= 0 then return end

    local d = State.Ensure(player)

    d.xp      = (tonumber(d.xp) or 0) + amt
    d.totalXP = (tonumber(d.totalXP) or 0) + amt

    recalcResetPoints(d)
    recalcLevel(d)
    d.xpNext=LevelTable.GetRequiredXP(d.level)

    pushState(player, d)
end

-- Server-side reward modules may request an authoritative state update.
function Commands.SyncPlayer(player)
    if not player then return false end
    local d=State.Ensure(player)
    if not d then return false end
    pushState(player,d)
    if player.transmitModData then pcall(function() player:transmitModData() end) end
    return true
end

-------------------------------------------------
-- XPBar position / config save (UI)
-------------------------------------------------
Commands[CMD_SET_XPBAR_POS] = function(player, args)
    args = args or {}
    local Config=require 'RPG_Shared_HUDConfig'
    local d = State.Ensure(player)

    d.ui = d.ui or {}
    d.ui.xpbar = d.ui.xpbar or {
        x = 200,
        y = 200,
        locked = false,
        scale = 1.0,
        visible = true,   -- ✅ 기본값
    }

    if Config.finite(args.x) then d.ui.xpbar.x = args.x end
    if Config.finite(args.y) then d.ui.xpbar.y = args.y end
    if type(args.locked) == "boolean" then d.ui.xpbar.locked = args.locked end

    if Config.finite(args.scale) then
        d.ui.xpbar.scale = clamp(args.scale, 0.5, 2.0)
    end

    -- ✅ 추가: XPBar 표시 / 숨김 저장
    if type(args.visible) == "boolean" then
        d.ui.xpbar.visible = args.visible
    end
    -- HUD cosmetics use the existing per-player save path. Gameplay keys
    -- (XP, levels, skill points, nodes) are never accepted by this helper.
    Config.apply('xp',d.ui.xpbar,args)

    pushState(player, d)
end

-------------------------------------------------
-- Toggle skill tree node
-------------------------------------------------
Commands[CMD_TOGGLE_NODE] = function(player, args)
    args = args or {}
    local nodeId = args.nodeId
    if type(nodeId) ~= "string" or nodeId == "" then return end

    local d = State.Ensure(player)
    d.nodes = d.nodes or {}

    -- v50: prevent buying the DNA node without Memory Stone on a multiplayer server.
    if nodeId == "GeneEditing" and not d.nodes.MemoryStone then return end
    -- Never leave an unlocked DNA node orphaned by a direct toggle request.
    if nodeId == "MemoryStone" and d.nodes.MemoryStone and d.nodes.GeneEditing then return end
    -- The new final node uses the same one-SP purchase/refund path, with a
    -- server-validated parent. Existing branches retain their original rules.
    if nodeId == "EnduranceKeystone" and not d.nodes.EnduranceKeystone and not d.nodes.BloodCollector then return end
    if nodeId == "EnduranceChance1" and not d.nodes.EnduranceChance1 and not d.nodes.EnduranceKeystone then return end
    if nodeId == "EnduranceChance2" and not d.nodes.EnduranceChance2 and not d.nodes.EnduranceChance1 then return end
    if nodeId == "BloodCollector" and d.nodes.BloodCollector and d.nodes.EnduranceKeystone then return end
    if nodeId == "EnduranceKeystone" and d.nodes.EnduranceKeystone and d.nodes.EnduranceChance1 then return end
    if nodeId == "EnduranceChance1" and d.nodes.EnduranceChance1 and d.nodes.EnduranceChance2 then return end
    -- Server-authoritative three-node item-find branch. Prevent bypassing SP cost or prerequisites.
    if nodeId == 'ItemFind1' and not d.nodes.ItemFind1 and not d.nodes.GeneEditing then return end
    if nodeId == 'ItemFind2' and not d.nodes.ItemFind2 and not d.nodes.ItemFind1 then return end
    if nodeId == 'ItemFind3' and not d.nodes.ItemFind3 and not d.nodes.ItemFind2 then return end
    if nodeId == 'GeneEditing' and d.nodes.GeneEditing and d.nodes.ItemFind1 then return end
    if nodeId == 'ItemFind1' and d.nodes.ItemFind1 and d.nodes.ItemFind2 then return end
    if nodeId == 'ItemFind2' and d.nodes.ItemFind2 and d.nodes.ItemFind3 then return end
    if not Vault.canToggle(d.nodes,nodeId) then return end

    if d.nodes[nodeId] then
        d.nodes[nodeId] = nil
        d.spentPoints = math.max(0, (tonumber(d.spentPoints) or 0) - 1)
    else
        local sp    = tonumber(d.skillPoints) or 0
        local spent = tonumber(d.spentPoints) or 0
        if (sp - spent - (tonumber(d.geneSpentPoints) or 0)) <= 0 then return end

        d.nodes[nodeId] = true
        d.spentPoints = spent + 1
    end

    pushState(player, d)
    if player.transmitModData then
        player:transmitModData()
    end
end

-------------------------------------------------
-- Gene editing: only the server can validate, spend SP and mutate traits.
-- Client packets supply IDs only, never prices or SP totals.
-------------------------------------------------
Commands.GeneEditTrait = function(player, args)
    if not player or type(args) ~= 'table' then return end
    local action, traitId = args.action, args.traitId
    if action ~= 'add' and action ~= 'remove' then return end
    if type(traitId) ~= 'string' or #traitId > 100 then return end
    local d = State.Ensure(player)
    if not d or not d.nodes or not d.nodes.GeneEditing or not d.nodes.MemoryStone then return end

    local row = Gene.find(traitId, action, (isMultiplayer == nil or isMultiplayer()))
    if not row or not player.getCharacterTraits then return end
    local owned = Gene.has(player,row.trait)
    if (action == 'add' and owned) or (action == 'remove' and not owned) then return end
    if action == 'add' and Gene.conflicts(player,row.definition) then return end

    local balance = (tonumber(d.skillPoints) or 0) - (tonumber(d.spentPoints) or 0)
                  - (tonumber(d.geneSpentPoints) or 0)
    if balance < row.cost then return end
    local traits=player:getCharacterTraits()
    local ok,err=pcall(function()
        if action == 'add' then traits:add(row.trait) else traits:remove(row.trait) end
    end)
    if not ok then
        print('[Project RPG][GeneEditing] trait operation failed: '..tostring(err))
        return
    end
    -- Verify before charging, so unsupported runtime traits don't eat SP.
    if Gene.has(player,row.trait) ~= (action == 'add') then return end
    d.geneSpentPoints = (tonumber(d.geneSpentPoints) or 0) + row.cost
    d.geneEdits = d.geneEdits or {}
    d.geneEdits[traitId] = (action == 'add') and 'add' or 'remove'
    d.geneEditSeq = (tonumber(d.geneEditSeq) or 0) + 1
    pushState(player,d)
    if player.transmitModData then player:transmitModData() end
    print('[Project RPG][GeneEditing] '..tostring(action)..' '..traitId..' SP='..tostring(row.cost))
end

-------------------------------------------------
-- Reset all nodes (consume reset point)
-------------------------------------------------
Commands[CMD_RESET_NODES] = function(player)
    local d = State.Ensure(player)
    local rp = tonumber(d.resetPoints) or 0
    if rp <= 0 then return end

    d.resetPoints = rp - 1
    d.nodes = {}
    d.spentPoints = 0

    pushState(player, d)
    if player.transmitModData then
        player:transmitModData()
    end
end

-------------------------------------------------
-- Client → Server router (ONLY ONE)
-------------------------------------------------
local function OnClientCommand(module, command, player, args)
    if module ~= MODULE then return end

    local fn = Commands[command]
    if fn then
        return fn(player, args or {})
    elseif command ~= "RandomboxOpen" and command ~= "Save"
        and command ~= "Restore" and command ~= "SummonRequest"
        and command ~= "HordeHUDRequest" and command ~= "HordeHUDSave" then
        -- Separate RPG server modules handle those four commands.
        print("RPG SERVER: unknown command =", tostring(command))
    end
end

-- SP and MP share the same handlers and validation. In SP we call the
-- handler directly because there is no network server to receive packets.
-- MP still uses the normal OnClientCommand transport.
function Commands.DispatchLocal(player, command, args)
    if isMultiplayer == nil or isMultiplayer() then return false end
    local result = OnClientCommand(MODULE, command, player, args or {})
    -- The XP watcher retries only when its server-side poll succeeds.
    if command == "SPKillCounterUpdate" then return result == true end
    return true
end

RPG_SP_DispatchCommand = function(player, command, args)
    return Commands.DispatchLocal(player, command, args)
end

Events.OnClientCommand.Add(OnClientCommand)

-------------------------------------------------
-- EXPORT
-------------------------------------------------
RCERequestRPGSync=function(player) Commands.RequestSync(player) end
RCEApplyGeneEdits=function(player,edits)
 for traitId,action in pairs(edits) do
  local row=Gene.find(traitId,action,true)
  if row then
   if action=='add' then player:getCharacterTraits():add(row.trait)
   elseif action=='remove' then player:getCharacterTraits():remove(row.trait) end
  end
 end
end
return Commands