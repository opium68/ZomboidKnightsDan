require 'RCE/Server'
local S=RCE.Server
local function filename(kind)
    local name=getServerName()
    assert(name:match('^[%w_%-]+$'),'Unsupported server name for checkpoint')
    -- B42 permits .txt writes, but rejects .properties in getFileWriter.
    return 'RCE-'..name..'-'..kind..'.txt'
end
function S.checkpoint()
    if not S.ready then return end
    local state=S.store();local occupants=0
    for _,p in pairs(state.participants) do if p.inside and not p.dead then occupants=occupants+1 end end
    local w=getFileWriter(filename('checkpoint'),true,false)
    if not w then error('Cannot write expedition checkpoint') end
    w:write('version=1\nworld='..getServerName()..'\ncycle='..state.cycle..'\nstartedHour='..state.startedHour
        ..'\ncurrentHour='..S.hour()..'\nregistryOccupants='..occupants..'\nsavedAt='..getTimestamp()..'\n')
    w:close()
end
function S.applyResetInstruction()
    if S.resetInstructionChecked then return end
    local reader=getFileReader(filename('reset'),false)
    if not reader then S.resetInstructionChecked=true;return end
    local data={};local line=reader:readLine()
    while line do local k,v=line:match('^(%w+)=(.*)$');if k then data[k]=v end;line=reader:readLine() end
    reader:close()
    if data.version~='1' or data.world~=getServerName() then error('Invalid expedition reset instruction') end
    local state=S.store();local from=tonumber(data.fromCycle)
    if state.cycle==from then
        -- Keep account growth and historical return records, discard only the
        -- previous expedition's allocation, awards and area-specific flags.
        state.cycle=from+1;state.startedHour=S.hour();state.allocation=nil;state.plan=nil
        state.loot={delivered={},bonus={}};state.reservations={}
        local md=getGameTime():getModData()
        for _,k in ipairs({'BoxCount','RanList','JigsawCompleteNum','strPassWord','Katana','dabaojian','SamuraiEdgeNum','AdapterNum'}) do md[k]=nil end
        local cars=ModData.get('BasementPoliceCarSpawns')
        if cars then
            for key in pairs(cars) do
                local x,y=tostring(key):match('^(%d+),(%d+),')
                if x and RCE.inside(tonumber(x),tonumber(y)) then cars[key]=nil end
            end
        end
        print('[RCE] Applied offline reset instruction; cycle='..state.cycle)
    elseif state.cycle~=from+1 then error('Reset instruction cycle mismatch') end
    S.resetInstructionChecked=true
end
Events.OnSave.Add(S.checkpoint)
Events.OnServerFinishSaving.Add(S.checkpoint)
local last=0
Events.OnTick.Add(function()
    if not S.ready or S.now()-last<30 then return end
    last=S.now();S.checkpoint()
end)
