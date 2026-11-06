-- Project RPG 1.10.00: the server owns item validation, consumption and rewards.
local Elixirs=require 'RPG_Shared_GrowthElixirs'
local State=require 'RPG_Server_State'
local Commands=require 'RPG_Server_Commands'
local Levels=require 'RPG_Server_LevelTable'
local Cure=require 'RPG_Shared_MythicElixir'
local Server={}

local function reply(player,args)
    if not Elixirs.inMP() then
        if triggerEvent then triggerEvent('OnServerCommand',Elixirs.MODULE,'ElixirResult',args) end
    elseif player and sendServerCommand then
        sendServerCommand(player,Elixirs.MODULE,'ElixirResult',args)
    end
end
local function fail(player,id,code)
    reply(player,{ok=false,itemId=id,code=code,
        playerNum=player and player.getPlayerNum and player:getPlayerNum() or 0})
    return false
end
local function syncRemove(player,container,item)
    if not Elixirs.inMP() then return end
    local ok=false
    if player.sendRemoveItemFromContainer then
        ok=pcall(function() player:sendRemoveItemFromContainer(container,item) end)
    end
    if not ok and sendRemoveItemFromContainer then
        pcall(function() sendRemoveItemFromContainer(container,item) end)
    end
end
function Server.use(player,args)
    -- This handler never runs on an MP client's local inventory/state.
    if isClient and isClient() and not (isServer and isServer()) then return false end
    if not player or type(args)~='table' or not Elixirs.validId(args.itemId) then return false end
    local id=args.itemId
    if player.isDead and player:isDead() then return fail(player,id,'Dead') end
    local item,container=Elixirs.findOwnedItem(player,id)
    if not item then return fail(player,id,'Missing') end
    local fullType=item.getFullType and item:getFullType()
    local definition=Elixirs.definition(fullType)
    if not definition then return fail(player,id,'Invalid') end
    if definition.kind=='xp' or definition.kind=='sp' then return fail(player,id,'Disabled') end
    -- Unlike growth items, a mythic cure never requires progression data.
    local d=nil
    if definition.kind=='cure' then
        if not Cure.isSupported(player) then return fail(player,id,'NotReady') end
    else
        d=State.Ensure(player)
        if not d then return fail(player,id,'NotReady') end
    end
    if definition.kind=='level' and d.level>=Levels.MAX_LEVEL then
        return fail(player,id,'MaximumLevel')
    end
    -- Consume this exact instance first; a replay of its ID cannot grant a
    -- second reward. A failed removal never grants XP/levels/points.
    local removed=pcall(function() container:Remove(item) end)
    if not removed or Elixirs.findOwnedItem(player,id) then return fail(player,id,'ConsumeFailed') end
    syncRemove(player,container,item)
    if definition.kind=='cure' then
        local ok,cured=pcall(Cure.apply,player)
        if not ok or cured~=true then
            -- Never permanently consume an elixir if recovery failed.
            -- Reinsert the original item object, retaining its metadata.
            local refunded=pcall(function() container:AddItem(item) end)
            if refunded and Elixirs.inMP() and player.sendAddItemToContainer then
                pcall(function() player:sendAddItemToContainer(container,item) end)
            end
            print('[Project RPG][MythicElixir] Recovery failed, refund attempted: '..tostring(cured))
            return fail(player,id,'CureFailed')
        end
    elseif definition.kind=='xp' then
        -- Fixed amounts, no skill/equipment XP multipliers. Reuse normal
        -- progression, level rollover and cumulative-XP RP calculations.
        Commands.GiveXP(player,definition.amount)
    else
        if definition.kind=='level' then
            d.level=d.level+1
            d.skillPoints=d.skillPoints+1 -- same SP reward as a normal level-up
            d.xpNext=Levels.GetRequiredXP(d.level)
        elseif definition.kind=='sp' then
            d.skillPoints=d.skillPoints+1
        elseif definition.kind=='rp' then
            d.resetPoints=d.resetPoints+1
        end
        -- Level/SP/RP elixirs do not modify current XP or cumulative XP.
        Commands.RequestSync(player)
    end
    if RCE and RCE.Persistence then RCE.Persistence.save(player) end
    reply(player,{ok=true,itemId=id,fullType=fullType,
        playerNum=player.getPlayerNum and player:getPlayerNum() or 0})
    return true
end
-- One authoritative bulk request: consume only the clicked elixir's XP type.
-- The client supplies an item ID, never an XP amount or quantity.
function Server.useAll(player,args) if true then return false end
    if isClient and isClient() and not (isServer and isServer()) then return false end
    if not player or type(args)~='table' or not Elixirs.validId(args.itemId) then return false end
    local id=args.itemId
    local function bulkFail(code)
        reply(player,{ok=false,itemId=id,bulk=true,code=code,
            playerNum=player and player.getPlayerNum and player:getPlayerNum() or 0})
        return false
    end
    if player.isDead and player:isDead() then return bulkFail('Dead') end
    local selected=Elixirs.findOwnedItem(player,id)
    if not selected then return bulkFail('Missing') end
    local fullType=selected.getFullType and selected:getFullType()
    local definition=Elixirs.definition(fullType)
    if not definition or definition.kind~='xp' then return bulkFail('Invalid') end
    if not State.Ensure(player) then return bulkFail('NotReady') end

    local entries=Elixirs.findOwnedItemsOfType(player,fullType)
    local consumed=0
    for _,entry in ipairs(entries) do
        local item,container=entry.item,entry.container
        local itemId=item and item.getID and item:getID()
        -- Recheck ownership before every removal; duplicate/replayed commands
        -- can never award XP for an item already consumed.
        if Elixirs.validId(itemId) then
            local owned,actualContainer=Elixirs.findOwnedItem(player,itemId)
            if owned==item and actualContainer==container then
                local ok=pcall(function() container:Remove(item) end)
                if ok and not Elixirs.findOwnedItem(player,itemId) then
                    consumed=consumed+1
                    syncRemove(player,container,item)
                end
            end
        end
    end
    if consumed==0 then return bulkFail('ConsumeFailed') end
    local amount=consumed*definition.amount
    Commands.GiveXP(player,amount)
    reply(player,{ok=true,bulk=true,itemId=id,fullType=fullType,
        count=consumed,amount=amount,
        playerNum=player.getPlayerNum and player:getPlayerNum() or 0})
    return true
end
Events.OnClientCommand.Add(function(module,command,player,args)
    if module~=Elixirs.MODULE then return end
    if command=='UseElixir' then Server.use(player,args)
    elseif command=='UseAllElixirs' then Server.useAll(player,args) end
end)
-- SP has no network server. Use the identical handler without a client grant.
RPG_SP_UseGrowthElixir=function(player,args)
    if Elixirs.inMP() then return false end
    Server.use(player,args)
    return true
end
-- SP uses the same server-owned bulk handler, without network packets.
RPG_SP_UseAllGrowthElixirs=function(player,args)
    if Elixirs.inMP() then return false end
    return Server.useAll(player,args)
end
return Server
