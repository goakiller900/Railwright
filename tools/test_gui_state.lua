-- Focused non-Factorio regression checks for saved entity selections, optional
-- loader recovery, GUI picker construction, and generator validation.
package.path = "./?.lua;./?/init.lua;" .. package.path

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

defines = {
    direction = {
        north = 0,
        northeast = 2,
        east = 4,
        eastsoutheast = 6,
        southeast = 6,
        south = 8,
        southwest = 10,
        westsouthwest = 10,
        west = 12,
        northwest = 14,
    },
    inventory = { cargo_wagon = 1, chest = 2 },
    wire_connector_id = {
        circuit_red = 1,
        circuit_green = 2,
        combinator_input_red = 3,
        combinator_input_green = 4,
        combinator_output_red = 5,
        combinator_output_green = 6,
        pole_copper = 7,
    },
}

local function inventory_size() return 48 end
local function wagon_inventory_size() return 40 end
local function tank_capacity() return 25000 end

prototypes = {
    entity = {
        ["fast-inserter"] = { type = "inserter" },
        ["modded-inserter"] = { type = "inserter" },
        ["steel-chest"] = { type = "container", get_inventory_size = inventory_size },
        ["fast-transport-belt"] = { type = "transport-belt" },
        ["fast-splitter"] = { type = "splitter" },
        pump = { type = "pump" },
        ["storage-tank"] = { type = "storage-tank", get_fluid_capacity = tank_capacity },
        pipe = { type = "pipe" },
        locomotive = {
            type = "locomotive",
            burner_prototype = { fuel_categories = { chemical = true } },
        },
        ["cargo-wagon"] = { get_inventory_size = wagon_inventory_size },
        ["fluid-wagon"] = { get_fluid_capacity = tank_capacity },
        ["straight-rail"] = { type = "straight-rail" },
        ["curved-rail-a"] = { type = "curved-rail-a" },
        ["curved-rail-b"] = { type = "curved-rail-b" },
    },
    item = {
        ["solid-fuel"] = { type = "item", fuel_category = "chemical" },
        coal = { type = "item", fuel_category = "chemical" },
        ["iron-plate"] = { type = "item" },
        ["nuclear-fuel-cell"] = { type = "item", fuel_category = "nuclear" },
        ["modded-item"] = { type = "item" },
        ["modded-fuel"] = { type = "item", fuel_category = "chemical" },
    },
}

storage = {
    players = {
        [1] = { transfer_mode = "loaders", loader_name = "" },
        [2] = { chest_name = "removed-chest" },
        [3] = { inserter_name = "modded-inserter" },
        [4] = { transfer_mode = "loaders", loader_name = "removed-loader" },
        [8] = { refill_fuel = "removed-fuel" },
        [9] = { filter_items = { "modded-item", "removed-filter" } },
        [10] = { request_items = { { name = "removed-request", count = 75 } } },
        [11] = {
            station_type = "fluid-loading",
            refill_enabled = false,
            refill_fuel = "removed-hidden-fuel",
            filter_enabled = false,
            filter_items = { "removed-hidden-filter" },
            request_items = { { name = "removed-hidden-request", count = 50 } },
        },
        [12] = {
            refill_fuel = "modded-fuel",
            filter_items = { "modded-item" },
            request_items = { { name = "modded-item", count = 125 } },
        },
        [13] = { refill_fuel = "nuclear-fuel-cell" },
        [15] = {
            refill_fuel = 42,
            filter_items = { 42 },
            request_items = { { name = {}, count = 25 } },
        },
        [16] = { refill_fuel = "iron-plate" },
        [17] = { station_type = "stacker", double_headed = true },
        [18] = { stacker_double_headed = "true" },
    },
}

local State = require("scripts.state")

local empty_loader = State.ensure_player(1)
equal(empty_loader.loader_name, nil, "empty loader selection is sanitized")
equal(empty_loader.transfer_mode, "inserters", "empty loader selection falls back to inserters")

local removed_entity = State.ensure_player(2)
equal(removed_entity.chest_name, nil, "removed entity prototype is sanitized")

