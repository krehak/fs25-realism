--
-- Realism — DisableTeleport
--
-- Stops the player from instantly switching to / teleporting into a
-- vehicle they are not physically next to.
--
-- ONE switch, not four. The three guards below are the same rule wearing
-- different hats — reach a vehicle you are not standing beside — and leaving
-- any one of them open defeats the other two, because Tab, the map's enter,
-- and the map's Visit all end up doing the same thing. Splitting them only
-- created settings that appeared to do nothing: allowing Tab while the enter
-- guard still refused a distant vehicle looked exactly like a broken switch.
--
--   1. The SWITCH_VEHICLE / SWITCH_VEHICLE_BACK input actions (Tab and
--      Shift+Tab) are deactivated, so cycling between vehicles does
--      nothing and the prompt is hidden.
--   2. Player:requestToEnterVehicle gets a distance check, so entering a
--      vehicle picked from the in-game map (which would teleport you to
--      a remote vehicle) is rejected when it is too far away.
--   3. Player:teleportTo rejects any jump of the local player further than
--      maxTeleportDistance, which is what the map's "Visit" / "Go To"
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
-- Everything here is read live from Settings ("disableTeleport"), never
-- cached at install time, so an admin can hand teleporting back to a stuck
-- player mid-session and take it away again a minute later. Because the Tab
-- block works by deactivating already-registered action events, the ids it
-- has touched are remembered and reactivated the moment the switch flips
-- back, instead of staying dead until the next vehicle change.
--

DisableTeleport = {}
DisableTeleport.NAME = "DisableTeleport"

-- Distances in metres, deliberately not exposed as settings. They are the
-- line between "standing next to it" and "teleporting", which is the whole
-- point of the feature; a server that widens them has simply turned
-- teleporting back on, and there is already a switch for that.
DisableTeleport.ENTER_DISTANCE = 8.0
DisableTeleport.MAX_TELEPORT_DISTANCE = 50.0

-- The map's Visit / Go To sends the player to a field, a building or an NPC.
-- Fields and buildings arrive through Player:teleportTo and are caught by the
-- distance rule. Visiting an NPC does not: the game has a dedicated
-- teleportToNPC for it, which is why nothing keyed off distance or off the
-- click handler ever saw it.
--
-- It is blocked outright rather than by distance. A function whose only
-- purpose is "put the player next to that NPC" is the thing being disabled;
-- there is no near-enough case where it should still fire.
--
-- Its two siblings are deliberately NOT touched: teleportToExitPoint is how
-- you get out of a vehicle and teleportToSpawnPoint is how you respawn.
-- Blocking either would strand the player.
DisableTeleport.ALWAYS_BLOCKED = { "teleportToNPC" }

-- Both the player and its mover expose the same call; whichever the game
-- routes through, it is covered.
DisableTeleport.MOVER_CLASSES = { "PlayerMover", "PlayerStateMachine", "PlayerController" }

-- Flip to true and rebuild to have the player / map-frame / mover APIs of the
-- running game written to log.txt. That is how teleportToNPC was found, and
-- it is how the next rename will be.
DisableTeleport.PROBE_API = false

DisableTeleport.hookedBlocks = {}
DisableTeleport.probed = false

DisableTeleport.gameStarted = false
DisableTeleport.pendingBlocked = {}
DisableTeleport.knownEventIds = {}
DisableTeleport.switchBlockApplied = nil

local function isEnabled()
    if Settings == nil then
        return true
    end

    return Settings.isEnabled("disableTeleport")
end

function DisableTeleport.getEnterDistance()
    return DisableTeleport.ENTER_DISTANCE
end

function DisableTeleport.getMaxTeleportDistance()
    return DisableTeleport.MAX_TELEPORT_DISTANCE
end

function DisableTeleport.isSwitchBlocked()
    return isEnabled()
end

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

    local range = DisableTeleport.getEnterDistance()

    return (dx * dx + dy * dy + dz * dz) <= (range * range)
end

