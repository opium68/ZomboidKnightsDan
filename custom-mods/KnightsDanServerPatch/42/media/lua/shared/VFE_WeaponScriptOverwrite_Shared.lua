-- Preserve the installed original reload logic, suppress only link emission.
local reader=assert(getModFileReader('VFExpansion1','media/lua/shared/VFE_WeaponScriptOverwrite_Shared.lua',false))
local lines={};local line=reader:readLine()
while line do lines[#lines+1]=line;line=reader:readLine() end;reader:close()
local source=table.concat(lines,'\n')
local count
source,count=source:gsub('Events%.OnWeaponSwingHitPoint%.Add%(VFEOnShootShared%)','-- M60 links retired by KnightsDan')
assert(count==1,'VFE link hook changed; review required')
assert(loadstring(source,'KnightsDan/VFE reload compatibility'))()