local modded_entity = State.ensure_player(3)
equal(modded_entity.inserter_name, "modded-inserter", "valid modded entity is preserved")

local removed_loader = State.ensure_player(4)
equal(removed_loader.loader_name, nil, "removed loader prototype is sanitized")
equal(removed_loader.transfer_mode, "inserters", "removed loader falls back to inserters")

local removed_fuel = State.ensure_player(8)
equal(removed_fuel.refill_fuel, "solid-fuel", "removed refuelling fuel falls back to the valid default")

local removed_filter = State.ensure_player(9)
equal(removed_filter.filter_items[1], "modded-item", "valid modded filter item is preserved")
equal(removed_filter.filter_items[2], "", "removed filter item becomes unselected")
for index = 1, 5 do
    equal(removed_filter.filter_items[index] ~= nil, true, "filter slots remain dense at " .. index)
end

local removed_request = State.ensure_player(10)
equal(removed_request.request_items[1].name, "", "removed logistic-request item becomes unselected")
equal(removed_request.request_items[1].count, 75, "removed logistic-request item keeps its slot amount")
for index = 1, 12 do
    equal(removed_request.request_items[index] ~= nil, true, "request slots remain dense at " .. index)
end

local hidden_stale_items = State.ensure_player(11)
equal(hidden_stale_items.refill_fuel, "solid-fuel", "disabled stale fuel recovers to the valid default")
equal(hidden_stale_items.filter_items[1], "", "hidden stale filter is cleared")
equal(hidden_stale_items.request_items[1].name, "", "hidden stale request is cleared")

local modded_items = State.ensure_player(12)
equal(modded_items.refill_fuel, "modded-fuel", "valid modded fuel is preserved")
equal(modded_items.filter_items[1], "modded-item", "valid modded filter is preserved")
equal(modded_items.request_items[1].name, "modded-item", "valid modded request is preserved")

local incompatible_fuel = State.ensure_player(13)
equal(incompatible_fuel.refill_fuel, "solid-fuel", "incompatible saved fuel falls back to the valid default")

local malformed_items = State.ensure_player(15)
equal(malformed_items.refill_fuel, "solid-fuel", "malformed saved fuel falls back to the valid default")
equal(malformed_items.filter_items[1], "", "malformed saved filter becomes unselected")
equal(malformed_items.request_items[1].name, "", "malformed saved request becomes unselected")

local non_fuel = State.ensure_player(16)
equal(non_fuel.refill_fuel, "solid-fuel", "saved non-fuel falls back to the valid default")

local legacy_stacker = State.ensure_player(17)
equal(legacy_stacker.double_headed, true, "legacy station double-headed choice is preserved")
equal(legacy_stacker.stacker_double_headed, false, "legacy stacker defaults safely to single-headed sizing")

local malformed_stacker = State.ensure_player(18)
equal(malformed_stacker.stacker_double_headed, false, "malformed stacker headedness normalizes safely")

local solid_fuel = prototypes.item["solid-fuel"]
prototypes.item["solid-fuel"] = nil
storage.players[14] = { refill_fuel = "removed-fuel-without-default" }
equal(State.ensure_player(14).refill_fuel, nil, "removed fuel stays unselected when the default is unavailable")
prototypes.item["solid-fuel"] = solid_fuel

prototypes.entity["modded-loader"] = { type = "loader-1x1" }

