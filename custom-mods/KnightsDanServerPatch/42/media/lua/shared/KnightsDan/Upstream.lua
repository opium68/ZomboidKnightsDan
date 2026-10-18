KnightsDan = KnightsDan or {}
local K = KnightsDan

-- Read Workshop source from its own mod directory, bypassing our overlay.
-- Original sources/assets remain installed by Steam, not bundled in releases.
function K.loadPzLinuxSource(path, adapt)
    local reader = getModFileReader("B42_PZLinux", path, false)
    assert(reader, "PZLinux source unavailable: " .. path)
    local lines = {}
    local ok, failure = pcall(function()
        local line = reader:readLine()
        while line do
            lines[#lines + 1] = line
            line = reader:readLine()
        end
    end)
    reader:close()
    assert(ok, failure)
    local source = adapt(table.concat(lines, "\n"))
    local compiled, compileError = loadstring(source, "KnightsDan/" .. path)
    assert(compiled, compileError)
    return compiled()
end
