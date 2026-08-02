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
-- Cutting works anywhere on the stump — the ring selector does NOT have to be
-- green. The base game only reaches its CUTTING state on a valid full cut (the
-- green ring), which is impossible to line up on a short stump. But while the
-- player holds the saw trigger into an invalid spot the base game enters its
-- DELIMBING state instead, so we treat DELIMBING and CUTTING alike: either one,
-- aimed at a stump, means "actively sawing this stump". (spec_chainsaw has no
-- turned-on / RPM flag we can read; a chainsaw is a HandTool, not a vehicle.)
--
-- The aimed shape and the cut state both flicker frame-to-frame while sawing,
-- so we latch the stump and keep a short grace window (GRACE_MS): brief
-- dropouts don't reset the grind timer, but releasing the trigger or aiming
-- away for longer than the grace clears it.
--
-- Hooks:
--   HandToolChainsaw.updateRingSelector — capture the shape the chainsaw
--     is currently aimed at (same hook LumberJack uses).
--   HandToolChainsaw.onUpdate — while sawing (DELIMBING or CUTTING) a latched
--     stump, run a short timer, then delete it.
--
-- Removal mirrors LumberJack: removeKnownSplitShape + delete the LOD and the
-- shape. Everything is pcall-guarded and re-checks isStump before deleting.
--
-- Multiplayer: detection (aiming + cut state) only exists on the machine of the
-- player holding the chainsaw, but a raw delete(node) is local to one scene and
-- does NOT sync. So removal is server-authoritative AND broadcast:
--   * client holding the saw  -> sends StumpCutterEvent(node) to the server
--   * server                  -> removes locally, then broadcasts the same
--                                event to every client, which each delete their
--                                own copy (host-held saw skips straight to this)
-- Split-shape node ids are network-consistent in FS25 (the base game's own tree
-- cutting relies on the same fact), so the id resolves to the same stump on
-- every machine; the receiving side still re-checks isStump as a safety net.
--

StumpCutter = {}
StumpCutter.NAME = "StumpCutter"
StumpCutter.GRIND_TIME_MS = 700
StumpCutter.GRACE_MS = 500

StumpCutter.targetShape = nil
StumpCutter.grindStump = nil
StumpCutter.grindTime = 0
StumpCutter.idleTime = 0

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

local function applyRemovalLocally(node)
    if not isStump(node) then
        return false
    end

    return pcall(function()
        if isServer() and type(g_currentMission.removeKnownSplitShape) == "function" then
            g_currentMission:removeKnownSplitShape(node)
        end

        local lodId = node + 2

        if entityExists ~= nil and entityExists(lodId) and getName ~= nil and getName(lodId) == "LOD1" then
            delete(lodId)
        end

        if entityExists == nil or entityExists(node) then
            delete(node)
        end

        if isServer() and g_densityMapHeightManager ~= nil and type(g_densityMapHeightManager.consoleCommandUpdateTipCollisions) == "function" then
            g_densityMapHeightManager:consoleCommandUpdateTipCollisions()
        end
    end)
end

local function removeStumpEverywhere(node)
    if not applyRemovalLocally(node) then
        return false
    end

    if g_server ~= nil and type(g_server.broadcastEvent) == "function" then
        g_server:broadcastEvent(StumpCutterEvent.new(node))
    end

    return true
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
    if isServer() then
        if removeStumpEverywhere(self.node) then
            log("stump removed (client request)")
        end
    else
        log(string.format("applying removal from server: node=%s isStump=%s",
            tostring(self.node), tostring(isStump(self.node))))

        applyRemovalLocally(self.node)
    end
end

local function requestStumpRemoval(node)
    if isServer() then
        if removeStumpEverywhere(node) then
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
    else
        StumpCutter.targetShape = nil
    end

    return superFunc(self, shape, canCut, ...)
end

local function isSawing(spec)
    if ChainsawCutState == nil then
        return false
    end

    local state = spec.currentCutState

    return state == ChainsawCutState.CUTTING or state == ChainsawCutState.DELIMBING
end

local function onChainsawUpdate(self, dt)
    local spec = self.spec_chainsaw

    if spec == nil then
        return
    end

    dt = dt or 0

    local target = StumpCutter.targetShape
    local grinding = isSawing(spec) and isStump(target)

    if grinding then
        if StumpCutter.grindStump ~= target then
            StumpCutter.grindStump = target
            StumpCutter.grindTime = 0
        end

        StumpCutter.grindTime = StumpCutter.grindTime + dt
        StumpCutter.idleTime = 0

        if StumpCutter.grindTime >= StumpCutter.GRIND_TIME_MS then
            local node = StumpCutter.grindStump

            StumpCutter.grindStump = nil
            StumpCutter.grindTime = 0

            requestStumpRemoval(node)
        end
    elseif StumpCutter.grindStump ~= nil then
        StumpCutter.idleTime = StumpCutter.idleTime + dt

        if StumpCutter.idleTime >= StumpCutter.GRACE_MS then
            StumpCutter.grindStump = nil
            StumpCutter.grindTime = 0
            StumpCutter.idleTime = 0
        end
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
