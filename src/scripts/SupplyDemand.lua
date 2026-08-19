--
-- Realism — SupplyDemand
--
-- A living market driven by RATES, the way a real one works. Every market
-- good has a demand rate — how much of it the world absorbs each month at
-- the normal price — and the farms feed it a supply rate. The price
-- chases the ratio between the two, losing a fixed number of points every
-- time supply DOUBLES past demand:
--
--   supply <= demand      ->  100%
--   supply == 2x demand   ->   90%
--   supply == 4x demand   ->   80%
--   supply == 8x demand   ->   70%   (and so on, down to MIN_INDEX)
--
-- where "demand" is that product family's own market size, in money per
-- in-game month.
--
-- Selling LESS than the market wants is simply normal trade, priced at
-- 100%. The premium above 100% is not paid for being small — it is paid
-- for being ABSENT, and only after the product has gone unsold for
-- SCARCITY_ONSET_MONTHS, after which it climbs slowly to MAX_INDEX. Sell
-- a product every month, even a trickle of it, and it stays at 100%.
--
-- and gaining half as much for every halving below demand, up to
-- MAX_INDEX. A constant cost per doubling keeps the curve gentle right
-- where farms actually live — near balance — instead of falling off a
-- cliff the moment you tip past it.
--
-- Because both sides are RATES, selling the same amount every month does
-- NOT let the price recover between deliveries: a steady stream of
-- lettuce holds lettuce down for as long as it keeps coming. The price
-- only climbs back when the flow actually slows down or stops.
--
-- WHAT THIS FEATURE COVERS
--   Three product families, and nothing else. The point is to blunt the
--   handful of earners that scale without effort, not to price the whole
--   economy:
--
--     greenhouse — lettuce, tomatoes, strawberries and whatever else the
--                  greenhouses on this map produce. Plant once, add water,
--                  collect pallets forever: the easiest money in the game,
--                  so much the strictest limit.
--     wood       — planks, long planks, beams, wood chips. Real work —
--                  fell, delimb, haul, cut, chip — so the market is far
--                  more forgiving. RAW LOGS ARE NOT INCLUDED: they are
--                  worth little per litre and moving them is already the
--                  job.
--     animalProducts — milk, eggs, wool, honey and the dairy made from
--                  them. The most demanding thing on a farm to keep
--                  running, so the most generous market of the three.
--                  Named for the PRODUCE, not the herd size.
--
--   FIELD CROPS ARE DELIBERATELY EXCLUDED. A silo holds grain
--   indefinitely at no cost, so there is no glut to model — you just
--   store it until you want the money. Wheat, barley, canola and the rest
--   trade at exactly the price the game sets, and so does every good
--   outside the three classes: bricks, bread, cans, flour, sugar, fabric.
--   Untracked goods never move at all, in either direction, so the
--   scarcity premium is likewise confined to those same three families.
--
--   Greenhouse produce is detected from the greenhouse buildings actually
--   on the map, so modded greenhouses and their fruit are covered without
--   a list. Wood and animal produce are matched by name; anything a mod
--   adds can be pulled in with a one-line <products> entry naming its
--   class.
--
-- Timing is measured in in-game MONTHS (periods), not days, so the feel
-- is identical whether a month is 1 day or 10.
--
-- Server / client:
--   The server owns the market — it tracks supply, ages prices and
--   broadcasts the price index. Clients ask for the full state on join.
--   Supply figures stay server-side; clients only need prices.
--
-- Persistence:
--   Prices AND the supply memory are written to the savegame folder as
--   realismSupplyDemand.xml, keyed by fill type NAME.
--
-- Tuning:
--   savegame<N>/realism.xml, under <supplyDemand>
--

SupplyDemand = {}
SupplyDemand.NAME = "SupplyDemand"

SupplyDemand.SAVEGAME_FILENAME = "realismSupplyDemand.xml"

-- Flip to true and rebuild to have the full market table — every product
-- with its class, supply, demand and how long it has gone unsold — written
-- to log.txt on load and once a minute after. A developer's tool, not a
-- server setting: it is noisy, and nothing about the game changes.
SupplyDemand.DEBUG = false

-- Per-class market size (money worth absorbed each in-game month) and
-- market memory (how many months of trade the price remembers).
SupplyDemand.CLASS_ORDER = { "greenhouse", "wood", "animalProducts" }
--
-- Each class is sized by how much WORK its money costs, so the market
-- leans on the effortless earners and leaves the laborious ones alone:
--
--   greenhouse — plant once, add water, collect pallets forever. The
--                easiest money in the game, so the smallest market and
--                the strictest limit by a wide margin.
--   wood       — a real job: fell, delimb, haul, cut, chip. Worth far
--                more before the price reacts.
--   animalProducts — the most demanding thing on a farm; feed, straw, water,
--                muck out, every month, forever. The most generous
--                market of the three, and a short memory only because
--                herds produce steadily anyway.
--
-- memoryMonths also decides how much a LUMPY seller is punished versus a
-- steady one. A short memory concentrates one delivery, so hoarding for a
-- single giant payday craters the price while the load comes off.
SupplyDemand.DEFAULT_CLASSES = {
    greenhouse = { demandPerMonth = 35000, memoryMonths = 3 },
    wood = { demandPerMonth = 50000, memoryMonths = 3 },
    animalProducts = { demandPerMonth = 100000, memoryMonths = 2 },
}

