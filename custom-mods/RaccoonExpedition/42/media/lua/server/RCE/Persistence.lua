require 'RCE/Server'
RCE.Persistence={initialized=setmetatable({},{__mode='k'}),dead=setmetatable({},{__mode='k'}),last=0}
local P=RCE.Persistence
local fields={'saveVersion','level','xp','xpNext','totalXP','skillPoints','resetPoints','spentPoints',
    'geneSpentPoints','geneEdits','geneEditSeq','resetEarnedTotal','nodes','ui'}
function P.save(player,dead)
    if not player or not RCE.Server.ready or not P.initialized[player] then return end
    local key=RCE.key(player);local state=RCE.Server.store()
    local saved=state.accounts[key] or {};local d=player:getModData().RPGSkillTree
    if type(d)=='table' then
        saved.rpg={};for _,field in ipairs(fields) do saved.rpg[field]=RCE.copy(d[field]) end
    end
    if RCENativePerks then saved.perks=RCENativePerks(player) end
    saved.savedHour=RCE.Server.hour();state.accounts[key]=saved
    -- Never persist vault contents in the account-level growth backup.
    if dead then player:getModData().ProjectRPGDimensionalVault=nil end
end
function P.restore(player)
    if P.initialized[player] then return end
    if not RCENativeRestorePerks then return end
    local md=player:getModData();local saved=RCE.Server.store().accounts[RCE.key(player)]
    -- Only a NEW character inherits an account's growth. Existing living
    -- characters retain their own data instead of being rolled back on login.
    if saved and not md.RCEGrowthIdentity then
        -- Native MP restore can be deferred until the connection exists.
        -- Keep the character unmarked so the next server poll retries it.
        if saved.perks and RCENativeRestorePerks(player,saved.perks)~=true then return false end
        if saved.rpg then md.RPGSkillTree=RCE.copy(saved.rpg) end
        md.ProjectRPGDimensionalVault=nil
        if saved.rpg and saved.rpg.geneEdits then
            -- The upstream generator adds RCEApplyGeneEdits using its native
            -- trait lookup, so purchased edits survive without copying all traits.
            if RCEApplyGeneEdits then RCEApplyGeneEdits(player,saved.rpg.geneEdits) end
        end
    end
    md.RCEGrowthIdentity=true;P.initialized[player]=true
    player:transmitModData()
    if RCERequestRPGSync then RCERequestRPGSync(player) end
    return true
end
function P.processPlayer(player)
    if not player:isDead() then
        P.restore(player);P.save(player)
    elseif not P.dead[player] then
        P.save(player,true);P.dead[player]=true
        local record=RCE.Server.store().participants[RCE.key(player)]
        if record then record.inside=false;record.dead=true end
    end
end
function P.tick()
    if not RCE.Server.ready or RCE.Server.now()-P.last<5 then return end
    P.last=RCE.Server.now()
    local list=getOnlinePlayers()
    for i=0,list:size()-1 do
        local player=list:get(i)
        P.processPlayer(player)
    end
end
Events.OnTick.Add(P.tick)
Events.OnSave.Add(function()
    if not RCE.Server.ready then return end
    local list=getOnlinePlayers()
    for i=0,list:size()-1 do P.save(list:get(i)) end
end)
Events.AddXP.Add(function(player)
    if player and P.initialized[player] then P.save(player) end
end)
