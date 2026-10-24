local nativeRequire=require
ISBaseTimedAction={derive=function() return {} end,perform=function() end}
local songA={name="KnownSong",level=2,isaddon=0,sound="known",length=80}
local songB={name="LearnedSong",level=2,isaddon=0,sound="learned",length=90}
require=function(name)
    if name=="TimedActions/ISBaseTimedAction" or name=="Helper/TransferHelper" then return true end
    if string.find(name,"Tracks",1,true) then return {songA,songB} end
    return nativeRequire(name)
end
getActivatedMods=function() return {contains=function() return true end} end
isClient=function() return true end
getText=function(key) return key end
ZombRand=function() return 0 end
HaloTextHelper={addGoodText=function() end}
getSoundManager=function() return {playUISound=function() end} end
Perks={Music="Music"}
local data={other="untouched"}
local character={getModData=function() return data end,getPerkLevel=function() return 2 end,setReading=function() end}
local mapping={GuitarElectricBass="GuitarEBLearnedTracks",GuitarElectric="GuitarELearnedTracks",GuitarAcoustic="GuitarALearnedTracks",
    Banjo="BanjoLearnedTracks",Trumpet="TrumpetLearnedTracks",Keytar="KeytarLearnedTracks",Saxophone="SaxophoneLearnedTracks",
    Flute="FluteLearnedTracks",Harmonica="HarmonicaLearnedTracks",Violin="ViolinLearnedTracks",Piano="PianoLearnedTracks"}
local sent=0
sendClientCommand=function(player,module,command,args)
    assert(player==character and module=="LS" and command=="SavePlayerData")
    assert(args[1].other==nil)
    for key,songs in pairs(args[1]) do
        assert(string.find(key,"LearnedTracks",1,true))
        assert(#songs>0)
    end
    sent=sent+1
end
require "TimedActions/PlayInstrumentTraining"
require "TimedActions/PlayInstrumentActionNew"
require "TimedActions/LSSheetBookAction"
require "Instruments/VanillaInstrumentsContextMenu"
require "Instruments/NewInstrumentsContextMenu"
require "Instruments/InstrumentPianoContextMenu"
LSSync={updateClientData=function() end}
local function wipe() for _,key in pairs(mapping) do data[key]={} end end
local starts,ends=0,0
PlayInstrumentTraining.start=function(self) self.sandboxAddChance=5; return "training" end
PlayInstrumentTraining.stop=function() wipe(); return "training-stop" end
PlayInstrumentTraining.perform=function() wipe(); return "training-end" end
PlayInstrumentActionNew.start=function() starts=starts+1; return "start" end
PlayInstrumentActionNew.perform=function() ends=ends+1; wipe(); return "end" end
PlayInstrumentActionNew.stop=function() ends=ends+1; wipe(); return "stop" end
require "zzzzz_KnightsDanMusicLearning"
require "zzzzzz_KnightsDanBassPersistence"

local count=0
for kind,key in pairs(mapping) do
    wipe(); data[key]={songA}
    local action=setmetatable({character=character,instrumentType=kind,learnedTracksData={songA},
        PriorityToLearnLow={songB},PriorityToLearnMid={},PriorityToLearnHigh={},PriorityToLearnMaster={},
        instrumentSounds={songA,songB},playerLevel=2}, {__index=PlayInstrumentTraining})
    assert(action:start()=="training" and action.sandboxAddChance==25,"chance boost must compose")
    -- Replace current repertoire after start while the action holds its old list.
    data[key]={songA}
    action:learnSong()
    assert(action.learnedTracksData==data[key] and #data[key]==2,kind.." native learning")
    assert(action:perform()=="training-end" and #data[key]==2,kind.." training completion")
    assert(action:stop()=="training-stop" and #data[key]==2,kind.." training cancel")
    action.learnedOneSong=false; action.PriorityToLearnLow={songB}
    action:learnMidSong(); assert(#data[key]==2,kind.." no duplicate on terminal learning")
    for _,menu in ipairs({VanillaInstrumentsContextMenu,NewInstrumentsContextMenu,InstrumentPianoContextMenu}) do
        data[key]={}
        menu.onDebug(nil,character,kind,{songA},2)
        assert(#data[key]==2,kind.." native Learn All")
    end
    -- A performance must retain every instrument's existing repertoire.
    for _,otherKey in pairs(mapping) do data[otherKey]={songA,songB} end
    local play=setmetatable({character=character,instrumentType=kind},{__index=PlayInstrumentActionNew})
    assert(play:start()=="start" and play:perform()=="end")
    for _,otherKey in pairs(mapping) do assert(#data[otherKey]==2,kind.." cross-instrument retention") end
    play:start(); assert(play:stop()=="stop")
    for _,otherKey in pairs(mapping) do assert(#data[otherKey]==2) end
    assert(data.other=="untouched")
    count=count+1
end
-- Run original sheet reading: learn an eligible flute song, reject level 3.
wipe()
local locked={name="LockedSong",level=3,isaddon=0}
local sheet=setmetatable({character=character,actionType="isRead",sheetBookTracksData={{songB,"flute"},{locked,"flute"}}},
    {__index=LSSheetBookAction})
local before=sent
sheet:perform()
assert(#data.FluteLearnedTracks==1 and data.FluteLearnedTracks[1]==songB and sent==before+1)
assert(data.other=="untouched")
-- Unknown instruments do not acquire the retention behavior.
local other=setmetatable({character=character,instrumentType="Unknown"},{__index=PlayInstrumentActionNew})
other:perform(); assert(#data.FluteLearnedTracks==0)
assert(count==11)
print("PASS 11 instruments: native learning/debug/sheet; stale references; finish/cancel; cross-instrument retention; chance boost; level restrictions; narrow sync")
