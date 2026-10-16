-- Use LGEP's existing server-authorized cleanup, even without -debug.
-- No fixture flags or saved world data are changed on the client.
require "ISUI/ISModalDialog"

local function isAdmin(player)
    return player and player.getAccessLevel
        and tostring(player:getAccessLevel() or ""):lower() == "admin"
end

local function available()
    return LGEP and LGEP.COMMAND_MODULE and LGEP.CMD_ADMIN_UNINSTALL
end

local function confirmed(player, button)
    if not button or button.internal ~= "YES" then return end
    if not isAdmin(player) or not available() then return end
    sendClientCommand(player, LGEP.COMMAND_MODULE, LGEP.CMD_ADMIN_UNINSTALL, {})
end

local function restore(player)
    if not isAdmin(player) or not available() then return end
    local modal = ISModalDialog:new(0, 0, 560, 240,
        getText("UI_KnightsDan_PlumbingRestoreConfirm"), true, player, confirmed)
    modal:initialise()
    modal:addToUIManager()
end

Events.OnFillWorldObjectContextMenu.Add(function(playerIndex, context, objects, test)
    if test or not available() then return end
    local player = getSpecificPlayer(playerIndex)
    if not isAdmin(player) then return end
    context:addOption(getText("UI_KnightsDan_PlumbingRestore"), player, restore)
end)
