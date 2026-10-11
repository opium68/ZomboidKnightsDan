-- Read-only repair evidence. Ensure VRO's command handler runs before our post probe.
if isClient() then return end
require "VRO_VehicleCommands"

local function snapshot(player, args, phase)
    if not player or type(args) ~= "table" then return end
    local vehicle = args.vehicleId and getVehicleById(args.vehicleId)
    if not vehicle or vehicle:getScript():getFullName() ~= "Base.M998_Humvee" then return end
    local dx, dy = player:getX()-vehicle:getX(), player:getY()-vehicle:getY()
    if dx*dx+dy*dy > 100 then return end
    local part = type(args.partId) == "string" and vehicle:getPartById(args.partId)
    if not part then return end
    local item = part:getInventoryItem()
    print("[KD_HUMVEE_REPAIR_SERVER] phase=" .. phase
        .. " player=" .. tostring(player:getUsername())
        .. " vehicle=" .. tostring(vehicle:getId())
        .. " part=" .. args.partId
        .. " condition=" .. tostring(part:getCondition())
        .. " itemCondition=" .. tostring(item and item:getCondition())
        .. " itemMax=" .. tostring(item and item:getConditionMax())
        .. " repairs=" .. tostring(item and item:getHaveBeenRepaired())
        .. " clientCondition=" .. tostring(args.clientCondition)
        .. " fixerIndex=" .. tostring(args.fixerIndex)
        .. " fixingCondMod=" .. tostring(args.fixingCondMod))
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module == "KDHumveeDiag" and command == "beforeRepair" then
        snapshot(player, args, "before-repair")
    elseif module == "VRO_vehicle" and command == "doFix" then
        snapshot(player, args, "after-repair")
    end
end)
