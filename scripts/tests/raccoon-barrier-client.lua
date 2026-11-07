local load=require
local start
Events={OnGameStart={Add=function(fn)start=fn end}}
local calls=0
RCE={Barrier={protected=function(obj)return obj=='barrier'end}}
require=function(name)
 if name=='RCE/Barrier' then return true end
 error('Client requested unavailable module: '..name)
end
ISDestroyCursor=nil
load('zzzz_RCEBarrier')
assert(start,'Deferred installation registered')
start()
local original=function(self,obj)calls=calls+1;return obj=='ordinary'end
ISDestroyCursor={canDestroy=original}
start()
local wrapped=ISDestroyCursor.canDestroy
assert(not wrapped({},'barrier') and calls==0,'Protected object blocked')
assert(wrapped({},'ordinary') and calls==1,'Ordinary destruction delegated')
start()
assert(ISDestroyCursor.canDestroy==wrapped,'Repeated installation is idempotent')
return 'B42 client without server cursor loads; optional late cursor preserves protection PASS'