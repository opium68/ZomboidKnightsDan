-- Project RPG 1.00.54: data schema and server-authoritative box catalog.
-- Custom boxes reuse the existing physical Randombox_Normal item, marked by
-- modData.rpgBoxId. No runtime script registration is required.
local Loot = require('RPG_Shared_RandomboxLoot')
local Chance = require('RPG_Shared_RandomboxChance')
local ItemFind = require('RPG_Shared_ItemFindChance')
local Catalog = {}
Catalog.KEY = 'ProjectRPG_AdminBoxes_1'
Catalog.PHYSICAL = 'RPGSkillTree.Randombox_Normal'
Catalog.MAX_BOXES = 60
Catalog.MAX_REWARDS = 80
Catalog.TIERS = {'Normal','Rare','Legendary','Mythic'}
function Catalog.rewardTier(row)
    if type(row)=='table' and (row.tier=='Normal' or row.tier=='Rare' or row.tier=='Legendary' or row.tier=='Mythic') then
        return row.tier
    end
    return Loot.getTier(type(row)=='table' and row.type or row)
end
local saved = nil
local function singleplayer()
    if type(isClient)=='function' and isClient() then return false end
    if type(isServer)=='function' and isServer() then return false end
    return not (type(isMultiplayer)=='function' and isMultiplayer())
end

