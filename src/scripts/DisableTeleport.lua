--
-- Realism — DisableTeleport
--
-- Stops the player from instantly switching to / teleporting into a
-- vehicle they are not physically next to.
--
--   1. The SWITCH_VEHICLE / SWITCH_VEHICLE_BACK input actions (Tab and
--      Shift+Tab) are deactivated, so cycling between vehicles does
--      nothing and the prompt is hidden.
--   2. Player:requestToEnterVehicle gets a distance check, so entering a
--      vehicle picked from the in-game map (which would teleport you to
--      a remote vehicle) is rejected when it is too far away.
--   3. Player:teleportTo rejects any jump of the local player further than
--      MAX_TELEPORT_DISTANCE, which is what the map's "Visit" / "Go To"
--      does on a field, building or NPC.
--
-- Walking up to a vehicle and pressing E still works — the game already
-- gates that on the vehicle being in range, and the distance check here
-- passes when you are standing next to it.
--
-- The teleport guard keys off distance rather than "was a menu open just
-- now", which is what it used to do. That heuristic leaked both ways: the
-- map closes its screen before teleporting, so a Visit could land outside
-- the window and go through, while ShopTrigger:openShop — which opens the
-- shop screen and only then teleports you to the shop's spawn — sat inside
-- it and got blocked. Distance also lets the short, legitimate teleports
-- through untouched: stepping out of a vehicle, or entering the shop.
-- Only the local controlled player is guarded, so a joining or moving
-- player elsewhere in a multiplayer session is never affected.
--
-- The switch block wraps InputBinding:registerActionEvent, which every
-- vehicle and implement control in the game goes through, so that wrapper
-- has to be invisible to everything except the two blocked actions:
--
--   * Any other action is a straight tail call to the original. No return
--     values are captured and re-returned, because doing that truncates
--     them to the two the wrapper happens to name — callers like
--     Vehicle:addActionEvent key their spec.actionEvents table off those
--     returns, and an implement whose entry never lands in that table has
--     a control that silently does nothing (a bale wrapper that won't
--     unload, for instance).
--   * A blocked action is only recorded here and deactivated on the next
--     frame from update(). Calling setActionEventActive() from inside
--     registerActionEvent mutates the input system mid-registration,
--     while the vehicle's whole action-event pass is still open.
--
-- Both hooks are installed defensively (only when the target really is a
-- function) so a future game patch can't turn this into a hard error.
--

DisableTeleport = {}
DisableTeleport.NAME = "DisableTeleport"
DisableTeleport.ENTER_DISTANCE = 8.0
DisableTeleport.gameStarted = false
DisableTeleport.MAX_TELEPORT_DISTANCE = 50.0
DisableTeleport.pendingBlocked = {}

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

-- Remember the event id (2nd return) without disturbing the return list.
local function recordBlocked(...)
    local actionEventId = select(2, ...)

    if actionEventId ~= nil then
        DisableTeleport.pendingBlocked[#DisableTeleport.pendingBlocked + 1] = actionEventId
    end

    return ...
end

local function suppressSwitchRegister(self, superFunc, inputActionId, ...)
    if inputActionId == nil or not blockedActions[inputActionId] then
        return superFunc(self, inputActionId, ...)
    end

    return recordBlocked(superFunc(self, inputActionId, ...))
end

local function applyPendingBlocks()
    local pending = DisableTeleport.pendingBlocked

    if #pending == 0 then
        return
    end

    DisableTeleport.pendingBlocked = {}

    if g_inputBinding == nil then
        return
    end

    for _, actionEventId in ipairs(pending) do
        pcall(function()
            g_inputBinding:setActionEventActive(actionEventId, false)
            g_inputBinding:setActionEventTextVisibility(actionEventId, false)
        end)
    end
end

local function distanceCheckedEnter(self, superFunc, vehicle, ...)
    if vehicle ~= nil and not isPlayerNearVehicle(self, vehicle) then
        logBlocked("vehicle is too far away (map teleport)")

        return
    end

    return superFunc(self, vehicle, ...)
end

local function isLocalControlledPlayer(player)
    if player == nil then
        return false
    end

    if g_localPlayer ~= nil then
        return player == g_localPlayer
    end

    return player.isOwner == true
end

local function teleportDistance(player, x, y, z)
    if x == nil or y == nil or z == nil then
        return nil
    end

    local px, py, pz = getNodePosition(player.rootNode)

    if px == nil then
        return nil
    end

    local dx = px - x
    local dy = py - y
    local dz = pz - z

    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function guardedTeleportTo(self, superFunc, x, y, z, ...)
    if DisableTeleport.gameStarted and isLocalControlledPlayer(self) then
        local distance = teleportDistance(self, x, y, z)

        if distance ~= nil and distance > DisableTeleport.MAX_TELEPORT_DISTANCE then
            logBlocked(string.format("player jump of %.0f m (map Visit / Go To)", distance))

            return
        end
    end

    return superFunc(self, x, y, z, ...)
end

function DisableTeleport:update(dt)
    DisableTeleport.gameStarted = true

    applyPendingBlocks()
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
