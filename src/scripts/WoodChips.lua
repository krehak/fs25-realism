--
-- Realism — WoodChips
--
-- Chipping a log creates wood chips out of thin air. A tree worth 20,000
-- litres of wood goes into the chipper and 60,000 litres of chips come
-- out — the game multiplies the volume by three. Nothing is gained by
-- chipping in reality: you get the wood you put in, in a different shape.
--
-- This feature scales the chipper's output so a log yields its own volume
-- in chips, 1 : 1 by default. Chipping stays worthwhile for what it
-- actually is — turning awkward branches into something a trailer can
-- carry and a heating plant will buy — instead of being a way to triple
-- your timber on the way out of the forest.
--
-- How it works:
--   The conversion is caught at FillUnit:addFillUnitFillLevel, the single
--   funnel every wood crusher pours its chips through, rather than at any
--   one crusher function. That covers vehicle chippers, the chipper that
--   fills an attached trailer, and stationary crushers alike, whatever
--   internal name the specialisation uses.
--
--   Only additions that come from a wood crusher are touched: either the
--   receiving vehicle carries the woodCrusher specialisation itself, or a
--   crusher is mid-update and pouring into something attached. Chips
--   moved by any other means — loaded from a heap, tipped out of a
--   trailer, bought — are left completely alone.
--
-- Not configurable, on purpose. "A log yields its own volume in chips" is
-- not a difficulty dial, it is the fix for a base-game bug that mints wood
-- out of nothing, so there is no switch for it in realism.xml. The two
-- numbers below are the physics, not a setting: the output is scaled by
-- CHIPS_PER_WOOD_LITER / GAME_CHIPS_PER_WOOD_LITER, and if a future patch
-- changes the vanilla ratio it is the second number that needs correcting.
--

WoodChips = {}
WoodChips.NAME = "WoodChips"

WoodChips.CHIPS_PER_WOOD_LITER = 1.0
WoodChips.GAME_CHIPS_PER_WOOD_LITER = 3.0

WoodChips.fillTypeIndex = nil
WoodChips.crusherContext = nil
WoodChips.reported = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("WoodChips: " .. tostring(message))
    else
        print("[Realism] WoodChips: " .. tostring(message))
    end
end

-- How much of the game's chip output survives. 1.0 leaves it untouched.
function WoodChips.getFactor()
    if WoodChips.GAME_CHIPS_PER_WOOD_LITER <= 0 then
        return 1
    end

    return WoodChips.CHIPS_PER_WOOD_LITER / WoodChips.GAME_CHIPS_PER_WOOD_LITER
end

local function getWoodChipsIndex()
    if WoodChips.fillTypeIndex ~= nil then
        return WoodChips.fillTypeIndex
    end

    if g_fillTypeManager == nil then
        return nil
    end

    WoodChips.fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName("WOODCHIPS")

    return WoodChips.fillTypeIndex
end

-- ---------------------------------------------------
-- Conversion
-- ---------------------------------------------------

-- True when these litres are being produced by a chipper right now, as
-- opposed to merely moved around like any other cargo.
local function isFromCrusher(vehicle)
    if WoodChips.crusherContext ~= nil then
        return true
    end

    return type(vehicle) == "table" and vehicle.spec_woodCrusher ~= nil
end

local function scaledAddFillUnitFillLevel(self, superFunc, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, ...)
    if fillLevelDelta ~= nil and fillLevelDelta > 0
        and fillTypeIndex ~= nil and fillTypeIndex == getWoodChipsIndex()
        and isFromCrusher(self) then

        local factor = WoodChips.getFactor()

        if factor ~= 1 then
            if not WoodChips.reported then
                WoodChips.reported = true

                log(string.format("chipper output scaled to %.0f%% of vanilla", factor * 100))
            end

            fillLevelDelta = fillLevelDelta * factor
        end
    end

    return superFunc(self, farmId, fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, ...)
end

-- A chipper that unloads into an attached trailer adds the fill level to
-- the TRAILER, which carries no crusher specialisation of its own. Marking
-- the crusher's own update tick lets those litres be recognised too.
local function markCrusherContext(self, superFunc, ...)
    local previous = WoodChips.crusherContext

    WoodChips.crusherContext = self

    local result = superFunc(self, ...)

    WoodChips.crusherContext = previous

    return result
end

function WoodChips.install()
    if FillUnit == nil or FillUnit.addFillUnitFillLevel == nil then
        log("FillUnit.addFillUnitFillLevel not found — chipper yield unchanged")

        return
    end

    FillUnit.addFillUnitFillLevel = Utils.overwrittenFunction(FillUnit.addFillUnitFillLevel, scaledAddFillUnitFillLevel)

    if WoodCrusher ~= nil then
        for _, name in ipairs({ "onUpdateTick", "onUpdate" }) do
            if type(WoodCrusher[name]) == "function" then
                WoodCrusher[name] = Utils.overwrittenFunction(WoodCrusher[name], markCrusherContext)
            end
        end
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(WoodChips.NAME, WoodChips)
    end

    log("installed")
end

WoodChips.install()
