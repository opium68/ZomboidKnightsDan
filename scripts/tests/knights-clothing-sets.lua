require "KnightsDan/ClothingShop"
local K=KnightsDan
local count=0
for id,definition in pairs(K.clothingSets) do
    count=count+1
    if definition.family=="vanguard" then
        local colour=id:match("_([^_]+)$")
        local expected="Base.Military_FullHelmet_Vanguard-"..colour:sub(1,1):upper()..colour:sub(2)
        local helmet=false
        for _,part in ipairs(definition.items) do
            assert(not part:find("Base.Military_Helmet_Defender-",1,true),"Vanguard must not include Defender helmet")
            if part==expected then helmet=true end
        end
        assert(helmet and definition.price==225000,"matching NV helmet and unchanged price")
    end
    local contents,md={},{}
    local inventory={
        AddItem=function(_,name)
            local item={id=name,texture=-1}
            function item:getVisual() return {setTextureChoice=function(_,value) item.texture=value end} end
            contents[#contents+1]=item
            return item
        end,
        Remove=function(_,item) for n=#contents,1,-1 do if contents[n]==item then table.remove(contents,n) end end end,
    }
    local package={getFullType=function() return id end,getModData=function() return md end,getInventory=function() return inventory end}
    K.createClothingSet(package)
    assert(#contents==#definition.items and md.knightsClothingSetFilled)
    for n,item in ipairs(contents) do assert(item.id==definition.items[n] and item.texture==0) end
    K.createClothingSet(package)
    assert(#contents==#definition.items,"repeat callback must not duplicate contents")
end
assert(count==25)
for _,offer in ipairs(K.shopItems) do assert(not K.individualClothingItems[offer.id],"individual clothing must not flood shop") end
PZLinuxDarkWebItemsTable={{id={"Base.Apple","Base.MT_Nano_Helmet"},Price=5},{id={"Base.MT_Nano_Bot"},Price=1}}
K.removeIndividualClothingOffers()
assert(#PZLinuxDarkWebItemsTable==1 and #PZLinuxDarkWebItemsTable[1].id==1)
assert(PZLinuxDarkWebItemsTable[1].id[1]=="Base.Apple")
K.removeIndividualClothingOffers()
local md={};local contents={}
local package={getFullType=function() return "KnightsDan.ClothingSet_black_multicam" end,getModData=function() return md end,
    getInventory=function() return {AddItem=function(_,id)
        if #contents==1 then return nil end
        local item={getVisual=function() return nil end};contents[#contents+1]=item;return item
    end,Remove=function() table.remove(contents) end} end}
assert(not pcall(K.createClothingSet,package) and #contents==0 and not md.knightsClothingSetFilled)
return "25 complete packages, texture choice 0, repeat-safe creation, component failure rollback, individual offer purge"
