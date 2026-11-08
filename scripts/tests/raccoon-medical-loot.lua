local load=require
local state={cycle=8}
RCE={Config={ampoule='RPGSkillTree.LevelUpElixir'},Server={ready=true,prepared=true,store=function()return state end,now=function()return 0 end}}
Events=setmetatable({},{__index=function()return {Add=function()end}end})
require=function(name)if name=='RCE/Server'then return true end;return load(name)end
load('RCE/MedicalPools')
assert(#RCE.MedicalPools==11,'Eleven reviewed buildings')
local randomValue=0
ZombRand=function(n)return math.min(randomValue,n-1)end
local M=load('RCE/MedicalLoot')
for choice=0,3 do
 state.medical=nil;randomValue=choice
 local med=M.initialize();assert(med.total==choice*11,'Uniform 0..3 per building')
 for _,count in pairs(med.buildings)do assert(count==choice)end
 assert(M.initialize()==med,'Repeated init does not reroll')
end
local med=state.medical
local key,entry
for k,v in pairs(med.plan)do key,entry=k,v;break end
local given=0
local sq={getX=function()return entry.x end,getY=function()return entry.y end,getZ=function()return entry.z end}
local parent={getSprite=function()return {getName=function()return entry.tile end}end}
local container={getSourceGrid=function()return sq end,getParent=function()return parent end,getType=function()return entry.type end,AddItem=function()given=given+1;return {}end}
M.fill(nil,nil,container);assert(given==entry.quantity,'Exact planned grant')
M.fill(nil,nil,container);assert(given==entry.quantity,'No repeat/entry duplication')
state.cycle=9;randomValue=0
assert(M.initialize().total==0,'New cycle resets plan')
for _ in pairs(state.medical.delivered)do error('New cycle must clear delivery ledger')end
return '11 buildings; exact 0/1/2/3 counts; no reroll/duplicate; cycle reset PASS'
