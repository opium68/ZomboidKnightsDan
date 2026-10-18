import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const out=path.join(root,'custom-mods/KnightsDanServerPatch/42/media');
function files(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):e.name.endsWith('.txt')?[path.join(dir,e.name)]:[]);}
function declarations(dir){
 const result={};
 for(const f of files(dir)){
  const s=fs.readFileSync(f,'utf8').replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g,'');
  const mod=s.match(/\bmodule\s+(\w+)/)?.[1];if(!mod)continue;
  for(const m of s.matchAll(/\bitem\s+([\w-]+)\s*\{/g)){
   let start=m.index+m[0].length,end=start,depth=1;
   while(depth&&end<s.length){if(s[end]==='{')depth++;if(s[end]==='}')depth--;end++;}
   result[mod+'.'+m[1]]=Object.fromEntries([...s.slice(start,end-1).matchAll(/(\w+)\s*=\s*([^,\r\n]+)/g)].map(x=>[x[1],x[2].trim()]));
  }
 }return result;
}
const metro=declarations('D:/PZDedicated/steamapps/workshop/content/108600/3786428136/mods/Metro2033Armory/42/media/scripts');
const items={...declarations('D:/PZDedicated/media/scripts/generated/items'),...declarations('D:/PZDedicated/steamapps/workshop/content/108600/3761077099/mods/VFE/42/media/scripts')};
const ammo={'base:bullets_3030':'Base.3030Bullets','base:bullets_308':'Base.308Bullets','base:bullets_357':'Base.Bullets357','base:bullets_38':'Base.Bullets38','base:bullets_44':'Base.Bullets44','base:bullets_45':'Base.Bullets45','base:bullets_556':'Base.556Bullets','base:bullets_9mm':'Base.Bullets9mm','base:shotgun_shells':'Base.ShotgunShells','vfe:bullets_22':'Base.22Bullets','vfe:bullets_223':'Base.223Bullets','vfe:bullets_762':'Base.762Bullets','vfe:bullets_308_linked':'Base.308Bullets'};
const guns={};
for(const [id,p] of Object.entries(items)){
 if(p.IsAimedFirearm?.toLowerCase()!=='true'||!ammo[p.AmmoType])continue;
 const magazine=p.MagazineType,capacity=Number(items[magazine]?.MaxAmmo??p.MaxAmmo??0);if(capacity<=0)continue;
 guns[id]={ammo:ammo[p.AmmoType],...(magazine?{magazine}:{}),capacity,rounds:capacity*(magazine?4:2),package:'KnightsDan.WeaponBundle_'+id.replaceAll('.','_')};
}
function lua(v){return typeof v==='object'&&v!==null?'{'+Object.entries(v).map(([k,x])=>'['+JSON.stringify(k)+']='+lua(x)).join(',')+'}':JSON.stringify(v);}
fs.writeFileSync(path.join(out,'lua/shared/KnightsDan/SupplyDefinitions.lua'),'require "KnightsDan/Core"\nKnightsDan.weaponBundles='+lua(guns)+'\nKnightsDan.retiredMetro='+lua(Object.fromEntries(Object.keys(metro).map(id=>[id,true])))+'\n');
fs.writeFileSync(path.join(out,'scripts/KnightsDanWeaponBundles.txt'),'module KnightsDan {\n'+Object.values(guns).map(d=>` item ${d.package.split('.')[1]} { ItemType = base:container, DisplayName = ${d.package.split('.')[1]}, Icon = Duffelbag, DisplayCategory = Weapon, Weight = 0.5, Capacity = 100, WeightReduction = 0, CanBeEquipped = Secondary, OnCreate = KnightsDan.createWeaponBundle, }`).join('\n')+'\n}\n');
const kinds=new Set(['weaponpart','weapon','drainable','container','literature','normal']);
fs.writeFileSync(path.join(out,'scripts/KnightsDanMetroMigration.txt'),'/* Owned save-migration shells; no original behavior or assets. */\nmodule Base {\n'+Object.entries(metro).map(([id,p])=>{if(!id.startsWith('Base.'))throw Error(id);let kind=(p.ItemType??p.Type??'Normal').toLowerCase().replace('base:','');if(!kinds.has(kind))kind='normal';return ` item ${id.slice(5)} { ItemType = base:${kind}, DisplayName = Retired Metro Item, Icon = Question_On, Weight = 0, }`;}).join('\n')+'\n}\n');
fs.writeFileSync(path.join(root,'config/knights-supply.json'),JSON.stringify({weapons:guns,retiredMetroIds:Object.keys(metro).sort()},null,2)+'\n');
console.log(`Generated ${Object.keys(guns).length} weapon bundles, ${Object.keys(metro).length} exact Metro retirement IDs`);
