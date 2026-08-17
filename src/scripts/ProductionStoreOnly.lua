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
-- Closed-system exception:
--   Some products can never be moved by a vehicle in the first place —
--   the base game's biogas plant (methane, electricity) and modular
--   biogas mods such as PlanET Modular BGA, where every module feeds the
--   next one through custom fill types no trailer accepts. Forcing those
--   to KEEP does not create hauling work, it just deadlocks the chain.
--   Such outputs stay freely configurable. They are detected
--   automatically, and can also be listed by hand in the settings file:
--
--     modSettings/FS25_Realism/productionStoreOnly.xml
--
-- Implementation:
--   1. Override ProductionPoint:setOutputDistributionMode so any request
--      for DIRECT_SELL or AUTO_DELIVER is rewritten to KEEP — unless the
--      output is exempt. This covers the player's GUI clicks, savegame
--      loading, and network sync.
--   2. A one-time server-side sweep on load resets any non-exempt
--      production point that was already configured to sell/distribute
--      (e.g. when adding this mod to an existing save).
--

ProductionStoreOnly = {}
ProductionStoreOnly.NAME = "ProductionStoreOnly"

ProductionStoreOnly.CONFIG_DIRECTORY = "modSettings/FS25_Realism/"
ProductionStoreOnly.CONFIG_FILENAME = "productionStoreOnly.xml"

-- Fill type categories whose members can end up inside a vehicle. A
-- product in none of them, that is not a pallet and not traded on the
-- price table, cannot leave the building on wheels.
ProductionStoreOnly.TRANSPORT_CATEGORIES = {
    "BULK", "LIQUID", "PIECE", "SHOVEL", "FORK", "WINDROW", "COMBINE",
    "AUGERWAGON", "MIXERWAGON", "FORAGEWAGON", "FORAGEHARVESTER",
    "SILAGETRAILER", "TRAINWAGON", "SLURRYTANK", "MANURESPREADER",
    "MANURESPREADER_ORCHARDS", "SPRAYER", "SPREADER", "LOADINGVEHICLE",
    "ROOTCROP_BELT", "FARMSILO", "HAYLOFT", "ANIMAL", "HORSE", "PRODUCT",
}

ProductionStoreOnly.didInitialSweep = false
ProductionStoreOnly.config = nil
ProductionStoreOnly.haulableSet = nil
ProductionStoreOnly.haulableCache = {}
ProductionStoreOnly.reportedDecisions = {}

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

local function getFillTypeName(fillTypeId)
    if fillTypeId == nil or g_fillTypeManager == nil then
        return nil
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId)

    if fillType == nil or fillType.name == nil then
        return nil
    end

    return fillType.name:upper()
end

-- ---------------------------------------------------
-- Settings file
-- ---------------------------------------------------

local function getConfigPath()
    if getUserProfileAppPath == nil then
        return nil
    end

    return getUserProfileAppPath() .. ProductionStoreOnly.CONFIG_DIRECTORY .. ProductionStoreOnly.CONFIG_FILENAME
end

local function writeDefaultConfig(path)
    if XMLFile == nil or XMLFile.create == nil then
        return
    end

    if createFolder ~= nil then
        createFolder(getUserProfileAppPath() .. ProductionStoreOnly.CONFIG_DIRECTORY)
    end

    local xmlFile = XMLFile.create("realismProductionStoreOnlyDefault", path, "productionStoreOnly")

    if xmlFile == nil then
        return
    end

    xmlFile:setBool("productionStoreOnly#autoDetectClosedSystems", true)
    xmlFile:setBool("productionStoreOnly#debug", false)
    xmlFile:setString("productionStoreOnly.closedSystemMods#help", "<mod name=\"FS25_Example\"/> — every output of this mod's productions may sell/distribute freely")
    xmlFile:setString("productionStoreOnly.closedSystemFillTypes#help", "<fillType name=\"EXAMPLE\"/> — this product may sell/distribute freely everywhere")
    xmlFile:setString("productionStoreOnly.storeOnlyFillTypes#help", "<fillType name=\"EXAMPLE\"/> — this product is always forced to store, overriding auto-detection")

    xmlFile:save()
    xmlFile:delete()

    log("Created settings file: " .. path)
