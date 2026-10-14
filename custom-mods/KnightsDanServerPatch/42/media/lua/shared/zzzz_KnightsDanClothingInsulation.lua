require "KnightsDan/InsulationCaps"
local K=KnightsDan
function K.configureClothingInsulation()
    local count=0
    for id,cap in pairs(K.clothingInsulationCaps) do
        local script=getScriptManager():FindItem(id)
        if script and script:getInsulation()>cap then
            script:setInsulation(cap)
            count=count+1
        end
    end
    print('[KnightsDan] clothing insulation reduced: '..count)
end
function K.reduceItemInsulation(item)
    if not item or not instanceof(item,'Clothing') then return end
    local cap=K.clothingInsulationCaps[item:getFullType()]
    if cap and item:getInsulation()>cap then item:setInsulation(cap) end
end
local function updateWorn(player)
    if not player or not player.getWornItems then return end
    local worn=player:getWornItems()
    for i=0,worn:size()-1 do K.reduceItemInsulation(worn:get(i):getItem()) end
end
Events.OnGameBoot.Add(K.configureClothingInsulation)
Events.OnClothingUpdated.Add(updateWorn)
Events.OnCreatePlayer.Add(function(_,player)
    updateWorn(player)
    if player and player.getInventory then
        local function visit(container)
            local items=container:getItems()
            for i=0,items:size()-1 do
                local item=items:get(i)
                K.reduceItemInsulation(item)
                if instanceof(item,'InventoryContainer') then visit(item:getInventory()) end
            end
        end
        visit(player:getInventory())
    end
end)
