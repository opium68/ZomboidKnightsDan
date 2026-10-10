require "TimedActions/VRO_DoFixAction"
local VRO = require "VRO/Core"
local start = VRO.DoFixAction.start

-- Candidate workaround for the reported animation-blend overflow during
-- Humvee plate repairs. Keep the native repair logic and replace only the
-- welding pose; actual renderer/FPS verification is still required.
VRO.DoFixAction.start = function(self, ...)
    local vehicle = self.part and self.part:getVehicle()
    local script = vehicle and vehicle:getScript()
    local name = script and script:getFullName()
    local previous = self.actionAnim
    local fallback = name == "Base.M998_Humvee"
        and (previous == "BlowTorchMid" or previous == "BlowTorch")
    if fallback then self.actionAnim = "VehicleWorkOnMid" end
    local result = start(self, ...)
    if fallback then self.actionAnim = previous end
    return result
end
