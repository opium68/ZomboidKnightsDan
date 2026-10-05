require "ISUI/ISWorldObjectContextMenu"
require "ISUI/ISPanel"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "KnoxEscapeQuest/Shared"

local KEQ = KnoxEscapeQuest
local clientState = {
    stage = 0,
    defenseEndHour = 0,
    escaped = "",
    panelProgress = 0,
    panelTotal = 3,
    targetId = "",
    targetX = 0,
    targetY = 0,
    targetZ = 0,
    targetRadius = 0,
    actionSeconds = KEQ.ACTION_SECONDS,
}
local highlightedObject = nil
local highlightedPlayerNum = 0
local highlightColor = ColorInfo.new(1.0, 0.72, 0.05, 1.0)
local notifiedTargetId = ""
local lastHighlightUpdateMs = 0
local endingOverlay = nil
local endingMovementUnblockAtMs = 0
local extractionSound = nil
local extractionSoundStopAtMs = 0
local stateSyncPending = false
local stateRequestAttempts = 0
local nextStateRequestMs = 0
local announceStateOnReceive = false
local statusDisplayPending = false
local initialSyncTriggered = false
local playerCreateCount = 0

local ENDING_FADE_MS = 1500
local ENDING_HOLD_MS = 12000
local EXTRACTION_SOUND_MS = ENDING_FADE_MS * 2 + ENDING_HOLD_MS
local STATE_RETRY_MAX_MS = 10000

local function stopExtractionSound()
    if extractionSound then
        local manager = getSoundManager and getSoundManager() or nil
        local stopped = false
        if manager and manager.StopSound then
            stopped = pcall(manager.StopSound, manager, extractionSound)
        end
        if not stopped and extractionSound.stop then
            pcall(extractionSound.stop, extractionSound)
        end
    end
    extractionSound = nil
    extractionSoundStopAtMs = 0
end

KEQEndingOverlay = ISPanel:derive("KEQEndingOverlay")

function KEQEndingOverlay:finish()
    stopExtractionSound()
    if self.blockedMovement and self.player and self.player.setBlockMovement then
        self.player:setBlockMovement(false)
    end
    self.blockedMovement = false
    self:setVisible(false)
    self:removeFromUIManager()
    if endingOverlay == self then
        endingOverlay = nil
        endingMovementUnblockAtMs = 0
    end
end

function KEQEndingOverlay:update()
    ISPanel.update(self)
    local elapsed = (getTimestampMs and getTimestampMs() or self.startedAt) - self.startedAt
    local total = ENDING_FADE_MS * 2 + ENDING_HOLD_MS
    if elapsed >= total then
        self:finish()
        return
    end

    if elapsed < ENDING_FADE_MS then
        self.fadeAlpha = elapsed / ENDING_FADE_MS
    elseif elapsed > ENDING_FADE_MS + ENDING_HOLD_MS then
        self.fadeAlpha = (total - elapsed) / ENDING_FADE_MS
    else
        self.fadeAlpha = 1
    end
    self.fadeAlpha = math.max(0, math.min(1, self.fadeAlpha))

    local playerNum = self.playerNum
    self:setX(getPlayerScreenLeft(playerNum))
    self:setY(getPlayerScreenTop(playerNum))
    self:setWidth(getPlayerScreenWidth(playerNum))
    self:setHeight(getPlayerScreenHeight(playerNum))
end

function KEQEndingOverlay:prerender()
    local alpha = tonumber(self.fadeAlpha) or 0
    self:drawRectStatic(0, 0, self.width, self.height, alpha, 0, 0, 0)
    if alpha < 0.55 then return end

    local textAlpha = math.min(1, (alpha - 0.55) / 0.45)
    local centreX = self.width / 2
    local centreY = self.height / 2
    self:drawTextCentre(getText("IGUI_KEQ_Ending_Title"), centreX, centreY - 76,
        0.94, 0.82, 0.46, textAlpha, UIFont.Large)
    self:drawTextCentre(getText("IGUI_KEQ_Ending_Subtitle"), centreX, centreY - 22,
        1, 1, 1, textAlpha, UIFont.Medium)
    self:drawTextCentre(getText("IGUI_KEQ_EscapedNames", self.escapedNames), centreX, centreY + 24,
        0.86, 0.86, 0.86, textAlpha, UIFont.Small)
    self:drawTextCentre(getText("IGUI_KEQ_Ending_Continue"), centreX, centreY + 74,
        0.65, 0.65, 0.65, textAlpha, UIFont.Small)
