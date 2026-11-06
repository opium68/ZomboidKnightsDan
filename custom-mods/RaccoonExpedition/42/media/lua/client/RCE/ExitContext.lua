require 'RCE/Config'
RCE.ExitContext={}
local E=RCE.ExitContext
function E.install()
 if not ISWorldObjectContextMenu or not ISWorldObjectContextMenu.createMenu then return false end
 if E.installed then return true end
 E.installed=true
 local original=ISWorldObjectContextMenu.createMenu
 ISWorldObjectContextMenu.createMenu=function(index,objects,x,y,test)
  local player=getSpecificPlayer(index)
  local atExit=player and not player:isDead() and RCE.exitAt(RCE.position(player))
  local context=original(index,objects,x,y,test)
  if not atExit then return context end
  -- Empty ground may return nil before OnFill (fetch.c == 0).
  if test then return true end
  if not context then
   context=ISContextMenu.get(index,x,y)
   context:addOption(getText('IGUI_RCE_Exit'),player,function(p)RCE.Client.request(p,'Exit')end)
  end
  return context
 end
 return true
end
E.install()
Events.OnGameStart.Add(E.install)
Events.OnTick.Add(function()if not E.installed then E.install() end end)