local function gui_element(spec, parent)
    if spec.type == "choose-elem-button" and spec.elem_type == "entity" then
        if spec.entity == "" then error("GUI received an empty entity prototype name", 2) end
        if spec.entity ~= nil and not prototypes.entity[spec.entity] then
            error("GUI received an unknown entity prototype name: " .. tostring(spec.entity), 2)
        end
    end
    if spec.type == "choose-elem-button" and spec.elem_type == "item" then
        if spec.item == "" then error("GUI received an empty item prototype name", 2) end
        if spec.item ~= nil and not prototypes.item[spec.item] then
            error("GUI received an unknown item prototype name: " .. tostring(spec.item), 2)
        end
    end

    local element = {
        valid = true,
        visible = true,
        children = {},
        style = {},
        parent = parent,
    }
    for key, value in pairs(spec or {}) do
        if key == "style" then
            element.style_name = value
        else
            element[key] = value
        end
    end
    if spec.type == "choose-elem-button" then
        element.elem_value = spec.entity or spec.item
    end

    element.add = function(child_spec)
        local child = gui_element(child_spec, element)
        element.children[#element.children + 1] = child
        if child.name then element[child.name] = child end
        return child
    end
    element.destroy = function()
        element.valid = false
        if element.parent then
            if element.name then element.parent[element.name] = nil end
            for index, child in ipairs(element.parent.children) do
                if child == element then
                    table.remove(element.parent.children, index)
                    break
                end
            end
        end
    end
    element.force_auto_center = function() end
    return element
end

local function find_gui_element(root, name)
    if root.name == name then return root end
    for _, child in ipairs(root.children or {}) do
        local found = find_gui_element(child, name)
        if found then return found end
    end
end

local Constants = require("scripts.constants")
local Gui = require("scripts.gui")

local function gui_player(index)
    local cursor = { valid = true }
    cursor.set_stack = function() return true end
    cursor.set_blueprint_entities = function(entities) cursor.entities = entities end
    local player = {
        index = index,
        gui = { screen = gui_element({ name = "screen" }) },
        mod_settings = {},
        force = {
            inserter_stack_size_bonus = 0,
            bulk_inserter_capacity_bonus = 0,
        },
        cursor_stack = cursor,
    }
    player.clear_cursor = function() return true end
    return player
end

storage.players[7] = { chest_name = "removed-chest" }
local removed_player = gui_player(7)
Gui.open(removed_player)
local removed_chest_picker = find_gui_element(removed_player.gui.screen, Constants.gui.chest)
equal(removed_chest_picker.entity, nil, "GUI opens a removed saved entity as unselected")

storage.players[5] = {
    transfer_mode = "loaders",
    loader_name = "modded-loader",
    inserter_name = "modded-inserter",
}
local modded_player = gui_player(5)
Gui.open(modded_player)
local modded_loader_picker = find_gui_element(modded_player.gui.screen, Constants.gui.loader)
equal(modded_loader_picker.entity, "modded-loader", "GUI preserves a valid modded loader")

storage.players[6] = { transfer_mode = "loaders", loader_name = "" }
local recovered_player = gui_player(6)
Gui.open(recovered_player)
local recovered_loader_picker = find_gui_element(recovered_player.gui.screen, Constants.gui.loader)
equal(recovered_loader_picker.entity, nil, "GUI opens an empty saved loader as unselected")
local recovered_settings = Gui.read_settings(recovered_player)
equal(recovered_settings.loader_name, nil, "GUI reader keeps an unselected loader nil")
equal(recovered_settings.transfer_mode, "inserters", "GUI reflects recovered inserter mode")

storage.players[19] = {
    station_type = "stacker",
    double_headed = true,
}
local stacker_player = gui_player(19)
Gui.open(stacker_player)
local station_double = find_gui_element(stacker_player.gui.screen, Constants.gui.double_headed)
local stacker_double = find_gui_element(stacker_player.gui.screen, Constants.gui.stacker_double_headed)
local stacker_group = find_gui_element(stacker_player.gui.screen, Constants.gui.stacker_group)
equal(station_double.visible, false, "stacker hides the station double-headed option")
equal(stacker_double.visible, true, "stacker double-headed sizing option is visible")
equal(stacker_group.visible, true, "stacker sizing group is visible")
equal(stacker_double.state, false, "legacy stacker GUI opens single-headed")

stacker_double.state = true
Gui.update_summary(stacker_player)
local stacker_read = Gui.read_settings(stacker_player)
equal(stacker_read.double_headed, true, "stacker read does not corrupt the station headedness")
equal(stacker_read.stacker_double_headed, true, "stacker reads its explicit double-headed choice")
local stacker_summary = find_gui_element(stacker_player.gui.screen, Constants.gui.summary_label)
equal(stacker_summary.caption[7][1], "railwright.train-double-headed",
    "stacker summary identifies double-headed sizing")

Gui.close(stacker_player)
Gui.open(stacker_player)
stacker_double = find_gui_element(stacker_player.gui.screen, Constants.gui.stacker_double_headed)
equal(stacker_double.state, true, "closing and reopening preserves stacker double-headed sizing")

local station_type = find_gui_element(stacker_player.gui.screen, Constants.gui.station_type)
station_double = find_gui_element(stacker_player.gui.screen, Constants.gui.double_headed)
station_type.selected_index = 1
Gui.update_visibility(stacker_player)
equal(station_double.visible, true, "station layout shows its own double-headed option")
equal(find_gui_element(stacker_player.gui.screen, Constants.gui.stacker_group).visible, false,
    "station layout hides stacker sizing controls")
station_double.state = false
local station_read = Gui.read_settings(stacker_player)
equal(station_read.double_headed, false, "station reads its own single-headed choice")
equal(station_read.stacker_double_headed, true, "station switch preserves stacker double-headed choice")

station_type.selected_index = 5
Gui.update_visibility(stacker_player)
local switched_stacker_read = Gui.read_settings(stacker_player)
equal(switched_stacker_read.double_headed, false, "station headedness does not leak when switching to stacker")
equal(switched_stacker_read.stacker_double_headed, true,
    "stacker headedness survives station-to-stacker switching")

modded_loader_picker.elem_value = nil
local transfer_mode = find_gui_element(modded_player.gui.screen, Constants.gui.transfer_mode)
transfer_mode.selected_index = 1
local cleared_settings = Gui.read_settings(modded_player)
equal(cleared_settings.loader_name, nil, "cleared loader picker reads as nil")
State.set_player(modded_player.index, cleared_settings)
Gui.close(modded_player)
Gui.open(modded_player)
local reopened_loader_picker = find_gui_element(modded_player.gui.screen, Constants.gui.loader)
equal(reopened_loader_picker.entity, nil, "GUI reopens safely after a loader selection is cleared")

local unknown_item_ok = pcall(gui_element, {
    type = "choose-elem-button",
    elem_type = "item",
    item = "removed-item",
})
equal(unknown_item_ok, false, "GUI mock rejects unknown item prototype names")

local hidden_stale_player = gui_player(11)
Gui.open(hidden_stale_player)
equal(
    find_gui_element(hidden_stale_player.gui.screen, Constants.gui.filter_item_prefix .. 1).item,
    nil,
    "GUI opens a hidden stale filter as unselected"
)
equal(
    find_gui_element(hidden_stale_player.gui.screen, Constants.gui.request_item_prefix .. 1).item,
    nil,
    "GUI opens a hidden stale request as unselected"
)
equal(
    find_gui_element(hidden_stale_player.gui.screen, Constants.gui.refill_fuel).item,
    "solid-fuel",
    "GUI opens a disabled stale fuel with the recovered default"
)

local non_fuel_player = gui_player(16)
Gui.open(non_fuel_player)
equal(
    find_gui_element(non_fuel_player.gui.screen, Constants.gui.refill_fuel).item,
    "solid-fuel",
    "GUI opens safely after a saved non-fuel selection is recovered"
)

local modded_item_player = gui_player(12)
Gui.open(modded_item_player)
local modded_filter_picker = find_gui_element(
    modded_item_player.gui.screen,
    Constants.gui.filter_item_prefix .. 1
)
local modded_request_picker = find_gui_element(
    modded_item_player.gui.screen,
    Constants.gui.request_item_prefix .. 1
)
local modded_fuel_picker = find_gui_element(modded_item_player.gui.screen, Constants.gui.refill_fuel)
equal(modded_filter_picker.item, "modded-item", "GUI preserves a valid modded filter item")
equal(modded_request_picker.item, "modded-item", "GUI preserves a valid modded request item")
equal(modded_fuel_picker.item, "modded-fuel", "GUI preserves a valid modded refuelling fuel")
equal(modded_fuel_picker.elem_filters[1].filter, "fuel-category", "fuel picker uses a category filter")
equal(
    modded_fuel_picker.elem_filters[1]["fuel-category"],
    "chemical",
    "fuel picker derives the locomotive's accepted category"
)

modded_filter_picker.elem_value = nil
modded_request_picker.elem_value = nil
modded_fuel_picker.elem_value = nil
find_gui_element(modded_item_player.gui.screen, Constants.gui.refill_enabled).state = false
Gui.update_visibility(modded_item_player)
local cleared_item_settings = Gui.read_settings(modded_item_player)
equal(cleared_item_settings.filter_items[1], "", "cleared filter picker reads as unselected")
equal(cleared_item_settings.request_items[1].name, "", "cleared request picker reads as unselected")
equal(cleared_item_settings.refill_fuel, nil, "cleared refuelling picker reads as unselected")
State.set_player(modded_item_player.index, cleared_item_settings)
Gui.close(modded_item_player)
Gui.open(modded_item_player)
equal(
    find_gui_element(modded_item_player.gui.screen, Constants.gui.filter_item_prefix .. 1).item,
    nil,
    "cleared filter remains unselected after reopening"
)
equal(
    find_gui_element(modded_item_player.gui.screen, Constants.gui.request_item_prefix .. 1).item,
    nil,
    "cleared request remains unselected after reopening"
)
equal(
    find_gui_element(modded_item_player.gui.screen, Constants.gui.refill_fuel).item,
    "solid-fuel",
    "cleared refuelling fuel recovers to the valid default after reopening"
)

local Generator = require("scripts.generator")
local invalid_settings = State.defaults()
invalid_settings.chest_name = nil
local call_ok, generated, message = pcall(Generator.generate_into_cursor, {}, invalid_settings)
equal(call_ok, true, "missing required entity is handled without a runtime error")
equal(generated, false, "missing required entity prevents blueprint generation")
equal(message, "Chest is not selected.", "missing required entity has a readable error")

local hidden_numeric_cases = {
    {
        field = "chest_limit",
        element = Constants.gui.chest_limit,
        saved = 7,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 3
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 1
        end,
    },
    {
        field = "tank_columns",
        element = Constants.gui.tank_columns,
        saved = 3,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 1
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 3
        end,
    },
    {
        field = "refill_amount",
        element = Constants.gui.refill_amount,
        saved = 40,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.refill_enabled).state = false
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.refill_enabled).state = true
        end,
    },
    {
        field = "train_limit_stack_size",
        element = Constants.gui.train_limit_stack_size,
        saved = 100,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.train_limit).selected_index = 1
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.train_limit).selected_index = 2
        end,
    },
    {
        field = "enabled_amount",
        element = Constants.gui.enabled_amount,
        saved = 8000,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.enabled_condition).state = false
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.enabled_condition).state = true
        end,
    },
    {
        field = "stacker_lanes",
        element = Constants.gui.stacker_lanes,
        saved = 5,
        hide = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 1
        end,
        activate = function(player)
            find_gui_element(player.gui.screen, Constants.gui.station_type).selected_index = 5
        end,
    },
}