end

function KEQEndingOverlay:new(player, escapedNames)
    local playerNum = player and player:getPlayerNum() or 0
    local o = ISPanel.new(self,
        getPlayerScreenLeft(playerNum), getPlayerScreenTop(playerNum),
        getPlayerScreenWidth(playerNum), getPlayerScreenHeight(playerNum))
    o.player = player
    o.playerNum = playerNum
    o.escapedNames = tostring(escapedNames or "")
    o.startedAt = getTimestampMs and getTimestampMs() or 0
    o.fadeAlpha = 0
    o.background = false
    o.moveWithMouse = false
    if player and player.isBlockMovement and player.setBlockMovement and not player:isBlockMovement() then
        player:setBlockMovement(true)
        o.blockedMovement = true
        endingMovementUnblockAtMs = o.startedAt + ENDING_FADE_MS * 2 + ENDING_HOLD_MS + 1000
    end
    return o
end

local function showEndingOverlay(player, escapedNames)
    if endingOverlay then endingOverlay:finish() end
    endingOverlay = KEQEndingOverlay:new(player, escapedNames)
    endingOverlay:initialise()
    endingOverlay:setAlwaysOnTop(true)
    endingOverlay:addToUIManager()
end

local function currentPlayer(playerNum)
    if playerNum ~= nil and getSpecificPlayer then return getSpecificPlayer(playerNum) end
    if getPlayer then return getPlayer() end
    return nil
end

local function showMessage(player, message)
    if not message or message == "" then return end
    if HaloTextHelper and HaloTextHelper.addText and player then
        local shown = pcall(function() HaloTextHelper.addText(player, message) end)
        if not shown and player.Say then player:Say(message) end
    elseif player and player.Say then
        player:Say(message)
    end
    print("[KnoxEscapeQuest] " .. tostring(message))
end

local function objectiveText(stage)
    local key = "IGUI_KEQ_Objective_" .. tostring(tonumber(stage) or 0)
    return getText(key)
end

local function sendCommand(player, command, args)
    args = args or {}
    if not sendClientCommand then return false end
    local ok = pcall(sendClientCommand, player, KEQ.MODULE, command, args)
    if ok then return true end
    return pcall(sendClientCommand, KEQ.MODULE, command, args)
end

local function requestState(player)
    if not player then return false end
    return sendCommand(player, "requestState", {})
end

local function stateNowMs()
    return getTimestampMs and getTimestampMs() or 0
end

local function sendStateRequestAttempt(player)
    if not player then return end
    stateRequestAttempts = stateRequestAttempts + 1
    requestState(player)
    local exponent = math.min(stateRequestAttempts - 1, 4)
    local delay = math.min(STATE_RETRY_MAX_MS, 1000 * (2 ^ exponent))
    nextStateRequestMs = stateNowMs() + delay
    if stateRequestAttempts <= 3 or stateRequestAttempts % 6 == 0 then
        print("[KnoxEscapeQuest] requesting campaign state; attempt=" .. tostring(stateRequestAttempts))
    end
end

local function beginStateSync(player, announce, force)
    if isClient and not isClient() then return end
    if announce then announceStateOnReceive = true end
    if stateSyncPending and not force then return end
    stateSyncPending = true
    stateRequestAttempts = 0
    nextStateRequestMs = 0
    if player then sendStateRequestAttempt(player) end
end

local function getClientTarget()
    if tostring(clientState.targetId or "") == "" then return nil end
    return {
        id = tostring(clientState.targetId),
        x = tonumber(clientState.targetX) or 0,
        y = tonumber(clientState.targetY) or 0,
        z = tonumber(clientState.targetZ) or 0,
        radius = tonumber(clientState.targetRadius) or 0,
    }
end

local function directionText(player, target)
    local dx = (tonumber(target.x) or 0) - (tonumber(player:getX()) or 0)
    local dy = (tonumber(target.y) or 0) - (tonumber(player:getY()) or 0)
    local horizontal = math.abs(dx) >= 4 and (dx > 0 and "E" or "W") or ""
    local vertical = math.abs(dy) >= 4 and (dy > 0 and "S" or "N") or ""
    local key = vertical .. horizontal
    if key == "" then key = "HERE" end
    return getText("IGUI_KEQ_Direction_" .. key)
end

