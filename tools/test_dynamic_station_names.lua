-- Focused non-Factorio regression checks for dynamic naming decisions, marker
-- lifecycle state, blueprint tags, and generated marker wiring.
package.path = "./?.lua;./?/init.lua;" .. package.path

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

do
    local setting_prototypes
    data = {
        extend = function(_, prototypes_to_add) setting_prototypes = prototypes_to_add end,
    }
    dofile("settings.lua")
    data = nil

    local experimental
    for _, prototype in ipairs(setting_prototypes or {}) do
        if prototype.name == "railwright-enable-experimental-dynamic-station-names" then
            experimental = prototype
        end
    end
    equal(experimental and experimental.type, "bool-setting", "experimental setting type")
    equal(experimental and experimental.setting_type, "runtime-per-user", "experimental setting scope")
    equal(experimental and experimental.default_value, false, "experimental setting defaults off")
end

defines = {
    direction = {
        north = 0,
        east = 4,
        south = 8,
        west = 12,
    },
    inventory = {
        cargo_wagon = 1,
        chest = 2,
    },
    wire_connector_id = {
        circuit_red = 1,
        circuit_green = 2,
        combinator_input_red = 3,
        combinator_input_green = 4,
        combinator_output_red = 5,
        combinator_output_green = 6,
    },
}

storage = {}
local entities_by_unit = {}
game = {
    get_entity_by_unit_number = function(unit_number) return entities_by_unit[unit_number] end,
    surfaces = {},
}

local function stop(unit_number, name)
    local entity = {
        valid = true,
        name = "train-stop",
        type = "train-stop",
        unit_number = unit_number,
        backer_name = name,
        position = { x = 1, y = -1.5 },
    }
    entities_by_unit[unit_number] = entity
    return entity
end

local function marker(unit_number, connected_stops)
    local output = { valid = true, real_connections = {} }
    for _, train_stop in ipairs(connected_stops or {}) do
        output.real_connections[#output.real_connections + 1] = {
            target = { valid = true, owner = train_stop },
        }
    end

    local entity = {
        valid = true,
        name = "railwright-station-name-combinator",
        type = "decider-combinator",
        unit_number = unit_number,
        surface = { index = 1 },
        position = { x = 2.5, y = 1.5 },
        signals = {},
        output = output,
    }
    entity.get_wire_connector = function(connector_id)
        if connector_id == defines.wire_connector_id.combinator_output_red then return entity.output end
    end
    entity.get_signals = function(red_id, green_id)
        equal(red_id, defines.wire_connector_id.combinator_input_red, "runtime reads input red")
        equal(green_id, defines.wire_connector_id.combinator_input_green, "runtime reads input green")
        return entity.signals
    end
    entities_by_unit[unit_number] = entity
    return entity
end

local function signal(signal_type, name, count)
    return { signal = { type = signal_type, name = name }, count = count }
end

local DynamicStationNames = require("scripts.dynamic_station_names")
local main_stop = stop(100, "Load")
local main_marker = marker(10, { main_stop })
local tags = {
    railwright_dynamic_station_name = true,
    railwright_dynamic_name_schema = 1,
    railwright_base_name = "Load",
    railwright_station_type = "loading",
}

DynamicStationNames.on_built({ entity = main_marker, tags = tags })
main_marker.signals = { { signal = { name = "iron-ore" }, count = 100 } }
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=iron-ore] Load", "single item signal")

main_marker.signals = { signal("item", "copper-plate", 50) }
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=copper-plate] Load", "resource signal change")

main_marker.signals = {}
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=copper-plate] Load", "zero signal preserves last name")

main_marker.signals = {
    signal("item", "iron-ore", 10),
    signal("fluid", "crude-oil", 10),
}
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=copper-plate] Load", "ambiguous resources preserve last name")

main_marker.signals = {
    signal("item", "iron-ore", 10),
    signal("item", "iron-ore", 20),
    signal("virtual", "signal-L", 100),
}
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=iron-ore] Load", "duplicate resource is de-duplicated")

main_stop.backer_name = "Manual edit"
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=iron-ore] Load", "valid input restores managed name")

main_marker.signals = { signal("item", "iron-ore", -1), signal("virtual", "signal-red", 1) }
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=iron-ore] Load", "negative and virtual signals are ignored")

local empty_stop = stop(101, "Railwright Station")
local empty_marker = marker(11, { empty_stop })
DynamicStationNames.on_built({
    entity = empty_marker,
    tags = {
        railwright_dynamic_station_name = true,
        railwright_dynamic_name_schema = 1,
        railwright_base_name = "",
        railwright_station_type = "fluid-loading",
    },
})
empty_marker.signals = { signal("fluid", "petroleum-gas", 1) }
DynamicStationNames.on_nth_tick()
equal(empty_stop.backer_name, "[fluid=petroleum-gas]", "empty base has no trailing space")

