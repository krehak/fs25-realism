--
-- Realism — GameStart
--
-- A one-time, tutorial-style intro that fires only on the FIRST load of a
-- brand-new savegame, regardless of which career preset the player chose.
-- It shows an info dialog explaining the "Realism" rules so the player
-- knows what they signed up for.
--
-- The mod no longer touches money, vehicles, farmland or player position at
-- the start — the starting money, starting vehicle and starting field are
-- left to whatever the chosen map / career preset provides, and getting
-- around is up to the player. This module is now purely informational.
--
-- Safety: the intro only triggers when both (a) no marker exists for this
-- save and (b) the save is genuinely new (tiny playTime). So reloading an
-- initialised save, or adding the mod to an existing save, never re-runs
-- it. Every engine call is pcall-guarded.
--

GameStart = {}
GameStart.NAME = "GameStart"

GameStart.NEW_GAME_PLAYTIME_MS = 60000

GameStart.STATE_IDLE = 0
GameStart.STATE_INTRO = 1
GameStart.STATE_DONE = 2

GameStart.state = GameStart.STATE_IDLE
GameStart.checked = false
GameStart.introShown = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("GameStart: " .. tostring(message))
    else
        print("[Realism] GameStart: " .. tostring(message))
    end
end

local function l10n(key, fallback)
    if g_i18n ~= nil and g_i18n:hasText(key) then
        return g_i18n:getText(key)
    end

    return fallback
end

local function notify(text)
    if g_currentMission ~= nil and g_currentMission.hud ~= nil and type(g_currentMission.hud.addSideNotification) == "function" then
        local color = FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_INFO or { 1, 1, 1, 1 }

        pcall(function()
            g_currentMission.hud:addSideNotification(color, text, 6000)
        end)
    end
end

local function getMarkerPath()
    local mi = g_currentMission and g_currentMission.missionInfo

    if mi == nil or mi.savegameDirectory == nil then
        return nil
    end

    return mi.savegameDirectory .. "/realismGameStart.xml"
end

local function markerExists()
    local path = getMarkerPath()

    return path ~= nil and fileExists ~= nil and fileExists(path)
end

local function writeMarker()
    local path = getMarkerPath()

    if path == nil or createXMLFile == nil then
        return
    end

    pcall(function()
        local handle = createXMLFile("realismGameStart", path, "realismGameStart")

        if handle ~= nil and handle ~= 0 then
            setXMLBool(handle, "realismGameStart#done", true)
            saveXMLFile(handle)
            delete(handle)
        end
    end)
end

local function isNewGame()
    local mi = g_currentMission and g_currentMission.missionInfo

    if mi == nil then
        return false
    end

    local playTime = mi.playTime or 0

    return playTime < GameStart.NEW_GAME_PLAYTIME_MS
end

function GameStart.finish()
    GameStart.state = GameStart.STATE_DONE
    writeMarker()
    log("Realism intro complete")
end

local function onIntroConfirmed()
    GameStart.finish()
end

local function showIntro()
    GameStart.introShown = true

    local body = l10n("realism_intro_body",
        "This mod makes farming authentic and hard. No teleporting, " ..
        "inflation, no auto-selling, locked realism settings. Your starting money, " ..
        "vehicle and field are whatever the map you picked gives you — build your " ..
        "farm from there, the hard way.")

    if g_gui ~= nil and type(g_gui.showInfoDialog) == "function" then
        local ok = pcall(function()
            g_gui:showInfoDialog({
                text = body,
                callback = onIntroConfirmed,
                target = GameStart,
            })
        end)

        if ok then
            return
        end
    end

    -- Fallback: no dialog API — just notify and proceed.
    notify(l10n("realism_intro_title", "Welcome to Realism"))
    onIntroConfirmed()
end

function GameStart:update(dt)
    if not GameStart.checked then
        GameStart.checked = true

        if g_server == nil then
            GameStart.state = GameStart.STATE_DONE

            return
        end

        if markerExists() or not isNewGame() then
            GameStart.state = GameStart.STATE_DONE
            log("not a fresh new game — Realism intro skipped")

            return
        end

        GameStart.state = GameStart.STATE_INTRO
        log("new game detected — showing Realism intro")
    end

    if GameStart.state == GameStart.STATE_INTRO and not GameStart.introShown then
        showIntro()
    end
end

function GameStart.install()
    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(GameStart.NAME, GameStart)
    end

    log("enabled (Realism intro for new games)")
end

GameStart.install()