end

local function loadConfig()
    local config = {
        autoDetect = true,
        debug = false,
        allowMods = {},
        allowFillTypes = {},
        forceStoreOnly = {},
    }

    local path = getConfigPath()

    if path == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return config
    end

    local xmlFile = XMLFile.loadIfExists("realismProductionStoreOnly", path)

    if xmlFile == nil then
        writeDefaultConfig(path)

        return config
    end

    config.autoDetect = xmlFile:getBool("productionStoreOnly#autoDetectClosedSystems", config.autoDetect)
    config.debug = xmlFile:getBool("productionStoreOnly#debug", config.debug)

    xmlFile:iterate("productionStoreOnly.closedSystemMods.mod", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            config.allowMods[name:lower()] = true
        end
    end)

    xmlFile:iterate("productionStoreOnly.closedSystemFillTypes.fillType", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            config.allowFillTypes[name:upper()] = true
        end
    end)

    xmlFile:iterate("productionStoreOnly.storeOnlyFillTypes.fillType", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            config.forceStoreOnly[name:upper()] = true
        end
    end)

    xmlFile:delete()

    return config
end

local function getConfig()
    if ProductionStoreOnly.config == nil then
        ProductionStoreOnly.config = loadConfig()
    end

    return ProductionStoreOnly.config
end

-- ---------------------------------------------------
-- Transportability detection
-- ---------------------------------------------------

local function buildHaulableSet()
    local set = {}

    if g_fillTypeManager == nil or g_fillTypeManager.categoryNameToFillTypes == nil then
        return set
    end

    for _, categoryName in ipairs(ProductionStoreOnly.TRANSPORT_CATEGORIES) do
        local entries = g_fillTypeManager.categoryNameToFillTypes[categoryName]

        if entries ~= nil then
            for key, value in pairs(entries) do
                local fillTypeId = nil

                if type(value) == "number" then
                    fillTypeId = value
                elseif type(value) == "table" and value.index ~= nil then
                    fillTypeId = value.index
                elseif type(key) == "number" then
                    fillTypeId = key
                end

                if fillTypeId ~= nil then
                    set[fillTypeId] = true
                end
            end
        end
    end

    return set
end

-- A product counts as haulable when a vehicle could realistically pick it
-- up: it belongs to a transport category, comes on a pallet, or is traded
-- on the price table. Anything else only exists inside its own building.
function ProductionStoreOnly.isFillTypeHaulable(fillTypeId)
    if fillTypeId == nil then
        return true
    end

    local cached = ProductionStoreOnly.haulableCache[fillTypeId]

    if cached ~= nil then
        return cached
    end

    if g_fillTypeManager == nil then
        return true
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId)

    if fillType == nil then
        return true
    end

    if ProductionStoreOnly.haulableSet == nil then
        ProductionStoreOnly.haulableSet = buildHaulableSet()
    end

    local result = ProductionStoreOnly.haulableSet[fillTypeId] == true
        or fillType.showOnPriceTable == true
        or fillType.isPalletType == true
        or fillType.palletFilename ~= nil

    ProductionStoreOnly.haulableCache[fillTypeId] = result

    return result
end

local function getOutputFillTypeId(output)
    if type(output) ~= "table" then
        return nil
    end

    local fillTypeId = output.type or output.fillTypeId or output.fillTypeIndex or output.fillType

    if type(fillTypeId) == "table" then
        fillTypeId = fillTypeId.index
    end

    if type(fillTypeId) == "number" then
        return fillTypeId
    end

    return nil
end

