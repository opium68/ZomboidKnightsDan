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
local function coopMenu(index,context)
    local player=getSpecificPlayer(index)
    if not player then return end
    local root=context:addOption("협동 의뢰")
    local menu=ISContextMenu:getNew(context)
    context:addSubMenu(root,menu)
    menu:addOption("받은 초대 수락",player,command,"join")
    menu:addOption("참가 등록 취소",player,command,"leave")
    if getOnlinePlayers then
        local all=getOnlinePlayers()
        for i=0,all:size()-1 do
            local buddy=all:get(i)
            if buddy~=player and buddy:getZ()==player:getZ()
                and math.abs(buddy:getX()-player:getX())<=10 and math.abs(buddy:getY()-player:getY())<=10 then
                menu:addOption(buddy:getUsername().."님 초대",player,command,"invite",{username=buddy:getUsername()})
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(coopMenu)
Events.OnServerCommand.Add(function(module,cmd,args)
    if module=="KnightsDan" and cmd=="notice" and args then
        local p=getPlayer()
        if p then p:Say(tostring(args.message)) end
    end
end)