-- Sawn and processed timber only. Raw WOOD is deliberately absent: logs
-- are worth little per litre and hauling them is already the work, so
-- there is nothing to discourage.
SupplyDemand.WOOD_FILL_TYPES = {
    WOODCHIPS = true,
    PLANK = true, PLANKS = true,
    LONGPLANK = true, LONGPLANKS = true, PLANKLONG = true, PLANKSLONG = true,
    WOODBEAM = true, WOODBEAMS = true, BEAM = true, BEAMS = true,
}

-- What a herd yields, and the dairy made directly from it. Deliberately
-- NOT a catch-all for processed goods: bricks, bread, cans, flour, sugar
-- and the rest are outside this feature entirely and trade at the price
-- the game sets. Modded animal produce can be added with a <products>
-- entry naming class="animalProducts".
SupplyDemand.ANIMAL_FILL_TYPES = {
    MILK = true, GOATMILK = true, BUFFALOMILK = true, SHEEPMILK = true,
    EGG = true, EGGS = true, WOOL = true, HONEY = true,
    BUTTER = true, CHEESE = true, GOATCHEESE = true, BUFFALOMOZZARELLA = true,
    CREAM = true, YOGURT = true,
}

-- Used only if the map exposes no greenhouse buildings to learn from.
SupplyDemand.GREENHOUSE_FALLBACK = {
    TOMATO = true, STRAWBERRY = true, LETTUCE = true,
    CUCUMBER = true, PEPPER = true, CHILLI = true,
}
SupplyDemand.UPDATE_INTERVAL_MS = 2500
SupplyDemand.SYNC_INTERVAL_MS = 15000
SupplyDemand.DEBUG_DUMP_INTERVAL_MS = 60000
SupplyDemand.SYNC_EPSILON = 0.005
SupplyDemand.MAX_ENTRIES_PER_EVENT = 200
SupplyDemand.MARKET_SCAN_RETRIES = 40

SupplyDemand.OVERSUPPLY_THRESHOLD = 0.85
SupplyDemand.DEMAND_THRESHOLD = 1.15
SupplyDemand.TRADED_THRESHOLD = 0.995
SupplyDemand.MAX_NOTIFICATIONS_PER_TICK = 2

SupplyDemand.MS_PER_DAY = 86400000
SupplyDemand.LN2 = 0.6931471805599453

-- Things a farm buys or that are not goods at all. Market membership is
-- normally decided by what the map's sell points accept; this only
-- guards the cases where a map also happens to buy an input back.
SupplyDemand.DEFAULT_EXCLUDED = {
    "DIESEL", "DEF", "ELECTRICCHARGE", "METHANE", "WATER",
    "SEEDS", "FERTILIZER", "LIQUIDFERTILIZER", "HERBICIDE", "LIME",
    "ROCK", "ROCKS", "STONE", "STONES",
    "MANURE", "LIQUIDMANURE", "SLURRY", "DIGESTATE",
}

SupplyDemand.market = {}
SupplyDemand.syncedIndex = {}
SupplyDemand.marketState = {}
SupplyDemand.wasOversupplied = {}

SupplyDemand.config = nil
SupplyDemand.lastMonth = nil
SupplyDemand.timeSinceUpdate = 0
SupplyDemand.timeSinceSync = 0
SupplyDemand.timeSinceDump = 0
SupplyDemand.scanAttempts = 0
SupplyDemand.seeded = false
SupplyDemand.loaded = false
SupplyDemand.requestedState = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("SupplyDemand: " .. tostring(message))
    else
        print("[Realism] SupplyDemand: " .. tostring(message))
    end
end

local function isServer()
    return g_server ~= nil
end

local function l10n(key, fallback)
    if g_i18n ~= nil and g_i18n.hasText ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end

    return fallback
end

local function notify(text)
    if g_currentMission == nil or g_currentMission.hud == nil then
        return
    end

    local hud = g_currentMission.hud

    if type(hud.addSideNotification) ~= "function" then
        return
    end

    local color = FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_INFO or { 1, 1, 1, 1 }

    pcall(function()
        hud:addSideNotification(color, text, 6000)
    end)
end

-- ---------------------------------------------------
-- Fill type helpers
-- ---------------------------------------------------

local function getFillType(fillTypeIndex)
    if fillTypeIndex == nil or g_fillTypeManager == nil then
        return nil
    end

    return g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
end

-- Memoised: this is called on every price lookup and every sale chunk, and
-- name:upper() would otherwise allocate a string each time. Fill types do
-- not change during a session.
SupplyDemand.nameCache = {}

local function getFillTypeName(fillTypeIndex)
    local cached = SupplyDemand.nameCache[fillTypeIndex]

    if cached ~= nil then
        return cached
    end

    local fillType = getFillType(fillTypeIndex)

    if fillType == nil or fillType.name == nil then
        return nil
    end

    local name = fillType.name:upper()
    SupplyDemand.nameCache[fillTypeIndex] = name

    return name
end

local function getFillTypeTitle(fillTypeIndex)
    local fillType = getFillType(fillTypeIndex)

    if fillType == nil then
        return "?"
    end

    if fillType.title ~= nil and fillType.title ~= "" then
        return fillType.title
    end

    return tostring(fillType.name)
end

-- The undisturbed base worth of one litre. Trade is measured in money so
-- that a tanker of milk and a tanker of silage do not press on their
-- markets by the same amount just because they hold the same litres.
local function getBasePricePerLiter(fillTypeIndex)
    local fillType = getFillType(fillTypeIndex)

    if fillType == nil or fillType.pricePerLiter == nil or fillType.pricePerLiter <= 0 then
        return 1
    end

    return fillType.pricePerLiter
end

