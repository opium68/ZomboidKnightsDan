require 'RCE/Barrier'
require 'BuildingObjects/ISDestroyCursor'
require 'TimedActions/ISDestroyStuffAction'
local old=ISDestroyCursor.canDestroy
ISDestroyCursor.canDestroy=function(self,obj)
 if RCE.Barrier.protected(obj)then return false end
 return old(self,obj)
end
local valid=ISDestroyStuffAction.isValid
ISDestroyStuffAction.isValid=function(self)
 if RCE.Barrier.protected(self.item)then return false end
 return valid(self)
end
