--
-- Realism — SleepSchedule
--
-- Forces a realistic sleep rhythm:
--
--   * You can only sleep in the evening (from 21:00). The sleep dialog is
--     blocked during the day, so you can't nap through the day to skip
--     it. Because sleep runs to the morning, the evening-only window
--     naturally gives roughly 6-9 hours of sleep.
--   * After 16 hours awake you become tired: a notification, an on-screen
--     warning, a short fade-to-black, and a sound tell you to go to bed.
--
-- Tiredness is tracked from the last wake-up. A sleep is detected as a
-- large forward jump in game time (normal play only advances minutes per
-- frame, sleeping jumps hours), which resets the awake timer.
--
-- The fade reuses the mod's own icon texture tinted black, so no extra
-- asset is needed. The sound plays sounds/yawn.ogg if you add one, else
-- falls back to a built-in game sound. Everything is guarded so a missing
-- API or file never causes an error.
--

SleepSchedule = {}
SleepSchedule.NAME = "SleepSchedule"

SleepSchedule.SLEEP_EARLIEST_HOUR = 21
SleepSchedule.AWAKE_HOURS_UNTIL_TIRED = 16
SleepSchedule.MIN_SLEEP_HOURS = 6
SleepSchedule.FADE_DURATION_MS = 2000
SleepSchedule.FADE_MAX_ALPHA = 0.8
SleepSchedule.SLEEP_JUMP_HOURS = 2.0
SleepSchedule.WAKE_GRACE_MS = 2500
SleepSchedule.TIRED_REPEAT_MS = 60000

SleepSchedule.prevGameHours = nil
SleepSchedule.lastWakeGameHours = nil
SleepSchedule.sleepDeprived = false
SleepSchedule.graceUntil = 0
SleepSchedule.lastTiredEffectTime = nil
SleepSchedule.fadeStart = nil
SleepSchedule.overlay = nil
SleepSchedule.overlayTried = false

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(message)
    else
        print("[Realism] " .. message)
    end
end

local function getDayHour()
    local env = g_currentMission and g_currentMission.environment

    if env == nil or env.dayTime == nil then
        return nil
    end

    return env.dayTime / 3600000
end

local function getGameHours()
    local env = g_currentMission and g_currentMission.environment

    if env == nil then
        return nil
    end

    local day = env.currentMonotonicDay or env.currentDay or 0
    local hour = (env.dayTime or 0) / 3600000

    return day * 24 + hour
end

-- Tired either after being awake too long, or because the last sleep was
-- shorter than a full rest (sleep deprivation).
function SleepSchedule.isTired()
    if SleepSchedule.sleepDeprived then
        return true
    end

    if SleepSchedule.lastWakeGameHours == nil then
        return false
    end

    local now = getGameHours()

    if now == nil then
        return false
    end

    return (now - SleepSchedule.lastWakeGameHours) >= SleepSchedule.AWAKE_HOURS_UNTIL_TIRED
end

local function notify(text)
    if g_currentMission == nil or g_currentMission.hud == nil then
        return
    end

    local hud = g_currentMission.hud

    if type(hud.addSideNotification) == "function" then
        local color = FSBaseMission ~= nil and FSBaseMission.INGAME_NOTIFICATION_CRITICAL or { 1, 0.4, 0.2, 1 }

        pcall(function()
            hud:addSideNotification(color, text, 6000)
        end)
    end
end

local function warn(text)
    if g_currentMission ~= nil and type(g_currentMission.showBlinkingWarning) == "function" then
        pcall(function()
            g_currentMission:showBlinkingWarning(text, 3000)
        end)

        return
    end

    notify(text)
end