-- Outputs the building's XML declares as sellDirectly are sold by the
-- game itself and usually have no storage node at all — the PlanET
-- generators are exactly that. Forcing them to store stalls the plant.
local function isSellDirectlyOutput(productionPoint, fillTypeId)
    if productionPoint == nil or fillTypeId == nil then
        return false
    end

    if productionPoint.outputFillTypeIdsSellDirectly ~= nil and productionPoint.outputFillTypeIdsSellDirectly[fillTypeId] then
        return true
    end

    if productionPoint.productions == nil then
        return false
    end

    for _, production in pairs(productionPoint.productions) do
        if production.outputs ~= nil then
            for _, output in pairs(production.outputs) do
                if type(output) == "table" and output.sellDirectly == true and getOutputFillTypeId(output) == fillTypeId then
                    return true
                end
            end
        end
    end

    return false
end

local function getProductionPointName(productionPoint)
    if productionPoint == nil then
        return "?"
    end

    local placeable = productionPoint.owningPlaceable

    if placeable ~= nil and placeable.getName ~= nil then
        local name = placeable:getName()

        if name ~= nil and name ~= "" then
            return name
        end
    end

    if productionPoint.getName ~= nil then
        local name = productionPoint:getName()

        if name ~= nil and name ~= "" then
            return name
        end
    end

    return "?"
end

local function getModName(productionPoint)
    local placeable = productionPoint ~= nil and productionPoint.owningPlaceable or nil

    if placeable ~= nil and placeable.customEnvironment ~= nil and placeable.customEnvironment ~= "" then
        return placeable.customEnvironment
    end

    return nil
end

-- Forcing KEEP on a product the building cannot store would stall the
-- production line for good, so those outputs are always left alone.
local function hasOutputStorage(productionPoint, fillTypeId)
    local storage = productionPoint ~= nil and productionPoint.storage or nil

    if storage == nil then
        return false
    end

    if storage.getCapacity ~= nil then
        local capacity = storage:getCapacity(fillTypeId)

        if capacity ~= nil then
            return capacity > 0
        end
    end

    if storage.capacities ~= nil then
        local capacity = storage.capacities[fillTypeId]

        return capacity ~= nil and capacity > 0
    end

    return true
end

-- Returns whether the output must be forced to store, plus the reason,
-- so the decision can be traced in log.txt.
function ProductionStoreOnly.getRestriction(productionPoint, fillTypeId)
    local config = getConfig()
    local fillTypeName = getFillTypeName(fillTypeId)

    if fillTypeName ~= nil and config.forceStoreOnly[fillTypeName] then
        return true, "listed in storeOnlyFillTypes"
    end

    if fillTypeName ~= nil and config.allowFillTypes[fillTypeName] then
        return false, "listed in closedSystemFillTypes"
    end

    local modName = getModName(productionPoint)

    if modName ~= nil and config.allowMods[modName:lower()] then
        return false, "mod listed in closedSystemMods"
    end

    if isSellDirectlyOutput(productionPoint, fillTypeId) then
        return false, "building sells this output directly by design"
    end

    if not hasOutputStorage(productionPoint, fillTypeId) then
        return false, "building has no storage for it"
    end

    if config.autoDetect and not ProductionStoreOnly.isFillTypeHaulable(fillTypeId) then
        return false, "no vehicle can carry it"
    end

    return true, "haulable product"
end

function ProductionStoreOnly.isRestricted(productionPoint, fillTypeId)
    local restricted = ProductionStoreOnly.getRestriction(productionPoint, fillTypeId)

    return restricted
end

-- Logs each production point / product decision once per session.
local function reportDecision(productionPoint, fillTypeId, restricted, reason)
    local pointId = tostring(productionPoint)
    local key = pointId .. "|" .. tostring(fillTypeId)

    if ProductionStoreOnly.reportedDecisions[key] then
        return
    end

    ProductionStoreOnly.reportedDecisions[key] = true

    log(string.format(
        "%s / %s: %s (%s)",
        getProductionPointName(productionPoint),
        tostring(getFillTypeName(fillTypeId)),
        restricted and "forced to store-only" or "left configurable",
        reason
    ))