for index, case in ipairs(hidden_numeric_cases) do
    local player_index = 100 + index
    storage.players[player_index] = { [case.field] = case.saved }
    local player = gui_player(player_index)
    Gui.open(player)
    case.hide(player)
    Gui.update_visibility(player)

    find_gui_element(player.gui.screen, case.element).text = ""
    Gui.update_summary(player)
    local inactive_settings, inactive_error = Gui.read_settings(player)
    equal(inactive_settings ~= nil, true, case.field .. " is ignored while inactive: " .. tostring(inactive_error))
    equal(inactive_settings[case.field], case.saved, case.field .. " preserves its last valid saved value")
    equal(
        find_gui_element(player.gui.screen, Constants.gui.generate_button).enabled,
        true,
        case.field .. " keeps Create enabled while inactive and invalid"
    )

    local generated_ok, entity_count = Generator.generate_into_cursor(player, inactive_settings)
    equal(generated_ok, true, case.field .. " does not block unrelated blueprint generation: " .. tostring(entity_count))

    case.activate(player)
    Gui.update_visibility(player)
    local active_settings, active_error = Gui.read_settings(player)
    equal(active_settings, nil, case.field .. " is rejected when active")
    equal(type(active_error), "string", case.field .. " returns a readable active validation error")
    equal(
        find_gui_element(player.gui.screen, Constants.gui.generate_button).enabled,
        false,
        case.field .. " disables Create while active and invalid"
    )
