-- Keep valid Neat Crafting behavior; tolerate unresolved recipe perks in UI only.
local warned = {}

local function hasMissingPerk(recipe)
    if not recipe then return false end
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        if not skill or not skill:getPerk() then return true end
    end
    return false
end

local function safeRows(self, recipe, isList)
    local rows = {}
    local name = recipe:getName()
    if not warned[name] then
        warned[name] = true
        print("[KnightsDan] Neat Crafting unresolved required perk: " .. tostring(name))
    end
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        local perk = skill and skill:getPerk()
        local level = skill and skill:getLevel() or "?"
        local perkName = perk and perk:getName() or getText("IGUI_KD_UnresolvedRecipeSkill")
        local text = (isList and "LV" or "- LV") .. tostring(level) .. " " .. tostring(perkName)
        if isList then
            text = NeatTool.truncateText(text, self.maxTextWidth, NC_UIScale.getBodyFont(), "...")
        end
        rows[#rows + 1] = {
            text = text,
            isMet = perk ~= nil and CraftRecipeManager.hasPlayerRequiredSkill(skill, self.player) or false,
            level = level,
            perkName = perkName,
        }
    end
    return rows
end

Events.OnGameStart.Add(function()
    if NC_RecipeList_Box and not NC_RecipeList_Box.knightsSafeSkills then
        local original = NC_RecipeList_Box.updateSkillTexts
        NC_RecipeList_Box.updateSkillTexts = function(self, ...)
            if self.entryType == "recipe" and hasMissingPerk(self.recipe) then
                self.skillTexts = safeRows(self, self.recipe, true)
                return
            end
            return original(self, ...)
        end
        NC_RecipeList_Box.knightsSafeSkills = true
    end
    if NC_RecipeInfoPanel and not NC_RecipeInfoPanel.knightsSafeSkills then
        local original = NC_RecipeInfoPanel.updateSkillRequirements
        NC_RecipeInfoPanel.updateSkillRequirements = function(self, recipe, ...)
            if hasMissingPerk(recipe) then
                self.skillRequirements = safeRows(self, recipe, false)
                return
            end
            return original(self, recipe, ...)
        end
        NC_RecipeInfoPanel.knightsSafeSkills = true
    end
end)