end

-- ---------------------------------------------------
-- Enforcement
-- ---------------------------------------------------

local function forcedSetOutputDistributionMode(self, superFunc, fillTypeId, outputMode, noEventSend)
    local keepMode = getKeepMode()

    if keepMode ~= nil and outputMode ~= keepMode then
        local restricted, reason = ProductionStoreOnly.getRestriction(self, fillTypeId)

        reportDecision(self, fillTypeId, restricted, reason)

        if restricted then
            outputMode = keepMode
        end
    end

    return superFunc(self, fillTypeId, outputMode, noEventSend)
end

function ProductionStoreOnly.resetAllToKeep()
    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return 0, 0
    end

    local keepMode = getKeepMode()

    if keepMode == nil then
        return 0, 0
    end

    local resetCount = 0
    local exemptNames = {}
    local exemptCount = 0

    for _, productionPoint in pairs(mgr.productionPoints) do
        local candidates = {}

        if productionPoint.outputFillTypeIdsDirectSell ~= nil then
            for fillTypeId in pairs(productionPoint.outputFillTypeIdsDirectSell) do
                table.insert(candidates, fillTypeId)
            end
        end

        if productionPoint.outputFillTypeIdsAutoDeliver ~= nil then
            for fillTypeId in pairs(productionPoint.outputFillTypeIdsAutoDeliver) do
                table.insert(candidates, fillTypeId)
            end
        end

        for _, fillTypeId in ipairs(candidates) do
            if ProductionStoreOnly.isRestricted(productionPoint, fillTypeId) then
                productionPoint:setOutputDistributionMode(fillTypeId, keepMode)
                resetCount = resetCount + 1
            else
                local name = getFillTypeName(fillTypeId)

                if name ~= nil and exemptNames[name] == nil then
                    exemptNames[name] = true
                    exemptCount = exemptCount + 1
                end
            end
        end
    end

    if exemptCount > 0 then
        local names = {}

        for name in pairs(exemptNames) do
            table.insert(names, name)
        end

        table.sort(names)
        log("Closed-system outputs left configurable: " .. table.concat(names, ", "))
    end

    return resetCount, exemptCount
end

-- Full report of every production output and its verdict, enabled with
-- debug="true" in the settings file.
function ProductionStoreOnly.dumpProductionPoints()
    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return
    end

    log("--- production output report ---")

    for _, productionPoint in pairs(mgr.productionPoints) do
        local fillTypeIds = {}

        if productionPoint.productions ~= nil then
            for _, production in pairs(productionPoint.productions) do
                if production.outputs ~= nil then
                    for _, output in pairs(production.outputs) do
                        local fillTypeId = getOutputFillTypeId(output)

                        if fillTypeId ~= nil then
                            fillTypeIds[fillTypeId] = true
                        end
                    end
                end
            end
        end

        for fillTypeId in pairs(fillTypeIds) do
            local restricted, reason = ProductionStoreOnly.getRestriction(productionPoint, fillTypeId)

            log(string.format(
                "  %s / %s: %s (%s) haulable=%s storage=%s",
                getProductionPointName(productionPoint),
                tostring(getFillTypeName(fillTypeId)),
                restricted and "store-only" or "configurable",
                reason,
                tostring(ProductionStoreOnly.isFillTypeHaulable(fillTypeId)),
                tostring(hasOutputStorage(productionPoint, fillTypeId))
            ))
        end
    end

    log("--- end of report ---")
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

    if getConfig().debug then
        ProductionStoreOnly.dumpProductionPoints()
    end
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

    log("Production selling/distribution disabled — store only (closed-system products exempt)")
end

ProductionStoreOnly.install()
