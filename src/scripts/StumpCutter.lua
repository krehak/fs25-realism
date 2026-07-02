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
-- Hooks:
--   HandToolChainsaw.updateRingSelector — capture the shape the chainsaw
--     is currently aimed at (same hook LumberJack uses).
--   HandToolChainsaw.onUpdate — while actively cutting that shape and it's
--     a stump, run a short timer, then delete it.
--
-- Removal mirrors LumberJack: removeKnownSplitShape + delete the LOD and
-- the shape, server-side. Everything is pcall-guarded.
--

StumpCutter = {}
StumpCutter.NAME = "StumpCutter"
StumpCutter.GRIND_TIME_MS = 1000

StumpCutter.targetShape = nil
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

local function removeStump(node)
    if g_currentMission == nil or type(g_currentMission.getIsServer) ~= "function" or not g_currentMission:getIsServer() then
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

local function captureRingTarget(self, superFunc, shape, canCut, ...)
    if shape ~= nil and shape.node ~= nil then
        StumpCutter.targetShape = shape.node
    else
        StumpCutter.targetShape = nil
    end

    return superFunc(self, shape, canCut, ...)
end

local function onChainsawUpdate(self, dt)
    local spec = self.spec_chainsaw

    if spec == nil then
        return
    end

    local cutting = ChainsawCutState ~= nil and spec.currentCutState == ChainsawCutState.CUTTING

    if cutting and isStump(StumpCutter.targetShape) then
        StumpCutter.grindTime = (StumpCutter.grindTime or 0) + (dt or 0)

        if StumpCutter.grindTime >= StumpCutter.GRIND_TIME_MS then
            local node = StumpCutter.targetShape

            StumpCutter.grindTime = 0
            StumpCutter.targetShape = nil

            if removeStump(node) then
                log("stump removed")
            end
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
