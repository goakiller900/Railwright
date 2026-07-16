local Constants = require("scripts.constants")
local State = require("scripts.state")

local Gui = {}

local function find_index(values, selected, fallback)
    for index, value in ipairs(values) do
        if value == selected then return index end
    end
    return fallback or 1
end

local function find_element(root, name)
    if not root or not root.valid then return nil end
    if root.name == name then return root end

    for _, child in pairs(root.children) do
        local found = find_element(child, name)
        if found then return found end
    end

    return nil
end

local function set_row_visible(root, name, visible)
    local label = find_element(root, name .. "_label")
    local control = find_element(root, name)
    if label then label.visible = visible end
    if control then control.visible = visible end
end

local function add_row(table_element, caption, definition)
    local label_definition = { type = "label", caption = caption }
    if definition.name then label_definition.name = definition.name .. "_label" end
    table_element.add(label_definition)
    return table_element.add(definition)
end

local function add_section(parent, name, caption, columns)
    local frame = parent.add({
        type = "frame",
        name = name,
        direction = "vertical",
        caption = caption,
    })
    frame.style.horizontally_stretchable = true

    local content = frame.add({
        type = "table",
        column_count = columns or 2,
    })
    content.style.horizontal_spacing = 16
    content.style.vertical_spacing = 6

    return frame, content
end

local function entity_picker(table_element, caption, name, value, filters)
    local picker = add_row(table_element, caption, {
        type = "choose-elem-button",
        name = name,
        elem_type = "entity",
        entity = value,
    })
    if filters then picker.elem_filters = filters end
    return picker
end

local function item_picker(table_element, caption, name, value)
    return add_row(table_element, caption, {
        type = "choose-elem-button",
        name = name,
        elem_type = "item",
        item = value ~= "" and value or nil,
    })
end

local function textfield(table_element, caption, name, value, numeric)
    return add_row(table_element, caption, {
        type = "textfield",
        name = name,
        text = tostring(value),
        numeric = numeric or false,
        allow_decimal = not numeric,
        allow_negative = false,
    })
end

local function checkbox(table_element, caption, name, state)
    return add_row(table_element, caption, {
        type = "checkbox",
        name = name,
        state = state,
    })
end

local function dropdown(table_element, caption, name, items, selected_index)
    return add_row(table_element, caption, {
        type = "drop-down",
        name = name,
        items = items,
        selected_index = selected_index,
    })
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
    if frame then frame.destroy() end
end

function Gui.update_visibility(player)
    local frame = player.gui.screen[Constants.gui.frame]
    if not frame then return end

    local station_dropdown = find_element(frame, Constants.gui.station_type)
    if not station_dropdown then return end

    local station_type = Constants.station_type_keys[station_dropdown.selected_index] or "loading"
    local item_group = find_element(frame, Constants.gui.item_group)
    local fluid_group = find_element(frame, Constants.gui.fluid_group)
    local behavior_group = find_element(frame, Constants.gui.behavior_group)
    local stacker_group = find_element(frame, Constants.gui.stacker_group)

    local item_station = station_type == "loading" or station_type == "unloading"
    local fluid_station = station_type == "fluid-loading" or station_type == "fluid-unloading"
    local stacker = station_type == "stacker"

    if item_group then item_group.visible = item_station end
    if fluid_group then fluid_group.visible = fluid_station end
    if behavior_group then behavior_group.visible = not stacker end
    if stacker_group then stacker_group.visible = stacker end

    set_row_visible(frame, Constants.gui.station_name, not stacker)
    set_row_visible(frame, Constants.gui.double_headed, not stacker)
    set_row_visible(frame, Constants.gui.include_train, not stacker)
end

