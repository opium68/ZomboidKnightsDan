require "KnightsDan/Upstream"
require "KnightsDan/DeliveryFeedback"
KnightsDan.loadPzLinuxSource('media/lua/client/Context/World/ISContextStreetMailBox.lua',function(source)
 for _,request in ipairs({'PZLinuxRequestDarkWebDeliverOrders','PZLinuxRequestDeliver'}) do
  local marker=request..'(playerObj, self.mailbox, function(result)'
  local first,last=source:find(marker,1,true);assert(first,'Mailbox callback changed: '..request)
  local finish=assert(source:find('        PZLinuxStreetMailBoxActionFinished()',last+1,true),'Mailbox finish changed')
  source=source:sub(1,last)..'\n        KnightsDan.showDeliveryResult(playerObj,result)\n'..source:sub(finish)
 end
 return source
end)
