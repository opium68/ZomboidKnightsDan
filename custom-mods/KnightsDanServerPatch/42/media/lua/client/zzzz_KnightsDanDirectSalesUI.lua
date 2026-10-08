Events.OnGameStart.Add(function()
    if not darkWebUI or not darkWebUI.onHelp then return end
    local help = darkWebUI.onHelp
    darkWebUI.onHelp = function(self, ...)
        help(self, ...)
        for _, child in pairs(self.children or {}) do
            if type(child.name) == "string"
                and child.name:find("To sell an item, it must", 1, true) then
                child:setName(PZLinuxGetText("IGUI_KD_DirectSellHelp"))
            end
        end
    end
end)
