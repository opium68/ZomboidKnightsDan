-- Filename retained so existing local installations replace the bass-only hook.
-- Preserve already-known songs; never grant new songs or change level/XP rules.
if not getActivatedMods or not getActivatedMods():contains("LifestyleHobbies") then return end
require "TimedActions/PlayInstrumentTraining"
require "TimedActions/PlayInstrumentActionNew"
require "TimedActions/LSSheetBookAction"
require "Instruments/VanillaInstrumentsContextMenu"
require "Instruments/NewInstrumentsContextMenu"
require "Instruments/InstrumentPianoContextMenu"

local keys = {
    GuitarElectricBass="GuitarEBLearnedTracks", GuitarElectric="GuitarELearnedTracks",
    GuitarAcoustic="GuitarALearnedTracks", Banjo="BanjoLearnedTracks",
    Trumpet="TrumpetLearnedTracks", Keytar="KeytarLearnedTracks",
    Saxophone="SaxophoneLearnedTracks", Flute="FluteLearnedTracks",
    Harmonica="HarmonicaLearnedTracks", Violin="ViolinLearnedTracks", Piano="PianoLearnedTracks",
}
local function merge(target, source)
    local known = {}
    local i = 1
    while i <= #target do
        local song = target[i]
        local id = song.name and (song.name .. ":" .. tostring(song.isaddon))
        if id and known[id] then
            table.remove(target, i)
        else
            if id then known[id] = true end
            i = i + 1
        end
    end
    for _, song in ipairs(source or {}) do
        if song.name then
            local id = song.name .. ":" .. tostring(song.isaddon)
            if not known[id] then target[#target+1] = song; known[id] = true end
        end
    end
    return target
end
local function restore(character, key, songs)
    local data = character:getModData()
    data[key] = merge(data[key] or {}, songs)
    return data[key]
end
local function snapshot(character)
    local copy = {}
    for _, key in pairs(keys) do
        local songs = character:getModData()[key]
        if songs and #songs > 0 then copy[key] = merge({}, songs) end
    end
    return copy
end
local function restoreAll(character, copy)
    for key, songs in pairs(copy or {}) do restore(character, key, songs) end
end
local function sync(character)
    if not isClient() then return end
    -- LS SavePlayerData merges supplied keys. Never send unrelated player data.
    local payload = snapshot(character)
    for _ in pairs(payload) do
        sendClientCommand(character, "LS", "SavePlayerData", {payload})
        break
    end
end
local function rebind(self)
    restoreAll(self.character, self.KD_songSnapshot)
    local key = keys[self.instrumentType]
    if key and self.learnedTracksData then
        self.learnedTracksData = restore(self.character, key, self.learnedTracksData)
    end
end
local function protectActions(class)
    if class.KD_songPersistence then return end
    local start = class.start
    class.start = function(self, ...)
        if keys[self.instrumentType] then
            self.KD_songSnapshot = snapshot(self.character)
            sync(self.character)
        end
        return start(self, ...)
    end
    for _, method in ipairs({"stop", "perform"}) do
        local original = class[method]
        class[method] = function(self, ...)
            if not keys[self.instrumentType] then return original(self, ...) end
            rebind(self)
            -- Include songs learned during this action as well as at its start.
            self.KD_songSnapshot = snapshot(self.character)
            local result = original(self, ...)
            rebind(self)
            sync(self.character)
            return result
        end
    end
    class.KD_songPersistence = true
end

if not PlayInstrumentTraining.KD_songLearningPersistence then
    for _, method in ipairs({"learnSong", "learnMidSong"}) do
        local original = PlayInstrumentTraining[method]
        PlayInstrumentTraining[method] = function(self, ...)
            if not keys[self.instrumentType] then return original(self, ...) end
            rebind(self)
            local result = original(self, ...)
            rebind(self)
            self.KD_songSnapshot = snapshot(self.character)
            sync(self.character)
            return result
        end
    end
    PlayInstrumentTraining.KD_songLearningPersistence = true
end
for _, menu in ipairs({VanillaInstrumentsContextMenu, NewInstrumentsContextMenu, InstrumentPianoContextMenu}) do
    if not menu.KD_songPersistence then
        local original = menu.onDebug
        menu.onDebug = function(objects, character, instrumentType, songs, level)
            local key = keys[instrumentType]
            if not key then return original(objects, character, instrumentType, songs, level) end
            local current = restore(character, key, songs)
            local result = original(objects, character, instrumentType, current, level)
            restore(character, key, current)
            sync(character)
            return result
        end
        menu.KD_songPersistence = true
    end
end
protectActions(PlayInstrumentTraining)
protectActions(PlayInstrumentActionNew)
if not LSSheetBookAction.KD_songPersistence then
    local original = LSSheetBookAction.perform
    LSSheetBookAction.perform = function(self, ...)
        local result = original(self, ...)
        if self.actionType == "isRead" then sync(self.character) end
        return result
    end
    LSSheetBookAction.KD_songPersistence = true
end
print("[KD_MUSIC_PERSISTENCE] 11 instruments: learning, sheet reading, debug and playback sync enabled")