local function renderStatus(player)
    local stage = tonumber(clientState.stage) or 0
    local text = getText("IGUI_KEQ_StatusPrefix") .. objectiveText(stage)
    if stage == 2 then
        text = text .. " " .. getText("IGUI_KEQ_PanelStatus",
            tostring(clientState.panelProgress or 0), tostring(clientState.panelTotal or 3))
    end
    if stage == KEQ.DEFENSE_STAGE and tonumber(clientState.defenseEndHour or 0) > 0 then
        local now = getGameTime():getWorldAgeHours()
        local minutes = math.max(0, math.ceil((clientState.defenseEndHour - now) * 60))
        text = text .. " " .. getText("IGUI_KEQ_Remaining", tostring(minutes))
    end

    local target = getClientTarget()
    if target and stage <= KEQ.DEFENSE_STAGE then
        local distance = math.floor(KEQ.DistanceToTarget(player, target) + 0.5)
        text = text .. " " .. getText("IGUI_KEQ_TargetHint",
            tostring(distance), directionText(player, target), tostring(target.z))
    end
    if stage == KEQ.FINAL_STAGE and tostring(clientState.escaped or "") ~= "" then
        text = text .. " " .. getText("IGUI_KEQ_EscapedNames", tostring(clientState.escaped))
    end
    showMessage(player, text)
end

local function showStatus(player)
    statusDisplayPending = true
    beginStateSync(player, false, true)
end

KEQObjectiveAction = ISBaseTimedAction:derive("KEQObjectiveAction")

function KEQObjectiveAction:isValid()
    if not self.character or self.character:isDead() then return false end
    if tonumber(clientState.stage) ~= tonumber(self.stage) then return false end
    local target = getClientTarget()
    if not target or tostring(target.id) ~= tostring(self.targetId) then return false end
    if not KEQ.IsPlayerNearTarget(self.character, target) then return false end
    local health = self.character:getBodyDamage():getOverallBodyHealth()
    return health >= self.startHealth - 0.001
end

function KEQObjectiveAction:start()
end

function KEQObjectiveAction:update()
end

function KEQObjectiveAction:stop()
    ISBaseTimedAction.stop(self)
end

function KEQObjectiveAction:perform()
    if self:isValid() then
        -- Keep the action client-local; the server independently validates the
        -- stage, target id, floor, and distance before advancing the campaign.
        sendCommand(self.character, "activateStage", {
            stage = self.stage,
            targetId = self.targetId,
        })
    end
    ISBaseTimedAction.perform(self)
end

function KEQObjectiveAction:adjustMaxTime(maxTime)
    return maxTime
end

function KEQObjectiveAction:new(character, stage, targetId, seconds)
    local o = ISBaseTimedAction.new(self, character)
    o.stage = tonumber(stage) or 0
    o.targetId = tostring(targetId or "")
    o.startHealth = character:getBodyDamage():getOverallBodyHealth()
    o.maxTime = math.max(1, tonumber(seconds) or KEQ.ACTION_SECONDS) * KEQ.ACTION_TIME_UNITS_PER_SECOND
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = true
    o.ignoreHandsWounds = true
    return o
end

local function performStageAction(player)
    local target = getClientTarget()
    if not target then return end
    ISTimedActionQueue.add(KEQObjectiveAction:new(
        player,
        tonumber(clientState.stage) or 0,
        target.id,
        tonumber(clientState.actionSeconds) or KEQ.ACTION_SECONDS
    ))
end

local function adminCommand(player, command)
    sendCommand(player, command, {})
end

local function actionTranslationKey(stage)
    if stage == 2 then
        if tonumber(clientState.panelProgress or 0) < tonumber(clientState.panelTotal or 3) then
            return "ContextMenu_KEQ_Action_2_Panel"
        end
        return "ContextMenu_KEQ_Action_2_Terminal"
    end
    return "ContextMenu_KEQ_Action_" .. tostring(stage)
end

