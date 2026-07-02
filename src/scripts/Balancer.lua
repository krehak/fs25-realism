--
-- Realism — Balancer
--
-- Locks the gameplay settings that matter for realism so they can't be
-- softened. Even if a player opens the settings menu and turns these
-- down, they are forced back to the realistic value.
--
-- Forced ON / required:
--   trafficEnabled, isSnowEnabled, fruitDestruction (crop destruction),
--   plowingRequiredEnabled (periodical plow), weedsEnabled, limeRequired
-- Forced value:
--   growthMode            = 1        (seasonal growth)
--   economicDifficulty    = "NORMAL" (never easy)
--   disasterDestructionState = "ENABLED" (disasters on)
--
-- Default (not forced):
--   stonesEnabled (fieldstone) is turned OFF once when a brand-new game
--   is started, but the player is free to turn it back on in the settings
--   menu and it will stay on — it is a one-time default, not a lock.
--
-- The settings live in g_currentMission.missionInfo (field names taken
-- straight from the savegame's <settings> block). The forced ones are
-- re-applied on a poll, so any change made in the menu reverts within a
-- few seconds. Only the server/host enforces; clients receive the synced
-- values.
--

Balancer = {}
Balancer.NAME = "Balancer"
Balancer.INTERVAL_MS = 3000

Balancer.FORCED_TRUE = {
    "trafficEnabled",
    "isSnowEnabled",
    "fruitDestruction",
    "plowingRequiredEnabled",
    "weedsEnabled",
    "limeRequired",
}

-- AI helpers must never auto-buy consumables; the player has to refill.
Balancer.FORCED_FALSE = {
    "helperBuyFuel",
    "helperBuySeeds",
    "helperBuyFertilizer",
}

-- Slurry/manure source: 1 = none (player must supply), 2 = auto-buy,
-- >2 = a farm loading station. Force 1 so helpers never auto-source it.
Balancer.HELPER_NO_SOURCE = 1

Balancer.GROWTH_MODE = 1
Balancer.ECONOMIC_DIFFICULTY_STRING = "NORMAL"
Balancer.ECONOMIC_DIFFICULTY_NUMBER = 2
Balancer.DISASTER_STATE_STRING = "ENABLED"

Balancer.NEW_GAME_PLAYTIME_MS = 60000

Balancer.timeSinceLastCheck = Balancer.INTERVAL_MS
Balancer.stonesDefaultApplied = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(message)
    else
        print("[Realism] " .. message)
    end
end

local function forceField(missionInfo, name, value)
    if missionInfo[name] ~= nil and missionInfo[name] ~= value then
        missionInfo[name] = value

        return 1
    end

    return 0
end

local function isNewGame(missionInfo)
    return (missionInfo.playTime or 0) < Balancer.NEW_GAME_PLAYTIME_MS
end

function Balancer.applyStonesDefault()
    if Balancer.stonesDefaultApplied then
        return
    end

    local missionInfo = g_currentMission and g_currentMission.missionInfo

    if missionInfo == nil then
        return
    end

    Balancer.stonesDefaultApplied = true

    if not isNewGame(missionInfo) then
        return
    end

    if missionInfo.stonesEnabled ~= nil and missionInfo.stonesEnabled ~= false then
        missionInfo.stonesEnabled = false

        log("field stones disabled by default for new game (players may re-enable)")
    end
end

function Balancer.enforce()
    local missionInfo = g_currentMission and g_currentMission.missionInfo

    if missionInfo == nil then
        return 0
    end

    local changed = 0

    for _, name in ipairs(Balancer.FORCED_TRUE) do
        changed = changed + forceField(missionInfo, name, true)
    end

    for _, name in ipairs(Balancer.FORCED_FALSE) do
        changed = changed + forceField(missionInfo, name, false)
    end

    if missionInfo.helperSlurrySource ~= nil and type(missionInfo.helperSlurrySource) == "number" then
        changed = changed + forceField(missionInfo, "helperSlurrySource", Balancer.HELPER_NO_SOURCE)
    end

    if missionInfo.helperManureSource ~= nil and type(missionInfo.helperManureSource) == "number" then
        changed = changed + forceField(missionInfo, "helperManureSource", Balancer.HELPER_NO_SOURCE)
    end

    if missionInfo.growthMode ~= nil and type(missionInfo.growthMode) == "number" then
        changed = changed + forceField(missionInfo, "growthMode", Balancer.GROWTH_MODE)
    end

    if missionInfo.economicDifficulty ~= nil then
        if type(missionInfo.economicDifficulty) == "number" then
            changed = changed + forceField(missionInfo, "economicDifficulty", Balancer.ECONOMIC_DIFFICULTY_NUMBER)
        else
            changed = changed + forceField(missionInfo, "economicDifficulty", Balancer.ECONOMIC_DIFFICULTY_STRING)
        end
    end

    if missionInfo.disasterDestructionState ~= nil and type(missionInfo.disasterDestructionState) == "string" then
        changed = changed + forceField(missionInfo, "disasterDestructionState", Balancer.DISASTER_STATE_STRING)
    end

    return changed
end

function Balancer:update(dt)
    self.timeSinceLastCheck = (self.timeSinceLastCheck or 0) + dt

    if self.timeSinceLastCheck < Balancer.INTERVAL_MS then
        return
    end

    self.timeSinceLastCheck = 0

    if g_server == nil then
        return
    end

    Balancer.applyStonesDefault()

    local changed = Balancer.enforce()

    if changed > 0 then
        log(string.format("Balancer enforced %d realism setting(s)", changed))
    end
end

function Balancer.install()
    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(Balancer.NAME, Balancer)
    end

    log("Balancer enabled — realism settings locked on")
end

Balancer.install()
