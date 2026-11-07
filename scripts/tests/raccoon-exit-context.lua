require 'RCE/Config'
Events=setmetatable({},{__index=function()return {Add=function()end}end})
local p={}
function p:getX()return self.x end
function p:getY()return self.y end
function p:getZ()return self.z end
function p:isDead()return false end
getSpecificPlayer=function()return p end
getText=function(key)return key end
local sent=0
RCE.Client={request=function(player,cmd)assert(player==p and cmd=='Exit');sent=sent+1 end}
local vanillaResult=nil
ISWorldObjectContextMenu={createMenu=function()return vanillaResult end}
ISContextMenu={get=function()return {addOption=function(self,title,target,fn)self.action=function()fn(target)end end}end}
require 'RCE/ExitContext'
for _,exit in ipairs(RCE.Config.exits)do
 p.x=exit.x;p.y=exit.y;p.z=exit.z
 assert(ISWorldObjectContextMenu.createMenu(0,{},10,10,true)==true)
 local menu=ISWorldObjectContextMenu.createMenu(0,{},10,10,false)
 assert(menu and menu.action,'Empty-ground fallback at every exit');menu.action()
 vanillaResult={existing=true}
 assert(ISWorldObjectContextMenu.createMenu(0,{},10,10,false)==vanillaResult)
 vanillaResult=nil
end
assert(sent==5)
p.x=p.x+6;assert(ISWorldObjectContextMenu.createMenu(0,{},10,10,false)==nil)
p.x=p.x-6;p.z=1;assert(ISWorldObjectContextMenu.createMenu(0,{},10,10,false)==nil)
return 'five exits: empty-ground/test fallback; existing menus/radius/floor preserved PASS'
