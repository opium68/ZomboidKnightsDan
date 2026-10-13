require "KnightsDan/RequestPreview"
local activeUI
local pool=PZLinuxRequestsGetOfferPool
PZLinuxRequestsGetOfferPool=function(contract)
    local entries=pool(contract)
    local ui=activeUI
    if not ui or ui.isClosing or ui.knightsPreviewContract~=contract or contract==9 then return entries end
    ui.knightsPreviewItems={}
    local wrapped={}
    for _,entry in ipairs(entries) do
        local source=entry
        local copy={}
        for key,value in pairs(source) do if key~="baseName" then copy[key]=value end end
        setmetatable(copy,{__index=function(_,key)
            if key=="baseName" then table.insert(ui.knightsPreviewItems,source.baseName) end
            return source[key]
        end})
        table.insert(wrapped,copy)
    end
    return wrapped
end
local function install()
    if not requestUI or requestUI.knightsPreviewInstalled then return end
    requestUI.knightsPreviewInstalled=true
    local start=requestUI.onContractId
    requestUI.onContractId=function(self,contract,...)
        activeUI=self
        self.knightsPreviewContract=contract
        self.knightsPreviewItems={}
        local panel=self.loadingMessage
        if panel and not panel.knightsPreviewInstalled then
            panel.knightsPreviewInstalled=true
            local paginate=panel.paginate
            panel.paginate=function(p,...)
                if p.text==self.knightsPreviewRenderedText then return paginate(p,...) end
                local ids=self.knightsPreviewItems or {}
                if #ids>0 and self.knightsPreviewContract~=9 then
                    local template=PZLinuxGetText("IGUI_PZLinux_Request_SellerItemOffer")
                    local ok,phrase=pcall(string.format,template,#ids)
                    if ok and phrase~="" then
                        local text=tostring(p.text or "")
                        local first,last=text:find(phrase,1,true)
                        if first then p.text=text:sub(1,last).."\n"..KnightsDan.requestPreview(ids)..text:sub(last+1) end
                    end
                end
                self.knightsPreviewRenderedText=p.text
                return paginate(p,...)
            end
        end
        return start(self,contract,...)
    end
end
Events.OnGameBoot.Add(install)
Events.OnGameStart.Add(install)
