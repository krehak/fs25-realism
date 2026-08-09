--
-- Realism — CarryGrip
--
-- Two problems with carrying objects by hand in FS25:
--   1. Even a light object slips out of your hands the moment you run, jump or
--      change direction quickly — which makes no sense for something light.
--   2. The on-screen icon while holding looks the same as the "you can pick
--      this up" hover icon, so you can't tell whether you are holding anything.
--
-- How carrying works (discovered at runtime — the engine scripts are packed):
--   * On foot the player always has the "hands" hand tool equipped
--     (HandToolHands, player.currentHandTool). Picking an object up attaches
--     it to a kinematic node in front of the camera with a PHYSICS JOINT.
--   * Running / jumping jerks that kinematic node; the item's rigid body lags,
--     the joint stretches past its break force and snaps — the item drops.
--   * getHeldItem() / spec_hands.heldItemNode is the item's scene node;
--     spec_hands.kinematicNode is the hand target it is jointed to.
--     getMass(node) returns the mass in TONNES (0.0567 => ~57 kg).
--
-- Grip fix: rather than fight the joint after it breaks (which corrupts the
-- carry state and can strand the item off-screen), we PREVENT the break. Every
-- frame, for a light (green) item, we translate the item by exactly the same
-- amount the hand's kinematic node moved and zero its velocity. The item then
-- co-moves with the hand with no lag, so the joint never tensions and never
-- snaps — the object simply cannot fall out of your hands.
--
-- We only ever move the item's own body and never touch the joint or the drop
-- path, so dropping, throwing and everything else stay completely vanilla — and
-- nothing can ever get stuck. Heavier items are left alone: orange can slip
-- under stress, red drops easily.
--
-- HUD: while genuinely holding an item we draw our own indicator — the weight
-- in kg, tinted green / orange / red by grip strength, plus a short status.
--
-- Thresholds (mass in tonnes; getMass is tonnes):
--   green  <= 0.10 t (100 kg) — secure, never drops
--   orange <= 0.15 t (150 kg) — heavy, can slip under stress
--   red     > 0.15 t          — very heavy, drops easily
--

CarryGrip = {}
CarryGrip.NAME = "CarryGrip"

CarryGrip.GREEN_MAX_T = 0.10
CarryGrip.ORANGE_MAX_T = 0.15

CarryGrip.pinnedOnce = false

local COLOR_GREEN = { 0.20, 0.85, 0.25 }
local COLOR_ORANGE = { 0.95, 0.60, 0.10 }
local COLOR_RED = { 0.90, 0.18, 0.18 }

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("CarryGrip: " .. tostring(message))
    else
        print("[Realism] CarryGrip: " .. tostring(message))
    end
end

local function resolvePlayer()
    if g_localPlayer ~= nil then
        return g_localPlayer
    end

    if g_currentMission ~= nil then
        return g_currentMission.player
    end

    return nil
end

local function heldItemMass(tool)
    if tool == nil then
        return nil, nil
    end

    local node = nil

    if type(tool.getHeldItem) == "function" then
        local ok, item = pcall(function()
            return tool:getHeldItem()
        end)

        if ok and type(item) == "number" then
            node = item
        end
    end

    if node == nil and tool.spec_hands ~= nil then
        node = tool.spec_hands.heldItemNode
    end

    if node == nil or node == 0 or getMass == nil then
        return nil, nil
    end

    local ok, mass = pcall(getMass, node)

    if not ok or type(mass) ~= "number" then
        return nil, node
    end

    return mass, node
end

local function tierFor(massT)
    if massT <= CarryGrip.GREEN_MAX_T then
        return COLOR_GREEN, "Secure grip"
    elseif massT <= CarryGrip.ORANGE_MAX_T then
        return COLOR_ORANGE, "Heavy — hold steady"
    end

    return COLOR_RED, "Very heavy — may drop"
end

-- ---------------------------------------------------
-- Grip: keep a light item glued to the hand so the
-- holding joint never tensions and never breaks
-- ---------------------------------------------------

local function isThrowing(tool)
    if type(tool.getIsThrowingItem) ~= "function" then
        return false
    end

    local ok, throwing = pcall(function()
        return tool:getIsThrowingItem()
    end)

    return ok and throwing == true
end

local function pinHeldItem(self, dt)
    local spec = self.spec_hands

    if spec == nil then
        return
    end

    local holding = false

    if type(self.getIsHoldingItem) == "function" then
        local ok, v = pcall(function()
            return self:getIsHoldingItem()
        end)

        holding = ok and v == true
    end

    local mass, node = heldItemMass(self)
    local kin = spec.kinematicNode

    local eligible = holding
        and not isThrowing(self)
        and node ~= nil
        and mass ~= nil
        and mass <= CarryGrip.GREEN_MAX_T
        and kin ~= nil
        and kin ~= 0
        and getWorldTranslation ~= nil
        and setWorldTranslation ~= nil

    if not eligible then
        spec.realismPinValid = false

        return
    end

    pcall(function()
        local kx, ky, kz = getWorldTranslation(kin)

        if spec.realismPinValid and spec.realismPinNode == node then
            local dx = kx - spec.realismPinKX
            local dy = ky - spec.realismPinKY
            local dz = kz - spec.realismPinKZ

            if dx ~= 0 or dy ~= 0 or dz ~= 0 then
                local ix, iy, iz = getWorldTranslation(node)

                setWorldTranslation(node, ix + dx, iy + dy, iz + dz)

                if setLinearVelocity ~= nil then
                    setLinearVelocity(node, 0, 0, 0)
                end

                if setAngularVelocity ~= nil then
                    setAngularVelocity(node, 0, 0, 0)
                end

                if not CarryGrip.pinnedOnce then
                    CarryGrip.pinnedOnce = true

                    log("holding light item with reinforced grip (working)")
                end
            end
        end

        spec.realismPinValid = true
        spec.realismPinNode = node
        spec.realismPinKX = kx
        spec.realismPinKY = ky
        spec.realismPinKZ = kz
    end)
end

-- ---------------------------------------------------
-- HUD: weight + colour while holding
-- ---------------------------------------------------

function CarryGrip:draw()
    local player = resolvePlayer()

    if player == nil or not player.isControlled then
        return
    end

    local tool = player.currentHandTool

    if tool == nil or type(tool.getIsHoldingItem) ~= "function" then
        return
    end

    local holding = false
    local ok = pcall(function()
        holding = tool:getIsHoldingItem()
    end)

    if not ok or not holding then
        return
    end

    local massT = heldItemMass(tool)

    if massT == nil then
        return
    end

    local color, status = tierFor(massT)
    local kg = math.floor(massT * 1000 + 0.5)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(color[1], color[2], color[3], 1)
    renderText(0.5, 0.145, 0.020, string.format("%d kg", kg))

    setTextBold(false)
    renderText(0.5, 0.120, 0.014, status)

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(1, 1, 1, 1)
end

function CarryGrip.install()
    if HandToolHands == nil then
        log("HandToolHands not found — carry grip unavailable")

        return
    end

    if type(HandToolHands.onUpdate) == "function" then
        HandToolHands.onUpdate = Utils.appendedFunction(HandToolHands.onUpdate, pinHeldItem)
    else
        log("HandToolHands.onUpdate not found — grip reinforcement unavailable")
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(CarryGrip.NAME, CarryGrip)
    end

    log("carry grip + holding indicator enabled")
end

CarryGrip.install()
