require "PZLinux/PZLinuxMissionLocations"
assert(#PZLinuxGetMissionLocationPool("manhunt")==1,"expected installed single-location baseline")
local before = {}
for _,name in ipairs({"packages","cargo","protect","vehicles"}) do
    before[name]=#PZLinuxGetMissionLocationPool(name)
end
local board={cityId=9,locationX=10609,locationY=9221,status="accepted"}
PZLinux.contractPreviews={existing=board}
require "zzzz_KnightsDanManhuntLocations"
local locations=PZLinuxGetMissionLocationPool("manhunt")
local cities=PZLinuxGetMissionLocationCityIds("manhunt")
assert(#locations==16 and #cities==7)
assert(PZLinux.MissionLocations.templates.manhunt.enabled==false)
assert(PZLinux.contractPreviews.existing==board and board.cityId==9 and board.status=="accepted")
for name,count in pairs(before) do assert(#PZLinuxGetMissionLocationPool(name)==count) end
-- Exercise native city and target selection for every enabled city/location.
local selected=0
for i,city in ipairs(cities) do
    ZombRand=function(n) assert(n==#cities); return i-1 end
    assert(PZLinuxGetRandomContractCityId(3)==city)
    local cityLocations=PZLinuxGetMissionLocationPool("manhunt",city)
    for j,entry in ipairs(cityLocations) do
        ZombRand=function(n) assert(n==#cityLocations); return j-1 end
        assert(PZLinuxGetRandomMissionLocation("manhunt",city).id==entry.id)
        selected=selected+1
    end
end
assert(selected==16)
print("PASS installed native location/city selection: 1 -> 16 manhunt locations in 7 cities; other pools/templates/existing contracts preserved")

-- Run the installed mission builder, including coordinates, note and reward.
-- Text/name/economy presentation helpers are controlled fixtures here.
require "PZLinux/PZLinuxContractMission"
PZLinux.Economy={roundPrice=function(n) return math.floor(n+0.5) end}
PZLinuxContractsRandomTargetName=function() return "Verification target" end
PZLinuxFormatFloorLabel=function(z) return "Floor "..tostring(z) end
local built=0
for _,city in ipairs(cities) do
    local entries=PZLinuxGetMissionLocationPool("manhunt",city)
    for i,entry in ipairs(entries) do
        ZombRand=function(n) assert(n==#entries); return i-1 end
        local mission,err=PZLinuxContractsBuildMission({id=3,cityId=city,code="TEST",questName="Eliminate the target",difficulty=3,reward=20000})
        assert(mission,err)
        assert(mission.locationId==entry.id and mission.locationPool=="manhunt")
        assert(mission.locationX==entry.x and mission.locationY==entry.y and mission.locationZ==(entry.z or 0))
        assert(mission.locationCity==entry.city and mission.reward==20000)
        assert(mission.targetName=="Verification target" and #mission.fullNote>0)
        assert(string.find(mission.fullNote,entry.city,1,true))
        built=built+1
    end
end
assert(built==16)
print("PASS native mission builder: 16/16 matching coordinates/cities, target, note and unchanged reward")
