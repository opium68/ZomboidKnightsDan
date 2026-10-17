-- Explicit admin requests only; no world scan, ticking job or water creation.
if not isServer() then return end
local module = "KnightsDanPlumbing"

local function integer(n)
    return type(n) == "number" and n == n and n > -1000000 and n < 1000000 and n == math.floor(n)
end

local function spriteName(obj)
    local sprite = obj and obj:getSprite()
    return sprite and sprite:getName() or "?"
end

local function snapshot(obj)
    local sq = obj:getSquare()
    local md = obj:hasModData() and obj:getModData() or {}
    local source = obj:FindExternalWaterSource()
    return {
        external = obj:getUsesExternalWaterSource() == true,
        marker = md[LGEP.KEY_PIPED] == true,
        moved = md.canBeWaterPiped == true,
        room = sq:getRoom() ~= nil,
        noWater = sq:isNoWater() == true,
        days = getGameTime():getWorldAgeDaysSinceBegin(),
        shutoff = getSandboxOptions():getWaterShutModifier(),
        amount = obj:getFluidAmount(),
        source = source ~= nil,
        sourceSprite = source and spriteName(source) or "-",
        sourceGhost = source and LGEP.isGhost(source) or false,
    }
end

Events.OnClientCommand.Add(function(mod, command, player, args)
    if mod ~= module or (command ~= "inspect" and command ~= "restore") then return end
    if not player or tostring(player:getAccessLevel() or ""):lower() ~= "admin" then return end
    if not LGEP or not LGEP.isPlumbableFixture or not LGEP.getOption then return end
    if type(args) ~= "table" or not integer(args.x) or not integer(args.y)
        or not integer(args.z) or not integer(args.index) or type(args.sprite) ~= "string" then return end
    if player:getZ() ~= args.z or (player:getX()-args.x)^2 + (player:getY()-args.y)^2 > 36 then return end
    local square = getCell():getGridSquare(args.x, args.y, args.z)
    if not square then return end
    local objects = square:getObjects()
    if args.index < 0 or args.index >= objects:size() then return end
    local obj = objects:get(args.index)
    if not LGEP.isPlumbableFixture(obj) or spriteName(obj) ~= args.sprite then return end

    local result = {x=args.x, y=args.y, z=args.z, sprite=args.sprite, command=command}
    result.before = snapshot(obj)
    result.reason = "Inspect"
    if command == "restore" then
        if LGEP.getOption("Enabled") then
            result.reason = "Enabled"
        elseif result.before.source then
            -- A real collector or remaining LGEP mirror needs separate handling.
            result.reason = "Source"
        elseif not result.before.external and not result.before.marker then
            result.reason = "Unchanged"
        else
            -- Same vanilla channels as ISPlumbItem / LGEP.unplumbStranded,
            -- applied to the explicitly selected fixture, not a tracked mirror.
            if result.before.marker then
                obj:getModData()[LGEP.KEY_PIPED] = nil
                obj:transmitModData()
            end
            obj:setUsesExternalWaterSource(false)
            obj:sendObjectChange(IsoObjectChange.USES_EXTERNAL_WATER_SOURCE, {value=false})
            result.reason = "Restored"
        end
    end
    result.after = snapshot(obj)
    print(("[KD_PLUMBING] %s user=%s at=%d,%d,%d sprite=%s reason=%s external=%s->%s marker=%s->%s moved=%s room=%s noWater=%s amount=%s->%s source=%s ghost=%s")
        :format(command, player:getUsername(), args.x,args.y,args.z,args.sprite,result.reason,
            tostring(result.before.external),tostring(result.after.external),
            tostring(result.before.marker),tostring(result.after.marker),tostring(result.after.moved),
            tostring(result.after.room),tostring(result.after.noWater),tostring(result.before.amount),
            tostring(result.after.amount),result.after.sourceSprite,tostring(result.after.sourceGhost)))
    sendServerCommand(player, module, "result", result)
end)
