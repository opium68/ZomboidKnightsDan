require 'RCE/Server'
require 'RCE/Pools'
RCE.Loot={}
local L=RCE.Loot
function L.initialize()
    RCE.Logic.planLoot(RCE.Server.store(),RCE.Pools,ZombRand)
end
local function info(container)
    local square=container and container:getSourceGrid()
    local parent=container and container:getParent()
    local sprite=parent and parent.getSprite and parent:getSprite()
    if not square or not sprite then return nil end
    local x,y,z=square:getX(),square:getY(),square:getZ()
    if not RCE.inside(x,y) then return nil end
    local kind,tile=container:getType(),sprite:getName()
    -- Corpses and virtual inventories may have a sprite with no tile name.
    if type(kind)~='string' or type(tile)~='string' or tile=='' then return nil end
    return {x=x,y=y,z=z,type=kind,tile=tile,parent=parent}
end
local function add(container)
    local item=container:AddItem(RCE.Config.ampoule)
    if not item then error('Growth ampoule definition unavailable') end
    if sendAddItemToContainer then sendAddItemToContainer(container,item) end
    if container.setDirty then container:setDirty(true) end
    return true
end
function L.fill(room,kind,container)
    if not RCE.Server.prepared then return end
    local c=info(container);if not c then return end
    local state=RCE.Server.store();local xyz=c.x..':'..c.y..':'..c.z
    local primary=state.plan and state.plan[xyz]
    if primary and c.type==primary.type and c.tile==primary.tile then
        if not state.loot.delivered[xyz] then
            add(container);state.loot.delivered[xyz]=true
            c.parent:getModData().RCEPrimaryCycle=state.cycle;c.parent:transmitModData()
        end
        return
    end
    -- Primary squares never receive another ampoule from the bonus system.
    if primary then return end
    local key=xyz..':'..c.type..':'..c.tile
    if not RCE.Pools.bonus[key] then return end
    state.loot.bonusDelivered=state.loot.bonusDelivered or {}
    if state.loot.bonusDelivered[key] then return end
    if RCE.Logic.bonus(state,key,ZombRand) then add(container) end
    state.loot.bonusDelivered[key]=true
end
function L.square(square)
    if not RCE.Server.ready or not RCE.inside(square:getX(),square:getY()) then return end
    local key=square:getX()..':'..square:getY()..':'..square:getZ()
    if not RCE.Server.store().plan[key] then return end
    local objects=square:getObjects()
    for i=0,objects:size()-1 do
        local obj=objects:get(i)
        for j=0,obj:getContainerCount()-1 do L.fill(nil,nil,obj:getContainerByIndex(j)) end
    end
end
local last=0
Events.OnTick.Add(function()
    if not RCE.Server.ready or RCE.Server.now()-last<2 then return end
    last=RCE.Server.now()
    for key,entry in pairs(RCE.Server.store().plan or {}) do
        if not RCE.Server.store().loot.delivered[key] then
            local sq=getCell():getGridSquare(entry.x,entry.y,entry.z)
            if sq then L.square(sq) end
        end
    end
end)
Events.OnFillContainer.Add(L.fill)
Events.LoadGridsquare.Add(L.square)
Events.OnZombieDead.Add(function(zombie)
    if not RCE.Server.ready or not zombie or not RCE.inside(zombie:getX(),zombie:getY()) then return end
    local outfit=zombie:getOutfitName()
    if outfit~='SpiffoKnew' then return end
    local md=zombie:getModData()
    if md.RCEAmpouleAwarded then return end
    local inv=zombie:getInventory()
    if inv and inv:AddItem(RCE.Config.ampoule) then md.RCEAmpouleAwarded=true end
end)
