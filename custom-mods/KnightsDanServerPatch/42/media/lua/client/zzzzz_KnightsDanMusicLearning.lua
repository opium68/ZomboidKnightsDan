-- Add 20 outcomes to Lifestyle's 200-outcome learning roll (+10 percentage
-- points). Preserve its eligible-song lists, cooldown, XP and failure checks.
if getActivatedMods and getActivatedMods():contains("LifestyleHobbies") then
    require "TimedActions/PlayInstrumentTraining"
    if PlayInstrumentTraining and not PlayInstrumentTraining.KD_learningBoost then
        local originalStart = PlayInstrumentTraining.start
        function PlayInstrumentTraining:start(...)
            local result = originalStart(self, ...)
            self.sandboxAddChance = (self.sandboxAddChance or 0) + 20
            return result
        end
        PlayInstrumentTraining.KD_learningBoost = true
        print("[KD_MUSIC_LEARNING] learning roll bonus +20/200")
    end
end
