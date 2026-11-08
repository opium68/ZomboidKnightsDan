local load=require
local state={cycle=8}
RCE={Config={ampoule='RPGSkillTree.LevelUpElixir'},inside=function()return true end,Server={ready=true,prepared=true,store=function()return state end,now=function()return 0 end}}
Events=setmetatable({},{__index=function()return {Add=function()end}end})
require=function(name)if name=='RCE/Server'then return true end;return load(name)end
load('RCE/SecretPools')
assert(#RCE.SecretPools==2)
local randomValue=0
ZombRand=function(n)return math.min(randomValue,n-1)end
local M=load('RCE/SecretLoot')
for choice=0,2 do
 state.secret=nil;randomValue=choice
 local plan=M.initialize();assert(plan.total==(3+choice)*2)
 assert(plan.buildings.principal==3+choice and plan.buildings.slaughter==3+choice)
 assert(M.initialize()==plan,'No reroll on restart/reentry')
 local given=0
 for _,e in pairs(plan.plan)do
  local sq={getX=function()return e.x end,getY=function()return e.y end,getZ=function()return e.z end}
  local parent={getSprite=function()return {getName=function()return e.tile end}end}
  local c={getSourceGrid=function()return sq end,getParent=function()return parent end,getType=function()return e.type end,AddItem=function(_,kind)assert(kind==RCE.Config.ampoule);given=given+1;return {}end}
  M.fill(nil,nil,c);M.fill(nil,nil,c)
 end
 assert(given==plan.total,'Exactly 3..5 per room, including repeated callbacks')
end
state.cycle=9
local new=M.initialize();for _ in pairs(new.delivered)do error('Ledger not reset')end
local sword={getFullType=function()return 'Base.dabaojian'end}
local other={getFullType=function()return 'Base.Katana'end}
local inv={sword,other,sword}
local items={size=function()return #inv end,get=function(_,i)return inv[i+1]end}
local c={getItems=function()return items end,AddItem=function(_,kind)assert(kind==RCE.Config.ampoule);local a={getFullType=function()return kind end};inv[#inv+1]=a;return a end,Remove=function(_,it)for i=#inv,1,-1 do if inv[i]==it then table.remove(inv,i);return end end end}
M.replaceSword(c);assert(#inv==3 and inv[1]==other)
M.replaceSword(c);assert(#inv==3,'Sword conversion must be idempotent')
local before=#inv;c.AddItem=function()return nil end;inv[#inv+1]=sword;M.replaceSword(c);assert(#inv==before+1,'Keep sword when replacement creation fails')
return 'Secret rooms: 3/4/5 each; persisted delivery; new cycle; one-for-one sword migration; failure safety PASS'
