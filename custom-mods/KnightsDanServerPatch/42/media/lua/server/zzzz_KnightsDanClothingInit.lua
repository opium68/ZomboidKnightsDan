require "KnightsDan/ClothingShop"

-- Shared callbacks register before server callbacks. Militek and Haori add
-- distributions in server OnInitGlobalModData handlers, so purge again here.
Events.OnInitGlobalModData.Add(function()
    local K = KnightsDan
    K.purge(ProceduralDistributions)
    K.purge(SuburbsDistributions)
    K.purge(Distributions)
    K.purge(AttachedWeaponDefinitions)
    K.purge(ZombiesZoneDefinition)
end)
