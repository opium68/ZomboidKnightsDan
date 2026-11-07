require 'RaccoonCityPoliceDecryption'
getText=function(s)return s end
IsoObject={new=function()return {} end}
local good,bad=0,0
HaloTextHelper={addGoodText=function()good=good+1 end,addBadText=function()bad=bad+1 end}
for _,client in ipairs({true,false}) do
 isClient=function()return client end
 sendClientCommand=function()error('Unexpected badge spawn RPC')end
 addZombiesInOutfit=function()error('Unexpected badge spawn')end
 local items={}
 for _,name in ipairs({'UnicornBadge','MaidenBadge','LionBadge'})do
  local kind=name;items[#items+1]={getType=function()return kind end}
 end
 local inv={getItems=function()return {size=function()return #items end,get=function(_,i)return items[i+1]end}end}
 function inv:getItemFromType(name)for _,v in ipairs(items)do if v:getType()==name then return v end end end
 function inv:DoRemoveItem(item)for i,v in ipairs(items)do if v==item then table.remove(items,i);return end end end
 local p={getX=function()return 10218 end,getY=function()return 10384 end,getZ=function()return 0 end,getInventory=function()return inv end,getEmitter=function()return {playSoundImpl=function()end}end}
 getSpecificPlayer=function()return p end
 local removed,added={},{}
 RaccoonCityPoliceDecryption.RemoveSprite=function(_,x,y,z,s)removed[x..','..y..','..z..':'..s]=true end
 RaccoonCityPoliceDecryption.AddSprite=function(_,x,y,z,s)added[x..','..y..','..z..':'..s]=true end
 RaccoonCityPoliceDecryption.onClickPut(0,nil)
 assert(#items==0,'Badges consumed')
 assert(not removed['10223,10380,3:d_shisan_cannotdamaged_16'],'Armory is server-owned')
 local stairs=0;for k in pairs(added)do if string.find(k,'fixtures_stairs',1,true)then stairs=stairs+1 end end
 assert(stairs==6,'All stairs opened')
 RaccoonCityPoliceDecryption.onClickPut(0,nil)
end
assert(good==2 and bad==2)
print('RPD_BADGE_PASS actual handler: MP/SP, badges consumed, six stairs and armory opened, zero extra zombies, missing badges rejected')
