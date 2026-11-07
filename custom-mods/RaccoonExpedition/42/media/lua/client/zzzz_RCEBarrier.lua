require 'RCE/Barrier'
-- B42 multiplayer clients do not load server/BuildingObjects/ISDestroyCursor.
-- The shared timed action and native server guard remain authoritative.
local installedFor
local function installCursorGuard()
 if not ISDestroyCursor or type(ISDestroyCursor.canDestroy)~='function' then return end
 if installedFor==ISDestroyCursor then return end
 local old=ISDestroyCursor.canDestroy
 ISDestroyCursor.canDestroy=function(self,obj)
  if RCE.Barrier.protected(obj)then return false end
  return old(self,obj)
 end
 installedFor=ISDestroyCursor
end
installCursorGuard()
Events.OnGameStart.Add(installCursorGuard)