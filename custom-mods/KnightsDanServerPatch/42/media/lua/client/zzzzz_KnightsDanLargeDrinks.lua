require "ISUI/ISInventoryPaneContextMenu"

-- Preserve the native eligibility checks and action. Only reopen options that
-- vanilla disabled specifically because the container capacity exceeds 3 L.
local function install()
    local menu = ISInventoryPaneContextMenu
    if menu.knightsLargeDrinksInstalled then return end
    menu.knightsLargeDrinksInstalled = true
    local original = menu.doDrinkFluidMenu
    menu.doDrinkFluidMenu = function(playerObj, container, context)
        local first = #(context.options or {}) + 1
        original(playerObj, container, context)
        if not container then return end
        local fluid = container:getFluidContainer()
        if not fluid or fluid:getCapacity() <= 3 then return end
        local item = instanceof(container, "IsoWorldInventoryObject") and container:getItem() or container
        for i = first, #(context.options or {}) do
            local option = context.options[i]
            if option.notAvailable and option.toolTip and
                    option.toolTip.description == getText("Tooltip_CantDrinkFrom") then
                option.notAvailable = false
                option.toolTip = nil
                local openingRecipe = nil
                if item:isSealed() and item:getOpeningRecipe() then
                    openingRecipe = getScriptManager():getCraftRecipe(item:getOpeningRecipe())
                end
                local sub = context:getNew(context)
                context:addSubMenu(option, sub)
                sub:addOption(getText("ContextMenu_Eat_All"), container,
                    menu.onDrinkFluid, 1, playerObj, openingRecipe, item)
                sub:addOption(getText("ContextMenu_Eat_Half"), container,
                    menu.onDrinkFluid, 0.5, playerObj, openingRecipe, item)
                sub:addOption(getText("ContextMenu_Eat_Quarter"), container,
                    menu.onDrinkFluid, 0.25, playerObj, openingRecipe, item)
            end
        end
    end
end

Events.OnGameStart.Add(install)
