require "KnightsDan/RequestPreview"
local function text(key, ...)
    local value = PZLinuxGetText("IGUI_PZLinux_Request_"..key)
    local ok, formatted = pcall(string.format, value, ...)
    return ok and formatted or value
end
local function show(ui, message)
    local panel = ui.loadingMessage
    panel.text = "<RGB:0,1,0>"..message
    panel:paginate()
    local scroll = math.max(0, panel:getScrollHeight()-panel:getHeight())
    if panel.vscroll then panel.vscroll:setVisible(scroll>0) end
    panel:setYScroll(-scroll)
end
local function notify(ui, key)
    HaloTextHelper.addBadText(PZLinuxGetPlayer(ui.player), text(key))
end
local function install()
    if not requestUI or requestUI.knightsDailyInstalled then return end
    requestUI.knightsDailyInstalled = true
    local originalStart = requestUI.onContractId
    requestUI.onRefuseButton = function(self, button) return self:onMinimizeBack(button) end
    requestUI.onYesButton = function(self, button)
        local offer = self.knightsDailyOffer
        if not offer or self.knightsOrderPending then return end
        self.knightsOrderPending = true
        button:setEnable(false)
        local player = PZLinuxGetPlayer(self.player)
        PZLinuxRequestOrder(player, {contractId=offer.contractId,knightsOfferId=offer.offerId}, function(result)
            self.knightsOrderPending = false
            if not result or not result.ok then
                if not self.isClosing then button:setEnable(true); notify(self,"Rejected") end
                return
            end
            if result.balance then saveAtmBalance(result.balance,player) end
            self.isClosing = true
            self:removeFromUIManager()
            local md = PZLinuxGetModData(player)
            if result.contractId == 9 then
                md.PZLinuxActiveRequest = 1
                md.PZLinuxOnItemRequestCar = 1
                md.PZLinuxOnItemRequestCarName = result.vehicleName
                md.PZLinuxRequestLocationX = result.locationX
                md.PZLinuxRequestLocationY = result.locationY
                md.PZLinuxRequestLocationZ = result.locationZ
                md.PZLinuxRequestVehicleDeliveryId = result.deliveryId
                contractsDrawOnMap(result.locationX,result.locationY,text("CarRequested"))
                requestMenu_ShowUI(player)
            else
                md.PZLinuxUIOpenMenu = 8
                HaloTextHelper.addGoodText(player,text("MailboxAvailable"))
            end
        end)
    end
    requestUI.onContractId = function(self, contract)
        -- Reuse native panel creation, but never run its random offer coroutine.
        self.knightsDailyOfferMode = true
        if self.updateCoroutineFunc then Events.OnTick.Remove(self.updateCoroutineFunc) end
        originalStart(self,contract)
        Events.OnTick.Remove(self.updateCoroutineFunc)
        self.updateCoroutineFunc, self.terminalCoroutine = nil,nil
        self.knightsPreviewItems = {}
        self.knightsDailyOffer = nil
        self.knightsDailySequence = (self.knightsDailySequence or 0)+1
        local sequence = self.knightsDailySequence
        for _,name in ipairs({"yesButton","noButton"}) do
            if self[name] then self[name]:setVisible(false) end
        end
        show(self,text("WaitParticipants"))
        local player = PZLinuxGetPlayer(self.player)
        PZLinuxRequestGetCategories(player,function(result)
            if self.isClosing or self.knightsDailySequence ~= sequence then return end
            local offer = result and result.ok and result.knightsOffers and result.knightsOffers[tostring(contract)]
            if not offer then show(self,text("Rejected")); return end
            self.knightsDailyOffer = offer
            self.pendingRequestTotal = offer.amount
            self.terminalCoroutine = coroutine.create(function()
                local volume = getCore():getOptionSoundVolume()/50
                local function wait()
                    return not self.isClosing and PZLinux.Typing.waitProfile(self,"message") and not self.isClosing
                end
                local function sound()
                    getSoundManager():PlayWorldSound("ircNotification",false,player:getSquare(),0,20,1,true):setVolume(volume)
                end
                if not wait() then return end
                local seller = generateUsername()
                sound(); show(self,text("UserJoined",seller))
                if not wait() then return end
                seller = PZLinuxFormatIRCName(seller)
                local categoryKey = PZLinuxRequestCategoryTextKeys[contract]
                local message = seller..text("LookingFor",PZLinuxGetText(categoryKey))
                sound(); show(self,message)
                if not wait() then return end
                local interested = text("PlayerInterested")
                if not PZLinux.Typing.typeLabel(self,self.typingMessage,interested,player,{volume=volume}) or self.isClosing then return end
                message = message.."\n"..PZLinuxFormatIRCName(generatePseudo(string.lower(player:getUsername())))..interested
                self.typingMessage:setName("")
                show(self,message)
                if not wait() then return end
                if contract == 9 then
                    local vehicle = getScriptManager():getVehicle(offer.vehicleName)
                    local name = vehicle and getText("IGUI_VehicleName"..vehicle:getName()) or offer.vehicleName
                    message = message.."\n"..seller..text("SellerVehicleOffer",1,name)
                    sound(); show(self,message)
                    if not wait() then return end
                    message = message.."\n"..seller..text("VehicleLocation",offer.locationName or "")
                else
                    local ids = {}
                    for _,item in ipairs(offer.items) do ids[#ids+1]=item.name end
                    message = message.."\n"..seller..text("SellerItemOffer",#ids).."\n"..KnightsDan.requestPreview(ids)
                end
                sound(); show(self,message)
                if not wait() then return end
                message = message.."\n"..seller..text("Deal").."\n\n"..text("Total",offer.amount)
                sound(); show(self,message)
                local function button(label,x,handler)
                    local b=ISButton:new(self.width*x,self.height*0.65,self.width*0.20,25,label,self,handler)
                    b.id=contract; b:initialise(); b:instantiate(); self.topBar:addChild(b)
                    return b
                end
                if loadAtmBalance(player)>=offer.amount then
                    self.yesButton=button(text("Yes"),0.28,self.onYesButton)
                end
                self.noButton=button(text("No"),0.52,self.onRefuseButton)
            end)
            self.updateCoroutineFunc=function()
                if self.isClosing or not self.terminalCoroutine or coroutine.status(self.terminalCoroutine)=="dead" then
                    Events.OnTick.Remove(self.updateCoroutineFunc)
                    self.updateCoroutineFunc=nil; self.terminalCoroutine=nil
                    return
                end
                local ok,err=coroutine.resume(self.terminalCoroutine)
                if not ok then
                    print("[KnightsDan Daily Requests] "..tostring(err))
                    Events.OnTick.Remove(self.updateCoroutineFunc)
                    self.updateCoroutineFunc=nil; self.terminalCoroutine=nil
                end
            end
            Events.OnTick.Add(self.updateCoroutineFunc)
        end)
    end
end
Events.OnGameBoot.Add(install)
Events.OnGameStart.Add(install)
