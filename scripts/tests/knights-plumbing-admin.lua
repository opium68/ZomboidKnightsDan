local handler, modal, sent, resultHandler
Events = {OnFillWorldObjectContextMenu = {Add = function(fn) handler = fn end},
    OnServerCommand = {Add = function(fn) resultHandler = fn end}}
function require() end
function getText(key) return key end
local admin = {level = "admin"}
function admin:getAccessLevel() return self.level end
function getSpecificPlayer(index) return index == 0 and admin or nil end
function sendClientCommand(player, module, command, args)
    sent = {player = player, module = module, command = command, args = args}
end
ISModalDialog = {new = function(self, x, y, w, h, text, yesno, target, callback)
    modal = {target = target, callback = callback,
        initialise = function() end, addToUIManager = function() end}
    assert(type(text) == "string")
    return modal
end}
local options = {}
local context = {addOption = function(self, name, target, callback)
    options[#options + 1] = {name = name, target = target, callback = callback}
end}
assert(loadfile("custom-mods/KnightsDanServerPatch/42/media/lua/client/zzzzzz_KnightsDanPlumbingAdmin.lua"))()
handler(0, context, {}, false)
assert(#options == 0, "absent LGEP must not add a menu")
LGEP = {COMMAND_MODULE = "LGExtendedPlumbing", CMD_ADMIN_UNINSTALL = "adminuninstall"}
SandboxVars = {LGExtendedPlumbing = {Enabled = false}}
function isDebugEnabled() return false end
handler(0, context, {}, true)
assert(#options == 0, "test pass must not add a menu")
admin.level = "moderator"
handler(0, context, {}, false)
assert(#options == 0, "moderator must not receive server-wide cleanup")
admin.level = "admin"
handler(0, context, {}, false)
assert(#options == 1, "disabled plumbing and no debug must still show admin recovery")
options[1].callback(options[1].target)
assert(modal and not sent, "opening menu must only ask for confirmation")
modal.callback(modal.target, {internal = "NO"})
assert(not sent, "cancel must not send cleanup")
admin.level = "user"
modal.callback(modal.target, {internal = "YES"})
assert(not sent, "revoked admin must not send cleanup")
admin.level = "admin"
modal.callback(modal.target, {internal = "YES"})
assert(sent and sent.player == admin and sent.module == LGEP.COMMAND_MODULE
    and sent.command == LGEP.CMD_ADMIN_UNINSTALL and type(sent.args) == "table")
for _ in pairs(sent.args) do error("cleanup must not send extra arguments") end
local sq = {getX=function() return 10 end,getY=function() return 20 end,getZ=function() return 0 end}
local fixture = {getSquare=function() return sq end,getObjectIndex=function() return 2 end,
    getSprite=function() return {getName=function() return "sink" end} end}
LGEP.isPlumbableFixture = function(obj) return obj == fixture end
options = {}
handler(0,context,{fixture},false)
assert(#options == 3, "selected fixture adds inspect and guarded restore")
options[2].callback(options[2].target)
assert(sent.command == "inspect" and sent.args.index == 2 and sent.args.sprite == "sink")
sent = nil
options[3].callback(options[3].target)
modal.callback(modal.target,{internal="NO"})
assert(not sent)
modal.callback(modal.target,{internal="YES"})
assert(sent.command == "restore" and sent.args.x == 10 and sent.args.y == 20)
resultHandler("KnightsDanPlumbing","result",{x=10,y=20,z=0,sprite="sink",reason="Inspect",
    after={external=true,marker=true,moved=true,room=false,noWater=false,amount=0,
        sourceSprite="-",days=40,shutoff=90}})
assert(modal and modal.callback == nil, "inspection result opens an information dialog")
return "admin recovery without debug; fixture selection, inspect/result, confirmation and revoked permissions checked"