local function finite(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return n
end
Catalog.finite = finite
local function random100() -- PZ random generator is preferable to Lua's unseeded PRNG
    if ZombRandFloat then return ZombRandFloat(0.0, 100.0) end
    if ZombRand then return ZombRand(100000000) / 1000000 end
    return math.random() * 100
end
local function defaultBox()
    local entries = {}
    local sum = 0
    for _, row in ipairs(Loot.POOL) do
        local chance = row.chance * 100
        entries[#entries+1] = {type=row.type, chance=chance, tier=Catalog.rewardTier(row)}
        sum = sum + chance
    end
    if sum > 0 then
        for _,row in ipairs(entries) do row.chance = row.chance * 100 / sum end
    end
    return {id='default',name='Original RPG Random Box',drop=Chance.getRate(),rewards=entries}
end
Catalog.defaultBox = defaultBox
local function copyBox(row)
    local b = {id=row.id,name=row.name,drop=row.drop,rewards={}}
    for _,r in ipairs(row.rewards or {}) do
        b.rewards[#b.rewards+1] = {type=r.type,chance=r.chance,tier=Catalog.rewardTier(r)}
    end
    return b
end
Catalog.copyBox = copyBox
local function initial()
    return {revision=1, boxes={defaultBox()}}
end

-- Never trust data from the client, including item IDs and probability totals.
function Catalog.validate(raw)
    if type(raw)~='table' then return nil,'Invalid box data' end
    local id = raw.id
    if type(id)~='string' or #id<1 or #id>36 or not id:match('^[%w_%-]+$') then
        return nil,'Box ID must be 1-36 letters, numbers, _ or -'
    end
    local name = raw.name
    if type(name)~='string' or #name<1 or #name>96 or name:find('[\r\n]') then
        return nil,'Box name must be 1-96 bytes on one line'
    end
    local drop = finite(raw.drop)
    if not drop or drop<0 or drop>100 then return nil,'Drop chance must be between 0 and 100' end
    if type(raw.rewards)~='table' or #raw.rewards<1 or #raw.rewards>Catalog.MAX_REWARDS then
        return nil,'Box must contain 1-80 rewards'
    end
    local rewards, sum = {},0
    for i,entry in ipairs(raw.rewards) do
        if type(entry)~='table' or type(entry.type)~='string'
                or #entry.type>130 or not entry.type:match('^[%w_]+%.[%w_]+$') then
            return nil,'Invalid FullType in reward '..i
        end
        local weight = finite(entry.chance)
        if not weight or weight<=0 or weight>100 then
            return nil,'Reward chance must be >0 and <=100 at row '..i
        end
        -- Valid PZ item (including loaded mod items); invalid IDs must not consume boxes.
        if getScriptManager and (not getScriptManager():FindItem(entry.type)) then
            return nil,'Unknown item: '..entry.type
        end
        if entry.tier~=nil and entry.tier~='Normal' and entry.tier~='Rare' and entry.tier~='Legendary' and entry.tier~='Mythic' then
            return nil,'Invalid reward tier at row '..i
        end
        rewards[#rewards+1]={type=entry.type,chance=weight,tier=Catalog.rewardTier(entry)}
        sum=sum+weight
    end
    if math.abs(sum-100)>0.011 then
        return nil,string.format('Reward rates total %.4f%% (must be 100%%)',sum)
    end
    -- Normalize tiny floating point rounding errors.
    for _,entry in ipairs(rewards) do entry.chance=entry.chance*100/sum end
    return {id=id,name=name,drop=drop,rewards=rewards}
end

function Catalog.load()
    -- 1.00.78: SP must use the current world's registered table, not an
    -- early temporary table or a reference retained from a previous world.
    -- Leave multiplayer's existing catalog/cache behavior unchanged.
    local sp=singleplayer()
    if saved and not sp then return saved end
    if not ModData or not ModData.getOrCreate then
        if sp then return initial() end
        saved=initial(); return saved
    end
    saved=ModData.getOrCreate(Catalog.KEY)
    if type(saved.boxes)~='table' then saved.boxes=initial().boxes end
    if #saved.boxes==0 then saved.boxes={defaultBox()} end
    if not finite(saved.revision) then saved.revision=1 end
    -- The default box must always remain available for legacy inventory items.
    local found=false
    for _,b in ipairs(saved.boxes) do if b.id=='default' then found=true;break end end
    if not found then table.insert(saved.boxes,1,defaultBox()) end
    -- WIP pool revision 6: Normal Skeleton Key (three unlock charges). Refresh only the default box;
    -- custom user-created boxes and their reward tables are not touched.
    if saved.defaultRewardVersion ~= 6 then
        for _,box in ipairs(saved.boxes) do
            if box.id == 'default' then
                box.rewards=defaultBox().rewards
                -- Correct old pre-release 2.11% persisted default, not custom rates.
                if finite(box.drop) and math.abs(box.drop-2.11)<0.00001 then
                    box.drop=Chance.getRate()
                end
                break
            end
        end
        saved.defaultRewardVersion=6
        saved.revision=saved.revision+1
    end
    -- Remove the previously auto-inserted jump box from existing DEFAULT
    -- catalogs once. Custom boxes and their administrator-defined loot stay intact.
    if saved.jumpRewardVersion ~= 3 then
        for _,box in ipairs(saved.boxes) do
            if box.id=='default' then
                local kept={}
                local removed=false
                local mythicSum,otherSum=0,0
                for _,r in ipairs(box.rewards or {}) do
                    if r.type==Loot.JUMP_BOX_TYPE then
                        removed=true
                    else
                        kept[#kept+1]=r
                        local n=finite(r.chance) or 0
                        if r.type==Loot.MYTHIC_TYPE or r.type==Loot.FROST_BACKPACK_TYPE
                            or r.type==Loot.SCOUT_ARTIFACT_TYPE then
                            mythicSum=mythicSum+n
                        else
                            otherSum=otherSum+n
                        end
                    end
                end
                if removed then
                    if otherSum>0 and mythicSum<100 then
                        -- Reverse the old insertion: preserve mythic odds and
                        -- redistribute only among the remaining non-mythic rewards.
                        local scale=(100-mythicSum)/otherSum
                        for _,r in ipairs(kept) do
                            if r.type~=Loot.MYTHIC_TYPE and r.type~=Loot.FROST_BACKPACK_TYPE
                                and r.type~=Loot.SCOUT_ARTIFACT_TYPE then
                                r.chance=(finite(r.chance) or 0)*scale
                            end
                        end
                    elseif otherSum+mythicSum>0 then
                        -- Admin-made mythic-only catalog: avoid a probability gap.
                        for _,r in ipairs(kept) do
                            r.chance=(finite(r.chance) or 0)*100/(otherSum+mythicSum)
                        end
                    else
                        kept=defaultBox().rewards
                    end
                    box.rewards=kept
                    saved.revision=saved.revision+1
                end
                break
            end
        end
        saved.jumpRewardVersion=3
    end
    return saved
end
function Catalog.list()
    local result = {}
    for _,b in ipairs(Catalog.load().boxes) do result[#result+1]=copyBox(b) end
    return result
end
function Catalog.get(id)
    id = type(id)=='string' and id or 'default'
    for _,b in ipairs(Catalog.load().boxes) do if b.id==id then return b end end
    return nil
end
function Catalog.revision() return Catalog.load().revision end

function Catalog.save(raw, expectedRevision)
    if singleplayer() and (not ModData or not ModData.getOrCreate) then
        return false,'World save data is not ready; reopen the editor after loading'
    end
    local db=Catalog.load()
    if finite(expectedRevision) ~= db.revision then return false,'Catalog was changed: refresh before saving' end
    local box,err=Catalog.validate(raw)
    if not box then return false,err end
    local pos
    for i,b in ipairs(db.boxes) do if b.id==box.id then pos=i;break end end
    if not pos and #db.boxes>=Catalog.MAX_BOXES then return false,'Box limit reached' end
    local total=0
    for _,b in ipairs(db.boxes) do if b.id~=box.id then total=total+(finite(b.drop) or 0) end end
    if total+box.drop>100.00001 then return false,'Combined zombie drop chance exceeds 100%' end
    if pos then db.boxes[pos]=box else db.boxes[#db.boxes+1]=box end
    db.revision=db.revision+1
    return true
end
function Catalog.delete(id, expectedRevision)
    if singleplayer() and (not ModData or not ModData.getOrCreate) then
        return false,'World save data is not ready; reopen the editor after loading'
    end
    if id=='default' then return false,'The original box cannot be deleted' end
    local db=Catalog.load()
    if finite(expectedRevision) ~= db.revision then return false,'Catalog was changed: refresh before deleting' end
    for i,b in ipairs(db.boxes) do
        if b.id==id then
            table.remove(db.boxes,i)
            db.revision=db.revision+1
            return true
        end
    end
    return false,'Box not found'
end
function Catalog.rollRewardEntry(id, value)
    local box=Catalog.get(id)
    if not box then return nil end
    local roll=finite(value) or random100()
    roll=math.max(0,math.min(99.999999999,roll))
    local c=0
    for _,r in ipairs(box.rewards) do
        c=c+r.chance
        if roll<c then return r end
    end
    return box.rewards[#box.rewards]
end
function Catalog.rollReward(id, value)
    local entry=Catalog.rollRewardEntry(id,value)
    return entry and entry.type or nil
end
function Catalog.rollDrop(value, player) if true then return nil end
    local roll=finite(value) or random100()
    roll=math.max(0,math.min(99.999999999,roll))
    local boxes=Catalog.load().boxes
    local multiplier=ItemFind.multiplier(player)
    local total=0
    for _,box in ipairs(boxes) do total=total+(finite(box.drop) or 0) end
    -- Keep the relative editor odds even if the bonus would exceed 100% total.
    local scale=1
    if total*multiplier>100 then scale=100/(total*multiplier) end
    local c=0
    for _,box in ipairs(boxes) do
        c=c+(finite(box.drop) or 0)*multiplier*scale
        if roll<c then return box.id end
    end
    return nil
end
function Catalog.itemId(item)
    local ft=item and item.getFullType and item:getFullType()
    if ft~='RPGSkillTree.Randombox_Normal' and
        ft~='RPGSkillTree.Randombox_Rare' and
        ft~='RPGSkillTree.Randombox_Legendary' then return nil end
    if ft~='RPGSkillTree.Randombox_Normal' then return 'default' end
    local md=item.getModData and item:getModData()
    local id=md and md.rpgBoxId
    if type(id)~='string' or id=='' then return 'default' end
    return id
end
function Catalog.markItem(item,id)
    local box=Catalog.get(id)
    if not box or not item then return false end
    if id~='default' then
        item:getModData().rpgBoxId=id
        if item.setName then item:setName(box.name) end
    end
    return true
end
return Catalog