function Gui.open(player)
    Gui.close(player)

    local settings = State.get_player(player.index)
    local frame = player.gui.screen.add({
        type = "frame",
        name = Constants.gui.frame,
        direction = "vertical",
    })

    local titlebar = frame.add({ type = "flow", name = Constants.gui.titlebar, direction = "horizontal" })
    titlebar.drag_target = frame

    local title = titlebar.add({
        type = "label",
        caption = { "railwright.window-title" },
        style = "frame_title",
    })
    title.drag_target = frame

    local spacer = titlebar.add({ type = "empty-widget", style = "draggable_space_header" })
    spacer.style.horizontally_stretchable = true
    spacer.style.height = 24
    spacer.drag_target = frame

    titlebar.add({
        type = "sprite-button",
        name = Constants.gui.close_button,
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        style = "frame_action_button",
        tooltip = { "gui.close" },
    })

    frame.add({ type = "label", caption = { "railwright.intro" } })

    local scroll = frame.add({
        type = "scroll-pane",
        name = Constants.gui.scroll,
        direction = "vertical",
    })
    scroll.style.maximal_height = 760
    scroll.style.minimal_width = 650
    scroll.style.horizontally_stretchable = true

    local _, common = add_section(scroll, Constants.gui.common_group, { "railwright.section-common" })
    dropdown(
        common,
        { "railwright.station-type" },
        Constants.gui.station_type,
        Constants.station_types,
        find_index(Constants.station_type_keys, settings.station_type)
    )
    textfield(common, { "railwright.station-name" }, Constants.gui.station_name, settings.station_name, false)
    textfield(common, { "railwright.locomotives" }, Constants.gui.locomotives, settings.locomotives, true)
    textfield(common, { "railwright.cargo-wagons" }, Constants.gui.cargo_wagons, settings.cargo_wagons, true)
    checkbox(common, { "railwright.double-headed" }, Constants.gui.double_headed, settings.double_headed)
    checkbox(common, { "railwright.include-train" }, Constants.gui.include_train, settings.include_train)

    local item_frame, item = add_section(scroll, Constants.gui.item_group, { "railwright.section-item" })
    dropdown(item, { "railwright.station-sides" }, Constants.gui.sides, Constants.sides,
        find_index(Constants.side_keys, settings.sides))

    entity_picker(item, { "railwright.inserter" }, Constants.gui.inserter, settings.inserter_name, {
        { filter = "type", type = "inserter" },
    })
    entity_picker(item, { "railwright.chest" }, Constants.gui.chest, settings.chest_name, {
        { filter = "type", type = "container" },
        { filter = "type", type = "logistic-container", mode = "or" },
        { filter = "type", type = "infinity-container", mode = "or" },
        { filter = "type", type = "linked-container", mode = "or" },
    })
    entity_picker(item, { "railwright.belt" }, Constants.gui.belt, settings.belt_name, {
        { filter = "type", type = "transport-belt" },
    })
    entity_picker(item, { "railwright.splitter" }, Constants.gui.splitter, settings.splitter_name, {
        { filter = "type", type = "splitter" },
    })
    dropdown(item, { "railwright.belt-flow" }, Constants.gui.belt_flow, Constants.belt_flows,
        find_index(Constants.belt_flow_keys, settings.belt_flow))
    checkbox(item, { "railwright.filter-enabled" }, Constants.gui.filter_enabled, settings.filter_enabled)
    textfield(item, { "railwright.chest-limit" }, Constants.gui.chest_limit, settings.chest_limit, true)
    checkbox(item, { "railwright.request-from-buffers" }, Constants.gui.request_from_buffers, settings.request_from_buffers)
    checkbox(item, { "railwright.madzuri" }, Constants.gui.madzuri, settings.madzuri)

    item_frame.add({ type = "label", caption = { "railwright.filter-items" } })
    local filter_table = item_frame.add({ type = "table", column_count = 5 })
    for index = 1, 5 do
        filter_table.add({
            type = "choose-elem-button",
            name = Constants.gui.filter_item_prefix .. index,
            elem_type = "item",
            item = settings.filter_items[index] ~= "" and settings.filter_items[index] or nil,
        })
    end

    item_frame.add({ type = "label", caption = { "railwright.logistic-requests" } })
    local request_table = item_frame.add({ type = "table", column_count = 3 })
    request_table.add({ type = "label", caption = { "railwright.request-number" } })
    request_table.add({ type = "label", caption = { "railwright.request-item" } })
    request_table.add({ type = "label", caption = { "railwright.request-count" } })
    for index = 1, 12 do
        local request = settings.request_items[index]
        request_table.add({ type = "label", caption = tostring(index) })
        request_table.add({
            type = "choose-elem-button",
            name = Constants.gui.request_item_prefix .. index,
            elem_type = "item",
            item = request.name ~= "" and request.name or nil,
        })
        request_table.add({
            type = "textfield",
            name = Constants.gui.request_count_prefix .. index,
            text = tostring(request.count or 100),
            numeric = true,
            allow_decimal = false,
            allow_negative = false,
        })
    end

    local _, fluid = add_section(scroll, Constants.gui.fluid_group, { "railwright.section-fluid" })
    dropdown(fluid, { "railwright.pump-side" }, Constants.gui.pump_side, Constants.pump_sides,
        find_index(Constants.pump_side_keys, settings.pump_side))
    entity_picker(fluid, { "railwright.pump" }, Constants.gui.pump, settings.pump_name, {
        { filter = "type", type = "pump" },
    })
    entity_picker(fluid, { "railwright.storage-tank" }, Constants.gui.storage_tank, settings.storage_tank_name, {
        { filter = "type", type = "storage-tank" },
    })
    entity_picker(fluid, { "railwright.pipe" }, Constants.gui.pipe, settings.pipe_name, {
        { filter = "type", type = "pipe" },
    })
    textfield(fluid, { "railwright.tank-columns" }, Constants.gui.tank_columns, settings.tank_columns, true)
    checkbox(fluid, { "railwright.connect-pipes" }, Constants.gui.connect_pipes, settings.connect_pipes)

    local _, behavior = add_section(scroll, Constants.gui.behavior_group, { "railwright.section-behavior" })
    checkbox(behavior, { "railwright.connect-green" }, Constants.gui.connect_green, settings.connect_green)
    checkbox(behavior, { "railwright.connect-both-green" }, Constants.gui.connect_both_green, settings.connect_both_green)
    checkbox(behavior, { "railwright.connect-red" }, Constants.gui.connect_red, settings.connect_red)
    checkbox(behavior, { "railwright.connect-both-red" }, Constants.gui.connect_both_red, settings.connect_both_red)
    checkbox(behavior, { "railwright.refill-enabled" }, Constants.gui.refill_enabled, settings.refill_enabled)
    item_picker(behavior, { "railwright.refill-fuel" }, Constants.gui.refill_fuel, settings.refill_fuel)
    textfield(behavior, { "railwright.refill-amount" }, Constants.gui.refill_amount, settings.refill_amount, true)
    dropdown(behavior, { "railwright.train-limit" }, Constants.gui.train_limit, Constants.train_limits,
        find_index(Constants.train_limits, settings.train_limit))
    checkbox(behavior, { "railwright.train-limit-one" }, Constants.gui.train_limit_one, settings.train_limit_one)
    textfield(behavior, { "railwright.train-limit-stack-size" }, Constants.gui.train_limit_stack_size,
        settings.train_limit_stack_size, true)
    checkbox(behavior, { "railwright.enabled-condition" }, Constants.gui.enabled_condition, settings.enabled_condition)
    dropdown(behavior, { "railwright.enabled-operator" }, Constants.gui.enabled_operator, Constants.enabled_operators,
        find_index(Constants.enabled_operators, settings.enabled_operator))
    textfield(behavior, { "railwright.enabled-amount" }, Constants.gui.enabled_amount, settings.enabled_amount, true)
    checkbox(behavior, { "railwright.lamps" }, Constants.gui.lamps, settings.lamps)

    local _, stacker = add_section(scroll, Constants.gui.stacker_group, { "railwright.section-stacker" })
    textfield(stacker, { "railwright.stacker-lanes" }, Constants.gui.stacker_lanes, settings.stacker_lanes, true)
    dropdown(stacker, { "railwright.stacker-type" }, Constants.gui.stacker_type, Constants.stacker_types,
        find_index(Constants.stacker_types, settings.stacker_type))

    local generate = frame.add({
        type = "button",
        name = Constants.gui.generate_button,
        caption = { "railwright.generate" },
        style = "confirm_button",
    })
    generate.style.horizontally_stretchable = true

    Gui.update_visibility(player)
    frame.force_auto_center()
    player.opened = frame
