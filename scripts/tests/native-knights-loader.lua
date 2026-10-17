local roots={"scripts/tests/","custom-mods/KnightsDanServerPatch/42/media/lua/shared/",
    "custom-mods/KnightsDanServerPatch/42/media/lua/server/",
    "D:/PZDedicated/steamapps/workshop/content/108600/3414468585/mods/B42 PZLinux/42/media/lua/shared/"}
local loaded={}
function require(name)
    if loaded[name] then return loaded[name] end
    for _,root in ipairs(roots) do
        local fn=loadfile(root..name..".lua")
        if fn then
            loaded[name]=true
            local result=fn()
            if result~=nil then loaded[name]=result end
            return loaded[name]
        end
    end
    error("module not found: "..name)
end