-- ---------------------------------------------------
-- Settings
-- ---------------------------------------------------
--
-- The single-value knobs (the price floor and ceiling, how fast the index
-- moves, notifications, debug) live in realism.xml with every other
-- feature's, and are re-read whenever an admin changes one, so retuning the
-- market mid-session takes effect on the next tick.
--
-- The per-class and per-product rates are lists, so they are this feature's
-- own child elements in the same file, read and written through the
-- Settings extras hook. They are read once at load: changing a demand rate
-- means editing the file and running rlSettingsReload.
--

SupplyDemand.lists = nil
SupplyDemand.config = nil
SupplyDemand.configGeneration = nil

local function buildDefaultLists()
    local lists = {
        products = {},
        excluded = {},
        included = {},
    }

    for _, name in ipairs(SupplyDemand.DEFAULT_EXCLUDED) do
        lists.excluded[name] = true
    end

    return lists
end


local function readLists(xmlFile, basePath)
    local lists = buildDefaultLists()

    xmlFile:iterate(basePath .. ".products.fillType", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            lists.products[name:upper()] = {
                class = xmlFile:getString(key .. "#class"),
                demandPerMonth = xmlFile:getFloat(key .. "#demandPerMonth"),
                memoryMonths = xmlFile:getFloat(key .. "#memoryMonths"),
            }
        end
    end)

    xmlFile:iterate(basePath .. ".excludedFillTypes.fillType", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            lists.excluded[name:upper()] = true
        end
    end)

    xmlFile:iterate(basePath .. ".includedFillTypes.fillType", function(_, key)
        local name = xmlFile:getString(key .. "#name")

        if name ~= nil and name ~= "" then
            lists.included[name:upper()] = true
            lists.excluded[name:upper()] = nil
        end
    end)

    SupplyDemand.lists = lists
    SupplyDemand.configGeneration = nil
end

local function writeLists(xmlFile, basePath)
    local lists = SupplyDemand.lists or buildDefaultLists()

    local index = 0

    for name, override in pairs(lists.products) do
        local key = string.format("%s.products.fillType(%d)", basePath, index)

        xmlFile:setString(key .. "#name", name)

        if override.class ~= nil then
            xmlFile:setString(key .. "#class", override.class)
        end

        if override.demandPerMonth ~= nil then
            xmlFile:setFloat(key .. "#demandPerMonth", override.demandPerMonth)
        end

        if override.memoryMonths ~= nil then
            xmlFile:setFloat(key .. "#memoryMonths", override.memoryMonths)
        end

        index = index + 1
    end

    index = 0

    for name in pairs(lists.included) do
        xmlFile:setString(string.format("%s.includedFillTypes.fillType(%d)#name", basePath, index), name)
        index = index + 1
    end

    -- Only the admin's own additions are written back. The built-in
    -- exclusions (fuel, seed, rocks and the rest) are re-seeded from
    -- DEFAULT_EXCLUDED on every read, so listing them here would bloat the
    -- file for nothing — but anything hand-added must survive a save, or
    -- rlSettingsSave would quietly discard it.
    local isDefault = {}

    for _, name in ipairs(SupplyDemand.DEFAULT_EXCLUDED) do
        isDefault[name] = true
    end

    index = 0

    for name in pairs(lists.excluded) do
        if not isDefault[name] then
            xmlFile:setString(string.format("%s.excludedFillTypes.fillType(%d)#name", basePath, index), name)
            index = index + 1
        end
    end

    xmlFile:setString(basePath .. ".products#help", "<fillType name=\"LETTUCE\" class=\"greenhouse\" demandPerMonth=\"9000\" memoryMonths=\"3\"/> — override one product's class or rates")
    xmlFile:setString(basePath .. ".excludedFillTypes#help", "<fillType name=\"EXAMPLE\"/> — never part of the market, always trades at 100%")
    xmlFile:setString(basePath .. ".includedFillTypes#help", "<fillType name=\"EXAMPLE\"/> — force into the market even if no sell point advertises it")
end

if Settings ~= nil then
    Settings.registerExtra("supplyDemand", { read = readLists, write = writeLists })
end

local function setting(key, fallback)
    if Settings == nil then
        return fallback
    end

    local value = Settings.get("supplyDemand", key)

    if value == nil then
        return fallback
    end

    return value
end

-- One table the rest of the file reads, rebuilt whenever an admin changes
-- a setting so nothing has to know where a given value came from.
local function getConfig()
    local generation = Settings ~= nil and Settings.getGeneration() or 0

    if SupplyDemand.config ~= nil and SupplyDemand.configGeneration == generation then
        return SupplyDemand.config
    end

    if SupplyDemand.lists == nil then
        SupplyDemand.lists = buildDefaultLists()
    end

    local config = SupplyDemand.lists

    config.enabled = setting("enabled", true) == true
    config.minIndex = setting("minIndex", 0.55)
    config.maxIndex = setting("maxIndex", 1.20)
    config.oversupplyPerDoubling = setting("oversupplyPointsPerDoubling", 0.10)
    config.scarcityOnsetMonths = setting("scarcityOnsetMonths", 3.0)
    config.scarcityPerMonth = setting("scarcityPointsPerMonth", 0.02)
    config.dropHalfLifeMonths = setting("priceDropHalfLifeMonths", 0.5)
    config.riseHalfLifeMonths = setting("priceRiseHalfLifeMonths", 2.0)
    config.notifications = setting("notifications", true) == true
    config.debug = SupplyDemand.DEBUG

    if config.maxIndex < config.minIndex then
        config.maxIndex = config.minIndex
    end

    SupplyDemand.config = config
    SupplyDemand.configGeneration = generation

    return config
