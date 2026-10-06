require "Context/World/ISContextLinuxMenu"
require "TimedActions/ISPZLinuxAction"
require "Context/World/ISContextATMMenu"
require "KnightsDan/Core"
local oldMenu=linuxMenu_AddContext
local function heal(obj)
    local sprite=obj and obj.getSprite and obj:getSprite()
    local name=sprite and sprite:getName()
    if name and (name=="appliances_com_01_72" or name=="appliances_com_01_73"
        or name=="appliances_com_01_74" or name=="appliances_com_01_75") then
        obj:getModData().statusCondition=100
    end
end
Events.OnFillWorldObjectContextMenu.Remove(oldMenu)
linuxMenu_AddContext=function(player,context,objects)
    for _,obj in ipairs(objects) do
        heal(obj)
        local square=obj.getSquare and obj:getSquare()
        if square then
            local all=square:getObjects()
            for i=0,all:size()-1 do heal(all:get(i)) end
        end
    end
    oldMenu(player,context,objects)
end
Events.OnFillWorldObjectContextMenu.Add(linuxMenu_AddContext)
local start=ISPZLinuxAction.start
ISPZLinuxAction.start=function(self)
    self.item:getModData().statusCondition=100
    start(self)
    self.item:getModData().statusCondition=100
    self.character:getModData().PZLinuxComputerCondition=100
end
local update=linuxUI.update
linuxUI.update=function(self,...)
    if update then update(self,...) end
    if self.conditionButton then self.conditionButton:setVisible(false) end
end
linuxUI.onCondition=function() end
Events.OnFillWorldObjectContextMenu.Remove(AtmMenu_AddContext)
AtmMenu_AddContext=function() end
AtmMenu_OnUse=function() end
AtmMenu_ShowUI=function() return nil end
local function command(player,cmd,args) sendClientCommand(player,"KnightsDan",cmd,args or {}) end
local fallback={
    ContextMenu_KD_Coop="Cooperative contracts",
    ContextMenu_KD_Join="Accept invitation",
    ContextMenu_KD_Leave="Cancel registration",
    ContextMenu_KD_Invite="Invite %1",
    ContextMenu_KD_Active="Participants cannot be added to an active contract.",
    ContextMenu_KD_InviteNotice="%1 invited you. Accept from the right-click menu.",
    ContextMenu_KD_ExistingParty="Cancel your previous registration first.",
    ContextMenu_KD_JoinedLeader="%1 registered. Accept a contract when everyone is nearby.",
    ContextMenu_KD_Joined="Registered. Participants are fixed once the contract is accepted.",
    ContextMenu_KD_Left="Cooperative contract registration cancelled.",
}
local function text(key,param)
    local value=getText(key,param)
    if value and value~=key then return value end
    return (fallback[key] or key):gsub("%%1",function() return tostring(param or "") end)
end
local function coopMenu(index,context)
    local player=getSpecificPlayer(index)
    if not player then return end
    local root=context:addOption(text("ContextMenu_KD_Coop"))
    local menu=ISContextMenu:getNew(context)
    context:addSubMenu(root,menu)
    menu:addOption(text("ContextMenu_KD_Join"),player,command,"join")
    menu:addOption(text("ContextMenu_KD_Leave"),player,command,"leave")
    if getOnlinePlayers then
        local all=getOnlinePlayers()
        for i=0,all:size()-1 do
            local buddy=all:get(i)
            if buddy~=player and buddy:getZ()==player:getZ()
                and math.abs(buddy:getX()-player:getX())<=10 and math.abs(buddy:getY()-player:getY())<=10 then
                menu:addOption(text("ContextMenu_KD_Invite",buddy:getUsername()),player,command,"invite",{username=buddy:getUsername()})
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(coopMenu)
Events.OnServerCommand.Add(function(module,cmd,args)
    if module=="KnightsDan" and cmd=="notice" and args then
        local p=getPlayer()
        if p then p:Say(args.key and text(args.key,args.param) or tostring(args.message or "")) end
    end
end)
