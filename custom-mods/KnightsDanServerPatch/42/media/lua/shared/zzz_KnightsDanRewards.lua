require "ISPZLinuxVariablesTables"
require "KnightsDan/Catalog"
local K=KnightsDan
local function blockedItem(id)
    return type(id)=="string" and (K.rewardItems[id] or K.rewardItems["Base."..id])
end
local function blockedVehicle(id)
    return type(id)=="string" and (K.rewardVehicles[id] or K.rewardVehicles["Base."..id])
end
local function blockedOutfit(name)
    return type(name)=="string" and (name:find("^Cerberus_") or name:find("^KATTAJ1_Army_"))
end
-- Distribution lists use alternating item/weight pairs. Purge recursively
-- without touching unrelated vanilla loot or already created possessions.
function K.purge(value,seen)
    if type(value)~="table" then return end
    seen=seen or {}; if seen[value] then return end; seen[value]=true
    if type(value.items)=="table" then
        local items=value.items
        for i=#items-1,1,-2 do
            if blockedItem(items[i]) then table.remove(items,i+1); table.remove(items,i) end
        end
    end
    for i=#value,1,-1 do
        local child=value[i]
        if type(child)=="table" and (blockedOutfit(child.name) or blockedVehicle(child.name)
            or blockedItem(child.item)) then table.remove(value,i) end
    end
    for key,child in pairs(value) do
        if blockedVehicle(key) or blockedOutfit(key) then value[key]=nil
        elseif type(child)=="table" then
            if type(child.weapons)=="table" then
                for i=#child.weapons,1,-1 do if blockedItem(child.weapons[i]) then table.remove(child.weapons,i) end end
                if #child.weapons==0 then child.chance=0 end
            end
            K.purge(child,seen)
        end
    end
end
local function purgeAll()
    for _,value in ipairs({ProceduralDistributions,SuburbsDistributions,Distributions,
        VehicleDistributions,VehicleZoneDistribution,AttachedWeaponDefinitions,ZombiesZoneDefinition}) do K.purge(value) end
    -- ipairs stops at nil: cover every optional root independently as well.
    K.purge(ProceduralDistributions); K.purge(SuburbsDistributions); K.purge(Distributions)
    K.purge(VehicleDistributions); K.purge(VehicleZoneDistribution)
    K.purge(AttachedWeaponDefinitions); K.purge(ZombiesZoneDefinition)
end
local function preventStartingGear()
    for _,name in ipairs({"LBO","LKO","LNO","LTWO"}) do
        local section=SandboxVars and SandboxVars[name]
        if type(section)=="table" then
            for name,value in pairs(section) do
                if type(name)=="string" and name:find("^StartWith") then section[name]=false end
            end
        end
    end
end
local function restrictRecipes()
    local manager=getScriptManager()
    local count=0
    for _,list in ipairs({manager:getAllCraftRecipes(),manager:getAllRecipes()}) do
        for i=0,list:size()-1 do
            local recipe=list:get(i)
            if K.blockedRecipes[recipe:getName()] then
                -- The engine enforces required skills on the server too.
                -- Level 99 is unreachable (normal skills stop at 10).
                recipe:addRequiredSkill(Perks.Carpentry,99)
                count=count+1
            end
        end
    end
    print("[KnightsDan] creation recipes restricted: "..tostring(count))
end
local function installCatalog()
    local manager=getScriptManager()
    local known={}
    for _,entry in ipairs(PZLinuxDarkWebItemsTable) do
        for _,id in ipairs(entry.id or {}) do known[id]=true end
    end
    local added=0
    for _,entry in ipairs(K.shopItems) do
        if manager:FindItem(entry.id) and not known[entry.id] then
            table.insert(PZLinuxDarkWebItemsTable,{id={entry.id},Price=entry.price})
            known[entry.id]=true; added=added+1
        elseif not manager:FindItem(entry.id) then error("KnightsDan catalog item missing: "..entry.id) end
    end
    local cars=PZLinuxRequestDefinitions[9].vehicles
    local existing={}; for _,car in ipairs(cars) do existing[car.baseName]=true end
    for _,entry in ipairs(K.shopVehicles) do
        if not manager:getVehicle(entry.id) then error("KnightsDan catalog vehicle missing: "..entry.id) end
        if not existing[entry.id] then table.insert(cars,{baseName=entry.id,delta=entry.price/PZLinuxRequestDefinitions[9].price}) end
    end
    print("[KnightsDan] reward catalog installed: "..tostring(added).." items, "..tostring(#K.shopVehicles).." vehicles")
end
Events.OnGameBoot.Add(function() preventStartingGear(); restrictRecipes(); installCatalog(); purgeAll() end)
Events.OnInitGlobalModData.Add(function() preventStartingGear(); purgeAll() end)
if Events.OnPreDistributionMerge then Events.OnPreDistributionMerge.Add(purgeAll) end
if Events.OnGameStart then Events.OnGameStart.Add(purgeAll) end
