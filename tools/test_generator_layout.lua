-- Generator-level regression checks for station entity counts, footprints,
-- transport directions, copper power wires, and Madzuri circuit topology.
package.path = "./?.lua;./?/init.lua;" .. package.path

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

local function truthy(value, message)
    if not value then error(message, 2) end
end

defines = {
    direction = { north = 0, east = 4, south = 8, west = 12 },
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
        ["steel-chest"] = { type = "container", get_inventory_size = inventory_size },
        ["cargo-wagon"] = { get_inventory_size = wagon_inventory_size },
        ["fluid-wagon"] = { get_fluid_capacity = tank_capacity },
        ["storage-tank"] = { type = "storage-tank", get_fluid_capacity = tank_capacity },
    },
}

local Normal = require("scripts.generator_normal")
local Fluid = require("scripts.generator_fluid")
local Builder = require("scripts.generator_builder")

do
    local builder = Builder.new()
    local first = builder:add("medium-electric-pole", 0, 0)
    local second = builder:add("medium-electric-pole", 0, 7)
    builder:connect_copper(first, second)
    builder:connect_copper(first, second)
    builder:connect_copper(second, first)
    equal(#first.wires, 1, "builder de-duplicates copper wires")
    equal(first.wires[1][2], defines.wire_connector_id.pole_copper, "builder copper source connector")
    equal(first.wires[1][4], defines.wire_connector_id.pole_copper, "builder copper target connector")
end

local function item_settings(station_type, sides, overrides)
    local settings = {
        station_type = station_type,
        station_name = "Layout test",
        dynamic_station_name = false,
        locomotives = 1,
        cargo_wagons = 3,
        double_headed = true,
        include_train = false,
        sides = sides,
        transfer_mode = "inserters",
        inserter_name = "fast-inserter",
        loader_name = "test-loader",
        chest_name = "steel-chest",
        belt_name = "test-transport-belt",
        splitter_name = "test-splitter",
        belt_flow = "front",
        filter_enabled = false,
        filter_items = {},
        chest_limit = 0,
        request_items = {},
        request_from_buffers = false,
        madzuri = true,
        connect_green = true,
        connect_both_green = true,
        connect_red = true,
        connect_both_red = true,
        refill_enabled = true,
        refill_fuel = "solid-fuel",
        refill_amount = 20,
        train_limit = "Disabled",
        train_limit_one = true,
        train_limit_stack_size = 50,
        enabled_condition = false,
        enabled_operator = ">",
        enabled_amount = 100,
        lamps = false,
    }
    for key, value in pairs(overrides or {}) do settings[key] = value end
    return settings
end

local function fluid_settings(station_type, pump_side, overrides)
    local settings = {
        station_type = station_type,
        station_name = "Fluid layout test",
        dynamic_station_name = false,
        locomotives = 1,
        cargo_wagons = 3,
        double_headed = true,
        include_train = false,
        pump_side = pump_side,
        pump_name = "pump",
        storage_tank_name = "storage-tank",
        pipe_name = "pipe",
        tank_columns = 1,
        connect_pipes = true,
        connect_green = true,
        connect_red = true,
        refill_enabled = true,
        refill_fuel = "solid-fuel",
        refill_amount = 20,
        train_limit = "Disabled",
        train_limit_one = true,
        train_limit_stack_size = 50,
        enabled_condition = false,
        enabled_operator = ">",
        enabled_amount = 100,
        lamps = false,
    }
    for key, value in pairs(overrides or {}) do settings[key] = value end
    return settings
end

local function entities_named(entities, name)
    local result = {}
    for _, entity in ipairs(entities) do
        if entity.name == name then result[#result + 1] = entity end
    end
    return result
end

local function entity_at(entities, name, x, y)
    for _, entity in ipairs(entities) do
        if entity.name == name and entity.position.x == x and entity.position.y == y then
            return entity
        end
    end
end

local function all_wires(entities)
    local wires = {}
    for _, entity in ipairs(entities) do
        for _, wire in ipairs(entity.wires or {}) do wires[#wires + 1] = wire end
    end
    return wires
end

local function has_wire(entities, entity_a, connector_a, entity_b, connector_b)
    for _, wire in ipairs(all_wires(entities)) do
        local forward = wire[1] == entity_a.entity_number
            and wire[2] == connector_a
            and wire[3] == entity_b.entity_number
            and wire[4] == connector_b
        local reverse = wire[1] == entity_b.entity_number
            and wire[2] == connector_b
            and wire[3] == entity_a.entity_number
            and wire[4] == connector_a
        if forward or reverse then return true end
    end
    return false
end

local function copper_edges(entities)
    local edges = {}
    for _, wire in ipairs(all_wires(entities)) do
        if wire[2] == defines.wire_connector_id.pole_copper
            and wire[4] == defines.wire_connector_id.pole_copper then
            local low = math.min(wire[1], wire[3])
            local high = math.max(wire[1], wire[3])
            edges[#edges + 1] = low .. ":" .. high
        end
    end
    return edges
end

local function assert_pole_chain(entities, expected_sides, label)
    local poles = entities_named(entities, "medium-electric-pole")
    local by_x = {}
    for _, pole in ipairs(poles) do
        by_x[pole.position.x] = by_x[pole.position.x] or {}
        by_x[pole.position.x][#by_x[pole.position.x] + 1] = pole
    end

    local expected_links = 0
    for _, x in ipairs(expected_sides) do
        local line = by_x[x] or {}
        table.sort(line, function(a, b) return a.position.y < b.position.y end)
        equal(#line, 4, label .. " pole count at x=" .. x)
        expected_links = expected_links + #line - 1
        for index = 2, #line do
            truthy(has_wire(
                entities,
                line[index - 1],
                defines.wire_connector_id.pole_copper,
                line[index],
                defines.wire_connector_id.pole_copper
            ), label .. " missing consecutive copper wire")
        end
    end

    local edges = copper_edges(entities)
    equal(#edges, expected_links, label .. " copper-link count")
    local seen = {}
    for _, edge in ipairs(edges) do
        truthy(not seen[edge], label .. " duplicate copper link " .. edge)
        seen[edge] = true
    end
end

local function is_madzuri(entity)
    local conditions = entity.control_behavior and entity.control_behavior.arithmetic_conditions
    return entity.name == "arithmetic-combinator"
        and conditions
        and conditions.operation == "/"
        and conditions.first_signal
        and conditions.first_signal.name == "signal-each"
        and conditions.second_constant < 0
end

local function madzuri_entities(entities)
    local result = {}
    for _, entity in ipairs(entities) do
        if is_madzuri(entity) then result[#result + 1] = entity end
    end
    return result
end

local function footprint(entity)
    if entity.name == "arithmetic-combinator"
        or entity.name == "decider-combinator"
        or entity.name == "railwright-station-name-combinator" then
        if entity.direction == defines.direction.east or entity.direction == defines.direction.west then
            return 2, 1
        end
        return 1, 2
    end
    if entity.name == "test-splitter" then
        if entity.direction == defines.direction.east or entity.direction == defines.direction.west then
            return 1, 2
        end
        return 2, 1
    end
    if entity.name == "storage-tank" then return 3, 3 end
    if entity.name == "straight-rail" then return 2, 2 end
    if entity.name == "train-stop" then return 2, 2 end
    if entity.name == "locomotive" or entity.name == "cargo-wagon" or entity.name == "fluid-wagon" then
        return 2, 6
    end
    return 1, 1
end

local function overlaps(entity_a, entity_b)
    local width_a, height_a = footprint(entity_a)
    local width_b, height_b = footprint(entity_b)
    return math.abs(entity_a.position.x - entity_b.position.x) < (width_a + width_b) / 2
        and math.abs(entity_a.position.y - entity_b.position.y) < (height_a + height_b) / 2
end

local function assert_no_madzuri_collisions(entities, label)
    for _, arithmetic in ipairs(madzuri_entities(entities)) do
        for _, other in ipairs(entities) do
            if other ~= arithmetic then
                truthy(not overlaps(arithmetic, other), string.format(
                    "%s Madzuri at (%s,%s) overlaps %s at (%s,%s)",
                    label,
                    arithmetic.position.x,
                    arithmetic.position.y,
                    other.name,
                    other.position.x,
                    other.position.y
                ))
            end
        end

        local green_connections = 0
        for _, wire in ipairs(all_wires(entities)) do
            local other_number
            local arithmetic_connector
            if wire[1] == arithmetic.entity_number then
                arithmetic_connector = wire[2]
                other_number = wire[3]
            elseif wire[3] == arithmetic.entity_number then
                arithmetic_connector = wire[4]
                other_number = wire[1]
            end

            if other_number and (
                arithmetic_connector == defines.wire_connector_id.combinator_input_green
                or arithmetic_connector == defines.wire_connector_id.combinator_output_green
            ) then
                local other = entities[other_number]
                local dx = arithmetic.position.x - other.position.x
                local dy = arithmetic.position.y - other.position.y
                truthy(dx * dx + dy * dy <= 81, label .. " Madzuri anchor exceeds circuit-wire reach")
                green_connections = green_connections + 1
            end
        end
        equal(green_connections, 2, label .. " Madzuri green anchor count")
    end
end

local function assert_madzuri_geometry(entities, settings, label)
    local cargo_start = settings.locomotives * 7 - 3
    local expected_y = cargo_start + 0.5
    local expected = {}
    if settings.sides == "right" or settings.sides == "both" then
        expected[#expected + 1] = { x = 3.5, y = expected_y }
    end
    if settings.sides == "left" or settings.sides == "both" then
        expected[#expected + 1] = { x = -5.5, y = expected_y }
    end

    local arithmetic = madzuri_entities(entities)
    equal(#arithmetic, #expected, label .. " Madzuri geometry count")
    for _, position in ipairs(expected) do
        local entity = entity_at(entities, "arithmetic-combinator", position.x, position.y)
        truthy(entity, string.format(
            "%s missing station-aligned Madzuri at (%s,%s)",
            label,
            position.x,
            position.y
        ))
        truthy(is_madzuri(entity), label .. " expected arithmetic is not the Madzuri combinator")
        equal(entity.direction, defines.direction.north, label .. " Madzuri direction")
    end
end

local function side_geometry(side)
    if side == "right" then return 1.5, 2.5, 0.5 end
    return -3.5, -4.5, -2.5
end

local function assert_rows_and_wires(entities, settings, side)
    local chest_x, outer_x = side_geometry(side)
    local cargo_start = settings.locomotives * 7 - 3
    local rows = {}
    for wagon = 0, settings.cargo_wagons - 1 do
        for slot = 1, 6 do rows[#rows + 1] = cargo_start + wagon * 7 + slot + 1 end
    end

    local chests, outers = {}, {}
    for _, y in ipairs(rows) do
        local chest = entity_at(entities, settings.chest_name, chest_x, y)
        local outer = entity_at(entities, settings.inserter_name, outer_x, y)
        truthy(chest, string.format("%s %s missing chest row y=%s", settings.station_type, side, y))
        truthy(outer, string.format("%s %s missing outer inserter row y=%s", settings.station_type, side, y))
        chests[#chests + 1] = chest
        outers[#outers + 1] = outer
        truthy(has_wire(
            entities,
            chest,
            defines.wire_connector_id.circuit_red,
            outer,
            defines.wire_connector_id.circuit_red
        ), settings.station_type .. " missing chest-to-outer red wire")
    end

    equal(#chests, 6 * settings.cargo_wagons, settings.station_type .. " " .. side .. " chest count")
    equal(#outers, 6 * settings.cargo_wagons, settings.station_type .. " " .. side .. " outer count")

    local affected = 6
    truthy(has_wire(
        entities,
        chests[affected - 1],
        defines.wire_connector_id.circuit_green,
        chests[affected],
        defines.wire_connector_id.circuit_green
    ), settings.station_type .. " affected chest missing green-chain wire")
    truthy(has_wire(
        entities,
        chests[affected - 1],
        defines.wire_connector_id.circuit_red,
        chests[affected],
        defines.wire_connector_id.circuit_red
    ), settings.station_type .. " affected chest missing red-chain wire")
    truthy(has_wire(
        entities,
        outers[affected - 1],
        defines.wire_connector_id.circuit_green,
        outers[affected],
        defines.wire_connector_id.circuit_green
    ), settings.station_type .. " affected outer missing green-chain wire")
end

local function mirror_x(x) return -x - 2 end

local function assert_collector_directions(settings, right_side)
    local entities = Normal.generate(settings)
    local splitters = {}
    for _, splitter in ipairs(entities_named(entities, settings.splitter_name)) do
        if (right_side and splitter.position.x > 0)
            or ((not right_side) and splitter.position.x < 0) then
            splitters[#splitters + 1] = splitter
        end
    end
    table.sort(splitters, function(a, b) return a.position.y < b.position.y end)
    if settings.belt_flow == "back" then
        local reversed = {}
        for index = #splitters, 1, -1 do reversed[#reversed + 1] = splitters[index] end
        splitters = reversed
    end

    local loading = settings.station_type == "loading"
    local collector_direction
    if settings.belt_flow == "front" then
        collector_direction = loading and defines.direction.south or defines.direction.north
    else
        collector_direction = loading and defines.direction.north or defines.direction.south
    end
    local horizontal_direction
    if loading then
        horizontal_direction = right_side and defines.direction.west or defines.direction.east
    else
        horizontal_direction = right_side and defines.direction.east or defines.direction.west
    end

    local belt_positions = {}
    for _, belt in ipairs(entities_named(entities, settings.belt_name)) do
        local key = belt.position.x .. ":" .. belt.position.y
        truthy(not belt_positions[key], settings.station_type .. " duplicate belt at " .. key)
        belt_positions[key] = true
    end

    local anchor_y = splitters[1].position.y
    for index, splitter in ipairs(splitters) do
        local base_x = 5.5 + index - 1
        local collector_x = right_side and base_x or mirror_x(base_x)
        local step_y = splitter.position.y >= anchor_y and 1 or -1
        local y = anchor_y
        while (step_y > 0 and y <= splitter.position.y) or (step_y < 0 and y >= splitter.position.y) do
            if not loading or y ~= splitter.position.y then
                local collector = entity_at(entities, settings.belt_name, collector_x, y)
                truthy(collector, settings.station_type .. " missing collector belt")
                equal(collector.direction, collector_direction, settings.station_type .. " collector direction")
            end
            y = y + step_y
        end

        local branch_x = splitter.position.x + (right_side and 1 or -1)
        local function branch_has_tile()
            if right_side then return loading and branch_x <= collector_x or branch_x < collector_x end
            return loading and branch_x >= collector_x or branch_x > collector_x
        end
        while branch_has_tile() do
            local branch = entity_at(entities, settings.belt_name, branch_x, splitter.position.y)
            truthy(branch, settings.station_type .. " missing branch transition belt")
            equal(branch.direction, horizontal_direction, settings.station_type .. " branch transition direction")
            branch_x = branch_x + (right_side and 1 or -1)
        end
    end
end

-- Copper power networks cover every side and leave the existing circuit chains present.
for _, station_type in ipairs({ "loading", "unloading" }) do
    for _, sides in ipairs({ "right", "left", "both" }) do
        local settings = item_settings(station_type, sides)
        local entities = Normal.generate(settings)
        local pole_x = sides == "right" and { 0.5 }
            or sides == "left" and { -2.5 }
            or { 0.5, -2.5 }
        assert_pole_chain(entities, pole_x, station_type .. " " .. sides)
        if sides == "right" or sides == "both" then assert_rows_and_wires(entities, settings, "right") end
        if sides == "left" or sides == "both" then assert_rows_and_wires(entities, settings, "left") end
        equal(#madzuri_entities(entities), sides == "both" and 2 or 1, station_type .. " Madzuri count")
    end
end

for _, station_type in ipairs({ "fluid-loading", "fluid-unloading" }) do
    for _, side in ipairs({ "right", "left" }) do
        local settings = fluid_settings(station_type, side)
        local entities = Fluid.generate(settings)
        assert_pole_chain(entities, { side == "right" and 0.5 or -2.5 }, station_type .. " " .. side)
    end
end

-- Loading transition tiles feed into the collector; unloading retains its existing topology.
for _, station_type in ipairs({ "loading", "unloading" }) do
    for _, sides in ipairs({ "right", "left", "both" }) do
        for _, cargo_wagons in ipairs({ 1, 3, 5 }) do
            for _, belt_flow in ipairs({ "front", "back" }) do
                local settings = item_settings(station_type, sides, {
                    belt_flow = belt_flow,
                    cargo_wagons = cargo_wagons,
                    refill_enabled = false,
                    madzuri = false,
                })
                if sides == "right" or sides == "both" then
                    assert_collector_directions(settings, true)
                end
                if sides == "left" or sides == "both" then
                    assert_collector_directions(settings, false)
                end
            end
        end
    end
end

-- Exercise the safe Madzuri position across the relevant geometry and behavior matrix.
for _, station_type in ipairs({ "loading", "unloading" }) do
    for _, sides in ipairs({ "right", "left", "both" }) do
        for _, locomotives in ipairs({ 1, 2 }) do
            for _, lamps in ipairs({ false, true }) do
                for _, dynamic_name in ipairs({ false, true }) do
                    for _, behavior in ipairs({ "none", "combined" }) do
                        local settings = item_settings(station_type, sides, {
                            locomotives = locomotives,
                            cargo_wagons = behavior == "none" and 1 or 3,
                            lamps = lamps,
                            dynamic_station_name = dynamic_name,
                            enabled_condition = behavior == "combined",
                            train_limit = behavior == "combined" and "Dynamic" or "Disabled",
                            include_train = behavior == "combined",
                        })
                        local entities = Normal.generate(settings)
                        local label = table.concat({ station_type, sides, locomotives, tostring(lamps), tostring(dynamic_name), behavior }, " ")
                        equal(#madzuri_entities(entities), sides == "both" and 2 or 1, label .. " Madzuri count")
                        assert_madzuri_geometry(entities, settings, label)
                        assert_no_madzuri_collisions(entities, label)
                    end
                end
            end
        end
    end
end

-- The full behavior combination still includes one tagged name marker with its
-- dedicated green input and reserved direct red output connection.
local dynamic_settings = item_settings("loading", "both", {
    dynamic_station_name = true,
    enabled_condition = true,
    train_limit = "Dynamic",
    lamps = true,
})
local dynamic_entities = Normal.generate(dynamic_settings)
local markers = entities_named(dynamic_entities, "railwright-station-name-combinator")
equal(#markers, 1, "combined layout dynamic marker count")
local marker = markers[1]
equal(marker.tags.railwright_dynamic_name_schema, 1, "combined layout marker schema")
equal(marker.tags.railwright_base_name, dynamic_settings.station_name, "combined layout marker base tag")
local stop = entities_named(dynamic_entities, "train-stop")[1]
truthy(has_wire(
    dynamic_entities,
    marker,
    defines.wire_connector_id.combinator_output_red,
    stop,
    defines.wire_connector_id.circuit_red
), "combined layout missing reserved marker output-red wire")
local source = entity_at(dynamic_entities, dynamic_settings.chest_name, 1.5, 6)
truthy(has_wire(
    dynamic_entities,
    source,
    defines.wire_connector_id.circuit_green,
    marker,
    defines.wire_connector_id.combinator_input_green
), "combined layout missing marker green input wire")

print("Generator layout tests passed")
