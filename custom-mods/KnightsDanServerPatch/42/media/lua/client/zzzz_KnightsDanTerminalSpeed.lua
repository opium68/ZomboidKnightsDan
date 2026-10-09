require "PZLinux/PZLinuxTyping"
local nativeWait = PZLinux.Typing.wait
PZLinux.Typing.wait = function(ui, minimum, maximum, multiplier)
    local class = ui and getmetatable(ui)
    if (connectUI and class == connectUI) or (requestUI and class == requestUI) then
        multiplier = (tonumber(multiplier) or 1) / 5
    end
    return nativeWait(ui, minimum, maximum, multiplier)
end

Events.OnGameStart.Add(function()
    if not linuxUI or linuxUI.knightsFastBoot then return end
    local nativeBoot = linuxUI.onBoot
    linuxUI.onBoot = function(self, ...)
        nativeBoot(self, ...)
        if not self.terminalCoroutine or not self.bootMessages then return end
        -- Retain native messages, audio and the tick handler/prompt transition.
        self.terminalCoroutine = coroutine.create(function()
            local function wait(seconds)
                local deadline = getGameTime():getWorldAgeHours() + seconds / 3600 / 5
                while getGameTime():getWorldAgeHours() < deadline do
                    if self.isClosing then return false end
                    coroutine.yield()
                end
                return not self.isClosing
            end
            if not wait(1) then return end
            for _, line in ipairs(self.bootMessages) do
                if self.isClosing then return end
                self.bootOutput.text = self.bootOutput.text .. "\n" .. line
                self.bootOutput:paginate()
                local scroll = self.bootOutput:getScrollHeight() - self.bootOutput:getHeight()
                if scroll > 0 then self.bootOutput:setYScroll(-scroll) end
                if not wait(ZombRand(1, 10)) then return end
            end
        end)
    end
    linuxUI.knightsFastBoot = true
end)
