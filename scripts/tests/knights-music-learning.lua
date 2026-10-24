local active, starts = true, 0
getActivatedMods=function() return {contains=function(self,id)
    assert(id=="LifestyleHobbies"); return active
end} end
PlayInstrumentTraining={start=function(self)
    starts=starts+1
    self.sandboxAddChance=self.originalBonus
    return "native"
end}
local nativeRequire = require
require=function(name)
    if name=="TimedActions/PlayInstrumentTraining" then return end
    return nativeRequire(name)
end
require "zzzzz_KnightsDanMusicLearning"
local action=setmetatable({originalBonus=5,playerLevel=2,relearnTotal=5},
    {__index=PlayInstrumentTraining})
assert(action:start()=="native" and starts==1)
assert(action.sandboxAddChance==25 and action.playerLevel==2 and action.relearnTotal==5)
action:start()
assert(action.sandboxAddChance==25 and starts==2,"bonus must not accumulate")
local function successes(bonus,level,target)
    local total=0
    for roll=0,199 do
        if roll+1+bonus>=target-level then total=total+1 end
    end
    return total
end
for level=2,10 do
    for _,target in ipairs({198,201,205,208}) do
        assert(successes(25,level,target)-successes(5,level,target)==20)
    end
end
assert(successes(5,2,198)==10 and successes(25,2,198)==30)
print("PASS native start preserved; no accumulated bonus; all tiers/levels gain exactly 10 percentage points")
