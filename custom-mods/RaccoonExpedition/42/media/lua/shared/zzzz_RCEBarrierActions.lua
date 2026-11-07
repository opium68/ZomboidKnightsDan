require 'RCE/Barrier'
require 'TimedActions/ISDestroyStuffAction'
local old=ISDestroyStuffAction.isValid
ISDestroyStuffAction.isValid=function(self)
 if RCE.Barrier.protected(self.item)then return false end
 return old(self)
end
