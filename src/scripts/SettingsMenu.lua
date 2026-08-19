--
-- Realism — SettingsMenu
--
-- Puts every Realism setting into the game's own Settings page, under the
-- General / Game settings the player already knows, instead of making an
-- admin hand-edit XML.
--
-- The rows are generated from Settings.SCHEMA, so a setting added there
-- appears here automatically with no UI work: its label, tooltip and the
-- values a selector offers all live beside the option itself.
--
-- How the injection works (the game's menu is not built for extension, so
-- this is the established pattern):
--   * g_gui.screenControllers[InGameMenu].pageSettings is the page, and
--     pageSettings.gameSettingsLayout the column the rows live in.
--   * There is no "make me a setting row" API, so an existing row is
--     CLONED — checkWoodHarvesterAutoCutBox, a plain multi-option row —
--     and its label, tooltip, choices and callback replaced. Section
--     headers are cloned the same way from the layout's own sectionHeader.
--   * Every cloned element needs a fresh focus id, and has to be handed to
--     the FocusManager when the settings GUI opens, or the row exists but
--     cannot be reached with a controller.
--
-- Numbers become a list of sensible choices rather than free text, because
-- the settings page only has selectors. The XML file still accepts any
-- value in range, so nothing is lost for someone who wants 37,500 exactly.
--
-- Permissions and multiplayer are already solved by Settings.set: on a
-- client it sends an admin-checked event to the server, and the server
-- applies and broadcasts. So the menu just calls that and lets the reply
-- come back through the normal sync. Non-admins see the rows disabled.
--

SettingsMenu = {}
SettingsMenu.NAME = "SettingsMenu"

SettingsMenu.TEMPLATE_ROWS = {
    "checkWoodHarvesterAutoCutBox",
    "checkFuelUsageBox",
    "checkDirtIntervalBox",
}

SettingsMenu.built = false
SettingsMenu.rows = {}
SettingsMenu.lastGeneration = nil

local function log(message)
    if Realism ~= nil and Realism.log ~= nil then
        Realism.log("SettingsMenu: " .. tostring(message))
    else
        print("[Realism] SettingsMenu: " .. tostring(message))
    end
end

local function isAdmin()
    if g_currentMission == nil then
        return false
    end

    if type(g_currentMission.getIsServer) == "function" and g_currentMission:getIsServer() then
        return true
    end

    return g_currentMission.isMasterUser == true
end

local function getSettingsPage()
    local controllers = g_gui ~= nil and g_gui.screenControllers or nil
    local controller = controllers ~= nil and InGameMenu ~= nil and controllers[InGameMenu] or nil

    return controller ~= nil and controller.pageSettings or nil
end

-- ---------------------------------------------------
-- Values and labels
-- ---------------------------------------------------

local function formatMoney(value)
    local text = string.format("%d", math.floor(value + 0.5))
    local out = text:reverse():gsub("(%d%d%d)", "%1 "):reverse()

    return (out:gsub("^%s+", ""))
end

-- The choices one selector offers, and the text shown for each.
function SettingsMenu.getChoices(option)
    if option.type == Settings.TYPE_BOOL then
        local off = g_i18n ~= nil and g_i18n:getText("ui_off") or "Off"
        local on = g_i18n ~= nil and g_i18n:getText("ui_on") or "On"

        return { false, true }, { off, on }
    end

    local values = {}
    local step = option.uiStep

    if step ~= nil and step > 0 and option.uiMin ~= nil and option.uiMax ~= nil then
        local steps = math.floor((option.uiMax - option.uiMin) / step + 0.5)

        for i = 0, steps do
            -- Rebuilt from the index rather than accumulated, so 0.05 added
            -- forty times still lands exactly on 2 and not 1.9999999.
            local value = option.uiMin + i * step

            table.insert(values, math.floor(value * 1000000 + 0.5) / 1000000)
        end
    end

    if #values == 0 then
        values = { option.default }
    end

    -- The stored value must always be selectable, or opening the menu would
    -- silently round it to a neighbour the moment anything is changed.
    local current = Settings.get(option.featureName or "", option.key)
    local wanted = { option.default, current }

    for _, target in ipairs(wanted) do
        if type(target) == "number" then
            local found = false

            for _, value in ipairs(values) do
                if math.abs(value - target) < 1e-9 then
                    found = true

                    break
                end
            end

            if not found then
                table.insert(values, target)
                table.sort(values)
            end
        end
    end

    local texts = {}

    for _, value in ipairs(values) do
        local text

        if option.display == "percent" then
            text = string.format("%d%%", math.floor(value * 100 + 0.5))
        elseif option.display == "money" then
            text = formatMoney(value)
        elseif option.display == "months" then
            text = value == 1 and "1 month" or string.format("%g months", value)
        elseif option.display == "liters" then
            text = formatMoney(value) .. " l"
        else
            text = string.format("%g", value)
        end

        table.insert(texts, text)
    end

    return values, texts
