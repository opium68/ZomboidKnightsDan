require "KnightsDan/ClothingCombatSpeedIds"
local K=KnightsDan

function K.configureClothingCombatSpeed()
    local count=0
    for id,original in pairs(K.modClothingCombatSpeed) do
        if original<1 then
            local script=getScriptManager():FindItem(id)
            if script then
                script:DoParam('CombatSpeedModifier = 1')
                count=count+1
            end
        end
    end
    print('[KnightsDan] mod clothing combat speed penalties removed: '..count)
end

function K.restoreClothingCombatSpeed(item)
    if item and instanceof(item,'Clothing') and K.modClothingCombatSpeed[item:getFullType()]
        and item:getCombatSpeedModifier()<1 then
        item:setCombatSpeedModifier(1)
    end
end

local function updateWorn(player)
    if not player or not player.getWornItems then return end
    local worn=player:getWornItems()
    for i=0,worn:size()-1 do K.restoreClothingCombatSpeed(worn:get(i):getItem()) end
end

Events.OnGameBoot.Add(K.configureClothingCombatSpeed)
Events.OnClothingUpdated.Add(updateWorn)
Events.OnCreatePlayer.Add(function(_,player)
    updateWorn(player)
    if not player or not player.getInventory then return end
    local function visit(container)
        local items=container:getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            K.restoreClothingCombatSpeed(item)
            if instanceof(item,'InventoryContainer') then visit(item:getInventory()) end
        end
    end
    visit(player:getInventory())
end)
