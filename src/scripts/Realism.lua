--
-- Realism — main controller
--
-- Acts as the shared namespace for every realism feature module.
-- Individual features (DisableTeleport, ...) attach themselves to this
-- table so they can be inspected, toggled, or extended later without
-- touching the rest of the mod.
--

Realism = {}
Realism.MOD_NAME = g_currentModName or "FS25_Realism"
Realism.MOD_DIRECTORY = g_currentModDirectory or ""
Realism.VERSION = "1.0.0.0"

Realism.features = {}

function Realism.log(message)
    print(string.format("[Realism %s] %s", Realism.VERSION, tostring(message)))
end

function Realism.registerFeature(name, module)
    Realism.features[name] = module
    Realism.log("Feature registered: " .. tostring(name))
end

function Realism:loadMap(name)
    Realism.log("Loaded into map: " .. tostring(name))
end

function Realism:deleteMap()
end

function Realism:mouseEvent(posX, posY, isDown, isUp, button)
end

function Realism:keyEvent(unicode, sym, modifier, isDown)
end

function Realism:update(dt)
    for _, feature in pairs(Realism.features) do
        if type(feature.update) == "function" then
            feature:update(dt)
        end
    end
end

function Realism:draw()
    for _, feature in pairs(Realism.features) do
        if type(feature.draw) == "function" then
            feature:draw()
        end
    end
end

addModEventListener(Realism)

Realism.log("Mod initialised — " .. Realism.MOD_NAME)