end

-- Which choice is currently selected. A value the list does not contain —
-- someone typed 37,500 into the XML — snaps to the nearest one so the row
-- still shows something truthful rather than defaulting to the first.
local function getStateIndex(row)
    local value = Settings.get(row.feature, row.key)

    if row.option.type == Settings.TYPE_BOOL then
        return value == true and 2 or 1
    end

    if value == nil then
        return 1
    end

    local bestIndex, bestDistance = 1, nil

    for i, candidate in ipairs(row.values) do
        local distance = math.abs(candidate - value)

        if bestDistance == nil or distance < bestDistance then
            bestIndex, bestDistance = i, distance
        end
    end

    return bestIndex
end

-- ---------------------------------------------------
-- Row construction
-- ---------------------------------------------------

-- Every feature's first option is its master switch, and the feature checks
-- it before anything else it does. So with the master off the rows beneath
-- are already inert — showing them as editable would invite a player to set
-- values that quietly do nothing. They grey out instead, which says plainly
-- that the switch above governs them.
local function isRowDisabled(row)
    if not isAdmin() then
        return true
    end

    if row.key == "enabled" then
        return false
    end

    return Settings.isEnabled(row.feature) ~= true
end

local function updateFocusIds(element)
    if element == nil then
        return
    end

    element.focusId = FocusManager:serveAutoFocusId()

    for _, child in pairs(element.elements) do
        updateFocusIds(child)
    end
end

local function stateCount(control)
    if control == nil then
        return 0
    end

    if type(control.getStateCount) == "function" then
        local ok, count = pcall(control.getStateCount, control)

        if ok and type(count) == "number" then
            return count
        end
    end

    if type(control.texts) == "table" then
        return #control.texts
    end

    return 0
end

-- Two different rows are needed, and using the wrong one is what broke this
-- the first time: an Off/On row is a BINARY element that holds exactly two
-- states, so handing it a dozen choices keeps the first two and silently
-- maps every later choice onto the wrong value.
--
-- Rather than trust a hard-coded field name, the page's own rows are scanned
-- for one that already carries more than two states — that is a genuine
-- multi-option row, whatever the game calls it this version.
local function findTemplates(settingsPage, layout)
    local binary, multi, binaryName, multiName

    for _, element in ipairs(layout.elements) do
        local control = element.elements ~= nil and element.elements[1] or nil

        if control ~= nil and type(control.setTexts) == "function" and type(control.setState) == "function" then
            local count = stateCount(control)

            if count > 2 and multi == nil then
                multi, multiName = element, element.id or element.name or "?"
            elseif count == 2 and binary == nil then
                binary, binaryName = element, element.id or element.name or "?"
            end
        end
    end

    if binary == nil then
        for _, name in ipairs(SettingsMenu.TEMPLATE_ROWS) do
            if settingsPage[name] ~= nil then
                binary, binaryName = settingsPage[name], name

                break
            end
        end
    end

    return binary, multi, binaryName, multiName
end

function SettingsMenu:onRowChanged(state, control)
    local row = control ~= nil and control.realismRow or nil

    if row == nil then
        return
    end

    -- A non-admin can move the selector, but the change is refused server
    -- side, so put the control back where it was rather than leaving it
    -- showing a value that is not in force.
    if isRowDisabled(row) then
        control:setState(getStateIndex(row))

        return
    end

    local value = row.values[state]

    if value == nil then
        return
    end

    -- On a client the value is not ours to change directly: the request goes
    -- to the server and comes back as a broadcast, which bumps the settings
    -- generation and refreshes the row. So leave the player's choice showing
    -- until then, and only snap back if the request was refused outright.
    local ok = Settings.set(row.feature, row.key, value, true)

    if not ok then
        control:setState(getStateIndex(row))
    end
end

local function addSectionTitle(settingsPage, layout, title)
    local template = nil

    for _, element in ipairs(layout.elements) do
        if element.name == "sectionHeader" then
            template = element

            break
        end
    end

    if template == nil then
        return
    end

    local header = template:clone(layout)

    if header == nil then
        return
    end

    header:setText(title)
    header.focusId = FocusManager:serveAutoFocusId()

    table.insert(settingsPage.controlsList, header)
end