local function playYawn()
    local dir = (Realism ~= nil and Realism.MOD_DIRECTORY) or ""
    local path = dir .. "sounds/yawn.ogg"

    if fileExists ~= nil and fileExists(path) and createSample ~= nil then
        local ok = pcall(function()
            if SleepSchedule.yawnSample == nil then
                SleepSchedule.yawnSample = createSample("realismYawn")
                loadSample(SleepSchedule.yawnSample, path, false)
            end

            playSample(SleepSchedule.yawnSample, 1, 1.0, 0, 0, nil)
        end)

        if ok then
            return
        end
    end

    if g_gui ~= nil and type(g_gui.playSample) == "function" and GuiSoundPlayer ~= nil and GuiSoundPlayer.SOUND_SAMPLES ~= nil and GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION ~= nil then
        pcall(function()
            g_gui:playSample(GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
        end)
    end
end

local function fireTiredEffects()
    notify("You are exhausted. You can sleep now to rest.")
    SleepSchedule.fadeStart = g_time or 0
    playYawn()
end

local function guardedShowDialog(self, superFunc, ...)
    local hour = getDayHour()
    local lateEnough = (hour == nil) or (hour >= SleepSchedule.SLEEP_EARLIEST_HOUR)

    if not lateEnough and not SleepSchedule.isTired() then
        warn(string.format("It's too early to sleep. Wait until %02d:00, or until you're tired.", SleepSchedule.SLEEP_EARLIEST_HOUR))

        return
    end

    return superFunc(self, ...)
end

function SleepSchedule:update(dt)
    local nowGameHours = getGameHours()

    if nowGameHours == nil then
        return
    end

    if SleepSchedule.prevGameHours ~= nil then
        local delta = nowGameHours - SleepSchedule.prevGameHours

        -- A large forward jump means a sleep happened; the jump size is
        -- how long the player slept.
        if delta > SleepSchedule.SLEEP_JUMP_HOURS then
            SleepSchedule.lastWakeGameHours = nowGameHours
            SleepSchedule.lastTiredEffectTime = nil
            SleepSchedule.graceUntil = (g_time or 0) + SleepSchedule.WAKE_GRACE_MS

            -- A full rest (>= MIN_SLEEP_HOURS) clears tiredness; a shorter
            -- sleep leaves the player sleep-deprived and still tired.
            SleepSchedule.sleepDeprived = delta < SleepSchedule.MIN_SLEEP_HOURS

            if SleepSchedule.sleepDeprived then
                log(string.format("Short sleep (%.1fh) — still tired", delta))
            else
                log(string.format("Rested (%.1fh sleep)", delta))
            end
        end
    end

    SleepSchedule.prevGameHours = nowGameHours

    if SleepSchedule.lastWakeGameHours == nil then
        SleepSchedule.lastWakeGameHours = nowGameHours
    end

    -- Brief grace after waking so the tired effects don't collide with the
    -- game's own sleep fade.
    if (g_time or 0) < (SleepSchedule.graceUntil or 0) then
        return
    end

    if SleepSchedule.isTired() then
        local now = g_time or 0
        local firstThisEpisode = SleepSchedule.lastTiredEffectTime == nil

        -- Re-play the tired effects on first becoming tired and then once a
        -- real minute, so the player can't miss the reminder to sleep.
        if firstThisEpisode or (now - SleepSchedule.lastTiredEffectTime) >= SleepSchedule.TIRED_REPEAT_MS then
            SleepSchedule.lastTiredEffectTime = now

            if firstThisEpisode then
                log("Player is tired — sleep required")
            end

            fireTiredEffects()
        end

        if g_currentMission ~= nil and type(g_currentMission.addExtraPrintText) == "function" then
            g_currentMission:addExtraPrintText("You are exhausted — you need to sleep.")
        end
    end
end

local function renderFade(alpha)
    if SleepSchedule.overlay == nil then
        if SleepSchedule.overlayTried or createImageOverlay == nil then
            return
        end

        SleepSchedule.overlayTried = true

        local dir = (Realism ~= nil and Realism.MOD_DIRECTORY) or ""
        local path = dir .. "icon_Realism.png"

        if fileExists ~= nil and not fileExists(path) then
            return
        end

        SleepSchedule.overlay = createImageOverlay(path)
    end

    if SleepSchedule.overlay == nil or SleepSchedule.overlay == 0 then
        return
    end

    if setOverlayColor ~= nil and renderOverlay ~= nil then
        setOverlayColor(SleepSchedule.overlay, 0, 0, 0, alpha)
        renderOverlay(SleepSchedule.overlay, 0, 0, 1, 1)
    end
end

function SleepSchedule:draw()
    if SleepSchedule.fadeStart == nil then
        return
    end

    local now = g_time or 0
    local elapsed = now - SleepSchedule.fadeStart

    if elapsed < 0 or elapsed > SleepSchedule.FADE_DURATION_MS then
        SleepSchedule.fadeStart = nil

        return
    end

    local t = elapsed / SleepSchedule.FADE_DURATION_MS
    local alpha = math.sin(t * math.pi) * SleepSchedule.FADE_MAX_ALPHA

    renderFade(alpha)
end

function SleepSchedule.install()
    local restricted = false

    if SleepManager ~= nil and type(SleepManager.showDialog) == "function" then
        SleepManager.showDialog = Utils.overwrittenFunction(SleepManager.showDialog, guardedShowDialog)
        restricted = true
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(SleepSchedule.NAME, SleepSchedule)
    end

    log(string.format("SleepSchedule enabled (evening-only sleep=%s, tired after %dh)", tostring(restricted), SleepSchedule.AWAKE_HOURS_UNTIL_TIRED))
end

SleepSchedule.install()
