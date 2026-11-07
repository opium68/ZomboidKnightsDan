Events.OnServerStarted.Add(function()
 assert(RCE.Forge and RCE.ForgeServer,'Forge server loaded')
 assert(math.abs(RCE.Forge.chance-0.005)<0.000001,'Base drop chance')
 local ember=instanceItem('RPGSkillTree.Randombox_Normal')
 assert(ember and ember:getScriptItem():getIcon()=='RCEThunderEmber','Ember script and icon')
 local bag=instanceItem('RPGSkillTree.HydrationBackpack_Mythic')
 print('[RCE_FORGE_NATIVE] bag before capacity='..tostring(bag and bag:getInventory():getCapacity())..' reduction='..tostring(bag and bag:getWeightReduction()))
 local testRoot={getItems=function()return {size=function()return 1 end,get=function()return bag end}end}
 RCE.BackpackPolicy.apply(testRoot)
 print('[RCE_FORGE_NATIVE] bag after capacity='..tostring(bag and bag:getInventory():getCapacity())..' reduction='..tostring(bag and bag:getWeightReduction()))
 assert(bag and bag:getInventory():getCapacity()==50 and bag:getWeightReduction()==99,'Native bag 50/99')
 print('[RCE_FORGE_NATIVE] PASS item/icon, bag 50/99, drop 0.5%, server handlers')
end)
-- Copied into the test profile only. Never in an operating mod/package.
local started,points,index,passed,at,primary
Events.OnServerStarted.Add(function()
    if not RCENativeKeep then print('[RCE_RUNTIME] FAIL native bridge missing');return end
    points={};for _,p in ipairs(RCE.Config.entries) do local q=RCE.copy(p);q.kind='entry';points[#points+1]=q end
    for _,p in ipairs(RCE.Config.exits) do local q=RCE.copy(p);q.kind='exit';points[#points+1]=q end
    for _,p in ipairs(RCE.Barrier.repairs) do local q=RCE.copy(p);q.kind='barrier';q.id='barrier-'..p.x..'-'..p.y;points[#points+1]=q end
    primary=0
    for _,p in pairs(RCE.Server.store().plan) do
        local q=RCE.copy(p);q.kind='loot';q.id='loot-'..q.group;points[#points+1]=q;primary=primary+1
    end
    index=1;passed=0;started=true;at=getTimestampMs()
    print('[RCE_RUNTIME] BEGIN')
end)
Events.OnTick.Add(function()
    local ok,err=pcall(function()
    if not started then return end
    local p=points[index]
    if not p then print('[RCE_RUNTIME] PASS entries='..#RCE.Config.entries..' exits='..#RCE.Config.exits..' primary='..primary);started=false;return end
    RCENativeKeep(p.x,p.y,17)
    if getTimestampMs()-at>120000 then error('RCE probe timeout: '..p.id) end
    if not RCENativeLoaded(p.x,p.y,p.z,17) then return end
    if p.kind=='barrier' then
        local sq=getCell():getGridSquare(p.x,p.y,p.z);assert(sq,'Repair square loaded')
        RCE.Barrier.square(sq);RCE.Barrier.square(sq)
        local o,count=nil,0
        for i=0,sq:getObjects():size()-1 do local v=sq:getObjects():get(i)
            if v:getSprite() and v:getSprite():getName()==p.sprite then o=v;count=count+1 end
        end
        assert(o and count==1,'Repair exists exactly once')
        assert(RCE.Barrier.protected(o),'Protected perimeter object')
        assert(not o:getProperties():has('CanScrap') and not o:getProperties():has('IsMoveAble'),'No scrap/pickup')
        local damage=o:getDamage();o:Damage(100000);assert(o:getDamage()==damage,'Native damage blocked')
        o:Thump(nil,1);o:destroyFence(IsoDirections.N)
        assert(sq:RemoveTileObject(o)==-1 and o:getObjectIndex()>=0,'Native removal blocked')
        assert(sq:transmitRemoveItemFromSquare(o)==-1 and o:getObjectIndex()>=0,'Network removal blocked')
        sq:Burn(false);assert(o:getObjectIndex()>=0 and o:getSprite():getName()==p.sprite,'Fire blocked')
        local normal=IsoObject.new(getCell(),sq,getSprite('carpentry_02_82'));sq:AddTileObject(normal)
        assert(not RCE.Barrier.protected(normal),'Ordinary object unprotected')
        assert(sq:RemoveTileObject(normal)>=0 and normal:getObjectIndex()==-1,'Ordinary removal preserved')
        print('[RCE_BARRIER_NATIVE] PASS '..p.x..','..p.y..' collision='..tostring(sq:getProperties():has(IsoFlagType.collideN) or sq:getProperties():has(IsoFlagType.collideW) or sq:getProperties():has(IsoFlagType.solidtrans)))
        index=index+1;passed=passed+1;at=getTimestampMs();return
    end
    if p.kind=='loot' then
        local sq=getCell():getGridSquare(p.x,p.y,p.z);RCE.Loot.square(sq)
        local count=0;local objects=sq:getObjects()
        for oi=0,objects:size()-1 do
            local obj=objects:get(oi)
            for ci=0,obj:getContainerCount()-1 do
                local inv=obj:getContainerByIndex(ci);local items=inv:getItems()
                for ii=0,items:size()-1 do if items:get(ii):getFullType()==RCE.Config.ampoule then count=count+1 end end
            end
        end
        if count~=1 then print('[RCE_RUNTIME] FAIL primary count='..count..' at '..p.x..','..p.y..','..p.z);started=false;return end
        print('[RCE_RUNTIME] PRIMARY '..p.group..' count=1 PASS')
        index=index+1;passed=passed+1;at=getTimestampMs();return
    end
    local good=RCENativeSafe(p.x,p.y,p.z,0)
    if not good and p.kind=='exit' then
        for dx=-5,5 do for dy=-5,5 do
            if dx*dx+dy*dy<=25 and RCENativeSafe(p.x+dx,p.y+dy,p.z,0) then good=true end
        end end
    end
    if not good then
        print('[RCE_RUNTIME] FAIL unsafe '..p.kind..' '..p.id..' '..RCENativeInspect(p.x,p.y,p.z));started=false;return
    end
    assert(RCENativeReachable(p.x,p.y,p.x,p.y,p.z),'Origin reachability')
    -- Exercise the native deletion path even in the zero-population profile.
    local removed=RCENativeClear(p.x,p.y,p.z,15)
    assert(type(removed)=='number','Clear result')
    print('[RCE_RUNTIME] POINT '..p.id..' floor/free/loaded PASS removed='..removed)
    index=index+1;passed=passed+1;at=getTimestampMs()
    end)
    if not ok then started=false;print('[RCE_RUNTIME] FAIL '..tostring(err))end
end)
