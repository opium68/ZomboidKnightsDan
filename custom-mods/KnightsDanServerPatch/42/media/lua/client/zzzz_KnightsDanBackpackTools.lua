require "Hotbar/ISHotbar"

-- All-In-One toolboxes use the vanilla Bedroll attachment type. Older mod
-- backpacks often supply no BedrollBottom slot, even though they occupy Back.
local function addBottomSlot(hotbar, item)
    if not item or not instanceof(item, "InventoryContainer")
        or hotbar.chr:isHandItem(item) then return false end
    local location = item:canBeEquipped()
    local locationName = location and tostring(location):lower()
    if locationName ~= "back" and locationName ~= "base:back" then return false end

    local existing = item:getAttachmentsProvided()
    if existing then
        for i = 0, existing:size() - 1 do
            local slot = hotbar:getSlotDef(existing:get(i))
            -- Preserve custom Bedroll slots as well as all three vanilla sizes.
            if slot and slot.attachments and slot.attachments.Bedroll then return false end
        end
    end
    local bottom = hotbar:getSlotDef("BedrollBottom")
    if not bottom or not bottom.attachments or not bottom.attachments.Bedroll then return false end
    local slots = existing and ArrayList.new(existing) or ArrayList.new()
    slots:add("BedrollBottom")
    item:setAttachmentsProvided(slots)
    return true
end

local refresh = ISHotbar.refresh
ISHotbar.refresh = function(self, ...)
    local worn = self.chr:getWornItems()
    local changed = false
    for i = 0, worn:size() - 1 do
        if addBottomSlot(self, worn:getItemByIndex(i)) then changed = true end
    end
    -- Native refresh otherwise skips work when the same backpack is still worn.
    if changed then self.wornItems = nil end
    return refresh(self, ...)
end
