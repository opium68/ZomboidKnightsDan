local load=require
require=function(name)if name=='TimedActions/ISDrinkFluidAction'then return true end;return load(name)end
local real={ratio=1,getFilledRatio=function(self)return self.ratio end}
local stale={getFilledRatio=function()return 0 end}
local item={getFullType=function()return 'RPGSkillTree.HydrationBackpack_Mythic'end,getID=function()return 42 end,getFluidContainer=function()return real end}
local owned={getItemById=function(_,id)if id==42 then return item end end}
local player={getInventory=function()return owned end}
ISDrinkFluidAction={}
function ISDrinkFluidAction:isValid()return self.fluidContainer:getFilledRatio()>0 end
function ISDrinkFluidAction:updateEat(delta)
 local consumed=self.startRatio-self.fluidContainer:getFilledRatio()
 local amount=delta*self.targetConsumedRatio-consumed
 self.fluidContainer.ratio=self.fluidContainer.ratio-math.max(0,amount)
end
load('zzzz_RCEHydration')
local a=setmetatable({item=item,character=player,fluidContainer=stale,startRatio=0,targetConsumedRatio=0,percentage=0.5},{__index=ISDrinkFluidAction})
assert(a:isValid(),'Stale empty component replaced by owned full component')
a:updateEat(0.5);assert(real.ratio==0.75,'Partial drink consumes expected amount')
a:updateEat(1);assert(real.ratio==0.5,'Finish consumes only selected half')
a:updateEat(1);assert(real.ratio==0.5,'Repeated callback does not drink twice')
local normal={getFullType=function()return 'Base.WaterBottle'end}
local b={item=normal,fluidContainer=stale,startRatio=0.2}
RCE.Hydration.bind(b);assert(b.fluidContainer==stale and b.startRatio==0.2,'Other fluids untouched')
return 'owned hydration component rebound; partial/complete/idempotent consumption; ordinary bottles untouched PASS'
