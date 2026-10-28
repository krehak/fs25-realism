--
-- Realism — Loans
--
-- Disables taking out a NEW bank loan from the Finances tab. In the base
-- game the one-time loan fee barely scales with the amount borrowed — a
-- few hundred credits whether you take 5,000 or half a million — which
-- turns a loan into free money instead of a real financial decision.
--
-- Off by default ("loans.enabled" = false): Farm.MIN_LOAN and Farm.MAX_LOAN
-- — the game's own class-level constants for the loan floor and ceiling —
-- are pinned to 0, so there is nothing left to lend and the Finances tab's
-- own "can I still borrow?" check is what keeps the Borrow prompt from
-- appearing, rather than this mod hunting down and hiding a specific GUI
-- element by hand. That also means it can never go stale against a future
-- game update the way a hardcoded button id would.
--
-- Each farm caches its own loan ceiling in a loanMax field rather than
-- reading the class constant live, so changing Farm.MAX_LOAN alone has no
-- effect on a farm that already exists — Farm:updateMaxLoan() is what
-- recomputes that cache, and is called on every farm whenever the setting
-- changes. loanMax is also pinned directly as a fallback, in case a future
-- game version derives it from something other than Farm.MAX_LOAN.
--
-- Repaying an existing loan is NEVER affected: the ceiling only caps how
-- much MORE can be borrowed, it has nothing to do with a farm's current
-- loan balance, so a farm that already has an outstanding loan (because
-- the setting used to be on, or an admin flips it back on temporarily) can
-- always still pay it down to zero.
--
-- The game's own defaults are captured once, the first time Farm exists,
-- before this mod ever touches them — so turning the setting back on
-- restores the real default limit rather than a guessed number.
--

Loans = {}
Loans.NAME = "Loans"

Loans.defaultsCaptured = false
Loans.defaultMinLoan = nil
Loans.defaultMaxLoan = nil
Loans.lastGeneration = nil

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("Loans: " .. tostring(message))
    else
        print("[Realism] Loans: " .. tostring(message))
    end
end

local function isEnabled()
    if Settings == nil then
        return true
    end

    return Settings.isEnabled("loans")
end

local function getLocalFarm()
    if g_currentMission == nil then
        return nil
    end

    if g_farmManager ~= nil and type(g_farmManager.getFarmByUserId) == "function" and g_currentMission.playerUserId ~= nil then
        local farm = g_farmManager:getFarmByUserId(g_currentMission.playerUserId)

        if farm ~= nil then
            return farm
        end
    end

    if g_localPlayer ~= nil and g_farmManager ~= nil and type(g_farmManager.getFarmById) == "function" then
        return g_farmManager:getFarmById(g_localPlayer.farmId)
    end

    return nil
end

-- Every farm needs refreshing, not just the local player's — in
-- multiplayer, or singleplayer with more than one farm, each one has its
-- own cached loanMax.
local function forEachFarm(callback)
    if g_farmManager ~= nil and type(g_farmManager.getFarms) == "function" then
        local ok, farms = pcall(g_farmManager.getFarms, g_farmManager)

        if ok and type(farms) == "table" then
            for _, farm in pairs(farms) do
                callback(farm)
            end

            return
        end
    end

    local farm = getLocalFarm()

    if farm ~= nil then
        callback(farm)
    end
end

local function refreshFarmLoanLimits()
    forEachFarm(function(farm)
        if type(farm.updateMaxLoan) == "function" then
            pcall(farm.updateMaxLoan, farm)
        end

        if not isEnabled() and type(farm.loanMax) == "number" and farm.loanMax > 0 then
            farm.loanMax = 0
        end
    end)
end

local function captureDefaults()
    if Loans.defaultsCaptured or Farm == nil then
        return
    end

    Loans.defaultsCaptured = true
    Loans.defaultMinLoan = Farm.MIN_LOAN
    Loans.defaultMaxLoan = Farm.MAX_LOAN

    log(string.format("captured the game's loan limit (MIN_LOAN=%s MAX_LOAN=%s)",
        tostring(Loans.defaultMinLoan), tostring(Loans.defaultMaxLoan)))
end

local function apply()
    if Farm == nil or not Loans.defaultsCaptured then
        return
    end

    if isEnabled() then
        Farm.MIN_LOAN = Loans.defaultMinLoan
        Farm.MAX_LOAN = Loans.defaultMaxLoan
    else
        Farm.MIN_LOAN = 0
        Farm.MAX_LOAN = 0
    end

    refreshFarmLoanLimits()
end

-- Farm is not guaranteed to exist the instant this script loads, so the
-- defaults are captured lazily — the same "try until ready" shape
-- SettingsMenu.build() uses — rather than assumed at install time.
function Loans:update(dt)
    if not Loans.defaultsCaptured then
        if Farm == nil then
            return
        end

        captureDefaults()
        apply()

        return
    end

    if Settings == nil then
        return
    end

    local generation = Settings.getGeneration()

    if generation == Loans.lastGeneration then
        return
    end

    Loans.lastGeneration = generation

    apply()
end

-- Reports the live state and forces a re-apply, for an admin checking
-- things from the console without waiting for the next settings change.
function Loans:consoleStatus()
    if Farm == nil then
        return "Farm does not exist yet"
    end

    apply()

    local farm = getLocalFarm()

    return string.format(
        "loans.enabled=%s | Farm.MIN_LOAN=%s Farm.MAX_LOAN=%s | farm.loan=%s farm.loanMax=%s",
        tostring(isEnabled()), tostring(Farm.MIN_LOAN), tostring(Farm.MAX_LOAN),
        farm ~= nil and tostring(farm.loan) or "?", farm ~= nil and tostring(farm.loanMax) or "?")
end

function Loans.install()
    if addConsoleCommand ~= nil then
        addConsoleCommand("rlLoansStatus", "Show and re-apply the current Farm loan limit", "consoleStatus", Loans)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(Loans.NAME, Loans)
    end

    log("installed — waiting for Farm to exist before capturing the real loan limit")
end

Loans.install()
