-- Geometry regressions for parallel capacity, stacker-only double-headed state,
-- and diagonal sizing. These checks use generated entity positions rather than
-- copying the generator's rail-count constants.
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
    direction = {
        north = 0,
        northeast = 2,
        east = 4,
        eastsoutheast = 5,
        southeast = 6,
        south = 8,
        southwest = 10,
        westsouthwest = 11,
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

prototypes = { entity = {}, item = {} }

local Common = require("scripts.generator_common")
local DiagonalStacker = require("scripts.generator_stacker_diagonal")
local Generator = require("scripts.generator")

local function stacker_settings(locomotives, wagons, direction, lanes, double_headed)
    return {
        station_type = "stacker",
        locomotives = locomotives,
        cargo_wagons = wagons,
        -- Deliberately oppose the station flag to the stacker flag in callers;
        -- Generator must isolate the two settings.
        double_headed = not double_headed,
        stacker_double_headed = double_headed,
        include_train = true,
        stacker_lanes = lanes,
        stacker_diagonal = false,
        stacker_type = direction,
    }
end

local function named(entities, name)
    local result = {}
    for _, entity in ipairs(entities) do
        if entity.name == name then result[#result + 1] = entity end
    end
    return result
end

local function horizontal_run(entities, lane_y)
    local result = {}
    for _, entity in ipairs(entities) do
        if entity.name == "straight-rail"
            and entity.direction == defines.direction.east
            and entity.position.y == lane_y then
            result[#result + 1] = entity
        end
    end
    table.sort(result, function(a, b) return a.position.x < b.position.x end)
    return result
end

local function lane_curves(entities, lane_y)
    local result = {}
    for _, entity in ipairs(entities) do
        if entity.name == "curved-rail-a" and entity.position.y == lane_y then
            result[#result + 1] = entity
        end
    end
    table.sort(result, function(a, b) return a.position.x < b.position.x end)
    return result
end

local function entity_at_position(entities, x, y, predicate)
    for _, entity in ipairs(entities) do
        if entity.position.x == x and entity.position.y == y and (not predicate or predicate(entity)) then
            return entity
        end
    end
end

local function output_curve_anchor(entities, lane_y, direction)
    local rails = horizontal_run(entities, lane_y)
    truthy(#rails > 0, direction .. " lane has a holding run for its output curve")

    local selected
    for _, entity in ipairs(entities) do
        if entity.name == "curved-rail-a" and entity.position.y == lane_y then
            local output_side = direction == "Left-Right"
                and entity.position.x > rails[#rails].position.x
                or direction == "Right-Left" and entity.position.x < rails[1].position.x
            if output_side then
                truthy(not selected, direction .. " lane has only one output curve anchor")
                selected = entity
            end
        end
    end

    truthy(selected, direction .. " lane has an output curve anchor")
    return selected
end

local function count_direction(entities, direction)
    local count = 0
    for _, entity in ipairs(entities) do
        if entity.direction == direction then count = count + 1 end
    end
    return count
end

local function assert_parallel_signal_geometry(entities, direction, lanes, label)
    local rail_signals = named(entities, "rail-signal")
    local chain_signals = named(entities, "rail-chain-signal")
    local signal_direction = direction == "Left-Right"
        and defines.direction.eastsoutheast
        or defines.direction.westsouthwest
    local lane_chain_direction = direction == "Left-Right"
        and defines.direction.east
        or defines.direction.west
    local expected_chain_count = direction == "Left-Right" and lanes + 1 or lanes + 2
    local matched = {}

    equal(#rail_signals, lanes, label .. " normal signal count")
    equal(count_direction(rail_signals, signal_direction), lanes, label .. " normal signal directions")
    equal(#chain_signals, expected_chain_count, label .. " chain signal count")
    equal(count_direction(chain_signals, lane_chain_direction), lanes, label .. " lane chain-signal directions")
    equal(count_direction(chain_signals, defines.direction.south), expected_chain_count - lanes,
        label .. " final chain-signal directions")

    for lane = 0, lanes - 1 do
        local lane_y = lane * 4
        local anchor = output_curve_anchor(entities, lane_y, direction)
        local expected_x
        local expected_y

        if direction == "Left-Right" then
            expected_x = anchor.position.x + 4.5
            expected_y = anchor.position.y + 0.5
        else
            expected_x = anchor.position.x - 3.5
            expected_y = anchor.position.y + 2.5
        end

        local signal = entity_at_position(entities, expected_x, expected_y, function(entity)
            return entity.name == "rail-signal"
        end)
        truthy(signal, string.format(
            "%s lane %d normal signal uses the forward output-curve attachment",
            label,
            lane + 1
        ))
        equal(signal.direction, signal_direction, label .. " lane exit-signal direction")
        matched[signal.entity_number] = true
    end

    for _, signal in ipairs(rail_signals) do
        truthy(matched[signal.entity_number], label .. " has no unrelated normal signals")
    end
end

local function assert_lane_capacity(entities, lane_y, expected_cars, direction, label)
    local rails = horizontal_run(entities, lane_y)
    truthy(#rails > 0, label .. " has a horizontal holding run")

    for index = 2, #rails do
        equal(rails[index].position.x - rails[index - 1].position.x, 2, label .. " rail continuity")
    end

    -- Each native horizontal rail covers two tiles. Coupled vanilla rolling stock
    -- centres are seven tiles apart, so this checks the generated physical span
    -- fits this train while a train with one more car cannot fit on the run.
    local usable_tiles = rails[#rails].position.x - rails[1].position.x + 2
    local requested_centre_span = (expected_cars - 1) * 7
    local next_centre_span = expected_cars * 7
    truthy(requested_centre_span <= usable_tiles, label .. " fits the requested train")
    truthy(next_centre_span > usable_tiles, label .. " does not fit an extra car")

    local curves = lane_curves(entities, lane_y)
    equal(#curves, 2, label .. " has one entrance and one exit curve anchor")
    truthy(curves[1].position.x < rails[1].position.x, label .. " entrance curve clears the straight run")
    truthy(curves[2].position.x > rails[#rails].position.x, label .. " exit curve clears the straight run")

    if direction == "Left-Right" then
        local entry = entity_at_position(entities, -1.5, lane_y - 1.5, function(entity)
            return entity.name == "rail-chain-signal"
        end)
        local exit = entity_at_position(entities, curves[2].position.x + 4.5, lane_y + 0.5, function(entity)
            return entity.name == "rail-signal"
        end)
        truthy(entry, label .. " entry chain signal remains on its curve anchor")
        truthy(exit, label .. " exit rail signal remains beyond the exit curve")
        truthy(curves[1].position.x < entry.position.x and entry.position.x < rails[1].position.x,
            label .. " entry signal does not intrude into the holding run")
        truthy(exit.position.x > curves[2].position.x,
            label .. " exit signal does not intrude into the holding run")
    else
        local exit = entity_at_position(entities, -6.5, lane_y + 2.5, function(entity)
            return entity.name == "rail-signal"
        end)
        local entry = entity_at_position(entities, curves[2].position.x - 1.5, lane_y + 1.5, function(entity)
            return entity.name == "rail-chain-signal"
        end)
        truthy(exit, label .. " exit rail signal remains beyond the output curve")
        truthy(entry, label .. " entry chain signal remains on its curve anchor")
        truthy(exit.position.x < curves[1].position.x,
            label .. " exit signal does not intrude into the holding run")
        truthy(rails[#rails].position.x < entry.position.x and entry.position.x < curves[2].position.x,
            label .. " entry signal does not intrude into the holding run")
    end

    return usable_tiles
end

local cases = {
    { locomotives = 1, wagons = 1, total = 2 },
    { locomotives = 1, wagons = 4, total = 5 },
    { locomotives = 2, wagons = 4, total = 6 },
    { locomotives = 5, wagons = 2, total = 7 },
}

-- Normal exit signals use the forward attachment of each lane's output curve.
-- Exercise short and long holding runs so a train-length change cannot make a
-- world-coordinate-only signal correction appear valid, and mirror the check
-- across both dedicated parallel orientations.
for _, direction in ipairs({ "Left-Right", "Right-Left" }) do
    for _, lanes in ipairs({ 1, 3, 9 }) do
        for _, double_headed in ipairs({ false, true }) do
            for _, case in ipairs(cases) do
                local entities = Generator.create_entities(stacker_settings(
                    case.locomotives,
                    case.wagons,
                    direction,
                    lanes,
                    double_headed
                ))
                local heading = double_headed and "double-headed" or "single-headed"
                assert_parallel_signal_geometry(
                    entities,
                    direction,
                    lanes,
                    string.format(
                        "%s %s %d-%d %d-lane",
                        direction,
                        heading,
                        case.locomotives,
                        case.wagons,
                        lanes
                    )
                )
            end
        end
    end
end

-- Cover every reported train in both directions and every lane of the normal
-- three-lane layout.
for _, direction in ipairs({ "Left-Right", "Right-Left" }) do
    for _, case in ipairs(cases) do
        local settings = stacker_settings(case.locomotives, case.wagons, direction, 3, false)
        local entities = Generator.create_entities(settings)
        for lane = 0, 2 do
            assert_lane_capacity(
                entities,
                lane * 4,
                case.total,
                direction,
                string.format("%s %d-%d lane %d", direction, case.locomotives, case.wagons, lane + 1)
            )
        end
    end
end

-- The minimum one-lane 1-1 layout keeps every signal at a distinct, valid rail
-- anchor and provides only the two-car centre span.
for _, direction in ipairs({ "Left-Right", "Right-Left" }) do
    local entities = Generator.create_entities(stacker_settings(1, 1, direction, 1, false))
    equal(assert_lane_capacity(entities, 0, 2, direction, direction .. " minimum 1-1"), 8,
        direction .. " minimum physical straight span")

    for _, signal in ipairs(named(entities, "rail-signal")) do
        truthy(not entity_at_position(entities, signal.position.x, signal.position.y, function(entity)
            return entity ~= signal and entity.name:find("rail", 1, true) ~= nil
        end), direction .. " minimum rail signal does not overlap another rail entity")
    end
    for _, signal in ipairs(named(entities, "rail-chain-signal")) do
        truthy(not entity_at_position(entities, signal.position.x, signal.position.y, function(entity)
            return entity ~= signal and entity.name:find("rail", 1, true) ~= nil
        end), direction .. " minimum chain signal does not overlap another rail entity")
    end
end

-- Station and stacker headedness are independent, and stackers never place the
-- sizing-reference train in their blueprint.
local single_settings = stacker_settings(1, 4, "Left-Right", 1, false)
local single_entities = Generator.create_entities(single_settings)
assert_lane_capacity(single_entities, 0, 5, "Left-Right", "single-headed 1-4")
equal(#named(single_entities, "locomotive"), 0, "single-headed stacker places no locomotives")
equal(#named(single_entities, "cargo-wagon"), 0, "single-headed stacker places no wagons")

local double_settings = stacker_settings(1, 4, "Left-Right", 1, true)
local double_entities = Generator.create_entities(double_settings)
assert_lane_capacity(double_entities, 0, 6, "Left-Right", "double-headed 1-4-1")
equal(#named(double_entities, "locomotive"), 0, "double-headed stacker places no locomotives")
equal(#named(double_entities, "cargo-wagon"), 0, "double-headed stacker places no wagons")

-- Diagonal single-headed sizing remains byte-for-byte equivalent at the pure
-- geometry decision point, while double-headed sizing counts the rear end.
for _, direction in ipairs({ "Left-Right", "Right-Left" }) do
    local diagonal_single = {
        locomotives = 1,
        cargo_wagons = 4,
        double_headed = false,
        stacker_lanes = 3,
        stacker_type = direction,
    }
    equal(Common.total_cars(diagonal_single), 5, direction .. " diagonal single total cars")
    equal(DiagonalStacker.holding_straight_steps(diagonal_single), 13,
        direction .. " diagonal single-headed 1-4 steps stay stable")

    local diagonal_double = {
        locomotives = 1,
        cargo_wagons = 4,
        double_headed = true,
        stacker_lanes = 3,
        stacker_type = direction,
    }
    equal(Common.total_cars(diagonal_double), 6, direction .. " diagonal double total cars")
    equal(DiagonalStacker.holding_straight_steps(diagonal_double), 17,
        direction .. " diagonal double-headed 1-4-1 counts both ends")
end

local wide_single = {
    locomotives = 1,
    cargo_wagons = 4,
    double_headed = false,
    stacker_lanes = 10,
}
equal(DiagonalStacker.holding_straight_steps(wide_single), 14,
    "wide single-headed diagonal fan clearance stays stable")

print("Stacker layout tests passed")