end

-- ---------------------------------------------------
-- Game time, in months
-- ---------------------------------------------------

-- Continuous in-game month (period) number. Everything is expressed in
-- months so the market feels the same at 1 day per month as at 10.
local function getCurrentMonth()
    local env = g_currentMission and g_currentMission.environment

    if env == nil then
        return nil
    end

    local day = env.currentMonotonicDay or env.currentDay

    if day == nil then
        return nil
    end

    local daysPerPeriod = env.daysPerPeriod or 1

    if daysPerPeriod < 1 then
        daysPerPeriod = 1
    end

    local dayFraction = math.min(math.max((env.dayTime or env.currentDayTime or 0) / SupplyDemand.MS_PER_DAY, 0), 1)

    return (math.max(day - 1, 0) + dayFraction) / daysPerPeriod
end

-- ---------------------------------------------------
-- Market membership
-- ---------------------------------------------------

-- The market is an opt-in list of three product families, not everything
-- the map happens to buy. A good is in only if it classifies into one of
-- them; everything else keeps the game's own price.
local function buildMarketSet(greenhouseOutputs)
    local config = getConfig()
    local set = {}
    local count = 0

    if g_fillTypeManager == nil or g_fillTypeManager.fillTypes == nil then
        return set, count
    end

    for _, fillType in pairs(g_fillTypeManager.fillTypes) do
        local fillTypeIndex = fillType.index

        if fillTypeIndex ~= nil then
            local className = SupplyDemand.classifyFillType(fillTypeIndex, greenhouseOutputs)

            if className ~= nil then
                set[fillTypeIndex] = className
                count = count + 1
            end
        end
    end

    -- A hand-listed product with no class of its own joins the gentlest
    -- market rather than being silently ignored.
    for name in pairs(config.included) do
        local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)

        if fillTypeIndex ~= nil and set[fillTypeIndex] == nil then
            set[fillTypeIndex] = SupplyDemand.CLASS_ORDER[#SupplyDemand.CLASS_ORDER]
            count = count + 1

            log(string.format("%s forced into the market as '%s'", name, set[fillTypeIndex]))
        end
    end

    for fillTypeIndex in pairs(set) do
        local name = getFillTypeName(fillTypeIndex)

        if name ~= nil and config.excluded[name] then
            set[fillTypeIndex] = nil
            count = count - 1
        end
    end

    return set, count
end

function SupplyDemand.isTracked(fillTypeIndex)
    if fillTypeIndex == nil or not getConfig().enabled then
        return false
    end

    return SupplyDemand.market[fillTypeIndex] ~= nil
end

function SupplyDemand.getIndex(fillTypeIndex)
    local entry = SupplyDemand.market[fillTypeIndex]

    if entry == nil then
        return 1
    end

    return entry.index
end

-- Every product a greenhouse on this map produces. Learned from the map
-- itself (reusing SeasonalGreenhouse's building detection) so modded
-- greenhouses and their produce are covered, with a small name list as a
-- fallback for maps that expose nothing to learn from.
local function buildGreenhouseOutputs()
    local set = {}
    local manager = g_currentMission and g_currentMission.productionChainManager

    if manager ~= nil and manager.productionPoints ~= nil
        and SeasonalGreenhouse ~= nil and type(SeasonalGreenhouse.isGreenhouse) == "function" then

        for _, productionPoint in pairs(manager.productionPoints) do
            local ok, isGreenhouse = pcall(SeasonalGreenhouse.isGreenhouse, productionPoint)

            if ok and isGreenhouse and productionPoint.productions ~= nil then
                for _, production in pairs(productionPoint.productions) do
                    if production.outputs ~= nil then
                        for _, output in pairs(production.outputs) do
                            local fillTypeId = type(output) == "table" and (output.type or output.fillTypeId or output.fillTypeIndex) or nil

                            if type(fillTypeId) == "number" then
                                set[fillTypeId] = true
                            end
                        end
                    end
                end
            end
        end
    end

    if next(set) == nil and g_fillTypeManager ~= nil then
        for name in pairs(SupplyDemand.GREENHOUSE_FALLBACK) do
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)

            if fillTypeIndex ~= nil then
                set[fillTypeIndex] = true
            end
        end
    end

    return set
end

-- Which of the three markets a product belongs to, or nil for the great
-- majority of goods that this feature does not touch at all.
--
-- Field crops are deliberately absent. A farm silo holds grain
-- indefinitely at no cost, so there is no glut to model: you simply store
-- it until you want the money. Crops trade at the price the game sets,
-- and so does everything else outside the three classes — bricks, bread,
-- cans, flour, sugar, fabric and the rest.
function SupplyDemand.classifyFillType(fillTypeIndex, greenhouseOutputs)
    local name = getFillTypeName(fillTypeIndex)
    local override = name ~= nil and getConfig().products[name] or nil

    if override ~= nil and override.class ~= nil and override.class ~= "" then
        local className = override.class:lower()

        if SupplyDemand.DEFAULT_CLASSES[className] ~= nil then
            return className
        end
    end

    if name ~= nil and SupplyDemand.WOOD_FILL_TYPES[name] then
        return "wood"
    end

    if name ~= nil and SupplyDemand.ANIMAL_FILL_TYPES[name] then
        return "animalProducts"
    end

    if greenhouseOutputs ~= nil and greenhouseOutputs[fillTypeIndex] then
        return "greenhouse"
    end

    return nil
end

-- Resolves the market size and memory for one product: class defaults,
-- then any per-product override on top.
-- Each family's market size and memory are ordinary settings, so an admin
-- can see them with rlSettings and move them with rlSet like anything else:
--   greenhouseDemandPerMonth / greenhouseMemoryMonths, and the same for
--   wood and animal.
function SupplyDemand.getClassRates(className)
    local defaults = SupplyDemand.DEFAULT_CLASSES[className]

    if defaults == nil then
        return nil, nil
    end

    return setting(className .. "DemandPerMonth", defaults.demandPerMonth),
        setting(className .. "MemoryMonths", defaults.memoryMonths)
end

function SupplyDemand.resolveRates(fillTypeIndex, className)
    local config = getConfig()
    local demand, memory = SupplyDemand.getClassRates(className)

    if demand == nil then
        return nil, nil
    end

    local name = getFillTypeName(fillTypeIndex)
    local override = name ~= nil and config.products[name] or nil

    if override ~= nil then
        if override.demandPerMonth ~= nil and override.demandPerMonth > 0 then
            demand = override.demandPerMonth
        end

        if override.memoryMonths ~= nil and override.memoryMonths > 0 then
            memory = override.memoryMonths
        end
    end

    return demand, memory
end

-- ---------------------------------------------------
-- The market model
-- ---------------------------------------------------

-- Where the price wants to sit.
--
-- OVERSUPPLY is a fixed number of points per DOUBLING of supply past
-- demand, so the curve is gentle around the balance point where farms
-- actually operate and never has a cliff: 2x supply costs one step, 4x
-- costs two, 8x three.
--
-- SCARCITY is not a mirror of that. It is driven purely by how long the
-- product has gone WITHOUT A SINGLE SALE, never by how far below demand
-- you are. A shortage is the market running dry, not the market being
-- quiet: if you deliver every month the shelves are stocked, and stocked
-- shelves do not command a premium — however small each delivery is.
-- So any product you sell regularly sits at exactly 100%, and only one
-- that stops arriving entirely, for scarcityOnsetMonths, starts to climb.
--
-- Without that rule the premium became a subsidy: a smallholder selling a
-- trickle of milk was, by the ratio alone, "scarce", and got paid extra
-- every month for it.
function SupplyDemand.getTargetIndex(ratio, idleMonths, config)

    local target = 1

    if ratio >= 1 then
        target = 1 - config.oversupplyPerDoubling * (math.log(ratio) / SupplyDemand.LN2)
    else
        local quiet = (idleMonths or 0) - config.scarcityOnsetMonths

        if quiet > 0 then
            target = 1 + config.scarcityPerMonth * quiet
        end
    end

    return math.min(math.max(target, config.minIndex), config.maxIndex)
end

-- One tick of the market: age the supply memory, work out the target
-- price, then let the price drift towards it.
local function advanceEntry(fillTypeIndex, entry, deltaMonths, config)
    local demand, memory = SupplyDemand.resolveRates(fillTypeIndex, entry.class)

    if demand == nil then
        return
    end

    entry.supply = entry.supply * 0.5 ^ (deltaMonths / memory)

    if entry.supply < 1e-6 then
        entry.supply = 0
    end

    entry.idle = (entry.idle or 0) + deltaMonths

    local target = SupplyDemand.getTargetIndex(entry.supply / demand, entry.idle, config)
    local halfLife = target < entry.index and config.dropHalfLifeMonths or config.riseHalfLifeMonths

    entry.index = target + (entry.index - target) * 0.5 ^ (deltaMonths / halfLife)

    if entry.index < config.minIndex then
        entry.index = config.minIndex
    elseif entry.index > config.maxIndex then
        entry.index = config.maxIndex
    end
end

function SupplyDemand.advanceMarket()
    local config = getConfig()
    local month = getCurrentMonth()

    if month == nil then
        return
    end

    if SupplyDemand.lastMonth == nil then
        SupplyDemand.lastMonth = month

        return
    end

    local deltaMonths = month - SupplyDemand.lastMonth

    if deltaMonths <= 0 then
        SupplyDemand.lastMonth = month

        return
    end

    SupplyDemand.lastMonth = month

    for fillTypeIndex, entry in pairs(SupplyDemand.market) do
        advanceEntry(fillTypeIndex, entry, deltaMonths, config)
    end
end

-- Feeds a sale into the supply memory. The decaying average is scaled so
-- that a steady stream of R money per month settles at supply == R.
--
-- The price is then pulled straight down to whatever the new supply
-- justifies, without waiting for the next market tick. That immediacy is
-- what stops the oldest trick in the book: sit on a product until it
-- drifts up to the scarcity premium, then dump a year's stock into that
-- high price in one go. Here the price collapses as the load comes off —
-- the first litres fetch the premium, the rest do not — so a huge dump
-- is worth markedly less per litre than the same goods sold as they come.
--
-- Only downwards, and only from selling. Recovery stays gradual.
function SupplyDemand.registerSale(fillTypeIndex, liters)
    if not isServer() or liters == nil or liters <= 0 then
        return
    end

    local entry = SupplyDemand.market[fillTypeIndex]

    if entry == nil or not getConfig().enabled then
        return
    end

    local value = liters * getBasePricePerLiter(fillTypeIndex)

    local demand, memory = SupplyDemand.resolveRates(fillTypeIndex, entry.class)

    if demand == nil then
        return
    end

    entry.supply = entry.supply + value * SupplyDemand.LN2 / memory
    entry.idle = 0

    local target = SupplyDemand.getTargetIndex(entry.supply / demand, 0, getConfig())

    if target < entry.index then
        entry.index = target
    end
end

-- ---------------------------------------------------
-- Network sync
-- ---------------------------------------------------

SupplyDemandStateEvent = {}
local SupplyDemandStateEvent_mt = Class(SupplyDemandStateEvent, Event)

InitEventClass(SupplyDemandStateEvent, "SupplyDemandStateEvent")

function SupplyDemandStateEvent.emptyNew()
    return Event.new(SupplyDemandStateEvent_mt)
end

function SupplyDemandStateEvent.new(entries)
    local self = SupplyDemandStateEvent.emptyNew()
    self.entries = entries or {}

    return self
end

function SupplyDemandStateEvent:writeStream(streamId, connection)
    local count = math.min(#self.entries, SupplyDemand.MAX_ENTRIES_PER_EVENT)

    streamWriteUInt8(streamId, count)

    for i = 1, count do
        local entry = self.entries[i]

        streamWriteInt32(streamId, entry.fillTypeIndex)
        streamWriteFloat32(streamId, entry.value)
    end
end

function SupplyDemandStateEvent:readStream(streamId, connection)
    local count = streamReadUInt8(streamId)

    self.entries = {}

    for _ = 1, count do
        local fillTypeIndex = streamReadInt32(streamId)
        local value = streamReadFloat32(streamId)

        table.insert(self.entries, { fillTypeIndex = fillTypeIndex, value = value })
    end

    self:run(connection)
end

function SupplyDemandStateEvent:run(connection)
    if isServer() then
        return
    end

    for _, entry in ipairs(self.entries) do
        if entry.fillTypeIndex ~= nil and entry.value ~= nil and entry.value > 0 then
            local existing = SupplyDemand.market[entry.fillTypeIndex]

            if existing == nil then
                -- A price for something this client did not classify itself
                -- (the server's lists differ, or a mod product it lacks).
                -- Only the index is ever used here — the market is run on
                -- the server — so the rest is placeholder, marked as such
                -- so a debug dump does not claim a class it never had.
                SupplyDemand.market[entry.fillTypeIndex] = {
                    index = entry.value,
                    supply = 0,
                    idle = 0,
                    class = "from server",
                }
            else
                existing.index = entry.value
            end
        end
    end
end

SupplyDemandRequestEvent = {}
local SupplyDemandRequestEvent_mt = Class(SupplyDemandRequestEvent, Event)

InitEventClass(SupplyDemandRequestEvent, "SupplyDemandRequestEvent")

function SupplyDemandRequestEvent.emptyNew()
    return Event.new(SupplyDemandRequestEvent_mt)
end

function SupplyDemandRequestEvent.new()
    return SupplyDemandRequestEvent.emptyNew()
end

function SupplyDemandRequestEvent:writeStream(streamId, connection)
end

function SupplyDemandRequestEvent:readStream(streamId, connection)
    self:run(connection)
end

function SupplyDemandRequestEvent:run(connection)
    if connection:getIsServer() then
        return
    end

    SupplyDemand.sendState(connection, true)
end

local function sendEntries(entries, connection)
    local chunk = {}

    for _, entry in ipairs(entries) do
        table.insert(chunk, entry)

        if #chunk >= SupplyDemand.MAX_ENTRIES_PER_EVENT then
            if connection ~= nil then
                connection:sendEvent(SupplyDemandStateEvent.new(chunk))
            else
                g_server:broadcastEvent(SupplyDemandStateEvent.new(chunk))
            end

            chunk = {}
        end
    end

    if #chunk > 0 then
        if connection ~= nil then
            connection:sendEvent(SupplyDemandStateEvent.new(chunk))
        else
            g_server:broadcastEvent(SupplyDemandStateEvent.new(chunk))
        end
    end
end

-- Sends prices to one connection: everything when full is set, otherwise
-- only what has drifted since the last sync.
function SupplyDemand.sendState(connection, full)
    if connection == nil then
        return
    end

    local entries = {}

    for fillTypeIndex, entry in pairs(SupplyDemand.market) do
        local synced = SupplyDemand.syncedIndex[fillTypeIndex]

        if full or synced == nil or math.abs(synced - entry.index) >= SupplyDemand.SYNC_EPSILON then
            table.insert(entries, { fillTypeIndex = fillTypeIndex, value = entry.index })
        end
    end

    if #entries > 0 then
        sendEntries(entries, connection)
    end
end

local function broadcastChanges()
    if g_server == nil then
        return
    end

    local entries = {}

    for fillTypeIndex, entry in pairs(SupplyDemand.market) do
        local synced = SupplyDemand.syncedIndex[fillTypeIndex]

        if synced == nil or math.abs(synced - entry.index) >= SupplyDemand.SYNC_EPSILON then
            table.insert(entries, { fillTypeIndex = fillTypeIndex, value = entry.index })
            SupplyDemand.syncedIndex[fillTypeIndex] = entry.index
        end
    end

    if #entries > 0 then
        sendEntries(entries, nil)
    end
end

-- Returns whether the request actually went out, so a client whose server
-- connection is not up yet simply tries again next tick.
local function requestState()
    if g_client == nil or type(g_client.getServerConnection) ~= "function" then
        return false
    end

    local connection = g_client:getServerConnection()

    if connection == nil then
        return false
    end

    connection:sendEvent(SupplyDemandRequestEvent.new())

    return true
end

-- ---------------------------------------------------
-- Persistence
-- ---------------------------------------------------

local function getSavegamePath()
    local missionInfo = g_currentMission and g_currentMission.missionInfo

    if missionInfo == nil or missionInfo.savegameDirectory == nil then
        return nil
    end

    return missionInfo.savegameDirectory .. "/" .. SupplyDemand.SAVEGAME_FILENAME
end

function SupplyDemand.saveToSavegame()
    if not isServer() or not SupplyDemand.loaded then
        return
    end

    local path = getSavegamePath()

    if path == nil or XMLFile == nil or XMLFile.create == nil then
        return
    end

    local ok = pcall(function()
        local xmlFile = XMLFile.create("realismSupplyDemandSave", path, "supplyDemand")

        if xmlFile == nil then
            return
        end

        local i = 0

        for fillTypeIndex, entry in pairs(SupplyDemand.market) do
            local name = getFillTypeName(fillTypeIndex)

            if name ~= nil then
                local key = string.format("supplyDemand.product(%d)", i)

                xmlFile:setString(key .. "#name", name)
                xmlFile:setFloat(key .. "#index", entry.index)
                xmlFile:setFloat(key .. "#supply", entry.supply)
                xmlFile:setFloat(key .. "#idleMonths", entry.idle or 0)

                i = i + 1
            end
        end

        xmlFile:save()
        xmlFile:delete()
    end)

    if not ok then
        log("failed to write " .. tostring(path))
    end
end

local function loadFromSavegame()
    local path = getSavegamePath()

    if path == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return 0
    end

    local xmlFile = XMLFile.loadIfExists("realismSupplyDemandLoad", path)

    if xmlFile == nil then
        return 0
    end

    local config = getConfig()
    local restored = 0

    xmlFile:iterate("supplyDemand.product", function(_, key)
        local name = xmlFile:getString(key .. "#name")
        local index = xmlFile:getFloat(key .. "#index")
        local supply = xmlFile:getFloat(key .. "#supply")
        local idle = xmlFile:getFloat(key .. "#idleMonths")

        if name ~= nil and index ~= nil and g_fillTypeManager ~= nil then
            local fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName(name)
            local entry = fillTypeIndex ~= nil and SupplyDemand.market[fillTypeIndex] or nil

            if entry ~= nil then
                entry.index = math.min(math.max(index, config.minIndex), config.maxIndex)
                entry.supply = math.max(supply or 0, 0)
                entry.idle = math.max(idle or 0, 0)
                restored = restored + 1
            end
        end
    end)

    xmlFile:delete()

    return restored
end

-- ---------------------------------------------------
-- Price hook
-- ---------------------------------------------------

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

local function marketGetEffectiveFillTypePrice(self, superFunc, fillTypeIndex, ...)
    local entry = SupplyDemand.market[fillTypeIndex]

    if entry == nil then
        return superFunc(self, fillTypeIndex, ...)
    end

    return scaleReturns(entry.index, superFunc(self, fillTypeIndex, ...))
end

local function marketAddFillLevelFromTool(self, superFunc, farmId, fillLevelDelta, fillTypeIndex, ...)
    if fillTypeIndex ~= nil and fillLevelDelta ~= nil and fillLevelDelta > 0 then
        if self.acceptedFillTypes == nil or self.acceptedFillTypes[fillTypeIndex] then
            SupplyDemand.registerSale(fillTypeIndex, fillLevelDelta)
        end
    end

    return superFunc(self, farmId, fillLevelDelta, fillTypeIndex, ...)
end

-- ---------------------------------------------------
-- Notifications and reporting
-- ---------------------------------------------------

local function classify(value)
    if value <= SupplyDemand.OVERSUPPLY_THRESHOLD then
        return "oversupplied"
    end

    if value >= SupplyDemand.DEMAND_THRESHOLD then
        return "demand"
    end

    return "normal"
end

-- Announces the moment a product crosses into a market extreme.
--
-- A "back in demand" message only fires for something that was glutted
-- earlier in this session. Without that rule every untouched good on the
-- map would drift up to the premium after a few quiet months and
-- announce itself, burying the player in notifications about products
-- they have never touched — the news that matters is about goods they
-- actually trade.
local function updateNotifications()
    local config = getConfig()
    local sent = 0

    for fillTypeIndex, entry in pairs(SupplyDemand.market) do
        local value = entry.index

        if value < SupplyDemand.TRADED_THRESHOLD then
            SupplyDemand.wasOversupplied[fillTypeIndex] = true
        end

        local state = classify(value)
        local previous = SupplyDemand.marketState[fillTypeIndex]

        if previous == nil then
            SupplyDemand.marketState[fillTypeIndex] = state
        elseif previous ~= state then
            SupplyDemand.marketState[fillTypeIndex] = state

            local relevant = state == "oversupplied"
                or (state == "demand" and SupplyDemand.wasOversupplied[fillTypeIndex] == true)

            if config.notifications and relevant and sent < SupplyDemand.MAX_NOTIFICATIONS_PER_TICK then
                sent = sent + 1

                local title = getFillTypeTitle(fillTypeIndex)
                local percent = math.floor(value * 100 + 0.5)

                if state == "oversupplied" then
                    notify(string.format(l10n("realism_sd_oversupplied", "Market flooded: %s now sells for %d%% of its normal price"), title, percent))
                else
                    notify(string.format(l10n("realism_sd_demand", "In demand again: %s now sells for %d%% of its normal price"), title, percent))
                end
            end
        end
    end
end

function SupplyDemand.dumpMarket()
    local rows = {}

    for fillTypeIndex, entry in pairs(SupplyDemand.market) do
        table.insert(rows, {
            title = getFillTypeTitle(fillTypeIndex),
            index = entry.index,
            supply = entry.supply,
            demand = select(1, SupplyDemand.resolveRates(fillTypeIndex, entry.class)) or 0,
            class = entry.class,
            idle = entry.idle or 0,
        })
    end

    table.sort(rows, function(a, b)
        return a.index < b.index
    end)

    log("--- market report (supply and demand per month) ---")

    for _, row in ipairs(rows) do
        log(string.format(
            "  %-26s %-11s %3d%%   supply %9d / demand %8d per month, unsold for %.1f month(s)",
            row.title, tostring(row.class), math.floor(row.index * 100 + 0.5),
            math.floor(row.supply), math.floor(row.demand), row.idle
        ))
    end

    log("--- end of report ---")
end

-- ---------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------

-- The sell points only exist once the map's placeables have loaded, so
-- the market is built on the first update that finds them, with a bounded
-- number of retries before giving up.
local function seedMarket()
    -- Greenhouse produce is learned from the buildings on the map, so wait
    -- for the production points to exist before deciding anything.
    local manager = g_currentMission and g_currentMission.productionChainManager
    local ready = manager ~= nil and manager.productionPoints ~= nil and next(manager.productionPoints) ~= nil

    if not ready then
        SupplyDemand.scanAttempts = SupplyDemand.scanAttempts + 1

        if SupplyDemand.scanAttempts < SupplyDemand.MARKET_SCAN_RETRIES then
            return false
        end
    end

    local greenhouseOutputs = buildGreenhouseOutputs()
    local set, count = buildMarketSet(greenhouseOutputs)
    local perClass = {}

    for fillTypeIndex, className in pairs(set) do
        -- Only the class is stored. The rates themselves are read from the
        -- settings every time they are used, so rlSet greenhouseDemandPerMonth
        -- takes effect on the next tick with nothing to refresh.
        if SupplyDemand.resolveRates(fillTypeIndex, className) ~= nil then
            SupplyDemand.market[fillTypeIndex] = {
                index = 1,
                supply = 0,
                idle = 0,
                class = className,
            }

            perClass[className] = (perClass[className] or 0) + 1
        end
    end

    SupplyDemand.seeded = true

    local summary = {}

    for _, className in ipairs(SupplyDemand.CLASS_ORDER) do
        table.insert(summary, string.format("%s %d", className, perClass[className] or 0))
    end

    log(string.format(
        "market covers %d product(s) — %s. Crops and every other good trade at the game's own price.",
        count, table.concat(summary, ", ")
    ))

    return true
end

function SupplyDemand:update(dt)
    if not getConfig().enabled then
        return
    end

    if not SupplyDemand.loaded then
        if g_currentMission == nil or g_fillTypeManager == nil then
            return
        end

        if not SupplyDemand.seeded and not seedMarket() then
            return
        end

        if isServer() then
            local restored = loadFromSavegame()
            local config = getConfig()

            SupplyDemand.lastMonth = getCurrentMonth()

            log(string.format(
                "enabled (-%.0f pts per doubling of supply, price %.0f%%-%.0f%%) — %d product(s) restored from savegame",
                config.oversupplyPerDoubling * 100,
                config.minIndex * 100,
                config.maxIndex * 100,
                restored
            ))

            if config.debug then
                SupplyDemand.dumpMarket()
            end
        else
            SupplyDemand.requestedState = requestState()

            if not SupplyDemand.requestedState then
                return
            end
        end

        SupplyDemand.loaded = true

        return
    end

    SupplyDemand.timeSinceUpdate = SupplyDemand.timeSinceUpdate + dt

    if SupplyDemand.timeSinceUpdate < SupplyDemand.UPDATE_INTERVAL_MS then
        return
    end

    SupplyDemand.timeSinceUpdate = 0

    if isServer() then
        SupplyDemand.advanceMarket()

        SupplyDemand.timeSinceSync = SupplyDemand.timeSinceSync + SupplyDemand.UPDATE_INTERVAL_MS

        if SupplyDemand.timeSinceSync >= SupplyDemand.SYNC_INTERVAL_MS then
            SupplyDemand.timeSinceSync = 0

            broadcastChanges()
        end
    end

    updateNotifications()

    if getConfig().debug then
        SupplyDemand.timeSinceDump = SupplyDemand.timeSinceDump + SupplyDemand.UPDATE_INTERVAL_MS

        if SupplyDemand.timeSinceDump >= SupplyDemand.DEBUG_DUMP_INTERVAL_MS then
            SupplyDemand.timeSinceDump = 0

            SupplyDemand.dumpMarket()
        end
    end
end

-- The hooks are installed unconditionally and stay inert while the market
-- is empty, so the settings file is only ever touched from the mission
-- update loop, never at mod load.
function SupplyDemand.install()
    if SellingStation ~= nil then
        if SellingStation.getEffectiveFillTypePrice ~= nil then
            SellingStation.getEffectiveFillTypePrice = Utils.overwrittenFunction(
                SellingStation.getEffectiveFillTypePrice,
                marketGetEffectiveFillTypePrice
            )
        end

        if SellingStation.addFillLevelFromTool ~= nil then
            SellingStation.addFillLevelFromTool = Utils.overwrittenFunction(
                SellingStation.addFillLevelFromTool,
                marketAddFillLevelFromTool
            )
        end
    end

    if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
        FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function()
            SupplyDemand.saveToSavegame()
        end)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(SupplyDemand.NAME, SupplyDemand)
    end

    log("installed")
end

SupplyDemand.install()