end

local direct_numeric_cases = {
    { field = "chest_limit", inactive = { station_type = "fluid-loading" }, active = { station_type = "loading" } },
    { field = "tank_columns", inactive = { station_type = "loading" }, active = { station_type = "fluid-loading" } },
    { field = "refill_amount", inactive = { refill_enabled = false }, active = { refill_enabled = true } },
    { field = "train_limit_stack_size", inactive = { train_limit = "Disabled" }, active = { train_limit = "Dynamic" } },
    { field = "enabled_amount", inactive = { enabled_condition = false }, active = { enabled_condition = true } },
    { field = "stacker_lanes", inactive = { station_type = "loading" }, active = { station_type = "stacker" } },
}

local function settings_with(overrides)
    local settings = State.defaults()
    for key, value in pairs(overrides) do settings[key] = value end
    return settings
end

for _, case in ipairs(direct_numeric_cases) do
    local inactive_settings = settings_with(case.inactive)
    inactive_settings[case.field] = nil
    local inactive_call_ok, inactive_valid = pcall(Generator.validate_settings, inactive_settings)
    equal(inactive_call_ok, true, case.field .. " inactive direct validation does not crash")
    equal(inactive_valid, true, case.field .. " inactive direct validation succeeds")

    local active_settings = settings_with(case.active)
    active_settings[case.field] = nil
    local active_call_ok, active_valid, active_message = pcall(Generator.validate_settings, active_settings)
    equal(active_call_ok, true, case.field .. " active direct validation does not crash")
    equal(active_valid, false, case.field .. " active direct validation fails")
    equal(type(active_message), "string", case.field .. " active direct validation is readable")
