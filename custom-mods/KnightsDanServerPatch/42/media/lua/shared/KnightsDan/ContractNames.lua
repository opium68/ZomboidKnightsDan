KnightsDanContractNames = {}
local entries = {
    {"Base.CarBattery3", "IGUI_KD_ContractPart_CarBattery3", "Battery: Resistant"},
    {"Base.CarBattery2", "IGUI_KD_ContractPart_CarBattery2", "Battery: Sport"},
    {"Base.CarBattery1", "IGUI_KD_ContractPart_CarBattery1", "Battery: Standard"},
    {"Base.ModernBrake3", "IGUI_KD_ContractPart_ModernBrake3", "Performance brakes: Resistant"},
    {"Base.ModernBrake2", "IGUI_KD_ContractPart_ModernBrake2", "Performance brakes: Sport"},
    {"Base.ModernBrake1", "IGUI_KD_ContractPart_ModernBrake1", "Performance brakes: Standard"},
    {"Base.ModernCarMuffler3", "IGUI_KD_ContractPart_ModernCarMuffler3", "Performance silencers: Resistant"},
    {"Base.ModernCarMuffler2", "IGUI_KD_ContractPart_ModernCarMuffler2", "Performance silencers: Sport"},
    {"Base.ModernCarMuffler1", "IGUI_KD_ContractPart_ModernCarMuffler1", "Performance silencers: Standard"},
    {"Base.ModernSuspension3", "IGUI_KD_ContractPart_ModernSuspension3", "Performance suspension: Resistant"},
    {"Base.ModernSuspension2", "IGUI_KD_ContractPart_ModernSuspension2", "Performance suspension: Sport"},
    {"Base.ModernSuspension1", "IGUI_KD_ContractPart_ModernSuspension1", "Performance suspension: Standard"},
    {"Base.NormalBrake3", "IGUI_KD_ContractPart_NormalBrake3", "Standard brakes: Resistant"},
    {"Base.NormalBrake2", "IGUI_KD_ContractPart_NormalBrake2", "Standard brakes: Sport"},
    {"Base.NormalBrake1", "IGUI_KD_ContractPart_NormalBrake1", "Standard brakes: Standard"},
    {"Base.NormalCarMuffler3", "IGUI_KD_ContractPart_NormalCarMuffler3", "Standard silencers: Resistant"},
    {"Base.NormalCarMuffler2", "IGUI_KD_ContractPart_NormalCarMuffler2", "Standard silencers: Sport"},
    {"Base.NormalCarMuffler1", "IGUI_KD_ContractPart_NormalCarMuffler1", "Standard silencers: Standard"},
    {"Base.NormalSuspension3", "IGUI_KD_ContractPart_NormalSuspension3", "Standard suspension: Resistant"},
    {"Base.NormalSuspension2", "IGUI_KD_ContractPart_NormalSuspension2", "Standard suspension: Sport"},
    {"Base.NormalSuspension1", "IGUI_KD_ContractPart_NormalSuspension1", "Standard suspension: Standard"},
    {"Base.Bandaid", "IGUI_KD_ContractPart_Bandaid", "Bandage: Adhesive"},
    {"Base.Bandage", "IGUI_KD_ContractPart_Bandage", "Bandage"},
    {"Base.AlcoholWipes", "IGUI_KD_ContractPart_AlcoholWipes", "Alcohol Wipes"},
    {"Base.Disinfectant", "IGUI_KD_ContractPart_Disinfectant", "Bottle of Disinfectant"},
    {"Base.AlcoholedCottonBalls", "IGUI_KD_ContractPart_AlcoholedCottonBalls", "Cotton Balls Doused in Alcohol"},
    {"Base.Antibiotics", "IGUI_KD_ContractPart_Antibiotics", "Antibiotics"},
    {"Base.PillsAntiDep", "IGUI_KD_ContractPart_PillsAntiDep", "Antidepressants"},
    {"Base.PillsBeta", "IGUI_KD_ContractPart_PillsBeta", "Beta Blockers"},
    {"Base.Pills", "IGUI_KD_ContractPart_Pills", "Painkillers"},
    {"Base.PillsSleepingTablets", "IGUI_KD_ContractPart_PillsSleepingTablets", "Sleeping Pills"},
    {"Base.PillsVitamins", "IGUI_KD_ContractPart_PillsVitamins", "Caffeine Pills"},
    {"Base.Pistol3", "IGUI_KD_ContractPart_Pistol3", "B-F Pistol"},
    {"Base.Pistol2", "IGUI_KD_ContractPart_Pistol2", "M1911 Pistol"},
    {"Base.Revolver_Short", "IGUI_KD_ContractPart_RevolverShort", "SN38 Revolver"},
    {"Base.Revolver", "IGUI_KD_ContractPart_Revolver", "Patrol Revolver"},
    {"Base.Pistol", "IGUI_KD_ContractPart_Pistol", "M9 Pistol"},
    {"Base.Revolver_Long", "IGUI_KD_ContractPart_RevolverLong", "Magnum"},
    {"Base.DoubleBarrelShotgun", "IGUI_KD_ContractPart_DoubleBarrelShotgun", "Double Barrel Shotgun"},
    {"Base.Shotgun", "IGUI_KD_ContractPart_Shotgun", "JS-2000 Shotgun"},
    {"Base.DoubleBarrelShotgunSawnoff", "IGUI_KD_ContractPart_DoubleBarrelShotgunSawnoff", "Sawed-off Double Barrel Shotgun"},
    {"Base.ShotgunSawnoff", "IGUI_KD_ContractPart_ShotgunSawnoff", "Sawed-off JS-2000 Shotgun"},
    {"Base.AssaultRifle2", "IGUI_KD_ContractPart_AssaultRifle2", "M1A Rifle"},
    {"Base.AssaultRifle", "IGUI_KD_ContractPart_AssaultRifle", "M16 Assault Rifle"},
    {"Base.VarmintRifle", "IGUI_KD_ContractPart_VarmintRifle", "MSR700 Rifle"},
    {"Base.HuntingRifle", "IGUI_KD_ContractPart_HuntingRifle", "MSR788 Rifle"},
}
function KnightsDanContractNames.name(fullType)
    for _, entry in ipairs(entries) do
        if entry[1] == fullType then
            local translated = getText and getText(entry[2])
            return translated and translated ~= entry[2] and translated or entry[3]
        end
    end
end

function KnightsDanContractNames.note(text)
    if type(text) ~= "string" then return text end
    for _, request in ipairs({{"Send a computer", "IGUI_KD_Contract_SendComputer"},
        {"Send a fridge", "IGUI_KD_Contract_SendFridge"}}) do
        local translated = getText and getText(request[2])
        if translated and translated ~= request[2] then
            text = text:gsub("%* %[[^%]]+%] " .. request[1] .. " for %$",
                function(matched)
                    return (matched:gsub(request[1], function() return translated end))
                end)
        end
    end
    -- Match an entire quantity line, not substrings of names or location text.
    return (text:gsub("([^\r\n]+)", function(line)
        local prefix, itemName = line:match("^(%* %d+ )(.-)%s*$")
        if not prefix then return line end
        for _, entry in ipairs(entries) do
            if itemName == entry[3] then
                return prefix .. KnightsDanContractNames.name(entry[1])
            end
        end
        return line
    end))
end
