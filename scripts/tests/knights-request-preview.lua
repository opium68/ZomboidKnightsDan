Events={OnGameBoot={Add=function(f) f() end},OnGameStart={Add=function() end}}
function getScriptManager() return {FindItem=function(_,id) if id=='Base.Beans' then return {getDisplayName=function() return 'Beans' end} end end} end
function PZLinuxGetText() return 'Selling %s items.' end
function PZLinuxRequestsGetOfferPool() return {{baseName='Base.Beans',weight=1},{baseName='Base.Apple',weight=0.2}} end
requestUI={onContractId=function(self,contract)
    local pool=PZLinuxRequestsGetOfferPool(contract)
    local ids={pool[1].baseName,pool[1].baseName,pool[2].baseName}
    self.loadingMessage.text='Seller: Selling 3 items.\nPrice: 100'
    self.loadingMessage:paginate()
    return ids
end}
require 'zzzz_KnightsDanRequestPreview'
local ui={loadingMessage={paginate=function() end}}
requestUI.onContractId(ui,1)
assert(ui.loadingMessage.text:find('Beans x2',1,true) and ui.loadingMessage.text:find('Base.Apple x1',1,true))
assert(ui.loadingMessage.text:find('Price: 100',1,true))
local text=ui.loadingMessage.text;ui.loadingMessage:paginate();assert(text==ui.loadingMessage.text)
requestUI.onContractId(ui,9)
assert(not ui.loadingMessage.text:find('Beans x2',1,true),'vehicle presentation unchanged')
return 'actual client hooks capture selected items, merge duplicate quantities, preserve price/vehicle and repeated layout'
