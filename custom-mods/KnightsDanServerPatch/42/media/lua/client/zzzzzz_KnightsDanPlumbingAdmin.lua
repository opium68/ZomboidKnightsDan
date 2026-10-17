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

local function fixtureArgs(obj)
    local sq = obj:getSquare()
    return {x=sq:getX(), y=sq:getY(), z=sq:getZ(), index=obj:getObjectIndex(),
        sprite=obj:getSprite():getName()}
end

local function fixtureConfirmed(target, button)
    if button and button.internal == "YES" and isAdmin(target.player) then
        sendClientCommand(target.player, "KnightsDanPlumbing", "restore", target.args)
    end
end

local function fixtureRestore(target)
    if not isAdmin(target.player) then return end
    local modal = ISModalDialog:new(0, 0, 560, 240,
        getText("UI_KnightsDan_PlumbingFixtureConfirm"), true, target, fixtureConfirmed)
    modal:initialise()
    modal:addToUIManager()
end

local function fixtureInspect(target)
    if isAdmin(target.player) then
        sendClientCommand(target.player, "KnightsDanPlumbing", "inspect", target.args)
    end
end

Events.OnServerCommand.Add(function(module, command, result)
    if module ~= "KnightsDanPlumbing" or command ~= "result" or type(result) ~= "table" then return end
    local state = result.after
    if type(state) ~= "table" then return end
    local lines = {getText("UI_KnightsDan_PlumbingReason_" .. result.reason),
        tostring(result.x)..","..tostring(result.y)..","..tostring(result.z).." / "..tostring(result.sprite)}
    for _, entry in ipairs({{"External","external"},{"Marker","marker"},{"Moved","moved"},
        {"Room","room"},{"NoWater","noWater"},{"Amount","amount"},{"Source","sourceSprite"},
        {"Days","days"},{"Shutoff","shutoff"}}) do
        lines[#lines+1] = getText("UI_KnightsDan_PlumbingField_"..entry[1])..": "..tostring(state[entry[2]])
    end
    if state.moved or not state.room or state.noWater or state.days >= state.shutoff then
        lines[#lines+1] = getText("UI_KnightsDan_PlumbingMainsUnavailable")
    end
    local modal = ISModalDialog:new(0,0,600,300,table.concat(lines,"\n"),false)
    modal:initialise()
    modal:addToUIManager()
end)

Events.OnFillWorldObjectContextMenu.Add(function(playerIndex, context, objects, test)
    if test or not available() then return end
    local player = getSpecificPlayer(playerIndex)
    if not isAdmin(player) then return end
    context:addOption(getText("UI_KnightsDan_PlumbingRestore"), player, restore)
    if not LGEP.isPlumbableFixture then return end
    for _, obj in ipairs(objects or {}) do
        if LGEP.isPlumbableFixture(obj) then
            local target = {player=player, args=fixtureArgs(obj)}
            context:addOption(getText("UI_KnightsDan_PlumbingFixtureInspect"),target,fixtureInspect)
            context:addOption(getText("UI_KnightsDan_PlumbingFixtureRestore"),target,fixtureRestore)
            break
        end
    end
end)
