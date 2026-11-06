require 'RCE/Config'
-- Pure rules; engine and disk access live in the adapters.
RCE.Logic={}
local L=RCE.Logic
function L.initialize(state,hour,random)
    if state.version~=RCE.Config.version then
        assert(state.version==nil,'Unsupported expedition state version')
        state.version=RCE.Config.version;state.cycle=1;state.startedHour=hour
    end
    state.participants=state.participants or {}
    state.accounts=state.accounts or {}
    state.loot=state.loot or {delivered={},bonus={}}
    if not state.allocation then
        -- Uniform total 8..12; distribute remaining units into bounded groups.
        local a={lab=3,armory=3,clinic=1,pharmacy=1}
        local caps={lab=4,armory=4,clinic=2,pharmacy=2}
        local total=8+random(5)
        for i=9,total do
            local choices={}
            for _,g in ipairs({'lab','armory','clinic','pharmacy'}) do
                if a[g]<caps[g] then choices[#choices+1]=g end
            end
            local g=choices[random(#choices)+1];a[g]=a[g]+1
        end
        state.allocation=a;state.totalAmpoules=total
    end
    return state
end
-- Reset eligibility is evaluated offline on every restart, never by elapsed time.
function L.chooseEntry(state,random,online)
    local candidates={}
    for _,e in ipairs(RCE.Config.entries) do
        local occupied=false
        for _,p in ipairs(online or {}) do
            if p.z==e.z and RCE.distance2(e,p)<=(RCE.Config.clearRadius+2)^2 then occupied=true;break end
        end
        if not occupied then candidates[#candidates+1]=e end
    end
    if #candidates==0 then return nil end
    -- Prefer entries not reserved by another pending request.
    local unreserved={}
    for _,e in ipairs(candidates) do
        if not (state.reservations and state.reservations[e.id]) then unreserved[#unreserved+1]=e end
    end
    if #unreserved==0 then return nil end
    return unreserved[random(#unreserved)+1]
end
function L.validExit(pos,origin,hit)
    if hit then return false,'Hit' end
    if math.floor(pos.z)~=origin.z or RCE.distance2(pos,origin)>RCE.Config.exitRadius^2 then
        return false,'LeftExit'
    end
    return true
end
function L.containerKey(c)
    return table.concat({c.x,c.y,c.z,c.type,c.index or 0},':')
end
function L.planLoot(state,pools,random)
    if state.plan then return state.plan end
    local plan={}
    for _,group in ipairs({'lab','armory','clinic','pharmacy'}) do
        local candidates={};local seen={}
        for _,c in ipairs(pools[group] or {}) do
            -- One primary ampoule per square, even with stacked crates.
            local xyz=c.x..':'..c.y..':'..c.z
            if not seen[xyz] then candidates[#candidates+1]=c;seen[xyz]=true end
        end
        assert(#candidates>=state.allocation[group],'Not enough primary candidates: '..group)
        for i=1,state.allocation[group] do
            local at=random(#candidates)+1
            local c=table.remove(candidates,at)
            local k=c.x..':'..c.y..':'..c.z
            plan[k]={group=group,x=c.x,y=c.y,z=c.z,type=c.type,tile=c.tile}
        end
    end
    state.plan=plan;return plan
end
function L.bonus(state,key,random)
    if state.loot.bonus[key]==nil then state.loot.bonus[key]=random(1000000)<math.floor(RCE.Config.bonusChance*1000000) end
    return state.loot.bonus[key]
end
function L.findReturn(origin,valid,reachable,fallback)
    for _,radius in ipairs({0,5,15}) do
        local options={}
        for dx=-radius,radius do for dy=-radius,radius do
            local d=dx*dx+dy*dy
            if d<=radius*radius and (radius==0 or d>(radius==5 and 0 or 25)) then
                options[#options+1]={x=math.floor(origin.x)+dx,y=math.floor(origin.y)+dy,z=origin.z,d=d}
            end
        end end
        table.sort(options,function(a,b)
            if a.d~=b.d then return a.d<b.d end
            if a.x~=b.x then return a.x<b.x end
            return a.y<b.y
        end)
        for _,p in ipairs(options) do
            if valid(p) and reachable(origin,p) then return p,radius end
        end
    end
    if fallback and valid(fallback) then return RCE.copy(fallback),'fallback' end
    return nil,'NoSafeReturn'
end
