--
-- Realism — StumpCutter
--
-- Lets the chainsaw remove tree stumps, like the LumberJack mod. After a
-- tree is felled, cut into the leftover stump with the chainsaw and, after
-- about a second of cutting, the stump is removed. No shovel, no store
-- item, no extra key — it uses the chainsaw you already carry.
--
-- A stump is a split shape that is split AND static:
--   * standing tree = static + NOT split  -> ignored
--   * stump         = static + split      -> removable
--   * felled log    = dynamic + split     -> ignored (a real log)
--
-- Cutting works anywhere inside the stump — the ring selector does NOT have
-- to be green. The base game only reaches its CUTTING state on a valid full
-- cut (the green ring), which is fiddly to line up on a short stump, so we
-- instead trigger on the chainsaw revving hard (engine RPM) while aimed at a
-- stump. Just hold the running chainsaw into the stump and it grinds away.
--
-- Hooks:
--   HandToolChainsaw.updateRingSelector — capture the shape the chainsaw
--     is currently aimed at (same hook LumberJack uses). Marked "fresh" only
--     on the frame it fires, so we never grind a stump we've walked away from.
--   HandToolChainsaw.onUpdate — while the chainsaw is revving (or in the
--     base-game cut state) and aimed at a stump, run a short timer, delete it.
--
-- Removal mirrors LumberJack: removeKnownSplitShape + delete the LOD and
-- the shape, server-side. Everything is pcall-guarded.
--
-- Multiplayer: detection (aiming + cut state) only exists on the machine of
-- the player holding the chainsaw, but the actual deletion must run on the
-- server. On a client we therefore send StumpCutterEvent to the server with
-- the split-shape node id. Split-shape node ids are network-consistent in
-- FS25 (the base game's ChainsawCutEvent relies on the same fact), so the
-- server resolves the exact same stump and deletes it for everyone.
--

StumpCutter = {}
StumpCutter.NAME = "StumpCutter"
StumpCutter.GRIND_TIME_MS = 1000

StumpCutter.targetShape = nil
StumpCutter.targetFresh = false
StumpCutter.grindTime = 0

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("StumpCutter: " .. tostring(message))
    else
        print("[Realism] StumpCutter: " .. tostring(message))
    end
end

local function isStump(node)
    if node == nil or node == 0 then
        return false
    end

    if entityExists ~= nil and not entityExists(node) then
        return false
    end

    if getIsSplitShapeSplit == nil then
        return false
    end

    local okSplit, isSplit = pcall(getIsSplitShapeSplit, node)

    if not okSplit or not isSplit then
        return false
    end

    if getRigidBodyType ~= nil and RigidBodyType ~= nil and RigidBodyType.STATIC ~= nil then
        local okType, rbType = pcall(getRigidBodyType, node)

        if okType then
            return rbType == RigidBodyType.STATIC
        end
    end

    return true
end

local function isServer()
    return g_currentMission ~= nil and type(g_currentMission.getIsServer) == "function" and g_currentMission:getIsServer()
end

local function removeStumpOnServer(node)
    if not isServer() then
        return false
    end

    local ok = pcall(function()
        if entityExists ~= nil and not entityExists(node) then
            return
        end

        if type(g_currentMission.removeKnownSplitShape) == "function" then
            g_currentMission:removeKnownSplitShape(node)
        end

        local lodId = node + 2

        if entityExists ~= nil and entityExists(lodId) and getName ~= nil and getName(lodId) == "LOD1" then
            delete(lodId)
        end

        if entityExists == nil or entityExists(node) then
            delete(node)
        end

        if g_densityMapHeightManager ~= nil and type(g_densityMapHeightManager.consoleCommandUpdateTipCollisions) == "function" then
            g_densityMapHeightManager:consoleCommandUpdateTipCollisions()
        end
    end)

    return ok
end

StumpCutterEvent = {}
local StumpCutterEvent_mt = Class(StumpCutterEvent, Event)

InitEventClass(StumpCutterEvent, "StumpCutterEvent")

function StumpCutterEvent.emptyNew()
    return Event.new(StumpCutterEvent_mt)
end

function StumpCutterEvent.new(node)
    local self = StumpCutterEvent.emptyNew()
    self.node = node

    return self
end

function StumpCutterEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.node or 0)
end

function StumpCutterEvent:readStream(streamId, connection)
    self.node = streamReadInt32(streamId)

    self:run(connection)
end

function StumpCutterEvent:run(connection)
    if not connection:getIsServer() then
        if removeStumpOnServer(self.node) then
            log("stump removed (client request)")
        end
    end
end

local function requestStumpRemoval(node)
    if isServer() then
        if removeStumpOnServer(node) then
            log("stump removed")
        end

        return
    end

    if g_client ~= nil and g_client.getServerConnection ~= nil then
        g_client:getServerConnection():sendEvent(StumpCutterEvent.new(node))
        log("stump removal requested from server")
    end
end

local function captureRingTarget(self, superFunc, shape, canCut, ...)
    if shape ~= nil and shape.node ~= nil then
        StumpCutter.targetShape = shape.node
        StumpCutter.targetFresh = true
    else
        StumpCutter.targetShape = nil
        StumpCutter.targetFresh = false
    end

    return superFunc(self, shape, canCut, ...)
end

local function isChainsawRevving(self)
    local motor = self.spec_motorized

    if motor == nil or motor.maxRPM == nil or motor.maxRPM == 0 then
        return false
    end

    return (motor.currentRPM or 0) > 0.8 * motor.maxRPM
end

local function onChainsawUpdate(self, dt)
    local spec = self.spec_chainsaw

    if spec == nil then
        return
    end

    local fresh = StumpCutter.targetFresh
    StumpCutter.targetFresh = false

    local baseCutting = ChainsawCutState ~= nil and spec.currentCutState == ChainsawCutState.CUTTING
    local cutting = baseCutting or isChainsawRevving(self)

    if fresh and cutting and isStump(StumpCutter.targetShape) then
        StumpCutter.grindTime = (StumpCutter.grindTime or 0) + (dt or 0)

        if StumpCutter.grindTime >= StumpCutter.GRIND_TIME_MS then
            local node = StumpCutter.targetShape

            StumpCutter.grindTime = 0
            StumpCutter.targetShape = nil

            requestStumpRemoval(node)
        end
    else
        StumpCutter.grindTime = 0
    end
end

function StumpCutter.install()
    if HandToolChainsaw == nil then
        log("HandToolChainsaw not found — chainsaw stump removal unavailable")

        return
    end

    if type(HandToolChainsaw.updateRingSelector) == "function" then
        HandToolChainsaw.updateRingSelector = Utils.overwrittenFunction(HandToolChainsaw.updateRingSelector, captureRingTarget)
    end

    if type(HandToolChainsaw.onUpdate) == "function" then
        HandToolChainsaw.onUpdate = Utils.appendedFunction(HandToolChainsaw.onUpdate, onChainsawUpdate)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(StumpCutter.NAME, StumpCutter)
    end

    log("chainsaw stump removal enabled")
end

StumpCutter.install()
