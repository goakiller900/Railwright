local Constants = require("scripts.constants")
local State = require("scripts.state")

local Gui = {}

local function add_setting_row(table_element, caption, element_definition)
    table_element.add({
        type = "label",
        caption = caption,
    })
    return table_element.add(element_definition)
end

function Gui.ensure_button(player)
    local top = player.gui.top
    if top[Constants.gui.top_button] then return end

    top.add({
        type = "sprite-button",
        name = Constants.gui.top_button,
        sprite = "item/blueprint",
        style = "slot_button",
        tooltip = { "railwright.open-tooltip" },
    })
end

function Gui.close(player)
    local frame = player.gui.screen[Constants.gui.frame]
    if frame then
        frame.destroy()
    end
end

function Gui.open(player)
    Gui.close(player)

    local settings = State.get_player(player.index)
    local frame = player.gui.screen.add({
        type = "frame",
        name = Constants.gui.frame,
        direction = "vertical",
    })

    local titlebar = frame.add({
        type = "flow",
        name = Constants.gui.titlebar,
        direction = "horizontal",
    })
    titlebar.drag_target = frame

    local title = titlebar.add({
        type = "label",
        caption = { "railwright.window-title" },
        style = "frame_title",
    })
    title.drag_target = frame

    local spacer = titlebar.add({
        type = "empty-widget",
        style = "draggable_space_header",
    })
    spacer.style.horizontally_stretchable = true
    spacer.style.height = 24
    spacer.drag_target = frame

    titlebar.add({
        type = "button",
        name = Constants.gui.close_button,
        caption = "✕",
        style = "frame_action_button",
        tooltip = { "gui.close" },
    })

    frame.add({
        type = "label",
        caption = { "railwright.intro" },
    })

    local content = frame.add({
        type = "table",
        name = Constants.gui.content,
        column_count = 2,
    })
    content.style.horizontal_spacing = 16
    content.style.vertical_spacing = 8

    add_setting_row(content, { "railwright.station-type" }, {
        type = "drop-down",
        name = Constants.gui.station_type,
        items = Constants.station_types,
        selected_index = settings.station_type == "unloading" and 2 or 1,
    })

    add_setting_row(content, { "railwright.station-name" }, {
        type = "textfield",
        name = Constants.gui.station_name,
        text = settings.station_name,
    })

    add_setting_row(content, { "railwright.locomotives" }, {
        type = "textfield",
        name = Constants.gui.locomotives,
        text = tostring(settings.locomotives),
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
    })

    add_setting_row(content, { "railwright.cargo-wagons" }, {
        type = "textfield",
        name = Constants.gui.cargo_wagons,
        text = tostring(settings.cargo_wagons),
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
    })

    add_setting_row(content, { "railwright.double-headed" }, {
        type = "checkbox",
        name = Constants.gui.double_headed,
        state = settings.double_headed,
    })

    add_setting_row(content, { "railwright.include-train" }, {
        type = "checkbox",
        name = Constants.gui.include_train,
        state = settings.include_train,
    })

    local side_index = 1
    if settings.sides == "right" then
        side_index = 2
    elseif settings.sides == "left" then
        side_index = 3
    end

    add_setting_row(content, { "railwright.station-sides" }, {
        type = "drop-down",
        name = Constants.gui.sides,
        items = Constants.sides,
        selected_index = side_index,
    })

    add_setting_row(content, { "railwright.inserter" }, {
        type = "choose-elem-button",
        name = Constants.gui.inserter,
        elem_type = "entity",
        elem_value = settings.inserter_name,
    })

    add_setting_row(content, { "railwright.chest" }, {
        type = "choose-elem-button",
        name = Constants.gui.chest,
        elem_type = "entity",
        elem_value = settings.chest_name,
    })

    add_setting_row(content, { "railwright.belt" }, {
        type = "choose-elem-button",
        name = Constants.gui.belt,
        elem_type = "entity",
        elem_value = settings.belt_name,
    })

    local generate = frame.add({
        type = "button",
        name = Constants.gui.generate_button,
        caption = { "railwright.generate" },
        style = "confirm_button",
    })
    generate.style.horizontally_stretchable = true

    frame.force_auto_center()
    player.opened = frame
end

function Gui.toggle(player)
    if player.gui.screen[Constants.gui.frame] then
        Gui.close(player)
    else
        Gui.open(player)
    end
end

local function parse_positive_integer(text, label)
    local value = tonumber(text)
    if not value or value ~= math.floor(value) or value < 1 then
        return nil, label .. " must be a positive whole number."
    end
    return value
end

function Gui.read_settings(player)
    local frame = player.gui.screen[Constants.gui.frame]
    if not frame then
        return nil, "Railwright window is not open."
    end

    local content = frame[Constants.gui.content]
    if not content then
        return nil, "Railwright GUI is missing its settings panel."
    end

    local locomotives, error_message = parse_positive_integer(content[Constants.gui.locomotives].text, "Locomotives")
    if not locomotives then return nil, error_message end

    local cargo_wagons
    cargo_wagons, error_message = parse_positive_integer(content[Constants.gui.cargo_wagons].text, "Cargo wagons")
    if not cargo_wagons then return nil, error_message end

    local station_type = content[Constants.gui.station_type].selected_index == 2 and "unloading" or "loading"

    local side_index = content[Constants.gui.sides].selected_index
    local sides = "both"
    if side_index == 2 then
        sides = "right"
    elseif side_index == 3 then
        sides = "left"
    end

    return {
        station_type = station_type,
        station_name = content[Constants.gui.station_name].text,
        locomotives = locomotives,
        cargo_wagons = cargo_wagons,
        double_headed = content[Constants.gui.double_headed].state,
        include_train = content[Constants.gui.include_train].state,
        sides = sides,
        inserter_name = content[Constants.gui.inserter].elem_value,
        chest_name = content[Constants.gui.chest].elem_value,
        belt_name = content[Constants.gui.belt].elem_value,
    }
end

return Gui
