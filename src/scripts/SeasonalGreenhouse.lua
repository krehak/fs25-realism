--
-- Realism — SeasonalGreenhouse
--
-- Greenhouses don't produce at the same rate all year. Real-world
-- greenhouses lose output in winter (short days, heating costs, frost
-- damage) and benefit from clear sunny weather. This feature scales
-- each greenhouse's cyclesPerMinute / cyclesPerHour / cyclesPerMonth
-- by two multipliers:
--
--   1. Season   — derived from g_currentMission.environment.currentPeriod
--      (FS25 uses 12 periods; we group them into spring / summer /
--      fall / winter).
--   2. Weather  — derived from g_currentMission.environment.weather
--      (sun / cloud / rain / snow / hail).
--
-- Only placeables in the GREENHOUSES store category are affected. A
-- fallback identifies likely greenhouse productions by their output
-- fillType (tomato, strawberry, lettuce, cucumber, pepper) so modded
-- greenhouses that use a different category still get covered.
--
-- The original cyclesPer* values are cached on first touch so that
-- repeated re-application doesn't compound. Polling runs at a fixed
-- real-time interval (no per-frame work) and only recomputes when
-- season, weather, or production-point count actually changes.
--

SeasonalGreenhouse = {}
SeasonalGreenhouse.NAME = "SeasonalGreenhouse"

SeasonalGreenhouse.UPDATE_INTERVAL_MS = 5000

SeasonalGreenhouse.SEASON_MULTIPLIERS = {
    spring = 0.75,
    summer = 1.00,
    fall = 0.75,
    winter = 0.50,
}

SeasonalGreenhouse.WEATHER_MULTIPLIERS = {
    sun = 1.20,
    cloud = 1.00,
    rain = 0.90,
    snow = 0.70,
    hail = 0.60,
}

SeasonalGreenhouse.GREENHOUSE_CATEGORIES = {
    "GREENHOUSES",
    "GREENHOUSE",
}

SeasonalGreenhouse.GREENHOUSE_OUTPUTS = {
    "TOMATO",
    "STRAWBERRY",
    "LETTUCE",
    "CUCUMBER",
    "PEPPER",
    "CHILLI",
}

SeasonalGreenhouse.timeSinceLastCheck = 0
SeasonalGreenhouse.lastSeason = nil
SeasonalGreenhouse.lastWeather = nil
SeasonalGreenhouse.lastPointCount = -1

local function logChange(touched, season, seasonMult, weather, weatherMult, total)
    if Realism == nil or Realism.log == nil then
        return
    end

    Realism.log(string.format(
        "Greenhouses (%d) — season=%s ×%.2f, weather=%s ×%.2f, total ×%.2f",
        touched, season, seasonMult, weather, weatherMult, total
    ))
end

function SeasonalGreenhouse.periodToSeason(period)
    if period == nil then
        return "summer"
    end

    if period >= 1 and period <= 3 then
        return "spring"
    end

    if period >= 4 and period <= 6 then
        return "summer"
    end

    if period >= 7 and period <= 9 then
        return "fall"
    end

    return "winter"
end

function SeasonalGreenhouse.getCurrentSeason()
    local env = g_currentMission and g_currentMission.environment

    if env == nil then
        return "summer"
    end

    return SeasonalGreenhouse.periodToSeason(env.currentPeriod)
end

function SeasonalGreenhouse.getCurrentWeatherType()
    local env = g_currentMission and g_currentMission.environment
    local weather = env and env.weather

    if weather == nil or weather.forecast == nil then
        return nil
    end

    if type(weather.forecast.dataForTime) ~= "function" or type(weather.getWeatherObjectByIndex) ~= "function" then
        return nil
    end

    local day = env.currentMonotonicDay or env.currentDay
    local time = env.dayTime

    if day == nil or time == nil then
        return nil
    end

    local _, currentWeather = weather.forecast:dataForTime(day, time)

    if currentWeather == nil then
        return nil
    end

    local weatherObject = weather:getWeatherObjectByIndex(currentWeather.season, currentWeather.objectIndex)

    if weatherObject == nil then
        return nil
    end

    return weatherObject.weatherType
end

function SeasonalGreenhouse.getCurrentWeather()
    local env = g_currentMission and g_currentMission.environment
    local weather = env and env.weather

    if weather == nil then
        return "cloud"
    end

    if type(weather.getIsHailing) == "function" and weather:getIsHailing() then
        return "hail"
    end

    if type(weather.getIsSnowing) == "function" and weather:getIsSnowing() then
        return "snow"
    end

    if type(weather.getIsRaining) == "function" and weather:getIsRaining() then
        return "rain"
    end

    local weatherType = SeasonalGreenhouse.getCurrentWeatherType()

    if weatherType ~= nil and WeatherType ~= nil and weatherType == WeatherType.SUN then
        return "sun"
    end

    return "cloud"
