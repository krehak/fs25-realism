--
-- Realism — Settings
--
-- One place where a server admin configures the whole mod. Every tunable
-- feature declares its options in the schema below; the values live in a
-- single file, written into the SAVEGAME's own folder:
--
--   savegame<N>/realism.xml
--
-- created with commented defaults the first time that save runs. Settings
-- belong to the farm, not to the machine: two saves are two different
-- farms, usually two different maps and two different sets of house rules,
-- and retuning one must never silently retune the other.
--
-- Older shared files under modSettings/FS25_Realism (realism.xml itself,
-- and the per-feature supplyDemand.xml / productionStoreOnly.xml before
-- that) are read once as a migration source when the savegame has no
-- realism.xml yet, so nobody's tuning is lost on the way in.
--
-- Not everything is configurable on purpose. The features that define what
-- this mod IS — the intro, inflation, honest wood chips and multiplayer log
-- mass — have no switch and no numbers: turning them off would make the
-- mod something else. Everything else can be switched off and retuned.
--
-- Multiplayer
--   The SERVER's file is authoritative. A client loads its own copy so
--   single-player still works, then asks the server for the real values the
--   moment it joins and overwrites everything with what comes back. Any
--   later change an admin makes is broadcast to every client immediately,
--   so a setting like disableTeleport takes effect for joined players
--   without anyone reconnecting.
--
-- Runtime changes (the "player is stuck, let them teleport for a minute"
-- case) are made from the console — the dedicated server's web console, or
-- the in-game console of the host / an admin (master user):
--
--   rlSettings                        list every option and its value
--   rlSettings <feature>              list one feature's options
--   rlSet <feature> <key> <value>     change until the server restarts
--   rlSetSave <feature> <key> <value> change and write it to realism.xml
--   rlSettingsSave                    write all current values to the file
--   rlSettingsReload                  re-read the file and apply it
--
-- e.g.  rlSet disableTeleport enabled false   ... player walks free ...
--       rlSet disableTeleport enabled true
--
-- A client may run rlSet / rlSetSave too: the change is sent to the server,
-- which applies it only if that player is a master user (admin). Values are
-- never trusted from a non-admin connection.
--

Settings = {}
Settings.NAME = "Settings"

Settings.CONFIG_DIRECTORY = "modSettings/FS25_Realism/"
Settings.CONFIG_FILENAME = "realism.xml"
Settings.ROOT = "realism"

Settings.TYPE_BOOL = "bool"
Settings.TYPE_FLOAT = "float"
Settings.TYPE_INT = "int"