local function onFillWorldObjectContextMenu(playerNum, context, worldObjects, test)
    if test or not KEQ.IsEnabled() then return end
    local player = currentPlayer(playerNum)
    if not player then return end

    context:addOption(getText("ContextMenu_KEQ_Status"), player, showStatus)

    local stage = tonumber(clientState.stage) or 0
    local target = getClientTarget()
    if stage <= 8 and target and KEQ.IsPlayerNearTarget(player, target) then
        context:addOption(getText(actionTranslationKey(stage)), player, performStageAction)
    end

    if KEQ.IsAdmin(player) then
        local root = context:addOption(getText("ContextMenu_KEQ_Admin"))
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(root, sub)
        sub:addOption(getText("ContextMenu_KEQ_AdminSurvey"), player, adminCommand, "adminSurvey")
        sub:addOption(getText("ContextMenu_KEQ_AdminRefresh"), player, showStatus)
        sub:addOption(getText("ContextMenu_KEQ_AdminPrevious"), player, adminCommand, "adminPrevious")
        sub:addOption(getText("ContextMenu_KEQ_AdminNext"), player, adminCommand, "adminNext")
        sub:addOption(getText("ContextMenu_KEQ_AdminReset"), player, adminCommand, "adminReset")
        sub:addOption(getText("ContextMenu_KEQ_AdminReroll"), player, adminCommand, "adminReroll")
    end
end

local function clearHighlight()
    if highlightedObject then
        pcall(highlightedObject.setHighlighted, highlightedObject, highlightedPlayerNum, false)
        pcall(highlightedObject.setOutlineHighlight, highlightedObject, highlightedPlayerNum, false)
    end
    highlightedObject = nil
end

local function chooseHighlightObject(square)
    if not square then return nil end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object and object.getDeviceData then
                local ok, device = pcall(object.getDeviceData, object)
                if ok and device then return object end
            end
        end
        for i = 0, objects:size() - 1 do
            local object = objects:get(i)
            if object and object.getObjectName then
                local ok, name = pcall(object.getObjectName, object)
                if ok and tostring(name or "") ~= "IsoObject" then return object end
            end
        end
    end
    return square:getFloor()
end

local function updateHighlight(player)
    if not player then return end
    local nowMs = getTimestampMs and getTimestampMs() or 0
    if stateSyncPending and (nextStateRequestMs <= 0 or nowMs >= nextStateRequestMs) then
        sendStateRequestAttempt(player)
    end
    if extractionSoundStopAtMs > 0 and nowMs >= extractionSoundStopAtMs then
        stopExtractionSound()
    end
    if endingMovementUnblockAtMs > 0 and nowMs >= endingMovementUnblockAtMs then
        if endingOverlay then
            pcall(endingOverlay.finish, endingOverlay)
        elseif player.setBlockMovement then
            player:setBlockMovement(false)
            endingMovementUnblockAtMs = 0
        end
    end
    if nowMs > 0 and nowMs - lastHighlightUpdateMs < 500 then return end
    lastHighlightUpdateMs = nowMs

    local target = getClientTarget()
    local stage = tonumber(clientState.stage) or 0
    if not target or stage > 8 then
        clearHighlight()
        return
    end

    local distance = KEQ.DistanceToTarget(player, target)
    local sameFloor = math.floor((tonumber(player:getZ()) or 0) + 0.5) == tonumber(target.z)
    if sameFloor and distance <= 20 and notifiedTargetId ~= tostring(target.id) then
        notifiedTargetId = tostring(target.id)
        showMessage(player, getText("IGUI_KEQ_ProximityNotice"))
    end
    if not sameFloor or distance > 12 then
        clearHighlight()
        return
    end

    local square = getCell():getGridSquare(target.x, target.y, target.z)
    local object = chooseHighlightObject(square)
    if object ~= highlightedObject then
        clearHighlight()
        highlightedObject = object
    end
    if highlightedObject then
        highlightedPlayerNum = player.getPlayerNum and player:getPlayerNum() or 0
        pcall(highlightedObject.setHighlighted, highlightedObject, highlightedPlayerNum, true, true)
        pcall(highlightedObject.setHighlightColor, highlightedObject, highlightedPlayerNum, highlightColor)
        pcall(highlightedObject.setOutlineHighlight, highlightedObject, highlightedPlayerNum, true)
    end
end

local function applyState(args)
    if not args then return end
    local oldTargetId = tostring(clientState.targetId or "")
    clientState.stage = tonumber(args.stage) or clientState.stage or 0
    clientState.defenseEndHour = tonumber(args.defenseEndHour) or 0
    clientState.escaped = tostring(args.escaped or "")
    clientState.panelProgress = tonumber(args.panelProgress) or 0
    clientState.panelTotal = tonumber(args.panelTotal) or 3
    clientState.targetId = tostring(args.targetId or "")
    clientState.targetX = tonumber(args.targetX) or 0
    clientState.targetY = tonumber(args.targetY) or 0
    clientState.targetZ = tonumber(args.targetZ) or 0
    clientState.targetRadius = tonumber(args.targetRadius) or 0
    clientState.actionSeconds = tonumber(args.actionSeconds) or KEQ.ACTION_SECONDS
    if oldTargetId ~= clientState.targetId then
        notifiedTargetId = ""
        clearHighlight()
    end
