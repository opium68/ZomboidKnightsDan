-- RCE forging reward policy. Random-box opening stays disabled until forging ships.
local Loot={}
local ampoule='RPGSkillTree.LevelUpElixir'
local groups={
 Normal={
  {type='RPGSkillTree.Necklace_of_Strength_Normal'},
  {type=ampoule,count=1},
  {type='RPGSkillTree.SkeletonKey_Normal'},
 },
 Rare={
  {type='RPGSkillTree.Necklace_of_Strength_Rare'},
  {type=ampoule,count=3},
  {type='RPGSkillTree.Dew_Beaded_Ring_Rare'},
  {type='RPGSkillTree.Forest_Earrings_Rare'},
  {type='RPGSkillTree.Salvation_BraceletLeft_Rare'},
  {type='RPGSkillTree.Moonlit_Earring_Rare'},
 },
 Legendary={
  {type='RPGSkillTree.Necklace_of_Strength_Legendary'},
  {type=ampoule,count=10},
  {type='RPGSkillTree.Dew_Beaded_Ring_Legendary'},
  {type='RPGSkillTree.Forest_Earrings_Legendary'},
  {type='RPGSkillTree.Salvation_BraceletLeft_Legendary'},
  {type='RPGSkillTree.Moonlit_Earring_Legendary'},
  {type='RPGSkillTree.BoneCollectors_Earing'},
 },
}
-- Preserve the original rarity totals, including the historical box upgrades.
local normal=(200/211)*(95055/99998)
local rare=((200/211)*(4943/99998)+10/211)*(95139/100002)
local totals={Normal=normal,Rare=rare,Legendary=1-normal-rare}
Loot.POOL={}
for _,tier in ipairs({'Normal','Rare','Legendary'}) do
 for _,row in ipairs(groups[tier]) do
  Loot.POOL[#Loot.POOL+1]={type=row.type,count=row.count or 1,tier=tier,chance=totals[tier]*0.9991/#groups[tier]}
 end
end
Loot.MYTHIC_CHANCE=0.0003
Loot.MYTHIC_TYPE='RPGSkillTree.MythicElixir'
Loot.FROST_BACKPACK_TYPE='RPGSkillTree.HydrationBackpack_Mythic'
Loot.FROST_BACKPACK_CHANCE=0.0003
Loot.SCOUT_ARTIFACT_TYPE='RPGSkillTree.ScoutArtifact_Mythic'
Loot.SCOUT_ARTIFACT_CHANCE=0.0003
Loot.JUMP_BOX_TYPE='RPGSkillTree.RandomJumpBox'
Loot.JUMP_BOX_CHANCE=0
for _,ft in ipairs({Loot.MYTHIC_TYPE,Loot.FROST_BACKPACK_TYPE,Loot.SCOUT_ARTIFACT_TYPE}) do
 Loot.POOL[#Loot.POOL+1]={type=ft,count=1,tier='Mythic',chance=0.0003}
end
function Loot.getTier(ft)
 if ft==Loot.MYTHIC_TYPE or ft==Loot.FROST_BACKPACK_TYPE or ft==Loot.SCOUT_ARTIFACT_TYPE then return 'Mythic' end
 if ft=='RPGSkillTree.BoneCollectors_Earing' then return 'Legendary' end
 if ft==Loot.JUMP_BOX_TYPE then return 'Rare' end
 if type(ft)=='string' then
  if ft:find('_Mythic',1,true) then return 'Mythic' end
  if ft:find('_Legendary',1,true) then return 'Legendary' end
  if ft:find('_Rare',1,true) then return 'Rare' end
 end
 return 'Normal'
end
function Loot.getPreviewItems()
 local result={};for _,row in ipairs(Loot.POOL) do result[#result+1]=row.type end;return result
end
-- Consumers must retain the WHOLE entry: one ampoule item type has three quantities.
function Loot.rollEntry(value)
 local r=tonumber(value)
 if not r then
  if ZombRandFloat then r=ZombRandFloat(0,1)
  elseif ZombRand then r=ZombRand(100000000)/100000000
  else r=math.random() end
 end
 if r~=r or r<0 then r=0 end
 if r>=1 then r=0.999999999999 end
 local total=0
 for _,row in ipairs(Loot.POOL) do total=total+row.chance;if r<total then return row end end
 return Loot.POOL[#Loot.POOL]
end
function Loot.roll(value)return Loot.rollEntry(value).type end
return Loot