-- ---------------------------------------------------
-- Schema
-- ---------------------------------------------------
--
-- Every configurable option in the mod. Order matters: it is the order the
-- file is written in, and the order values are streamed to clients in, so
-- entries are appended rather than reordered when the mod grows.
--
-- legacyFile / legacyRoot name the pre-1.2 per-feature file this section
-- was migrated out of. Attribute names are unchanged, so the same reader
-- works for both the old root and the new realism.<feature> path.
--
Settings.SCHEMA = {
    {
        name = "disableTeleport",
        title = "Realism — Teleporting",
        help = "No teleporting: no Tab switching, no entering a vehicle from the map, no map Visit / Go To. Set enabled=\"false\" to hand teleporting back (e.g. someone is stuck).",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "No teleporting", tooltip = "Tab switching, entering a vehicle from the map and the map's Visit / Go To are all disabled. Walk or drive there." },
        },
    },
    {
        name = "seasonalGreenhouse",
        title = "Realism — Greenhouses",
        help = "Greenhouse output multipliers. Season and weather multiply together: 1.0 leaves output untouched.",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Seasonal greenhouses", tooltip = "Greenhouse output follows the season and the weather." },
            { key = "springMultiplier", type = Settings.TYPE_FLOAT, default = 0.75, min = 0, max = 10, label = "Greenhouse: spring", tooltip = "Greenhouse output in spring.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "summerMultiplier", type = Settings.TYPE_FLOAT, default = 1.00, min = 0, max = 10, label = "Greenhouse: summer", tooltip = "Greenhouse output in summer.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "fallMultiplier", type = Settings.TYPE_FLOAT, default = 0.75, min = 0, max = 10, label = "Greenhouse: autumn", tooltip = "Greenhouse output in autumn.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "winterMultiplier", type = Settings.TYPE_FLOAT, default = 0.50, min = 0, max = 10, label = "Greenhouse: winter", tooltip = "Greenhouse output in winter.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "sunMultiplier", type = Settings.TYPE_FLOAT, default = 1.20, min = 0, max = 10, label = "Greenhouse: sunny", tooltip = "Weather multiplier applied on top of the season.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "cloudMultiplier", type = Settings.TYPE_FLOAT, default = 1.00, min = 0, max = 10, label = "Greenhouse: cloudy", tooltip = "Weather multiplier applied on top of the season.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "rainMultiplier", type = Settings.TYPE_FLOAT, default = 0.90, min = 0, max = 10, label = "Greenhouse: rain", tooltip = "Weather multiplier applied on top of the season.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "snowMultiplier", type = Settings.TYPE_FLOAT, default = 0.70, min = 0, max = 10, label = "Greenhouse: snow", tooltip = "Weather multiplier applied on top of the season.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "hailMultiplier", type = Settings.TYPE_FLOAT, default = 0.60, min = 0, max = 10, label = "Greenhouse: hail", tooltip = "Weather multiplier applied on top of the season.", uiMin = 0, uiMax = 2, uiStep = 0.05, display = "percent" },
        },
    },
    {
        name = "supplyDemand",
        title = "Realism — Market",
        help = "The market. Prices are a fraction of normal: minIndex is the floor when flooded, maxIndex the ceiling when scarce. A product only starts earning the scarcity premium after scarcityOnsetMonths with NO sales at all, so anything you sell regularly stays at 100% however little of it you sell. The three <class>DemandPerMonth values are where each family starts to be nerfed: sell more than that per in-game month and its price falls, one tenth off per doubling. Per-product overrides live in the child elements below.",
        legacyFile = "supplyDemand.xml",
        legacyRoot = "supplyDemand",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Supply and demand", tooltip = "Prices react to how much you actually sell." },
            { key = "minIndex", type = Settings.TYPE_FLOAT, default = 0.55, min = 0.01, max = 10, label = "Market: lowest price", tooltip = "How far a flooded product's price can fall.", uiMin = 0.3, uiMax = 1, uiStep = 0.05, display = "percent" },
            { key = "maxIndex", type = Settings.TYPE_FLOAT, default = 1.20, min = 1, max = 10, label = "Market: highest price", tooltip = "How far a scarce product's price can rise.", uiMin = 1, uiMax = 2, uiStep = 0.05, display = "percent" },
            { key = "oversupplyPointsPerDoubling", type = Settings.TYPE_FLOAT, default = 0.10, min = 0, max = 1, label = "Market: drop per doubling", tooltip = "Price lost each time supply doubles past demand.", uiMin = 0, uiMax = 0.5, uiStep = 0.01, display = "percent" },
            { key = "scarcityOnsetMonths", type = Settings.TYPE_FLOAT, default = 3.0, min = 0, max = 1200, label = "Market: months before premium", tooltip = "Months with NO sale before a product starts earning a premium.", uiMin = 0, uiMax = 24, uiStep = 1, display = "months" },
            { key = "scarcityPointsPerMonth", type = Settings.TYPE_FLOAT, default = 0.02, min = 0, max = 1, label = "Market: premium per month", tooltip = "How fast an unsold product's price climbs after that.", uiMin = 0, uiMax = 0.2, uiStep = 0.01, display = "percent" },
            { key = "priceDropHalfLifeMonths", type = Settings.TYPE_FLOAT, default = 0.5, min = 0.01, max = 1200, label = "Market: how fast prices fall", tooltip = "Time for a price to close half the gap down to its target.", uiMin = 0.25, uiMax = 12, uiStep = 0.25, display = "months" },
            { key = "priceRiseHalfLifeMonths", type = Settings.TYPE_FLOAT, default = 2.0, min = 0.01, max = 1200, label = "Market: how fast prices recover", tooltip = "Time for a price to close half the gap back up.", uiMin = 0.25, uiMax = 12, uiStep = 0.25, display = "months" },
            { key = "notifications", type = Settings.TYPE_BOOL, default = true, label = "Market: notifications", tooltip = "Tell me when a product I trade is flooded or back in demand." },
            { key = "greenhouseDemandPerMonth", type = Settings.TYPE_FLOAT, default = 35000, min = 1, max = 1000000000, label = "Market: greenhouse limit", tooltip = "Sell more than this per month of one greenhouse crop and its price falls.", uiMin = 5000, uiMax = 200000, uiStep = 5000, display = "money" },
            { key = "greenhouseMemoryMonths", type = Settings.TYPE_FLOAT, default = 3, min = 0.1, max = 1200, label = "Market: greenhouse memory", tooltip = "How many months of trade the greenhouse market remembers.", uiMin = 1, uiMax = 24, uiStep = 1, display = "months" },
            { key = "woodDemandPerMonth", type = Settings.TYPE_FLOAT, default = 50000, min = 1, max = 1000000000, label = "Market: wood limit", tooltip = "Sell more than this per month of one wood product and its price falls.", uiMin = 5000, uiMax = 200000, uiStep = 5000, display = "money" },
            { key = "woodMemoryMonths", type = Settings.TYPE_FLOAT, default = 3, min = 0.1, max = 1200, label = "Market: wood memory", tooltip = "How many months of trade the timber market remembers.", uiMin = 1, uiMax = 24, uiStep = 1, display = "months" },
            { key = "animalProductsDemandPerMonth", type = Settings.TYPE_FLOAT, default = 100000, min = 1, max = 1000000000, label = "Market: animal produce limit", tooltip = "Sell more than this per month of one animal product and its price falls.", uiMin = 5000, uiMax = 200000, uiStep = 5000, display = "money" },
            { key = "animalProductsMemoryMonths", type = Settings.TYPE_FLOAT, default = 2, min = 0.1, max = 1200, label = "Market: animal produce memory", tooltip = "How many months of trade the animal produce market remembers.", uiMin = 1, uiMax = 24, uiStep = 1, display = "months" },
        },
    },
    {
        name = "productionStoreOnly",
        title = "Realism — Productions",
        help = "Productions may only store their output. Closed-system exemptions live in the child elements below.",
        legacyFile = "productionStoreOnly.xml",
        legacyRoot = "productionStoreOnly",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Store-only production", tooltip = "Productions cannot auto-sell or auto-distribute." },
        },
    },
    {
        name = "bulkTrade",
        title = "Realism — Trading",
        help = "Volume discount when buying at a fill station. Discounts are fractions: 0.10 is -10%.",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Bulk buying discounts", tooltip = "Buying in volume at a fill station is cheaper per litre." },
            { key = "minLiters", type = Settings.TYPE_FLOAT, default = 5000, min = 0, max = 100000000, label = "Bulk buying: from", tooltip = "Litres in one refill before any discount starts.", uiMin = 0, uiMax = 20000, uiStep = 500, display = "liters" },
            { key = "maxLiters", type = Settings.TYPE_FLOAT, default = 35000, min = 0, max = 100000000, label = "Bulk buying: full discount at", tooltip = "Litres in one refill for the biggest discount.", uiMin = 5000, uiMax = 100000, uiStep = 2500, display = "liters" },
            { key = "minDiscount", type = Settings.TYPE_FLOAT, default = 0.01, min = 0, max = 0.95, label = "Bulk buying: smallest discount", tooltip = "Discount at the starting volume.", uiMin = 0, uiMax = 0.25, uiStep = 0.01, display = "percent" },
            { key = "maxDiscount", type = Settings.TYPE_FLOAT, default = 0.10, min = 0, max = 0.95, label = "Bulk buying: biggest discount", tooltip = "Discount at the full volume.", uiMin = 0, uiMax = 0.25, uiStep = 0.01, display = "percent" },
        },
    },
    {
        name = "balancer",
        title = "Realism — Locked settings",
        help = "Realism-critical game settings the players cannot soften. Each lock can be released on its own.",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Locked realism settings", tooltip = "Realism-critical game settings cannot be softened." },
            { key = "forceTraffic", type = Settings.TYPE_BOOL, default = true, label = "Force traffic on", tooltip = "Players cannot switch traffic off." },
            { key = "forceSnow", type = Settings.TYPE_BOOL, default = true, label = "Force snow on", tooltip = "Players cannot switch snow off." },
            { key = "forceCropDestruction", type = Settings.TYPE_BOOL, default = true, label = "Force crop destruction on", tooltip = "Driving over crops always ruins them." },
            { key = "forcePeriodicalPlowing", type = Settings.TYPE_BOOL, default = true, label = "Force periodical plowing on", tooltip = "Fields must be plowed again periodically." },
            { key = "forceWeeds", type = Settings.TYPE_BOOL, default = true, label = "Force weeds on", tooltip = "Weeds always grow." },
            { key = "forceLimeRequired", type = Settings.TYPE_BOOL, default = true, label = "Force lime required on", tooltip = "Fields always need lime." },
            { key = "forceSeasonalGrowth", type = Settings.TYPE_BOOL, default = true, label = "Force seasonal growth on", tooltip = "Crops only grow in their season." },
            { key = "forceNormalEconomy", type = Settings.TYPE_BOOL, default = true, label = "Force normal economy", tooltip = "Economic difficulty cannot be set to easy." },
            { key = "forceDisasters", type = Settings.TYPE_BOOL, default = true, label = "Force disasters on", tooltip = "Hail and other disasters stay enabled." },
            { key = "blockHelperAutoBuy", type = Settings.TYPE_BOOL, default = true, label = "Helpers never auto-buy", tooltip = "Hired workers do not buy their own fuel, seed or fertiliser." },
        },
    },
    {
        name = "stumpCutter",
        title = "Realism — Forestry",
        help = "Grinding a stump away by holding the running chainsaw into it.",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "Chainsaw stump removal", tooltip = "Hold a running chainsaw into a stump to grind it away." },
        },
    },
    {
        name = "aiCropDamage",
        title = "Realism — Helpers",
        help = "Hired helpers flatten crops with the wrong tyres, exactly like the player does.",
        options = {
            { key = "enabled", type = Settings.TYPE_BOOL, default = true, label = "AI crop damage", tooltip = "Hired helpers flatten crops with the wrong tyres." },
        },
    },
}

