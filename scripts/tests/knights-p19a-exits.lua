local boot, calls = nil, 0
Events = {OnGameBoot={Add=function(fn) boot=fn end}}
local missing = false
local script = {
    getPassengerById=function(self,id) return not missing end,
    Load=function(self,name,source)
        assert(name=="86oshkoshUSMC")
        assert(string.find(source,"vehicle 86oshkoshUSMC",1,true))
        calls=calls+1
    end,
}
getScriptManager=function() return {getVehicle=function(self,name)
    assert(name=="Base.86oshkoshUSMC")
    return script
end} end
require "zzzz_KnightsDanP19AExits"
assert(boot and calls==0)
boot(); assert(calls==1)
missing=true; boot(); assert(calls==1)
script=nil; boot(); assert(calls==1)
print("PASS P19A boot hook; missing mod/seat skipped without partial overlay")
