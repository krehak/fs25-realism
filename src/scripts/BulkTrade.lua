--
-- Realism — BulkTrade
--
-- Rewards moving goods in volume, the way a real wholesale deal works.
--
-- SELLING (selling stations, per fill type, per continuous unload):
--   The more litres you sell in one go, the bigger the bonus on top of
--   the normal price.
--     < 25,000 l        no bonus
--     25,000 l          +1%
--     ramps linearly to
--     100,000 l+        +10% (capped)
--
-- BUYING (fill stations — fertilizer, lime, seeds, herbicide, fuel —
-- per fill type, per continuous refill):
--   The more litres you buy in one go, the bigger the discount.
--     < 1,000 l         no discount
--     1,000 l           -1%
--     ramps linearly to
--     10,000 l+         -8% (capped)
--
-- How it works:
--   A "session" accumulates the litres traded with one station/trigger
--   for one fill type. It resets after a short pause (SESSION_RESET_MS)
--   with no activity, so separate deals don't stack. The bonus/discount
--   rate is derived from the running session total and applied through
--   the game's own price functions, so the money flows through the
--   normal sell/buy pathway (no manual money juggling).
--
-- NOTE: this covers liquid/granular trade at stations. A discount for
-- buying multiple pallets/big-bags by count in the shop is NOT included
-- here — FS25's per-item buy price function does not expose the
-- purchase quantity, so that path needs in-game verification before it
-- can be wired up safely.
--

BulkTrade = {}
BulkTrade.NAME = "BulkTrade"

BulkTrade.SELL_MIN_LITERS = 25000
BulkTrade.SELL_MAX_LITERS = 100000
BulkTrade.SELL_MIN_BONUS = 0.01
BulkTrade.SELL_MAX_BONUS = 0.10

BulkTrade.BUY_MIN_LITERS = 1000
BulkTrade.BUY_MAX_LITERS = 10000
BulkTrade.BUY_MIN_DISCOUNT = 0.01
BulkTrade.BUY_MAX_DISCOUNT = 0.08

BulkTrade.SESSION_RESET_MS = 4000

BulkTrade.sellSessions = {}
BulkTrade.buySessions = {}

BulkTrade.sellContext = {}
BulkTrade.buyContext = {}

local function getNow()
    if g_time ~= nil then
        return g_time
    end

    if g_currentMission ~= nil and g_currentMission.time ~= nil then
        return g_currentMission.time
    end

    return 0
end

local function rampRate(liters, minLiters, maxLiters, minRate, maxRate)
    if liters < minLiters then
        return 0
    end

    if liters >= maxLiters then
        return maxRate
    end

    return minRate + (maxRate - minRate) * (liters - minLiters) / (maxLiters - minLiters)
end

local function trackSession(sessions, owner, fillType, addLiters)
    local byOwner = sessions[owner]

    if byOwner == nil then
        byOwner = {}
        sessions[owner] = byOwner
    end

    local session = byOwner[fillType]
    local nowTime = getNow()

    if session == nil or (nowTime - session.lastTime) > BulkTrade.SESSION_RESET_MS then
        session = { liters = 0, lastTime = nowTime }
        byOwner[fillType] = session
    end

    session.liters = session.liters + addLiters
    session.lastTime = nowTime

    return session.liters
end

local function getSessionLiters(sessions, owner, fillType)
    local byOwner = sessions[owner]

    if byOwner == nil then
        return 0
    end

    local session = byOwner[fillType]

    if session == nil then
        return 0
    end

    return session.liters
end

local function sellAddFillLevelFromTool(self, superFunc, farmId, fillLevelDelta, fillTypeIndex, ...)
    if fillTypeIndex == nil or fillLevelDelta == nil or fillLevelDelta <= 0 then
        return superFunc(self, farmId, fillLevelDelta, fillTypeIndex, ...)
    end

    trackSession(BulkTrade.sellSessions, self, fillTypeIndex, fillLevelDelta)

    BulkTrade.sellContext.station = self
    BulkTrade.sellContext.fillType = fillTypeIndex

    local result = superFunc(self, farmId, fillLevelDelta, fillTypeIndex, ...)

    BulkTrade.sellContext.station = nil
    BulkTrade.sellContext.fillType = nil

    return result