-- Remember the event id (2nd return) without disturbing the return list.
local function recordBlocked(...)
    local actionEventId = select(2, ...)

    if actionEventId ~= nil then
        DisableTeleport.pendingBlocked[#DisableTeleport.pendingBlocked + 1] = actionEventId
        DisableTeleport.knownEventIds[actionEventId] = true
    end

    return ...
end

local function suppressSwitchRegister(self, superFunc, inputActionId, ...)
    if inputActionId == nil or not blockedActions[inputActionId] then
        return superFunc(self, inputActionId, ...)
    end

    return recordBlocked(superFunc(self, inputActionId, ...))
end

local function setEventActive(actionEventId, active)
    pcall(function()
        g_inputBinding:setActionEventActive(actionEventId, active)
        g_inputBinding:setActionEventTextVisibility(actionEventId, active)
    end)
end

local function applyPendingBlocks(blocked)
    local pending = DisableTeleport.pendingBlocked

    if #pending == 0 then
        return
    end

    DisableTeleport.pendingBlocked = {}

    if g_inputBinding == nil or not blocked then
        return
    end

    for _, actionEventId in ipairs(pending) do
        setEventActive(actionEventId, false)
    end
end

-- Re-applies the switch block to every event id seen so far. Used when the
-- setting flips, so releasing the block brings Tab back immediately rather
-- than at the next action-event registration.
local function reapplySwitchBlock(blocked)
    DisableTeleport.pendingBlocked = {}

    if g_inputBinding == nil then
        return
    end

    for actionEventId in pairs(DisableTeleport.knownEventIds) do
        setEventActive(actionEventId, not blocked)
    end
end

local function distanceCheckedEnter(self, superFunc, vehicle, ...)
    local guarded = isEnabled()

    if guarded and vehicle ~= nil and not isPlayerNearVehicle(self, vehicle) then
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
    local guarded = isEnabled()

    if guarded and DisableTeleport.gameStarted and isLocalControlledPlayer(self) then
        local distance = teleportDistance(self, x, y, z)

        if distance ~= nil and distance > DisableTeleport.getMaxTeleportDistance() then
            logBlocked(string.format("player jump of %.0f m (map Visit / Go To)", distance))

            return
        end
    end

    return superFunc(self, x, y, z, ...)
end

-- Refuses the call and returns nothing, exactly as the distance guard does.
local function blockedMove(self, superFunc, ...)
    if isEnabled() and DisableTeleport.gameStarted and isLocalControlledPlayer(self) then
        logBlocked("map Visit / Go To on an NPC")

        return
    end

    return superFunc(self, ...)
end

-- Written once to log.txt. If a visit still slips through, this says which
-- functions exist to slip through, which beats another round of guessing.
local function probeApi()
    if not DisableTeleport.PROBE_API or DisableTeleport.probed or Realism == nil or Realism.log == nil then
        return
    end

    DisableTeleport.probed = true

    -- Lua patterns have no alternation, so the wanted substrings are just
    -- tested one at a time.
    local function names(tbl, wanted)
        if type(tbl) ~= "table" then
            return "<missing>"
        end

        local found = {}

        for key, value in pairs(tbl) do
            if type(key) == "string" and type(value) == "function" then
                local lower = key:lower()

                for _, needle in ipairs(wanted) do
                    if lower:find(needle, 1, true) ~= nil then
                        table.insert(found, key)

                        break
                    end
                end
            end
        end

        table.sort(found)

        return #found > 0 and table.concat(found, ", ") or "<none>"
    end

    local MOVE = { "pos", "teleport", "move", "warp" }
    local VISIT = { "visit", "hotspot", "goto", "click" }

    Realism.log("DisableTeleport probe — Player move-ish: " .. names(Player, MOVE))
    Realism.log("DisableTeleport probe — localPlayer fields: " .. names(g_localPlayer, MOVE))
    Realism.log("DisableTeleport probe — mapFrame visit-ish: " .. names(InGameMenuMapFrame, VISIT))

    for _, className in ipairs(DisableTeleport.MOVER_CLASSES) do
        Realism.log(string.format("DisableTeleport probe — %s: %s", className, names(_G[className], MOVE)))
    end
end

function DisableTeleport:update(dt)
    DisableTeleport.gameStarted = true

    probeApi()

    local blocked = DisableTeleport.isSwitchBlocked()

    if blocked ~= DisableTeleport.switchBlockApplied then
        DisableTeleport.switchBlockApplied = blocked

        reapplySwitchBlock(blocked)

        return
    end

    applyPendingBlocks(blocked)
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

    -- The NPC visit, on whichever object the game routes it through.
    local blocks = {}

    local function blockOn(class, className)
        if type(class) ~= "table" then
            return
        end

        for _, name in ipairs(DisableTeleport.ALWAYS_BLOCKED) do
            if type(class[name]) == "function" then
                class[name] = Utils.overwrittenFunction(class[name], blockedMove)
                table.insert(blocks, className .. ":" .. name)
            end
        end
    end

    blockOn(Player, "Player")

    for _, className in ipairs(DisableTeleport.MOVER_CLASSES) do
        blockOn(_G[className], className)
    end

    DisableTeleport.hookedBlocks = blocks

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(DisableTeleport.NAME, DisableTeleport)
    end

    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(string.format(
            "DisableTeleport: switch-block=%s, map-enter-guard=%s, visit-guard=%s, NPC visit blocked on: %s",
            tostring(switchBlocked), tostring(enterGuarded), tostring(visitGuarded),
            #DisableTeleport.hookedBlocks > 0
                and table.concat(DisableTeleport.hookedBlocks, ", ")
                or "NOTHING FOUND — the NPC visit will still work"
        ))
    end
end

DisableTeleport.install()