end

local function getStoreItem(placeable)
    if placeable == nil then
        return nil
    end

    if placeable.storeItem ~= nil then
        return placeable.storeItem
    end

    if type(placeable.getStoreItem) == "function" then
        return placeable:getStoreItem()
    end

    return nil
end

local function categoryMatches(name)
    if name == nil then
        return false
    end

    local upper = string.upper(name)

    for _, category in ipairs(SeasonalGreenhouse.GREENHOUSE_CATEGORIES) do
        if upper == category then
            return true
        end
    end

    return false
end

local function fillTypeNameFor(fillTypeRef)
    if fillTypeRef == nil then
        return nil
    end

    if type(fillTypeRef) == "string" then
        return string.upper(fillTypeRef)
    end

    if type(fillTypeRef) == "number" and g_fillTypeManager ~= nil then
        local desc = g_fillTypeManager:getFillTypeByIndex(fillTypeRef)

        if desc ~= nil and desc.name ~= nil then
            return string.upper(desc.name)
        end
    end

    return nil
end

local function productionTouchesGreenhouseOutput(prodpoint)
    if prodpoint.productions == nil then
        return false
    end

    for _, prod in ipairs(prodpoint.productions) do
        local outputs = prod.outputs or prod.outputProducts

        if outputs ~= nil then
            for _, output in pairs(outputs) do
                local name = fillTypeNameFor(output.type or output.fillType or output.fillTypeIndex)

                if name ~= nil then
                    for _, gh in ipairs(SeasonalGreenhouse.GREENHOUSE_OUTPUTS) do
                        if name == gh then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

function SeasonalGreenhouse.isGreenhouse(prodpoint)
    local placeable = prodpoint.owningPlaceable or prodpoint.placeable
    local storeItem = getStoreItem(placeable)

    if storeItem ~= nil and categoryMatches(storeItem.categoryName) then
        return true
    end

    return productionTouchesGreenhouseOutput(prodpoint)
end

local function cacheBaseValues(production)
    if production._realismBaseCpm == nil then
        production._realismBaseCpm = production.cyclesPerMinute or 0
        production._realismBaseCph = production.cyclesPerHour or 0
        production._realismBaseCpM = production.cyclesPerMonth or 0
    end
end

function SeasonalGreenhouse.applyMultipliers()
    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return 0
    end

    local season = SeasonalGreenhouse.getCurrentSeason()
    local weather = SeasonalGreenhouse.getCurrentWeather()
    local seasonMult = SeasonalGreenhouse.SEASON_MULTIPLIERS[season] or 1.0
    local weatherMult = SeasonalGreenhouse.WEATHER_MULTIPLIERS[weather] or 1.0
    local total = seasonMult * weatherMult
    local touched = 0

    for _, prodpoint in pairs(mgr.productionPoints) do
        if SeasonalGreenhouse.isGreenhouse(prodpoint) and prodpoint.productions ~= nil then
            for _, prod in ipairs(prodpoint.productions) do
                cacheBaseValues(prod)
                prod.cyclesPerMinute = prod._realismBaseCpm * total
                prod.cyclesPerHour = prod._realismBaseCph * total
                prod.cyclesPerMonth = prod._realismBaseCpM * total
            end

            touched = touched + 1
        end
    end

    logChange(touched, season, seasonMult, weather, weatherMult, total)

    return touched
end

local function countProductionPoints()
    local mgr = g_currentMission and g_currentMission.productionChainManager

    if mgr == nil or mgr.productionPoints == nil then
        return 0
    end

    local n = 0

    for _ in pairs(mgr.productionPoints) do
        n = n + 1
    end

    return n
end

function SeasonalGreenhouse:update(dt)
    self.timeSinceLastCheck = (self.timeSinceLastCheck or 0) + dt

    if self.timeSinceLastCheck < SeasonalGreenhouse.UPDATE_INTERVAL_MS then
        return
    end

    self.timeSinceLastCheck = 0

    local season = SeasonalGreenhouse.getCurrentSeason()
    local weather = SeasonalGreenhouse.getCurrentWeather()
    local count = countProductionPoints()

    if season == self.lastSeason and weather == self.lastWeather and count == self.lastPointCount then
        return
    end

    self.lastSeason = season
    self.lastWeather = weather
    self.lastPointCount = count

    SeasonalGreenhouse.applyMultipliers()
end

function SeasonalGreenhouse.install()
    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(SeasonalGreenhouse.NAME, SeasonalGreenhouse)
    end

    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("Greenhouse seasonal/weather production scaling enabled")
    else
        print("[Realism] Greenhouse seasonal/weather production scaling enabled")
    end
end

SeasonalGreenhouse.install()