end

-- Scale only the first return value (the price) while preserving any
-- other values the wrapped function returns. Truncating extra returns to
-- a single value crashes callers that expect them.
local function scaleReturns(multiplier, ...)
    local first = ...

    if type(first) == "number" then
        return first * multiplier, select(2, ...)
    end

    return ...
end

local function sellGetEffectiveFillTypePrice(self, superFunc, fillTypeIndex)
    if BulkTrade.sellContext.station == self and BulkTrade.sellContext.fillType == fillTypeIndex then
        local liters = getSessionLiters(BulkTrade.sellSessions, self, fillTypeIndex)
        local bonus = rampRate(liters, BulkTrade.SELL_MIN_LITERS, BulkTrade.SELL_MAX_LITERS, BulkTrade.SELL_MIN_BONUS, BulkTrade.SELL_MAX_BONUS)

        return scaleReturns(1 + bonus, superFunc(self, fillTypeIndex))
    end

    return superFunc(self, fillTypeIndex)
end

local function buyFillVehicle(self, superFunc, vehicle, delta, dt)
    local fillType = nil

    if type(self.getCurrentFillType) == "function" then
        fillType = self:getCurrentFillType()
    end

    if fillType == nil or delta == nil or delta <= 0 then
        return superFunc(self, vehicle, delta, dt)
    end

    trackSession(BulkTrade.buySessions, self, fillType, delta)

    BulkTrade.buyContext.trigger = self
    BulkTrade.buyContext.fillType = fillType

    local result = superFunc(self, vehicle, delta, dt)

    BulkTrade.buyContext.trigger = nil
    BulkTrade.buyContext.fillType = nil

    return result
end

local function buyGetPricePerLiter(self, superFunc, fillType)
    if BulkTrade.buyContext.trigger ~= nil and BulkTrade.buyContext.fillType == fillType then
        local liters = getSessionLiters(BulkTrade.buySessions, BulkTrade.buyContext.trigger, fillType)
        local discount = rampRate(liters, BulkTrade.BUY_MIN_LITERS, BulkTrade.BUY_MAX_LITERS, BulkTrade.BUY_MIN_DISCOUNT, BulkTrade.BUY_MAX_DISCOUNT)

        return scaleReturns(1 - discount, superFunc(self, fillType))
    end

    return superFunc(self, fillType)
end

local function installSellHooks()
    if SellingStation == nil then
        return false
    end

    if SellingStation.addFillLevelFromTool ~= nil then
        SellingStation.addFillLevelFromTool = Utils.overwrittenFunction(SellingStation.addFillLevelFromTool, sellAddFillLevelFromTool)
    end

    if SellingStation.getEffectiveFillTypePrice ~= nil then
        SellingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(SellingStation.getEffectiveFillTypePrice, sellGetEffectiveFillTypePrice)
    end

    return true
end

local function installBuyHooks()
    if FillTrigger ~= nil and FillTrigger.fillVehicle ~= nil then
        FillTrigger.fillVehicle = Utils.overwrittenFunction(FillTrigger.fillVehicle, buyFillVehicle)
    end

    if EconomyManager ~= nil and EconomyManager.getPricePerLiter ~= nil then
        EconomyManager.getPricePerLiter = Utils.overwrittenFunction(EconomyManager.getPricePerLiter, buyGetPricePerLiter)
    end

    return true
end

function BulkTrade.install()
    installSellHooks()
    installBuyHooks()

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(BulkTrade.NAME, BulkTrade)
    end

    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(string.format(
            "Bulk trade enabled (sell up to +%.0f%%, buy up to -%.0f%%)",
            BulkTrade.SELL_MAX_BONUS * 100, BulkTrade.BUY_MAX_DISCOUNT * 100
        ))
    else
        print("[Realism] Bulk trade enabled")
    end
end

BulkTrade.install()
