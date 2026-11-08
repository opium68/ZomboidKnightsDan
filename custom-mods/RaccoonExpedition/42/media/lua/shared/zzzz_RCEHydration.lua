require 'TimedActions/ISDrinkFluidAction'
RCE=RCE or {}
RCE.Hydration={}
local H=RCE.Hydration
function H.bind(action)
 local item=action.item
 if not item or not item.getFullType then return end
 local ft=item:getFullType()
 if type(ft)~='string' or not ft:find('^RPGSkillTree%.HydrationBackpack_')then return end
 -- Networked actions can retain a detached component after item resolution.
 -- Always use the fluid component of the actual inventory item.
 if action.character and action.character.getInventory and item.getID then
  local found=action.character:getInventory():getItemById(item:getID())
  if found then item=found;action.item=found end
 end
 local fluid=item:getFluidContainer()
 if not fluid then return end
 action.fluidContainer=fluid
 if not action.RCEHydrationBound then
  local ratio=fluid:getFilledRatio()
  action.startRatio=ratio
  action.targetConsumedRatio=ratio*(action.percentage or 1)
  action.endRatio=ratio-action.targetConsumedRatio
  action.consumedRatio=0
  action.RCEHydrationBound=true
 end
end
for _,name in ipairs({'isValidStart','isValid','start','serverStart','updateEat'})do
 local old=ISDrinkFluidAction[name]
 if old then ISDrinkFluidAction[name]=function(self,...)
  H.bind(self)
  return old(self,...)
 end end
end
