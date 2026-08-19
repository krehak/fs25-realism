--
-- Realism — BulkTrade
--
-- Buying in volume earns a discount, the way a real wholesale deal does.
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
--   A "session" accumulates the litres bought from one trigger for one
--   fill type. It resets after a short pause (SESSION_RESET_MS) with no
--   activity, so separate deals don't stack. The discount is derived from
--   the running session total and applied through the game's own price
--   function, so the money flows through the normal buy pathway (no
--   manual money juggling).
--
-- SELLING is deliberately NOT handled here. What a load is worth is
-- decided by the SupplyDemand feature, which prices every good against
-- what the market is actually absorbing. A flat volume bonus on top of
-- that would work against it — paying you more for exactly the dumping
-- that is supposed to depress the price.
--
-- The thresholds and the discount ramp are configurable under Settings
-- ("bulkTrade"); switching the feature off leaves station prices at their
-- normal value without unhooking anything.
--
-- NOTE: this covers liquid/granular buying at stations. A discount for
-- buying multiple pallets/big-bags by count in the shop is NOT included
-- here — FS25's per-item buy price function does not expose the
-- purchase quantity, so that path needs in-game verification before it
-- can be wired up safely.
--

BulkTrade = {}
BulkTrade.NAME = "BulkTrade"

-- How long a pause ends one refill "deal", in real milliseconds. Internal
-- pacing rather than a difficulty knob — an admin tuning it would only
-- change how easily two separate refills merge into one discount.
BulkTrade.SESSION_RESET_MS = 4000

BulkTrade.FALLBACK = {
    minLiters = 1000,
    maxLiters = 10000,
    minDiscount = 0.01,
    maxDiscount = 0.08,
    sessionResetMs = 4000,
}

BulkTrade.buySessions = {}

BulkTrade.buyContext = {}

local function isEnabled()
    if Settings == nil then
        return true
    end

    return Settings.isEnabled("bulkTrade")
end

local function setting(key)
    if Settings == nil then
        return BulkTrade.FALLBACK[key]
    end

    local value = Settings.get("bulkTrade", key)

    if value == nil then
        return BulkTrade.FALLBACK[key]
    end

    return value
end

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
    if isEnabled() and BulkTrade.buyContext.trigger ~= nil and BulkTrade.buyContext.fillType == fillType then
        local liters = getSessionLiters(BulkTrade.buySessions, BulkTrade.buyContext.trigger, fillType)
        local discount = rampRate(
            liters,
            setting("minLiters"), setting("maxLiters"),
            setting("minDiscount"), setting("maxDiscount")
        )

        return scaleReturns(1 - discount, superFunc(self, fillType))
    end

    return superFunc(self, fillType)
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
    installBuyHooks()

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(BulkTrade.NAME, BulkTrade)
    end

    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("Bulk buying installed (selling is priced by supply and demand)")
    else
        print("[Realism] Bulk buying installed")
    end
end

BulkTrade.install()