Settings.values = {}
Settings.flat = {}
Settings.index = {}
Settings.extras = {}

Settings.loaded = false
Settings.defaultsApplied = false
Settings.generation = 0
Settings.synced = false
Settings.requestedState = false
Settings.migratedFrom = nil

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("Settings: " .. tostring(message))
    else
        print("[Realism] Settings: " .. tostring(message))
    end
end

local function isServer()
    return g_server ~= nil
end

-- ---------------------------------------------------
-- Schema helpers
-- ---------------------------------------------------

local function buildIndex()
    Settings.flat = {}
    Settings.index = {}

    for _, section in ipairs(Settings.SCHEMA) do
        Settings.index[section.name] = { section = section, options = {} }

        for _, option in ipairs(section.options) do
            Settings.flat[#Settings.flat + 1] = { section = section, option = option }
            Settings.index[section.name].options[option.key] = option
        end
    end
end

buildIndex()

function Settings.getSection(featureName)
    local entry = Settings.index[featureName]

    return entry ~= nil and entry.section or nil
end

function Settings.getOption(featureName, key)
    local entry = Settings.index[featureName]

    if entry == nil then
        return nil
    end

    return entry.options[key]
end

local function clamp(option, value)
    if option.type == Settings.TYPE_BOOL then
        return value == true
    end

    if type(value) ~= "number" then
        return option.default
    end

    if option.min ~= nil and value < option.min then
        value = option.min
    end

    if option.max ~= nil and value > option.max then
        value = option.max
    end

    if option.type == Settings.TYPE_INT then
        value = math.floor(value + 0.5)
    end

    return value
end

local function setValue(featureName, key, value)
    local byFeature = Settings.values[featureName]

    if byFeature == nil then
        byFeature = {}
        Settings.values[featureName] = byFeature
    end

    byFeature[key] = value
end

local function applyDefaults()
    Settings.values = {}

    for _, section in ipairs(Settings.SCHEMA) do
        for _, option in ipairs(section.options) do
            setValue(section.name, option.key, option.default)
        end
    end
end

-- ---------------------------------------------------
-- Extra sections
-- ---------------------------------------------------
--
-- A feature whose settings are lists rather than single values (the market's
-- per-product rates, the store-only exemptions) registers a reader and a
-- writer here. Both are handed an XMLFile and the base path of that
-- feature's element, so the same pair works for realism.xml and for the old
-- per-feature file it is migrated from.
--
function Settings.registerExtra(featureName, handlers)
    Settings.extras[featureName] = handlers
end

local function readExtra(featureName, xmlFile, basePath)
    local handlers = Settings.extras[featureName]

    if handlers == nil or type(handlers.read) ~= "function" then
        return
    end

    local ok, err = pcall(handlers.read, xmlFile, basePath)

    if not ok then
        log(string.format("failed to read %s lists: %s", featureName, tostring(err)))
    end
end

local function writeExtra(featureName, xmlFile, basePath)
    local handlers = Settings.extras[featureName]

    if handlers == nil or type(handlers.write) ~= "function" then
        return
    end

    local ok, err = pcall(handlers.write, xmlFile, basePath)

    if not ok then
        log(string.format("failed to write %s lists: %s", featureName, tostring(err)))
    end
end

-- ---------------------------------------------------
-- File
-- ---------------------------------------------------

-- The settings belong to the SAVEGAME, not to the person running the game.
-- Two saves on one machine are two different farms, often two different
-- maps and two different sets of house rules, and a server admin editing
-- one must not silently retune the other. So realism.xml lives beside the
-- save it governs.
--
-- The old global copy under modSettings is still read once, as a migration
-- source, so an admin who already tuned it does not start over.
local function getSaveDirectory()
    local missionInfo = g_currentMission ~= nil and g_currentMission.missionInfo or nil

    if missionInfo == nil then
        return nil
    end

    local directory = missionInfo.savegameDirectory

    if directory == nil or directory == "" then
        return nil
    end

    return directory .. "/"
end

local function getGlobalDirectory()
    if getUserProfileAppPath == nil then
        return nil
    end

    return getUserProfileAppPath() .. Settings.CONFIG_DIRECTORY
end

local function getDirectory()
    return getSaveDirectory()
end

function Settings.getConfigPath()
    local directory = getDirectory()

    if directory == nil then
        return nil
    end

    return directory .. Settings.CONFIG_FILENAME
end

local function hasKey(xmlFile, key)
    if type(xmlFile.hasProperty) == "function" then
        local ok, result = pcall(xmlFile.hasProperty, xmlFile, key)

        if ok then
            return result == true
        end
    end

    local ok, value = pcall(xmlFile.getString, xmlFile, key)

    return ok and value ~= nil
end

local function readOption(xmlFile, basePath, section, option)
    local key = basePath .. "#" .. option.key

    if not hasKey(xmlFile, key) then
        return false
    end

    local value

    if option.type == Settings.TYPE_BOOL then
        value = xmlFile:getBool(key, option.default)
    else
        value = xmlFile:getFloat(key, option.default)
    end

    setValue(section.name, option.key, clamp(option, value))

    return true
end

local function writeOption(xmlFile, basePath, section, option)
    local key = basePath .. "#" .. option.key
    local value = Settings.values[section.name][option.key]

    if option.type == Settings.TYPE_BOOL then
        xmlFile:setBool(key, value == true)
    elseif option.type == Settings.TYPE_INT then
        xmlFile:setInt(key, math.floor(value + 0.5))
    else
        xmlFile:setFloat(key, value)
    end
end

local function writeAllSections(xmlFile, withExtras)
    for _, section in ipairs(Settings.SCHEMA) do
        local basePath = Settings.ROOT .. "." .. section.name

        for _, option in ipairs(section.options) do
            writeOption(xmlFile, basePath, section, option)
        end

        if section.help ~= nil then
            xmlFile:setString(basePath .. "#help", section.help)
        end

        if withExtras then
            writeExtra(section.name, xmlFile, basePath)
        end
    end

    xmlFile:setString(Settings.ROOT .. "#help",
        "Realism settings. In multiplayer THIS FILE ON THE SERVER wins; clients receive these values on join. " ..
        "Change them live with the rlSet / rlSettings console commands. " ..
        "Features with no entry here (intro, inflation, wood chips, log mass) are deliberately not configurable.")
end

-- Creates the file from scratch, including the list sections. Only used
-- when no realism.xml exists yet.
local function createConfigFile(path)
    if XMLFile == nil or XMLFile.create == nil then
        return false
    end

    if createFolder ~= nil then
        createFolder(getDirectory())
    end

    local xmlFile = XMLFile.create("realismSettingsDefault", path, Settings.ROOT)

    if xmlFile == nil then
        return false
    end

    writeAllSections(xmlFile, true)

    xmlFile:save()
    xmlFile:delete()

    return true
end

-- Writes the current values back over an existing file, leaving every list
-- element the admin edited by hand exactly where it is.
function Settings.save()
    local path = Settings.getConfigPath()

    if path == nil or XMLFile == nil then
        return false
    end

    local xmlFile = XMLFile.loadIfExists ~= nil and XMLFile.loadIfExists("realismSettingsSave", path) or nil

    if xmlFile == nil then
        return createConfigFile(path)
    end

    writeAllSections(xmlFile, false)

    xmlFile:save()
    xmlFile:delete()

    log("settings written to " .. path)

    return true
end

-- Pre-1.2 layout: one file per feature, same attribute names, feature name
-- as the root element. Read only when realism.xml does not exist yet.
-- Everything migrated in here comes from the OLD shared location under
-- modSettings, never from the savegame folder.
local function loadLegacy()
    local directory = getGlobalDirectory()

    if directory == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return
    end

    -- A global realism.xml from before settings moved into the savegame.
    local globalPath = directory .. Settings.CONFIG_FILENAME
    local globalFile = XMLFile.loadIfExists("realismSettingsGlobal", globalPath)

    if globalFile ~= nil then
        for _, section in ipairs(Settings.SCHEMA) do
            local basePath = Settings.ROOT .. "." .. section.name

            for _, option in ipairs(section.options) do
                readOption(globalFile, basePath, section, option)
            end

            readExtra(section.name, globalFile, basePath)
        end

        globalFile:delete()

        Settings.migratedFrom = (Settings.migratedFrom or "") .. "the shared " .. Settings.CONFIG_FILENAME .. " "
    end

    for _, section in ipairs(Settings.SCHEMA) do
        if section.legacyFile ~= nil then
            local path = directory .. section.legacyFile
            local xmlFile = XMLFile.loadIfExists("realismSettingsLegacy", path)

            if xmlFile ~= nil then
                for _, option in ipairs(section.options) do
                    readOption(xmlFile, section.legacyRoot, section, option)
                end

                readExtra(section.name, xmlFile, section.legacyRoot)
                xmlFile:delete()

                Settings.migratedFrom = (Settings.migratedFrom or "") .. section.legacyFile .. " "
            end
        end
    end
end

local function loadFromFile()
    local path = Settings.getConfigPath()

    if path == nil or XMLFile == nil or XMLFile.loadIfExists == nil then
        return
    end

    local xmlFile = XMLFile.loadIfExists("realismSettings", path)

    if xmlFile == nil then
        loadLegacy()

        if createConfigFile(path) then
            if Settings.migratedFrom ~= nil then
                log("created " .. path .. " (migrated from " .. Settings.migratedFrom .. "— the old files are no longer read)")
            else
                log("created " .. path)
            end
        end

        return
    end

    local missing = 0

    for _, section in ipairs(Settings.SCHEMA) do
        local basePath = Settings.ROOT .. "." .. section.name

        for _, option in ipairs(section.options) do
            if not readOption(xmlFile, basePath, section, option) then
                missing = missing + 1
            end
        end

        readExtra(section.name, xmlFile, basePath)
    end

    xmlFile:delete()

    log("loaded " .. path)

    if missing > 0 then
        Settings.save()
        log(string.format("added %d new option(s) introduced by this mod version", missing))
    end
end

-- Loading now waits for the savegame folder to exist, because that is where
-- the file lives. Anything asking for a setting before then — a feature
-- installing itself at mod load — gets the defaults and asks again later;
-- the generation bump on the real load is what makes the modules that cache
-- their config pick up the true values.
function Settings.ensureLoaded()
    if Settings.loaded then
        return
    end

    if not Settings.defaultsApplied then
        Settings.defaultsApplied = true

        applyDefaults()

        Settings.generation = Settings.generation + 1
    end

    if Settings.getConfigPath() == nil then
        return
    end

    Settings.loaded = true

    local ok, err = pcall(loadFromFile)

    if not ok then
        log("could not read settings, using defaults: " .. tostring(err))
    end

    Settings.generation = Settings.generation + 1
end

function Settings.reload()
    Settings.loaded = false
    Settings.defaultsApplied = false
    Settings.synced = false
    Settings.migratedFrom = nil

    Settings.ensureLoaded()

    if isServer() then
        Settings.broadcastAll()
    end
end

-- ---------------------------------------------------
-- Reading
-- ---------------------------------------------------

function Settings.get(featureName, key)
    Settings.ensureLoaded()

    local byFeature = Settings.values[featureName]

    if byFeature == nil then
        return nil
    end

    local value = byFeature[key]

    if value == nil then
        local option = Settings.getOption(featureName, key)

        return option ~= nil and option.default or nil
    end

    return value
end

function Settings.isEnabled(featureName)
    return Settings.get(featureName, "enabled") == true
end

function Settings.getGeneration()
    Settings.ensureLoaded()

    return Settings.generation
end

-- ---------------------------------------------------
-- Writing
-- ---------------------------------------------------

-- Applies a value locally. Everything that changes a setting — the console,
-- an incoming network event — funnels through here so the generation counter
-- is always bumped and cached values are always rebuilt.
function Settings.apply(featureName, key, value)
    local option = Settings.getOption(featureName, key)

    if option == nil then
        return false
    end

    Settings.ensureLoaded()

    setValue(featureName, key, clamp(option, value))
    Settings.generation = Settings.generation + 1

    return true
end

function Settings.parseValue(featureName, key, text)
    local option = Settings.getOption(featureName, key)

    if option == nil then
        return nil, string.format("unknown setting %s %s", tostring(featureName), tostring(key))
    end

    if option.type == Settings.TYPE_BOOL then
        local lowered = tostring(text):lower()

        if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on" then
            return true
        end

        if lowered == "false" or lowered == "0" or lowered == "no" or lowered == "off" then
            return false
        end

        return nil, string.format("%s.%s is a true/false setting", featureName, key)
    end

    local number = tonumber(text)

    if number == nil then
        return nil, string.format("%s.%s is a number", featureName, key)
    end

    return clamp(option, number)
end

function Settings.formatValue(featureName, key)
    local option = Settings.getOption(featureName, key)
    local value = Settings.get(featureName, key)

    if option == nil then
        return "?"
    end

    if option.type == Settings.TYPE_BOOL then
        return tostring(value == true)
    end

    if option.type == Settings.TYPE_INT then
        return string.format("%d", value)
    end

    return string.format("%g", value)
end

-- ---------------------------------------------------
-- Multiplayer
-- ---------------------------------------------------

local function encode(entry)
    local value = Settings.get(entry.section.name, entry.option.key)

    if entry.option.type == Settings.TYPE_BOOL then
        return value == true and 1 or 0
    end

    return value or 0
end

local function decode(entry, number)
    if entry.option.type == Settings.TYPE_BOOL then
        return number >= 0.5
    end

    return number
end

RealismSettingsEvent = {}
local RealismSettingsEvent_mt = Class(RealismSettingsEvent, Event)

InitEventClass(RealismSettingsEvent, "RealismSettingsEvent")

function RealismSettingsEvent.emptyNew()
    return Event.new(RealismSettingsEvent_mt)
end

function RealismSettingsEvent.new()
    return RealismSettingsEvent.emptyNew()
end

function RealismSettingsEvent:writeStream(streamId, connection)
    Settings.ensureLoaded()

    streamWriteUInt16(streamId, #Settings.flat)

    for _, entry in ipairs(Settings.flat) do
        streamWriteFloat32(streamId, encode(entry))
    end
end

function RealismSettingsEvent:readStream(streamId, connection)
    local count = streamReadUInt16(streamId)

    self.numbers = {}

    for i = 1, count do
        self.numbers[i] = streamReadFloat32(streamId)
    end

    self:run(connection)
end

function RealismSettingsEvent:run(connection)
    if isServer() then
        return
    end

    Settings.ensureLoaded()

    local applied = 0

    for i, number in ipairs(self.numbers) do
        local entry = Settings.flat[i]

        if entry ~= nil then
            setValue(entry.section.name, entry.option.key, decode(entry, number))
            applied = applied + 1
        end
    end

    Settings.generation = Settings.generation + 1
    Settings.synced = true

    log(string.format("received %d setting(s) from the server", applied))
end

RealismSettingsRequestEvent = {}
local RealismSettingsRequestEvent_mt = Class(RealismSettingsRequestEvent, Event)

InitEventClass(RealismSettingsRequestEvent, "RealismSettingsRequestEvent")

function RealismSettingsRequestEvent.emptyNew()
    return Event.new(RealismSettingsRequestEvent_mt)
end

function RealismSettingsRequestEvent.new()
    return RealismSettingsRequestEvent.emptyNew()
end

function RealismSettingsRequestEvent:writeStream(streamId, connection)
end

function RealismSettingsRequestEvent:readStream(streamId, connection)
    self:run(connection)
end

function RealismSettingsRequestEvent:run(connection)
    if connection:getIsServer() then
        return
    end

    connection:sendEvent(RealismSettingsEvent.new())
end

-- A single change. Server -> clients it is an order; client -> server it is
-- a request that is only honoured for a master user (admin).
RealismSettingsChangeEvent = {}
local RealismSettingsChangeEvent_mt = Class(RealismSettingsChangeEvent, Event)

InitEventClass(RealismSettingsChangeEvent, "RealismSettingsChangeEvent")

function RealismSettingsChangeEvent.emptyNew()
    return Event.new(RealismSettingsChangeEvent_mt)
end

function RealismSettingsChangeEvent.new(index, number, persist)
    local self = RealismSettingsChangeEvent.emptyNew()
    self.index = index
    self.number = number
    self.persist = persist == true

    return self
end

function RealismSettingsChangeEvent:writeStream(streamId, connection)
    streamWriteUInt16(streamId, self.index)
    streamWriteFloat32(streamId, self.number)
    streamWriteBool(streamId, self.persist)
end

function RealismSettingsChangeEvent:readStream(streamId, connection)
    self.index = streamReadUInt16(streamId)
    self.number = streamReadFloat32(streamId)
    self.persist = streamReadBool(streamId)

    self:run(connection)
end

local function isAdminConnection(connection)
    local mission = g_currentMission

    if mission == nil or mission.userManager == nil then
        return false
    end

    local ok, user = pcall(function()
        return mission.userManager:getUserByConnection(connection)
    end)

    if not ok or user == nil then
        return false
    end

    if type(user.getIsMasterUser) == "function" then
        local allowed

        ok, allowed = pcall(user.getIsMasterUser, user)

        if ok then
            return allowed == true
        end
    end

    return user.isMasterUser == true
end

function RealismSettingsChangeEvent:run(connection)
    local entry = Settings.flat[self.index]

    if entry == nil then
        return
    end

    if not isServer() then
        Settings.apply(entry.section.name, entry.option.key, decode(entry, self.number))

        return
    end

    if not isAdminConnection(connection) then
        log("rejected a settings change from a player who is not an admin")

        return
    end

    Settings.set(entry.section.name, entry.option.key, decode(entry, self.number), self.persist)
end

function Settings.broadcastAll()
    if not isServer() or g_server == nil then
        return
    end

    g_server:broadcastEvent(RealismSettingsEvent.new())
end

-- The one entry point for changing a setting. On the server it applies the
-- value and pushes it to every client; on a client it asks the server to do
-- the same, which only goes through for an admin.
function Settings.set(featureName, key, value, persist)
    local option = Settings.getOption(featureName, key)

    if option == nil then
        return false, string.format("unknown setting %s %s", tostring(featureName), tostring(key))
    end

    if not isServer() then
        if g_client == nil or type(g_client.getServerConnection) ~= "function" then
            return false, "not connected to a server"
        end

        local connection = g_client:getServerConnection()

        if connection == nil then
            return false, "not connected to a server"
        end

        for i, entry in ipairs(Settings.flat) do
            if entry.section.name == featureName and entry.option.key == key then
                local number = option.type == Settings.TYPE_BOOL and (value == true and 1 or 0) or value

                connection:sendEvent(RealismSettingsChangeEvent.new(i, number, persist))

                return true, "sent to the server (admins only)"
            end
        end

        return false, "unknown setting"
    end

    Settings.apply(featureName, key, value)

    for i, entry in ipairs(Settings.flat) do
        if entry.section.name == featureName and entry.option.key == key then
            if g_server ~= nil then
                g_server:broadcastEvent(RealismSettingsChangeEvent.new(i, encode(entry), false))
            end

            break
        end
    end

    if persist then
        Settings.save()
    end

    log(string.format("%s.%s = %s%s", featureName, key, Settings.formatValue(featureName, key), persist and " (saved)" or ""))

    return true, string.format("%s.%s = %s", featureName, key, Settings.formatValue(featureName, key))
end

-- ---------------------------------------------------
-- Console
-- ---------------------------------------------------

function Settings:consoleList(featureName)
    Settings.ensureLoaded()

    local lines = { "Realism settings (" .. tostring(Settings.getConfigPath()) .. ")" }

    for _, section in ipairs(Settings.SCHEMA) do
        if featureName == nil or featureName == "" or section.name:lower() == featureName:lower() then
            lines[#lines + 1] = "  " .. section.name

            for _, option in ipairs(section.options) do
                lines[#lines + 1] = string.format("    %-28s %s", option.key, Settings.formatValue(section.name, option.key))
            end
        end
    end

    lines[#lines + 1] = "  not configurable: intro, inflation, wood chips, log mass"
    lines[#lines + 1] = "  rlSet <feature> <key> <value> — change now; rlSetSave — change and keep"

    return table.concat(lines, "\n")
end

local function consoleSet(featureName, key, text, persist)
    if featureName == nil or key == nil or text == nil then
        return "usage: rlSet <feature> <key> <value>   (rlSettings lists them)"
    end

    local value, err = Settings.parseValue(featureName, key, text)

    if value == nil and err ~= nil then
        return err
    end

    local ok, message = Settings.set(featureName, key, value, persist)

    if not ok then
        return "failed: " .. tostring(message)
    end

    return message
end

function Settings:consoleSet(featureName, key, text)
    return consoleSet(featureName, key, text, false)
end

function Settings:consoleSetSave(featureName, key, text)
    return consoleSet(featureName, key, text, true)
end

function Settings:consoleSave()
    if not isServer() then
        return "only the server can write the settings file"
    end

    if Settings.save() then
        return "saved " .. tostring(Settings.getConfigPath())
    end

    return "could not write the settings file"
end

function Settings:consoleReload()
    if not isServer() then
        return "only the server can reload the settings file"
    end

    Settings.reload()

    return Settings:consoleList()
end

-- ---------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------

-- A joining client asks for the server's values as soon as its connection
-- is up; until then it runs on whatever its own file says.
function Settings:update(dt)
    Settings.ensureLoaded()

    if Settings.synced or Settings.requestedState or isServer() then
        return
    end

    if g_client == nil or type(g_client.getServerConnection) ~= "function" then
        return
    end

    local connection = g_client:getServerConnection()

    if connection == nil then
        return
    end

    connection:sendEvent(RealismSettingsRequestEvent.new())

    Settings.requestedState = true
end

function Settings.install()
    if addConsoleCommand ~= nil then
        addConsoleCommand("rlSettings", "List the Realism settings", "consoleList", Settings)
        addConsoleCommand("rlSet", "Change a Realism setting until restart: rlSet <feature> <key> <value>", "consoleSet", Settings)
        addConsoleCommand("rlSetSave", "Change a Realism setting and write it to the file", "consoleSetSave", Settings)
        addConsoleCommand("rlSettingsSave", "Write the current Realism settings to the file", "consoleSave", Settings)
        addConsoleCommand("rlSettingsReload", "Re-read the Realism settings file", "consoleReload", Settings)
    end

    -- The game rebuilds the savegame folder on every save, so realism.xml
    -- written out-of-band when a value changes is wiped the next time the
    -- player saves. Re-writing it from inside the save cycle — like every
    -- other per-save file the game keeps — is what actually makes the
    -- settings survive a reload.
    if FSCareerMissionInfo ~= nil and FSCareerMissionInfo.saveToXMLFile ~= nil then
        FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function()
            if isServer() then
                Settings.save()
            end
        end)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(Settings.NAME, Settings)
    end

    log(string.format("%d option(s) across %d feature(s) — rlSettings to list them", #Settings.flat, #Settings.SCHEMA))
end

Settings.install()
