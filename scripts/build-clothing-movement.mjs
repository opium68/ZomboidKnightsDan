import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const workshop='D:/PZDedicated/steamapps/workshop/content/108600';
const ini=fs.readFileSync(path.join(root,'config/escape_test/escape_test.ini'),'utf8');
const active=new Set(ini.match(/^Mods=(.*)$/m)[1].trim().replaceAll('\\','').split(';'));
const workshopIds=ini.match(/^WorkshopItems=(.*)$/m)[1].trim().split(';');
function files(dir){if(!fs.existsSync(dir))return [];return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(path.join(dir,e.name)):e.name.endsWith('.txt')?[path.join(dir,e.name)]:[]);}
function items(file){
 const s=fs.readFileSync(file,'utf8').replace(/\/\*[\s\S]*?\*\/|\/\/[^\n]*/g,'');const module=s.match(/\bmodule\s+(\S+)\s*\{/)?.[1];if(!module)return [];
 const out=[];
 for(const m of s.matchAll(/\bitem\s+([^\s{]+)\s*\{/g)){
  const start=m.index+m[0].length;let end=start,depth=1;
  while(depth&&end<s.length){if(s[end]==='{')depth++;if(s[end]==='}')depth--;end++;}
  const fields=Object.fromEntries([...s.slice(start,end-1).matchAll(/\b(\w+)\s*=\s*([^,\r\n]+)/g)].map(x=>[x[1],x[2].trim()]));
  out.push({id:module+'.'+m[1],fields});
 }return out;
}
const vanilla=new Set(files('D:/PZDedicated/media/scripts/generated/items').flatMap(f=>items(f).map(i=>i.id)));
const catalog=new Map();const exclusions=new Set();
for(const wid of workshopIds){
 const mods=path.join(workshop,wid,'mods');if(!fs.existsSync(mods))throw Error('Workshop missing '+wid);
 for(const folderName of fs.readdirSync(mods)){
  const folder=path.join(mods,folderName);if(!fs.statSync(folder).isDirectory())continue;
  const builds=fs.readdirSync(folder,{withFileTypes:true}).filter(e=>e.isDirectory()&&/^42(?:\.\d+)?$/.test(e.name)&&Number(e.name.split('.')[1]??0)<=21).map(e=>e.name).sort((a,b)=>Number(a.split('.')[1]??0)-Number(b.split('.')[1]??0));
  const build=builds.length?path.join(folder,builds.at(-1)):folder;
  const info=fs.existsSync(path.join(build,'mod.info'))?path.join(build,'mod.info'):path.join(folder,'mod.info');if(!fs.existsSync(info))continue;
  const mod=fs.readFileSync(info,'utf8').match(/^id\s*=\s*(.*?)\s*$/m)?.[1];if(!active.has(mod))continue;
  for(const media of [path.join(folder,'common/media'),path.join(build,'media')])for(const file of files(path.join(media,'scripts'))){
   for(const item of items(file)){
    const p=item.fields;if(!['base:clothing','base:alarmclockclothing'].includes(p.ItemType)&&!['Clothing','AlarmClockClothing'].includes(p.Type))continue;
    if(vanilla.has(item.id)){exclusions.add(item.id);continue;}
    const original=Number(p.RunSpeedModifier??1);if(!Number.isFinite(original))throw Error('Invalid movement modifier '+item.id);
    catalog.set(item.id,{id:item.id,mod,build:path.basename(build),original,file:path.relative(workshop,file).replaceAll('\\','/')});
   }
  }
 }
}
const entries=[...catalog.values()].sort((a,b)=>a.id.localeCompare(b.id,'en'));
fs.writeFileSync(path.join(root,'config/knights-clothing-movement.json'),JSON.stringify({version:1,scope:'Active Workshop-added clothing; RunSpeedModifier penalties only; bonuses and vanilla preserved',excludedVanillaOverrides:[...exclusions].sort(),entries},null,2)+'\n');
fs.writeFileSync(path.join(root,'custom-mods/KnightsDanServerPatch/42/media/lua/shared/KnightsDan/ClothingMovementIds.lua'),'require "KnightsDan/Core"\nKnightsDan.modClothingMovement = {\n'+entries.map(e=>'    ['+JSON.stringify(e.id)+'] = '+e.original+',').join('\n')+'\n}\n');
const penalties=entries.filter(e=>e.original<1);const mods={};for(const e of penalties)mods[e.mod]=(mods[e.mod]??0)+1;
console.log(JSON.stringify({clothing:entries.length,penalties:penalties.length,bonuses:entries.filter(e=>e.original>1).length,excludedVanillaOverrides:exclusions.size,mods}));
