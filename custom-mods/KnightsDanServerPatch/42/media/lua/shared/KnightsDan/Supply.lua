require "KnightsDan/SupplyDefinitions"
local K=KnightsDan
K.ammoCartons={
 {id="Base.22Carton",rounds=600},{id="Base.Bullets9mmCarton",rounds=600},
 {id="Base.Bullets38Carton",rounds=600},{id="Base.Bullets357Carton",rounds=600},
 {id="Base.Bullets45Carton",rounds=600},{id="Base.Bullets44Carton",rounds=240},
 {id="Base.223Carton",rounds=240},{id="Base.3030Carton",rounds=240},
 {id="Base.556Carton",rounds=240},{id="Base.762Carton",rounds=240},
 {id="Base.308Carton",rounds=240},{id="Base.ShotgunShellsCarton",rounds=300},
}
K.supplyProducts={}
K.bundleByPackage={}
for gun,d in pairs(K.weaponBundles) do K.bundleByPackage[d.package]=d;d.gun=gun end
local function script(id) return getScriptManager():FindItem(id) end
local function name(id) local s=script(id);return s and s:getDisplayName() or id end
local function weight(id) return math.max(0,script(id):getActualWeight()) end
function K.createWeaponBundle(package)
 local d=assert(K.bundleByPackage[package:getFullType()],"Unknown weapon bundle")
 local md=package:getModData();if md.knightsWeaponBundle then return end
 local inv=package:getInventory();local added={}
 local function add(id,n)
  for i=1,n do
   local item=inv:AddItem(id)
   if not item then for _,old in ipairs(added) do inv:Remove(old) end;error("Bundle component missing: "..id) end
   added[#added+1]=item
   if item.setCurrentAmmoCount then item:setCurrentAmmoCount(0) end
   if item.setRoundChambered then item:setRoundChambered(false) end
  end
 end
 add(d.gun,1);if d.magazine then add(d.magazine,4) end;add(d.ammo,d.rounds)
 -- Script weight reserves the complete contents in the native parcel plan;
 -- the actual container weighs only its empty bag, avoiding double counting.
 package:setActualWeight(0.5);package:setCustomWeight(true)
 md.knightsWeaponBundle=true
end

function K.installSupply()
 local sm=getScriptManager();local entries=PZLinuxDarkWebItemsTable
 local originalSales={}
 for _,e in ipairs(entries) do
  local ids={}
  for _,id in ipairs(e.id or {}) do
   if not K.retiredMetro[id] and id~='Base.308BulletsLinked' and id~='Base.M60_Link' and id~='Base.M60_Links_Box' then ids[#ids+1]=id end
  end
  if #ids>0 then originalSales[#originalSales+1]={id=ids,Price=e.Price,knightsSellOnly=true} end
 end
 local prices={};for _,e in ipairs(entries) do for _,id in ipairs(e.id or {}) do prices[id]=tonumber(e.Price) or 1 end end
 local function price(id,fallback) return math.max(1,prices[id] or fallback) end
 local known={};local clean={}
 for _,e in ipairs(entries) do
  local ids={}
  for _,id in ipairs(e.id or {}) do
    if not K.retiredMetro[id] and id~="Base.308BulletsLinked" and id~="Base.M60_Link" and id~="Base.M60_Links_Box" and id~="Base.M60_Link_Die" then
    local d=K.weaponBundles[id]
    ids[#ids+1]=d and d.package or id
   end
  end
  if #ids>0 then e.id=ids;clean[#clean+1]=e;for _,id in ipairs(ids) do known[id]=e end end
 end
 for gun,d in pairs(K.weaponBundles) do
  assert(script(gun) and script(d.ammo) and script(d.package),"Invalid weapon bundle "..gun)
  if d.magazine then assert(script(d.magazine),"Missing magazine "..d.magazine) end
  local title=name(gun).." 세트 / "..name(d.ammo).." "..d.rounds.."발"
  if d.magazine then title=title.." / "..name(d.magazine).." 4개" end
  script(d.package):setDisplayName(title)
  script(d.package):setActualWeight(0.5+weight(gun)+d.rounds*weight(d.ammo)+(d.magazine and 4*weight(d.magazine) or 0))
  local total=price(gun,15000)+d.rounds*price(d.ammo,10)+(d.magazine and 4*price(d.magazine,1500) or 0)
  K.supplyProducts[d.package]={category="firearms",price=total}
 end
 -- One bundle per offer makes its exact price and contents deterministic.
 for i=#clean,1,-1 do
  local ids=clean[i].id
  for n=#ids,1,-1 do if K.bundleByPackage[ids[n]] then table.remove(ids,n) end end
  if #ids==0 then table.remove(clean,i) end
 end
 local function product(id,category,reference,rounds)
  assert(script(id),"Supply item missing: "..id)
  K.supplyProducts[id]={category=category,price=reference,rounds=rounds}
 end
 for _,c in ipairs(K.ammoCartons) do product(c.id,"cartons",price(c.id,c.rounds*10),c.rounds) end
 for _,d in pairs(K.weaponBundles) do
  if d.magazine then product(d.magazine,"magazines",price(d.magazine,1500)) end
 end
 local compatible={}
 for gun,d in pairs(K.weaponBundles) do if d.magazine then
  compatible[d.magazine]=compatible[d.magazine] or {};table.insert(compatible[d.magazine],name(gun))
 end end
 for id,names in pairs(compatible) do
  table.sort(names)
  local current=name(id)
  if not current:find(' / 호환: ',1,true) then script(id):setDisplayName(current..' / 호환: '..table.concat(names,', ')) end
 end
 for _,c in ipairs(K.ammoCartons) do
  local current=name(c.id)
  if not current:find('발 / 큰 상자',1,true) then script(c.id):setDisplayName(current..' / '..c.rounds..'발 / 큰 상자 1개') end
 end
 -- Vehicle cartons are native packages; validate their round counts in engine.
 product("KnightsDan.VehicleAmmo127","vehicle",10000,100)
 product("KnightsDan.VehicleAmmo20","vehicle",20000,100)
 product("KnightsDan.VehicleAmmo20HE","vehicleHE",15000,50)
 for id,d in pairs(K.vehiclePacks) do script(id):setActualWeight(0.1+d.count*weight(d.id)) end
 for i=#clean,1,-1 do
  local ids=clean[i].id
  for n=#ids,1,-1 do
   local id=ids[n];local s=script(id)
   if K.supplyProducts[id] or (s and not s:isRanged() and (s:getAmmoType() or tostring(s:getDisplayCategory()):lower():find('ammo')))
     or id:find("Carton") or id=="Base.127x99mm" or id=="Base.20x102mm" or id=="Base.20x102mmHE" then table.remove(ids,n) end
  end
  if #ids==0 then table.remove(clean,i) end
 end
 -- Sorted IDs preserve sourceIndex across restarts and both VMs.
 local keys={};for id in pairs(K.supplyProducts) do keys[#keys+1]=id end;table.sort(keys)
 for _,id in ipairs(keys) do clean[#clean+1]={id={id},Price=K.supplyProducts[id].price} end
 local offered={};for _,e in ipairs(clean) do for _,id in ipairs(e.id) do offered[id]=true end end
 for _,e in ipairs(originalSales) do
  local ids={};for _,id in ipairs(e.id) do if not offered[id] then ids[#ids+1]=id;offered[id]=true end end
  if #ids>0 then e.id=ids;clean[#clean+1]=e end
 end
 PZLinuxDarkWebItemsTable=clean
 -- General Buy Goods uses the same complete packages, with native category validation.
 for _,definition in pairs(PZLinuxRequestDefinitions or {}) do
  for _,field in ipairs({"items","weapons"}) do
   local pool=definition[field]
   if type(pool)=="table" then
    for i=#pool,1,-1 do
     local id=type(pool[i])=='table' and pool[i].baseName or pool[i]
     if K.retiredMetro[id] then table.remove(pool,i)
     elseif K.weaponBundles[id] then
      local package=K.weaponBundles[id].package
      if type(pool[i])=='table' then pool[i].baseName=package else pool[i]=package end
      definition.itemWeights=definition.itemWeights or {};definition.itemWeights[package]=weight(package)
      if type(pool[i])~='table' then pool[i]={baseName=package,weight=weight(package),delta=K.supplyProducts[package].price/math.max(1,definition.price or 1)}
      else pool[i].delta=K.supplyProducts[package].price/math.max(1,definition.price or 1) end
     end
    end
   end
  end
 end
 K.supplyReady=true
end

K.vehiclePacks={
 ["KnightsDan.VehicleAmmo127"]={id="Base.127x99mm",count=100},
 ["KnightsDan.VehicleAmmo20"]={id="Base.20x102mm",count=100},
 ["KnightsDan.VehicleAmmo20HE"]={id="Base.20x102mmHE",count=50},
}
function K.createVehicleAmmo(package)
 local d=assert(K.vehiclePacks[package:getFullType()]);local md=package:getModData()
 if md.knightsVehicleAmmo then return end
 local inv=package:getInventory();local added={}
 for i=1,d.count do local item=inv:AddItem(d.id)
  if not item then for _,old in ipairs(added) do inv:Remove(old) end;error("Vehicle ammo missing: "..d.id) end
  added[#added+1]=item
 end
 package:setActualWeight(0.1);package:setCustomWeight(true);md.knightsVehicleAmmo=true
end