end

for _, fuel_name in ipairs({ "coal", "solid-fuel", "modded-fuel" }) do
    local fuel_settings = State.defaults()
    fuel_settings.refill_fuel = fuel_name
    local fuel_ok, fuel_message = Generator.validate_settings(fuel_settings)
    equal(fuel_ok, true, fuel_name .. " is accepted as locomotive fuel: " .. tostring(fuel_message))
end

for _, fuel_name in ipairs({ "iron-plate", "nuclear-fuel-cell" }) do
    local fuel_settings = State.defaults()
    fuel_settings.refill_fuel = fuel_name
    local fuel_ok, fuel_message = Generator.validate_settings(fuel_settings)
    equal(fuel_ok, false, fuel_name .. " is rejected as locomotive fuel")
    equal(type(fuel_message), "string", fuel_name .. " fuel rejection is readable")
end

local unselected_fuel_settings = State.defaults()
unselected_fuel_settings.refill_fuel = nil
local unselected_fuel_ok, unselected_fuel_message = Generator.validate_settings(unselected_fuel_settings)
equal(unselected_fuel_ok, false, "active refuelling rejects an unselected fuel")
equal(type(unselected_fuel_message), "string", "unselected active fuel has a readable validation message")

local burner_prototype = prototypes.entity.locomotive.burner_prototype
local no_burner_settings = State.defaults()
prototypes.entity.locomotive.burner_prototype = nil
local no_burner_ok, no_burner_message = Generator.validate_settings(no_burner_settings)
equal(no_burner_ok, false, "refuelling fails safely when the locomotive has no burner")
equal(type(no_burner_message), "string", "missing locomotive burner has a readable validation message")
prototypes.entity.locomotive.burner_prototype = burner_prototype

local fuel_categories = burner_prototype.fuel_categories
local no_compatible_fuel_settings = State.defaults()
burner_prototype.fuel_categories = { unavailable_category = true }
local no_compatible_ok, no_compatible_message = Generator.validate_settings(no_compatible_fuel_settings)
equal(no_compatible_ok, false, "refuelling fails safely when no compatible fuel exists")
equal(type(no_compatible_message), "string", "missing compatible fuel has a readable validation message")
burner_prototype.fuel_categories = fuel_categories

print("GUI and saved-state tests passed")
