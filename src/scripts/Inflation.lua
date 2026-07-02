--
-- Realism — Inflation
--
-- Economy-wide inflation, like the real world. Every year a rate between
-- 1.5% and 5.5% is chosen and held for that whole year. The effect
-- compounds across years and applies to BOTH buying and selling, so:
--
--   * inputs, fuel and machinery get more expensive over time
--   * crops and produced goods are worth more over time
--   * you can "invest" by storing goods and selling them years later at
--     the higher, inflated price
--
-- The price multiplier for year N is:
--   (1 + rate(1)) * (1 + rate(2)) * ... * (1 + rate(N))
--
-- Each year's rate is derived deterministically from the year number, so
-- it is stable across save reloads and identical for every multiplayer
-- peer (no desync, no need to persist anything). The rate sequence is
-- the same between playthroughs; true per-save randomness would need
-- savegame persistence and can be added later.
--
-- Applied through the game's own price functions (so it stacks correctly
-- with the BulkTrade bonuses):
--   EconomyManager:getPricePerLiter        (fill-station buying)
--   EconomyManager:getBuyPrice             (shop / vehicle / pallet buying)
--   SellingStation:getEffectiveFillTypePrice (selling)
--

Inflation = {}
Inflation.NAME = "Inflation"

Inflation.MIN_RATE = 0.015
Inflation.MAX_RATE = 0.055
Inflation.PERIODS_PER_YEAR = 12
Inflation.UPDATE_INTERVAL_MS = 5000

Inflation.cachedYear = -1
Inflation.cachedMultiplier = 1.0
Inflation.announcedYear = -1
Inflation.timeSinceLastCheck = 0

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(message)
    else
        print("[Realism] " .. message)
    end
end

function Inflation.getYearRate(year)
    if year == nil or year < 1 then
        return 0
    end

    local seed = (year * 1103515245 + 12345) % 2147483648
    seed = (seed * 1103515245 + 12345) % 2147483648
    local r = seed / 2147483648

    return Inflation.MIN_RATE + r * (Inflation.MAX_RATE - Inflation.MIN_RATE)
end

function Inflation.getCurrentYear()
    local env = g_currentMission and g_currentMission.environment

    if env == nil then
        return 1
    end

    local daysPerPeriod = env.daysPerPeriod or 1

    if daysPerPeriod < 1 then
        daysPerPeriod = 1
    end

    local day = env.currentMonotonicDay or env.currentDay or 1
    local elapsedMonths = math.floor(math.max(day - 1, 0) / daysPerPeriod)

    return math.floor(elapsedMonths / Inflation.PERIODS_PER_YEAR) + 1
end

function Inflation.computeMultiplier(year)
    local multiplier = 1.0

    for y = 1, year do
        multiplier = multiplier * (1 + Inflation.getYearRate(y))
    end

    return multiplier
end

function Inflation.getMultiplier()
    local year = Inflation.getCurrentYear()

    if year ~= Inflation.cachedYear then
        Inflation.cachedYear = year
        Inflation.cachedMultiplier = Inflation.computeMultiplier(year)
    end

    return Inflation.cachedMultiplier
end

-- Scale only the first return value (the price) by the multiplier while
-- preserving every other value the wrapped function returns. Truncating
-- extra returns to a single value crashes callers that expect them (e.g.
-- ShopConfigScreen, which subtracts a second returned value).
local function scaleReturns(multiplier, ...)
    local first = ...

    if type(first) == "number" then
        return first * multiplier, select(2, ...)
    end

    return ...
end

local function inflatedGetPricePerLiter(self, superFunc, ...)
    return scaleReturns(Inflation.getMultiplier(), superFunc(self, ...))
end

local function inflatedGetEffectiveFillTypePrice(self, superFunc, ...)
    return scaleReturns(Inflation.getMultiplier(), superFunc(self, ...))
end

local function inflatedGetBuyPrice(self, superFunc, ...)
    return scaleReturns(Inflation.getMultiplier(), superFunc(self, ...))
end

local function notify(text)
    if g_currentMission == nil or g_currentMission.hud == nil then
        return
    end

    local hud = g_currentMission.hud

    if type(hud.addSideNotification) == "function" then
        local color = FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_INFO or { 1, 1, 1, 1 }

        pcall(function()
            hud:addSideNotification(color, text, 6000)
        end)
    end
end

function Inflation:update(dt)
    self.timeSinceLastCheck = (self.timeSinceLastCheck or 0) + dt

    if self.timeSinceLastCheck < Inflation.UPDATE_INTERVAL_MS then
        return
    end

    self.timeSinceLastCheck = 0

    local year = Inflation.getCurrentYear()

    if year ~= Inflation.announcedYear then
        Inflation.announcedYear = year

        local rate = Inflation.getYearRate(year)
        local multiplier = Inflation.getMultiplier()

        log(string.format("Year %d inflation: +%.1f%% (cumulative prices x%.2f)", year, rate * 100, multiplier))
        notify(string.format("Inflation this year: +%.1f%% (prices x%.2f)", rate * 100, multiplier))
    end
end

function Inflation.install()
    if EconomyManager ~= nil then
        if type(EconomyManager.getPricePerLiter) == "function" then
            EconomyManager.getPricePerLiter = Utils.overwrittenFunction(EconomyManager.getPricePerLiter, inflatedGetPricePerLiter)
        end

        if type(EconomyManager.getBuyPrice) == "function" then
            EconomyManager.getBuyPrice = Utils.overwrittenFunction(EconomyManager.getBuyPrice, inflatedGetBuyPrice)
        end
    end

    if SellingStation ~= nil and type(SellingStation.getEffectiveFillTypePrice) == "function" then
        SellingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(SellingStation.getEffectiveFillTypePrice, inflatedGetEffectiveFillTypePrice)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(Inflation.NAME, Inflation)
    end

    log(string.format("Inflation enabled (random %.1f%%-%.1f%% per year, buying and selling)", Inflation.MIN_RATE * 100, Inflation.MAX_RATE * 100))
end

Inflation.install()