local function addRow(settingsPage, layout, template, section, option)
    if template == nil then
        return nil
    end

    local box = template:clone(layout)

    if box == nil then
        return nil
    end

    local control = box.elements[1]

    if control == nil then
        return nil
    end

    local values, texts = SettingsMenu.getChoices(option)
    local row = {
        feature = section.name,
        key = option.key,
        option = option,
        values = values,
        control = control,
    }

    box.id = "realism_" .. section.name .. "_" .. option.key .. "_box"
    control.id = "realism_" .. section.name .. "_" .. option.key
    control.realismRow = row
    control.target = SettingsMenu
    control:setCallback("onClickCallback", "onRowChanged")
    control:setTexts(texts)

    -- If the element refused the full list, every state index below would
    -- point at the wrong number and quietly write it to the settings file.
    -- Drop the row instead: a missing row is recoverable, a corrupted value
    -- is not.
    local accepted = stateCount(control)

    if accepted ~= #values then
        box:delete()

        log(string.format(
            "%s.%s: control took %d of %d choices — row skipped so it cannot write a wrong value",
            section.name, option.key, accepted, #values
        ))

        return nil
    end

    control:setState(getStateIndex(row))
    control:setDisabled(isRowDisabled(row))

    local tooltip = control.elements[1]

    if tooltip ~= nil and option.tooltip ~= nil then
        tooltip:setText(option.tooltip)
    end

    local label = box.elements[2]

    if label ~= nil then
        label:setText(option.label or option.key)
    end

    updateFocusIds(box)
    table.insert(settingsPage.controlsList, box)

    return row
end

function SettingsMenu.build()
    if SettingsMenu.built then
        return
    end

    local settingsPage = getSettingsPage()

    if settingsPage == nil or settingsPage.gameSettingsLayout == nil then
        return
    end

    local layout = settingsPage.gameSettingsLayout
    local binary, multi, binaryName, multiName = findTemplates(settingsPage, layout)

    if binary == nil and multi == nil then
        SettingsMenu.built = true

        log("no settings row to clone — in-game settings unavailable, use realism.xml or rlSet")

        return
    end

    local count = 0

    for _, section in ipairs(Settings.SCHEMA) do
        addSectionTitle(settingsPage, layout, section.title or section.name)

        for _, option in ipairs(section.options) do
            option.featureName = section.name

            local template = option.type == Settings.TYPE_BOOL and binary or multi
            local row = addRow(settingsPage, layout, template, section, option)

            if row ~= nil then
                table.insert(SettingsMenu.rows, row)
                count = count + 1
            end
        end
    end

    SettingsMenu.built = true

    layout:invalidateLayout()

    log(string.format(
        "%d setting(s) added to the game settings page (on/off rows from %s, value rows from %s)",
        count, tostring(binaryName), tostring(multiName)
    ))
end

function SettingsMenu.refresh()
    for _, row in ipairs(SettingsMenu.rows) do
        if row.control ~= nil then
            row.control:setState(getStateIndex(row))
            row.control:setDisabled(isRowDisabled(row))
        end
    end
end

-- Values can change under the menu: the server broadcasts an admin's edit,
-- or the settings file is reloaded. Settings bumps its generation whenever
-- that happens, which is the cue to redraw.
function SettingsMenu:update(dt)
    if not SettingsMenu.built then
        SettingsMenu.build()

        return
    end

    if Settings == nil then
        return
    end

    local generation = Settings.getGeneration()

    if generation ~= SettingsMenu.lastGeneration then
        SettingsMenu.lastGeneration = generation

        SettingsMenu.refresh()
    end
end

function SettingsMenu.install()
    if InGameMenuSettingsFrame ~= nil and type(InGameMenuSettingsFrame.onFrameOpen) == "function" then
        InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
            SettingsMenu.build()
            SettingsMenu.refresh()
        end)
    end

    -- A cloned row is invisible to the controller until the focus manager
    -- has been told about it, and that can only happen once the settings
    -- GUI is the active one.
    if FocusManager ~= nil and type(FocusManager.setGui) == "function" then
        FocusManager.setGui = Utils.appendedFunction(FocusManager.setGui, function(_, gui)
            if gui ~= "ingameMenuSettings" then
                return
            end

            for _, row in ipairs(SettingsMenu.rows) do
                local control = row.control

                if control ~= nil and control.focusId ~= nil
                    and FocusManager.currentFocusData.idToElementMapping[control.focusId] == nil then

                    FocusManager:loadElementFromCustomValues(control, nil, nil, false, false)
                end
            end

            local settingsPage = getSettingsPage()

            if settingsPage ~= nil and settingsPage.gameSettingsLayout ~= nil then
                settingsPage.gameSettingsLayout:invalidateLayout()
            end
        end)
    end

    if Realism ~= nil and Realism.registerFeature ~= nil then
        Realism.registerFeature(SettingsMenu.NAME, SettingsMenu)
    end

    log("installed")
end

SettingsMenu.install()
