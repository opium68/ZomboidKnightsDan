Events={OnGameBoot={Add=function(f) f() end},OnGameStart={Add=function() end}}
function getScriptManager() return {FindItem=function(_,id) if id=='Base.Beans' then return {getDisplayName=function() return 'Beans' end} end end} end
function PZLinuxGetText() return 'Selling %s items.' end
function PZLinuxRequestsGetOfferPool() return {{baseName='Base.Beans',weight=1},{baseName='Base.Apple',weight=0.2}} end
requestUI={onContractId=function(self,contract)
    if not self.loadingMessage then self.loadingMessage={paginate=function() end} end
    self.terminalCoroutine=coroutine.create(function()
    local pool=PZLinuxRequestsGetOfferPool(contract)
    local ids={pool[1].baseName,pool[1].baseName,pool[2].baseName}
    self.loadingMessage.text='Seller: Selling 3 items.\nPrice: 100'
    self.loadingMessage:paginate()
    return ids
    end)
end}
local rejected,returned=0,0
requestUI.onRefuseButton=function() rejected=rejected+1 end
requestUI.onMinimizeBack=function() returned=returned+1 end
require 'zzzz_KnightsDanRequestPreview'
local ui=setmetatable({}, {__index=requestUI})
requestUI.onContractId(ui,1)
assert(ui.loadingMessage and ui.loadingMessage.knightsPreviewInstalled,'first selection must hook a lazily created panel')
assert(coroutine.resume(ui.terminalCoroutine))
assert(ui.loadingMessage.text:find('Beans x2',1,true) and ui.loadingMessage.text:find('Base.Apple x1',1,true))
assert(ui.loadingMessage.text:find('Price: 100',1,true))
local text=ui.loadingMessage.text;ui.loadingMessage:paginate();assert(text==ui.loadingMessage.text)
requestUI.onContractId(ui,9)
assert(coroutine.resume(ui.terminalCoroutine))
assert(not ui.loadingMessage.text:find('Beans x2',1,true),'vehicle presentation unchanged')
requestUI.onRefuseButton(ui,{id=8})
assert(returned==1 and rejected==0,'ordinary refusal must not consume category')
requestUI.onRefuseButton(ui,{id=9})
assert(rejected==1,'vehicle refusal behavior unchanged')
return 'first lazily created UI and coroutine, contents/quantities, repeat-safe layout, ordinary refusal retains category; vehicle unchanged'
