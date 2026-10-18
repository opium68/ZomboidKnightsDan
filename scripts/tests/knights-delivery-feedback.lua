require "knights-coop"
require "KnightsDan/Upstream"
require "KnightsDan/DeliveryFeedback"
local messages={}
HaloTextHelper={addBadText=function(_,s) messages[#messages+1]=s end,addGoodText=function(_,s) messages[#messages+1]=s end}
KnightsDan.showDeliveryResult({}, {ok=false,error='parcel_sync_failed',delivered=2,recovered=1,remaining=1,pendingItems=3})
assert(#messages==3 and messages[2]:find('동기화',1,true) and messages[3]:find('3개',1,true))
messages={};KnightsDan.showDeliveryResult({}, {ok=false,error='unknown_code',remaining=0})
assert(messages[1]:find('확인되지',1,true),'unknown failures must not invent a cause')
local actual=KnightsDan.loadPzLinuxSource
KnightsDan.loadPzLinuxSource=function(path,adapt)
 local reader=assert(getModFileReader('B42_PZLinux',path,false));local lines={};local line=reader:readLine()
 while line do lines[#lines+1]=line;line=reader:readLine() end;reader:close()
 local source=adapt(table.concat(lines,'\n'));assert(loadstring(source))
 local _,count=source:gsub('KnightsDan%.showDeliveryResult','')
 assert(count==2,'both actual native receive callbacks must be replaced')
 assert(not source:find('Dark web delivery failed:',1,true))
end
require "Context/World/ISContextStreetMailBox"
KnightsDan.loadPzLinuxSource=actual
return 'partial receipt, remaining quantities, unknown error, actual native mailbox callback adaptation and compilation'
