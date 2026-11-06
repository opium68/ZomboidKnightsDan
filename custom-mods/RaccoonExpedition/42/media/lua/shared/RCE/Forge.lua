require 'RCE/Config'
RCE.Forge={chance=0.005,item='RPGSkillTree.Randombox_Normal'}
local F=RCE.Forge
function F.unlocked(player)
 local md=player and player:getModData()
 local st=md and md.RPGSkillTree
 return st and st.nodes and st.nodes.MemoryStone==true or false
end
function F.isItem(item)
 local ft=item and item:getFullType()
 return ft=='RPGSkillTree.Randombox_Normal' or ft=='RPGSkillTree.Randombox_Rare' or ft=='RPGSkillTree.Randombox_Legendary'
end
function F.probability(player)
 if not F.unlocked(player) then return 0 end
 return require('RPG_Shared_ItemFindChance').boost(F.chance,player)
end
