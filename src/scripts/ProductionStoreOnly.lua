--
-- Realism — ProductionStoreOnly
--
-- Production buildings normally let you set each output product to one
-- of three modes:
--
--   KEEP         — store the product in the building's own storage
--   DIRECT_SELL  — automatically sell it for money
--   AUTO_DELIVER — automatically distribute it to other buildings
--
-- This feature removes the two automated modes. Every output is forced
-- to KEEP, so produced goods pile up in storage and you have to drive a
-- trailer over, load them, and haul them to a sell point or another
-- production yourself — like a real supply chain.
--
-- Implementation:
--   1. Override ProductionPoint:setOutputDistributionMode so any request
--      for DIRECT_SELL or AUTO_DELIVER is rewritten to KEEP. This covers
--      the player's GUI clicks, savegame loading, and network sync.
--   2. A one-time server-side sweep on load resets any production point
--      that was already configured to sell/distribute (e.g. when adding
--      this mod to an existing save).
--

ProductionStoreOnly = {}
ProductionStoreOnly.NAME = "ProductionStoreOnly"

ProductionStoreOnly.didInitialSweep = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(message)
    else
        print("[Realism] " .. message)
    end
end

local function getKeepMode()
    if ProductionPoint ~= nil and ProductionPoint.OUTPUT_MODE ~= nil then
        return ProductionPoint.OUTPUT_MODE.KEEP
    end

    return nil
end

local function forcedSetOutputDistributionMode(self, superFunc, fillTypeId, outputMode, noEventSend)
    local keepMode = getKeepMode()

    if keepMode ~= nil then
        outputMode = keepMode
    end

    return superFunc(self, fillTypeId, outputMode, noEventSend)
end

function ProductionStoreOnly.resetAllToKeep()
    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return 0
    end

    local keepMode = getKeepMode()

    if keepMode == nil then
        return 0
    end

    local count = 0

    for _, productionPoint in pairs(mgr.productionPoints) do
        local toReset = {}

        if productionPoint.outputFillTypeIdsDirectSell ~= nil then
            for fillTypeId in pairs(productionPoint.outputFillTypeIdsDirectSell) do
                table.insert(toReset, fillTypeId)
            end
        end

        if productionPoint.outputFillTypeIdsAutoDeliver ~= nil then
            for fillTypeId in pairs(productionPoint.outputFillTypeIdsAutoDeliver) do
                table.insert(toReset, fillTypeId)
            end
        end

        for _, fillTypeId in ipairs(toReset) do
            productionPoint:setOutputDistributionMode(fillTypeId, keepMode)
            count = count + 1
        end
    end

    return count
end

function ProductionStoreOnly:update(dt)
    if self.didInitialSweep then
        return
    end

    if g_server == nil then
        self.didInitialSweep = true

        return
    end

    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return
    end

    self.didInitialSweep = true

    local resetCount = ProductionStoreOnly.resetAllToKeep()

    log(string.format("Forced %d production output(s) to store-only", resetCount))
end

function ProductionStoreOnly.install()
    if ProductionPoint ~= nil and ProductionPoint.setOutputDistributionMode ~= nil then
        ProductionPoint.setOutputDistributionMode = Utils.overwrittenFunction(
            ProductionPoint.setOutputDistributionMode,
            forcedSetOutputDistributionMode
        )
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(ProductionStoreOnly.NAME, ProductionStoreOnly)
    end

    log("Production selling/distribution disabled — store only")
end

ProductionStoreOnly.install()