local second_stop = stop(102, "Other")
main_marker.output.real_connections[#main_marker.output.real_connections + 1] = {
    target = { valid = true, owner = second_stop },
}
main_stop.backer_name = "Ambiguous association"
main_marker.signals = { signal("item", "iron-ore", 1) }
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "Ambiguous association", "two stops disable naming")
equal(storage.dynamic_station_names.registrations[10].stop_unit_number, nil, "ambiguous stop is pending")

main_marker.output.real_connections = {}
DynamicStationNames.on_nth_tick()
equal(storage.dynamic_station_names.registrations[10].stop_unit_number, nil, "disconnected stop is pending")
main_marker.output.real_connections = { { target = { valid = true, owner = main_stop } } }
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "[item=iron-ore] Load", "reconnected stop recovers")

local blueprint_tags
local blueprint = {
    valid_for_read = true,
    set_blueprint_entity_tags = function(index, value)
        equal(index, 1, "blueprint marker index")
        blueprint_tags = value
    end,
}
DynamicStationNames.on_player_setup_blueprint({
    stack = blueprint,
    mapping = {
        valid = true,
        get = function() return { [1] = main_marker } end,
    },
})
equal(blueprint_tags.railwright_base_name, "Load", "rebuilt blueprint keeps base name")
equal(blueprint_tags.railwright_station_type, "loading", "rebuilt blueprint keeps station type")

DynamicStationNames.on_removed({ entity = main_marker })
equal(storage.dynamic_station_names.registrations[10], nil, "mined marker removes registration")
main_stop.backer_name = "Unmanaged"
DynamicStationNames.on_nth_tick()
equal(main_stop.backer_name, "Unmanaged", "removed marker stops management")

local manual_stop = stop(103, "Manual base")
local manual_marker = marker(12, { manual_stop })
manual_marker.signals = { signal("fluid", "crude-oil", 1) }
DynamicStationNames.on_built({ entity = manual_marker })
DynamicStationNames.on_nth_tick()
equal(manual_stop.backer_name, "[fluid=crude-oil] Manual base", "manual marker uses stop name as base")
DynamicStationNames.on_removed({ entity = manual_stop })
manual_marker.output.real_connections = {}
manual_stop.valid = false
DynamicStationNames.on_nth_tick()
equal(storage.dynamic_station_names.registrations[12].stop_unit_number, nil, "destroyed stop leaves marker pending")

local State = require("scripts.state")
storage.players = { [1] = { station_name = "Migrated" } }
equal(State.ensure_player(1).dynamic_station_name, false, "existing player migrates to disabled")
equal(State.defaults().dynamic_station_name, false, "new player defaults to disabled")