end

function Gui.toggle(player)
    if player.gui.screen[Constants.gui.frame] then Gui.close(player) else Gui.open(player) end
end

local function parse_integer(element, label, minimum)
    local value = tonumber(element.text)
    if not value or value ~= math.floor(value) or value < minimum then
        return nil, string.format("%s must be a whole number of at least %d.", label, minimum)
    end
    return value
end

function Gui.read_settings(player)
    local frame = player.gui.screen[Constants.gui.frame]
    if not frame then return nil, "Railwright window is not open." end

    local function get(name)
        return find_element(frame, name)
    end

    local locomotives, error_message = parse_integer(get(Constants.gui.locomotives), "Locomotives", 1)
    if not locomotives then return nil, error_message end

    local cargo_wagons
    cargo_wagons, error_message = parse_integer(get(Constants.gui.cargo_wagons), "Wagons", 1)
    if not cargo_wagons then return nil, error_message end

    local chest_limit
    chest_limit, error_message = parse_integer(get(Constants.gui.chest_limit), "Chest limit", 0)
    if not chest_limit then return nil, error_message end

    local tank_columns
    tank_columns, error_message = parse_integer(get(Constants.gui.tank_columns), "Storage tank columns", 1)
    if not tank_columns then return nil, error_message end

    local refill_amount
    refill_amount, error_message = parse_integer(get(Constants.gui.refill_amount), "Refill amount", 1)
    if not refill_amount then return nil, error_message end

    local train_limit_stack_size
    train_limit_stack_size, error_message = parse_integer(get(Constants.gui.train_limit_stack_size), "Train-limit stack size", 1)
    if not train_limit_stack_size then return nil, error_message end

    local enabled_amount
    enabled_amount, error_message = parse_integer(get(Constants.gui.enabled_amount), "Enabled-condition amount", 0)
    if not enabled_amount then return nil, error_message end

    local stacker_lanes
    stacker_lanes, error_message = parse_integer(get(Constants.gui.stacker_lanes), "Stacker lanes", 1)
    if not stacker_lanes then return nil, error_message end

    local filter_items = {}
    for index = 1, 5 do
        filter_items[index] = get(Constants.gui.filter_item_prefix .. index).elem_value or ""
    end

    local request_items = {}
    for index = 1, 12 do
        local name = get(Constants.gui.request_item_prefix .. index).elem_value or ""
        local count_element = get(Constants.gui.request_count_prefix .. index)
        local count = tonumber(count_element.text) or 0
        if count ~= math.floor(count) or count < 0 then
            return nil, "Logistic request " .. index .. " has an invalid amount."
        end
        request_items[index] = { name = name, count = count }
    end

    local station_index = get(Constants.gui.station_type).selected_index
    local side_index = get(Constants.gui.sides).selected_index
    local pump_side_index = get(Constants.gui.pump_side).selected_index
    local belt_flow_index = get(Constants.gui.belt_flow).selected_index

    return {
        station_type = Constants.station_type_keys[station_index] or "loading",
        station_name = get(Constants.gui.station_name).text,
        locomotives = locomotives,
        cargo_wagons = cargo_wagons,
        double_headed = get(Constants.gui.double_headed).state,
        include_train = get(Constants.gui.include_train).state,

        sides = Constants.side_keys[side_index] or "both",
        inserter_name = get(Constants.gui.inserter).elem_value,
        chest_name = get(Constants.gui.chest).elem_value,
        belt_name = get(Constants.gui.belt).elem_value,
        splitter_name = get(Constants.gui.splitter).elem_value,
        belt_flow = Constants.belt_flow_keys[belt_flow_index] or "front",
        filter_enabled = get(Constants.gui.filter_enabled).state,
        filter_items = filter_items,
        chest_limit = chest_limit,
        request_from_buffers = get(Constants.gui.request_from_buffers).state,
        request_items = request_items,
        madzuri = get(Constants.gui.madzuri).state,

        pump_side = Constants.pump_side_keys[pump_side_index] or "right",
        pump_name = get(Constants.gui.pump).elem_value,
        storage_tank_name = get(Constants.gui.storage_tank).elem_value,
        pipe_name = get(Constants.gui.pipe).elem_value,
        tank_columns = tank_columns,
        connect_pipes = get(Constants.gui.connect_pipes).state,

        connect_green = get(Constants.gui.connect_green).state,
        connect_both_green = get(Constants.gui.connect_both_green).state,
        connect_red = get(Constants.gui.connect_red).state,
        connect_both_red = get(Constants.gui.connect_both_red).state,
        refill_enabled = get(Constants.gui.refill_enabled).state,
        refill_fuel = get(Constants.gui.refill_fuel).elem_value,
        refill_amount = refill_amount,
        train_limit = Constants.train_limits[get(Constants.gui.train_limit).selected_index] or "Disabled",
        train_limit_one = get(Constants.gui.train_limit_one).state,
        train_limit_stack_size = train_limit_stack_size,
        enabled_condition = get(Constants.gui.enabled_condition).state,
        enabled_operator = Constants.enabled_operators[get(Constants.gui.enabled_operator).selected_index] or ">",
        enabled_amount = enabled_amount,
        lamps = get(Constants.gui.lamps).state,

        stacker_lanes = stacker_lanes,
        stacker_diagonal = false,
        stacker_type = Constants.stacker_types[get(Constants.gui.stacker_type).selected_index] or "Left-Right",
    }
end

return Gui
