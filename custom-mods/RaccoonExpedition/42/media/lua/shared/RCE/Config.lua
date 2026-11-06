RCE = RCE or {}
RCE.Config = {
    module='RaccoonExpedition', version=1,
    -- Whole map-asset extent. Includes exterior padding; never reset a smaller
    -- rectangle using this value without deriving every storage format's scope.
    bounds={x1=9728,y1=9728,x2=10496,y2=10752},
    resetPolicy='empty-on-restart', entrySeconds=10, exitSeconds=10, exitRadius=5,
    clearRadius=15, preparationTimeout=60, bonusChance=0.01,
    ampoule='RPGSkillTree.LevelUpElixir',
    entries={
        {id='garage',x=10049,y=10116,z=0},
        {id='house',x=9945,y=10111,z=0},
        {id='warehouse',x=10391,y=10138,z=0},
        {id='south',x=9981,y=10465,z=0},
        {id='bedroom',x=9960,y=10055,z=0},
        {id='east-house',x=10456,y=9961,z=0},
        {id='west-hall',x=9980,y=10133,z=0},
        {id='upper-warehouse',x=9967,y=10389,z=1},
    },
    exits={
        {id='north',x=10064,y=9908,z=0},
        {id='east',x=10484,y=10051,z=0},
        {id='southwest',x=9905,y=10490,z=0},
        {id='south',x=10270,y=10478,z=0},
    },
    -- No invented fallback destination. If origin/nearby squares fail, stay
    -- inside the expedition and report failure until an admin sets a fallback.
    fallback=nil,
    -- Candidate coordinates are statically checked, not playtest-approved.
    testedCoordinates=false,
}
function RCE.inside(x,y)
    local b=RCE.Config.bounds
    return x>=b.x1 and x<b.x2 and y>=b.y1 and y<b.y2
end
function RCE.distance2(a,b)
    return (a.x-b.x)^2+(a.y-b.y)^2
end
function RCE.copy(t)
    if type(t)~='table' then return t end
    local out={};for k,v in pairs(t) do out[k]=RCE.copy(v) end
    return out
end
function RCE.position(p) return {x=p:getX(),y=p:getY(),z=math.floor(p:getZ())} end
function RCE.key(p)
    -- Username is the persistent server account, independent of character ID.
    return p:getUsername()
end
function RCE.exitAt(pos)
    for _,e in ipairs(RCE.Config.exits) do
        if math.floor(pos.z)==e.z and RCE.distance2(pos,e)<=RCE.Config.exitRadius^2 then return e end
    end
end