-- Generator checks use the real builder and common station-behavior module.
local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")
local station_types = { "loading", "unloading", "fluid-loading", "fluid-unloading" }
for _, station_type in ipairs(station_types) do
    local builder = Builder.new()
    local source = builder:add("storage", station_type:find("fluid", 1, true) and -5.5 or 1.5, 7)
    local train_stop = builder:add("train-stop", 1, -1.5)
    Common.add_station_behaviors(builder, {
        dynamic_station_name = true,
        station_name = "Base",
        station_type = station_type,
        enabled_condition = false,
        train_limit = "Disabled",
    }, source, train_stop, 1, 1, 1, station_type:find("fluid", 1, true) ~= nil)

    equal(#builder.entities, 3, station_type .. " has exactly one marker")
    local generated_marker = builder.entities[3]
    equal(generated_marker.name, "railwright-station-name-combinator", station_type .. " marker prototype")
    equal(generated_marker.tags.railwright_base_name, "Base", station_type .. " marker base tag")
    equal(generated_marker.tags.railwright_station_type, station_type, station_type .. " marker type tag")
    equal(source.wires[1][2], defines.wire_connector_id.circuit_green, station_type .. " source wire color")
    equal(source.wires[1][4], defines.wire_connector_id.combinator_input_green, station_type .. " input connector")
    equal(generated_marker.wires[1][2], defines.wire_connector_id.combinator_output_red, station_type .. " output connector")
    equal(generated_marker.wires[1][4], defines.wire_connector_id.circuit_red, station_type .. " stop connector")
end

local disabled_builder = Builder.new()
local disabled_source = disabled_builder:add("storage", 1.5, 7)
local disabled_stop = disabled_builder:add("train-stop", 1, -1.5)
Common.add_station_behaviors(disabled_builder, {
    dynamic_station_name = false,
    station_name = "Base",
    station_type = "loading",
    enabled_condition = false,
    train_limit = "Disabled",
}, disabled_source, disabled_stop, 1, 1, 1, false)
equal(#disabled_builder.entities, 2, "disabled dynamic naming adds nothing")

prototypes = {
    entity = {
        ["cargo-wagon"] = { get_inventory_size = function() return 40 end },
        ["steel-chest"] = { get_inventory_size = function() return 48 end },
    },
}
local coexist_builder = Builder.new()
local coexist_source = coexist_builder:add("storage", 1.5, 7)
local coexist_stop = coexist_builder:add("train-stop", 1, -1.5)
Common.add_station_behaviors(coexist_builder, {
    dynamic_station_name = true,
    station_name = "Load",
    station_type = "loading",
    enabled_condition = true,
    enabled_amount = 100,
    enabled_operator = ">",
    train_limit = "Dynamic",
    train_limit_one = true,
    train_limit_stack_size = 50,
    cargo_wagons = 2,
    chest_name = "steel-chest",
}, coexist_source, coexist_stop, 12, 12, 48, false)
equal(#coexist_builder.entities, 6, "enable, train-limit, and naming combinators coexist")
local coexist_marker = coexist_builder.entities[6]
equal(coexist_marker.position.x, 2.5, "right-side marker position")
equal(coexist_marker.position.y, 1.5, "marker vertical position")

local left_builder = Builder.new()
local left_source = left_builder:add("storage", -2.5, 7)
local left_stop = left_builder:add("train-stop", 1, -1.5)
Common.add_station_behaviors(left_builder, {
    dynamic_station_name = true,
    station_name = "Unload",
    station_type = "unloading",
    enabled_condition = false,
    train_limit = "Disabled",
}, left_source, left_stop, 1, 1, 1, false)
equal(left_builder.entities[3].position.x, -4.5, "left-side marker position")

-- Data-stage checks verify the Railwright prototypes are deep copies and that
-- the normal circuit-network technology owns the recipe unlock.
local function deep_copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[deep_copy(key)] = deep_copy(child) end
    return result
end
table.deepcopy = deep_copy

local vanilla_entity = {
    type = "decider-combinator",
    name = "decider-combinator",
    minable = { result = "decider-combinator" },
    animation = { filename = "__base__/graphics/entity/decider-combinator.png" },
    collision_box = { { -0.35, -0.65 }, { 0.35, 0.65 } },
}
local vanilla_item = {
    type = "item",
    name = "decider-combinator",
    place_result = "decider-combinator",
    icon = "__base__/graphics/icons/decider-combinator.png",
}
local vanilla_recipe = {
    type = "recipe",
    name = "decider-combinator",
    enabled = false,
    ingredients = { { type = "item", name = "electronic-circuit", amount = 5 } },
    results = { { type = "item", name = "decider-combinator", amount = 1 } },
}
data = {
    raw = {
        ["decider-combinator"] = { ["decider-combinator"] = vanilla_entity },
        item = { ["decider-combinator"] = vanilla_item },
        recipe = { ["decider-combinator"] = vanilla_recipe },
        technology = { ["circuit-network"] = { effects = {} } },
    },
}
data.extend = function(_, prototypes_to_add)
    for _, prototype in ipairs(prototypes_to_add) do
        data.raw[prototype.type] = data.raw[prototype.type] or {}
        data.raw[prototype.type][prototype.name] = prototype
    end
end

dofile("prototypes/station-name-combinator.lua")
local custom_name = "railwright-station-name-combinator"
local custom_entity = data.raw["decider-combinator"][custom_name]
local custom_item = data.raw.item[custom_name]
local custom_recipe = data.raw.recipe[custom_name]
equal(custom_entity.minable.result, custom_name, "custom entity mining result")
equal(custom_entity.flags[1], "get-by-unit-number", "custom entity supports unit lookup")
equal(custom_item.place_result, custom_name, "custom item placement result")
equal(custom_recipe.enabled, false, "custom recipe requires technology")
equal(custom_recipe.results[1].name, custom_name, "custom recipe result")
equal(custom_recipe.ingredients[1].name, "electronic-circuit", "custom recipe keeps circuit ingredients")
equal(data.raw.technology["circuit-network"].effects[1].recipe, custom_name, "circuit technology unlock")
equal(custom_entity.animation.filename:sub(1, 8), "__base__", "entity reuses vanilla graphics")
equal(custom_item.icon:sub(1, 8), "__base__", "item reuses vanilla icon")
equal(vanilla_entity.minable.result, "decider-combinator", "vanilla entity remains unchanged")
equal(vanilla_recipe.results[1].name, "decider-combinator", "vanilla recipe remains unchanged")

print("Dynamic station-name tests passed")