end

local function notificationText(args)
    local key = args and args.messageKey or nil
    if not key then return objectiveText(clientState.stage) end
    if key == "IGUI_KEQ_Notice_PanelProgress" then
        return getText(key, tostring(clientState.panelProgress), tostring(clientState.panelTotal))
    end
    return getText(key)
end

local function playExtractionSound()
    stopExtractionSound()
    local manager = getSoundManager and getSoundManager() or nil
    if manager and manager.PlayWorldSoundImpl then
        local ok, audio = pcall(manager.PlayWorldSoundImpl, manager, "Helicopter", false,
            KEQ.Helipad.centerX, KEQ.Helipad.centerY, KEQ.Helipad.z, 0, 80, 1, false)
        if ok and audio then
            extractionSound = audio
            extractionSoundStopAtMs = (getTimestampMs and getTimestampMs() or 0) + EXTRACTION_SOUND_MS
        end
    end
end

local function onServerCommand(module, command, args)
    if module ~= KEQ.MODULE then return end
    if command == "state" or command == "notify" or command == "announceObjective" or command == "ending" then
        applyState(args)
    end
    if command == "state" then
        stateSyncPending = false
        stateRequestAttempts = 0
        nextStateRequestMs = 0
        local shouldDisplay = announceStateOnReceive or statusDisplayPending
        announceStateOnReceive = false
        statusDisplayPending = false
        if shouldDisplay then renderStatus(currentPlayer(0)) end
    elseif command == "notify" then
        local message = notificationText(args)
        if args and args.actor and tostring(args.actor) ~= "" then
            message = message .. " - " .. tostring(args.actor)
        end
        showMessage(currentPlayer(0), message)
    elseif command == "announceObjective" then
        showMessage(currentPlayer(0), getText("IGUI_KEQ_StatusPrefix") .. objectiveText(clientState.stage))
    elseif command == "ending" then
        playExtractionSound()
        if args and args.success then
            local player = currentPlayer(0)
            local ok = pcall(showEndingOverlay, player, tostring(args.escapedNow or ""))
            if not ok then
                if endingOverlay then pcall(endingOverlay.finish, endingOverlay) end
                showMessage(player, getText("IGUI_KEQ_Ending_Success") .. " " ..
                    getText("IGUI_KEQ_EscapedNames", tostring(args.escapedNow or "")))
            end
        else
            showMessage(currentPlayer(0), getText("IGUI_KEQ_Ending_Missed"))
        end
    elseif command == "surveyResult" then
        local room = tostring(args and args.room or getText("IGUI_KEQ_SurveyOutside"))
        local surveyId = tostring(args and args.surveyId or "?")
        local roomCount = tostring(args and args.roomCount or 0)
        local objectCount = tostring(args and args.objectCount or 0)
        local message = getText("IGUI_KEQ_SurveySaved") .. " #" .. surveyId ..
            " · " .. getText("IGUI_KEQ_SurveyRoom") .. ": " .. room ..
            " · " .. getText("IGUI_KEQ_SurveyCounts", roomCount, objectCount)
        showMessage(currentPlayer(0), message)
    elseif command == "surveyError" then
        showMessage(currentPlayer(0), getText("IGUI_KEQ_SurveyFailed") .. ": " .. tostring(args and args.reason or "unknown"))
    end
end

local function onGameStart()
    if not initialSyncTriggered then
        initialSyncTriggered = true
        beginStateSync(currentPlayer(0), true, false)
    end
end

local function onCreatePlayer(playerNum, player)
    if tonumber(playerNum) == 0 then
        playerCreateCount = playerCreateCount + 1
        if not initialSyncTriggered then
            initialSyncTriggered = true
            beginStateSync(player, true, false)
        elseif playerCreateCount > 1 then
            -- A replacement character created after death must also refresh
            -- the shared campaign state without requiring administrator tools.
            beginStateSync(player, true, true)
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
Events.OnServerCommand.Add(onServerCommand)
Events.OnPlayerUpdate.Add(updateHighlight)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnGameStart.Add(onGameStart)
