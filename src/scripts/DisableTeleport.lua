--
-- Realism — DisableTeleport
--
-- Stops the player from instantly switching to / teleporting into a
-- vehicle they are not physically next to.
--
--   1. The SWITCH_VEHICLE / SWITCH_VEHICLE_BACK input actions (Tab and
--      Shift+Tab) are suppressed at registration time, so cycling
--      between vehicles does nothing and the prompt is hidden.
--   2. Player:requestToEnterVehicle gets a distance check, so entering a
--      vehicle picked from the in-game map (which would teleport you to
--      a remote vehicle) is rejected when it is too far away.
--
-- Walking up to a vehicle and pressing E still works — the game already
-- gates that on the vehicle being in range, and the distance check here
-- passes when you are standing next to it.
--
-- Both hooks are installed defensively (only when the target really is a
-- function) so a future game patch can't turn this into a hard error.
--

DisableTeleport = {}
DisableTeleport.NAME = "DisableTeleport"
DisableTeleport.ENTER_DISTANCE = 8.0
DisableTeleport.gameStarted = false
DisableTeleport.lastMenuTime = 0
DisableTeleport.MENU_RECENCY_MS = 1200

local blockedActions = {}

if InputAction ~= nil then
    if InputAction.SWITCH_VEHICLE ~= nil then
        blockedActions[InputAction.SWITCH_VEHICLE] = true
    end

    if InputAction.SWITCH_VEHICLE_BACK ~= nil then
        blockedActions[InputAction.SWITCH_VEHICLE_BACK] = true
    end
end

local function logBlocked(reason)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("Teleport blocked — " .. reason)
    end
end

local function getNodePosition(node)
    if node == nil or node == 0 then
        return nil
    end

    if entityExists ~= nil and not entityExists(node) then
        return nil
    end

    return getWorldTranslation(node)
end

local function getVehicleNode(vehicle)
    if vehicle.rootNode ~= nil then
        return vehicle.rootNode
    end

    if vehicle.components ~= nil and vehicle.components[1] ~= nil then
        return vehicle.components[1].node
    end

    return nil
end

local function isPlayerNearVehicle(player, vehicle)
    if player == nil or vehicle == nil then
        return true
    end

    local px, py, pz = getNodePosition(player.rootNode)
    local vx, vy, vz = getNodePosition(getVehicleNode(vehicle))

    if px == nil or vx == nil then
        return true
    end

    local dx = px - vx
    local dy = py - vy
    local dz = pz - vz

    return (dx * dx + dy * dy + dz * dz) <= (DisableTeleport.ENTER_DISTANCE * DisableTeleport.ENTER_DISTANCE)
end

local function suppressSwitchRegister(self, superFunc, inputActionId, ...)
    local success, actionEventId = superFunc(self, inputActionId, ...)

    if actionEventId ~= nil and inputActionId ~= nil and blockedActions[inputActionId] then
        self:setActionEventActive(actionEventId, false)
        self:setActionEventTextVisibility(actionEventId, false)
    end

    return success, actionEventId
end

local function distanceCheckedEnter(self, superFunc, vehicle, ...)
    if vehicle ~= nil and not isPlayerNearVehicle(self, vehicle) then
        logBlocked("vehicle is too far away (map teleport)")

        return
    end

    return superFunc(self, vehicle, ...)
end

local function isMenuOpen()
    if g_gui == nil then
        return false
    end

    if type(g_gui.getIsGuiVisible) == "function" and g_gui:getIsGuiVisible() then
        return true
    end

    return false
end

local function wasMenuRecentlyOpen()
    if isMenuOpen() then
        return true
    end

    local now = g_time or 0

    return (now - DisableTeleport.lastMenuTime) < DisableTeleport.MENU_RECENCY_MS
end

local function guardedTeleportTo(self, superFunc, ...)
    if DisableTeleport.gameStarted and wasMenuRecentlyOpen() then
        logBlocked("player teleport from map (Visit / Go To)")

        return
    end

    return superFunc(self, ...)
end

function DisableTeleport:update(dt)
    DisableTeleport.gameStarted = true

    if isMenuOpen() then
        DisableTeleport.lastMenuTime = g_time or 0
    end
end

function DisableTeleport.install()
    local switchBlocked = false

    if InputBinding ~= nil and type(InputBinding.registerActionEvent) == "function" then
        InputBinding.registerActionEvent = Utils.overwrittenFunction(InputBinding.registerActionEvent, suppressSwitchRegister)
        switchBlocked = true
    end

    local enterGuarded = false

    if Player ~= nil and type(Player.requestToEnterVehicle) == "function" then
        Player.requestToEnterVehicle = Utils.overwrittenFunction(Player.requestToEnterVehicle, distanceCheckedEnter)
        enterGuarded = true
    end

    local visitGuarded = false

    if Player ~= nil and type(Player.teleportTo) == "function" then
        Player.teleportTo = Utils.overwrittenFunction(Player.teleportTo, guardedTeleportTo)
        visitGuarded = true
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(DisableTeleport.NAME, DisableTeleport)
    end

    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(string.format(
            "DisableTeleport: switch-block=%s, map-enter-guard=%s, visit-guard=%s",
            tostring(switchBlocked), tostring(enterGuarded), tostring(visitGuarded)
        ))
    end
end

DisableTeleport.install()
