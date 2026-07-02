--
-- Realism — AICropDamage
--
-- By default, hired AI workers are exempt from crop destruction: the game
-- disables wheel foliage destruction whenever a vehicle is AI-controlled
-- (Wheels.lua: allowFoliageDestruction = ... and not getIsAIActive()).
-- That lets helpers drive over crops with the wrong tyres without leaving
-- a mark, which the player can't do.
--
-- This re-enables it for AI: wheel foliage destruction is computed exactly
-- like for the player — on whenever crop destruction is enabled and the
-- wheel isn't blocked. Care wheels (proper row-crop tyres) still don't
-- destroy crops, so AI only damages crops with the wrong tyres, just like
-- you do when driving manually.
--
-- Implemented by wrapping WheelDestruction:update (the callee that the
-- per-wheel updater hands the AI-exempted flag to) and undoing the AI
-- exemption. Guarded so a missing class can't error.
--

AICropDamage = {}
AICropDamage.NAME = "AICropDamage"

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log(message)
    else
        print("[Realism] " .. message)
    end
end

local function allowAIFoliageDestruction(self, superFunc, dt, allowFoliageDestruction)
    if not allowFoliageDestruction then
        local mission = g_currentMission

        if mission ~= nil and mission.missionInfo ~= nil and mission.missionInfo.fruitDestruction then
            local vehicle = self.vehicle
            local blocked = vehicle ~= nil and type(vehicle.getBlockFoliageDestruction) == "function" and vehicle:getBlockFoliageDestruction()

            if not blocked then
                allowFoliageDestruction = true
            end
        end
    end

    return superFunc(self, dt, allowFoliageDestruction)
end

function AICropDamage.install()
    if WheelDestruction ~= nil and type(WheelDestruction.update) == "function" then
        WheelDestruction.update = Utils.overwrittenFunction(WheelDestruction.update, allowAIFoliageDestruction)

        if Realism ~= nil and Realism.registerFeature ~= nil then
            Realism.registerFeature(AICropDamage.NAME, AICropDamage)
        end

        log("AI crop destruction enabled (workers damage crops with wrong tyres)")
    else
        log("WheelDestruction.update not found — AI crop damage unavailable")
    end
end

AICropDamage.install()
