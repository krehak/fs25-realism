--
-- Realism — WoodMass
--
-- Shows the mass (weight) of a tree / log in the info box for EVERYONE in
-- multiplayer, not just the server host.
--
-- Why this is needed: the engine's getMass() only returns a valid value for a
-- split shape on the machine that owns its physics — the server. On a client
-- getMass() returns nothing, so forestry mods (InfoDisplayExtension,
-- ForestryHelper, ...) simply hide the weight for anyone who is not the host.
-- The mass is visible in singleplayer (you are the server) but disappears for
-- a friend who joins your server.
--
-- The fix: a log's density (mass per volume) is a constant per wood species.
-- getVolume() DOES work on clients. So:
--   * server computes density = getMass / getVolume per split type and
--     broadcasts it (WoodMassDensityEvent),
--   * a client that lacks a species' density asks for it (WoodMassRequestEvent),
--   * the client then shows a Mass line = getVolume(shape) * density.
--
-- Only clients get the extra line; the host keeps whatever the other mods
-- already draw, so nothing is duplicated. Everything is pcall-guarded and a
-- no-op in singleplayer.
--

WoodMass = {}
WoodMass.NAME = "WoodMass"
WoodMass.REQUEST_INTERVAL_MS = 3000

WoodMass.density = {}
WoodMass.lastRequest = {}

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("WoodMass: " .. tostring(message))
    else
        print("[Realism] WoodMass: " .. tostring(message))
    end
end

local function isServer()
    return g_currentMission ~= nil and type(g_currentMission.getIsServer) == "function" and g_currentMission:getIsServer()
end

local function massLabel()
    local text = g_i18n:getText("infohud_mass")

    if text == nil or text == "" or string.find(text, "infohud_mass", 1, true) ~= nil then
        return g_i18n:getText("realism_mass")
    end

    return text
end

-- ---------------------------------------------------
-- Network events
-- ---------------------------------------------------

WoodMassDensityEvent = {}
local WoodMassDensityEvent_mt = Class(WoodMassDensityEvent, Event)

InitEventClass(WoodMassDensityEvent, "WoodMassDensityEvent")

function WoodMassDensityEvent.emptyNew()
    return Event.new(WoodMassDensityEvent_mt)
end

function WoodMassDensityEvent.new(typeIndex, density)
    local self = WoodMassDensityEvent.emptyNew()
    self.typeIndex = typeIndex
    self.density = density

    return self
end

function WoodMassDensityEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.typeIndex or 0, 8)
    streamWriteFloat32(streamId, self.density or 0)
end

function WoodMassDensityEvent:readStream(streamId, connection)
    self.typeIndex = streamReadUIntN(streamId, 8)
    self.density = streamReadFloat32(streamId)

    self:run(connection)
end

function WoodMassDensityEvent:run(connection)
    if self.typeIndex ~= nil and self.density ~= nil and self.density > 0 then
        WoodMass.density[self.typeIndex] = self.density

        log(string.format("density received for split type %d: %.2f kg/m3", self.typeIndex, self.density))
    end
end

WoodMassRequestEvent = {}
local WoodMassRequestEvent_mt = Class(WoodMassRequestEvent, Event)

InitEventClass(WoodMassRequestEvent, "WoodMassRequestEvent")

function WoodMassRequestEvent.emptyNew()
    return Event.new(WoodMassRequestEvent_mt)
end

function WoodMassRequestEvent.new(node, typeIndex)
    local self = WoodMassRequestEvent.emptyNew()
    self.node = node
    self.typeIndex = typeIndex

    return self
end

function WoodMassRequestEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, self.node or 0)
    streamWriteUIntN(streamId, self.typeIndex or 0, 8)
end

function WoodMassRequestEvent:readStream(streamId, connection)
    self.node = streamReadInt32(streamId)
    self.typeIndex = streamReadUIntN(streamId, 8)

    self:run(connection)
end

function WoodMassRequestEvent:run(connection)
    if connection:getIsServer() then
        return
    end

    WoodMass.sampleDensity(self.node)

    local density = WoodMass.density[self.typeIndex]

    if density ~= nil then
        connection:sendEvent(WoodMassDensityEvent.new(self.typeIndex, density))
    end
end

-- ---------------------------------------------------
-- Density sampling (server) and requesting (client)
-- ---------------------------------------------------

function WoodMass.sampleDensity(node)
    if not isServer() then
        return
    end

    if node == nil or node == 0 then
        return
    end

    if entityExists ~= nil and not entityExists(node) then
        return
    end

    if getSplitType == nil then
        return
    end

    local okType, typeIndex = pcall(getSplitType, node)

    if not okType or typeIndex == nil or typeIndex == 0 then
        return
    end

    if WoodMass.density[typeIndex] ~= nil then
        return
    end

    local mass, volume

    local ok = pcall(function()
        mass = getMass(node)
        volume = getVolume(node)
    end)

    if not ok or mass == nil or volume == nil or volume <= 0 or mass <= 0 then
        return
    end

    WoodMass.density[typeIndex] = mass / volume

    if g_server ~= nil then
        g_server:broadcastEvent(WoodMassDensityEvent.new(typeIndex, WoodMass.density[typeIndex]))
    end
end

local function requestDensity(node, typeIndex)
    if g_client == nil or type(g_client.getServerConnection) ~= "function" then
        return
    end

    local now = (g_currentMission ~= nil and g_currentMission.time) or 0
    local last = WoodMass.lastRequest[typeIndex]

    if last ~= nil and (now - last) < WoodMass.REQUEST_INTERVAL_MS then
        return
    end

    WoodMass.lastRequest[typeIndex] = now

    g_client:getServerConnection():sendEvent(WoodMassRequestEvent.new(node, typeIndex))
end

-- ---------------------------------------------------
-- Info box line
-- ---------------------------------------------------

local function appendMassLine(playerHudUpdater, splitShape)
    if isServer() then
        WoodMass.sampleDensity(splitShape)

        return
    end

    if splitShape == nil or splitShape == 0 then
        return
    end

    if entityExists ~= nil and not entityExists(splitShape) then
        return
    end

    if getSplitType == nil then
        return
    end

    local okType, typeIndex = pcall(getSplitType, splitShape)

    if not okType or typeIndex == nil or typeIndex == 0 then
        return
    end

    local box = playerHudUpdater.objectBox

    if box == nil or type(box.addLine) ~= "function" then
        return
    end

    local density = WoodMass.density[typeIndex]

    if density == nil then
        requestDensity(splitShape, typeIndex)

        return
    end

    local volume

    local okVol = pcall(function()
        volume = getVolume(splitShape)
    end)

    if not okVol or volume == nil or volume <= 0 then
        return
    end

    box:addLine(massLabel(), g_i18n:formatMass(volume * density))
end

function WoodMass.install()
    if PlayerHUDUpdater == nil or type(PlayerHUDUpdater.showSplitShapeInfo) ~= "function" then
        log("PlayerHUDUpdater.showSplitShapeInfo not found — wood mass sync unavailable")

        return
    end

    PlayerHUDUpdater.showSplitShapeInfo = Utils.appendedFunction(PlayerHUDUpdater.showSplitShapeInfo, appendMassLine)

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(WoodMass.NAME, WoodMass)
    end

    log("wood mass multiplayer sync enabled")
end

WoodMass.install()
