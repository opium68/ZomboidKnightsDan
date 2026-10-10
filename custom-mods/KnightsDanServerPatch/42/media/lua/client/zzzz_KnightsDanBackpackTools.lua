require "Hotbar/ISHotbar"

-- B42's automatic slot removal clears these fields only on the client.
-- The normal ISDetachItemHotbar action also sends syncItemFields. Do the
-- same for Bedroll items when a backpack disappears from the worn slots.
local removeItem = ISHotbar.removeItem
ISHotbar.removeItem = function(self, item, doAnim, ...)
    local sync = not doAnim and item and item:getAttachmentType() == "Bedroll"
        and item:getAttachedSlot() ~= -1
        and not self.availableSlot[item:getAttachedSlot()] and isClient()
    local result = removeItem(self, item, doAnim, ...)
    if sync then syncItemFields(self.chr, item) end
    return result
end

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
