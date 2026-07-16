-- Generates only the two confirmed parallel native-rail stackers. Experimental
-- diagonal generation is deliberately isolated in generator_stacker_diagonal.lua.
local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local Stacker = {}

-- Native Factorio 2.1 parallel stacker geometry is based on known-working,
-- manually built in-game references supplied by the project maintainer.
-- Left-Right and Right-Left use dedicated layouts because modern rail curves
-- cannot be mirrored reliably by only flipping entity coordinates/directions.

local LANE_SPACING = 4
local REFERENCE_TOTAL_CARS = 6
local REFERENCE_STRAIGHT_RAILS = 16
local STRAIGHT_RAILS_PER_EXTRA_CAR = 4
local MINIMUM_STRAIGHT_RAILS = 8

local function normalize_stacker_type(stacker_type)
    return stacker_type == "Right-Left" and "Right-Left" or "Left-Right"
end

local function make_unique_adder(builder)
    -- Adjacent lane templates share trunk pieces; deduplicate exact overlaps while
    -- retaining the entity object needed by the blueprint builder.
    local seen = {}

    return function(name, x, y, options)
        options = options or {}
        local key = table.concat({
            name,
            string.format("%.3f", x),
            string.format("%.3f", y),
            options.direction == nil and "" or tostring(options.direction),
            options.orientation == nil and "" or tostring(options.orientation),
        }, "|")

        if seen[key] then return seen[key] end

        local created = builder:add(name, x, y, options)
        seen[key] = created
        return created
    end
end

local function add_horizontal_rails(add, y, rail_count)
    for index = 0, rail_count - 1 do
        add("straight-rail", index * 2, y, {
            direction = defines.direction.east,
        })
    end
end

local function add_vertical_rails(add, x, first_y, last_y)
    if first_y > last_y then return end

    for y = first_y, last_y, 2 do
        add("straight-rail", x, y, {
            direction = defines.direction.north,
        })
    end
end

local function add_left_right_entry_transition(add, lane_y)
    add("curved-rail-a", -14, lane_y - 11, {
        direction = defines.direction.south,
    })
    add("curved-rail-b", -12, lane_y - 6, {
        direction = defines.direction.south,
    })
    add("curved-rail-b", -8, lane_y - 2, {
        direction = defines.direction.northwest,
    })
    add("curved-rail-a", -3, lane_y, {
        direction = defines.direction.northwest,
    })
end

local function add_left_right_exit_transition(add, lane_y, exit_curve_x)
    add("curved-rail-a", exit_curve_x, lane_y, {
        direction = defines.direction.southeast,
    })
    add("curved-rail-b", exit_curve_x + 5, lane_y + 2, {
        direction = defines.direction.southeast,
    })
    add("curved-rail-b", exit_curve_x + 9, lane_y + 6, {
        direction = defines.direction.north,
    })
    add("curved-rail-a", exit_curve_x + 11, lane_y + 11, {
        direction = defines.direction.north,
    })
end

local function add_right_left_left_transition(add, lane_y)
    add("curved-rail-a", -14, lane_y + 11, {
        direction = defines.direction.northeast,
    })
    add("curved-rail-b", -12, lane_y + 6, {
        direction = defines.direction.northeast,
    })
    add("curved-rail-b", -8, lane_y + 2, {
        direction = defines.direction.west,
    })
    add("curved-rail-a", -3, lane_y, {
        direction = defines.direction.west,
    })
end

local function add_right_left_right_transition(add, lane_y, exit_curve_x)
    add("curved-rail-a", exit_curve_x, lane_y, {
        direction = defines.direction.east,
    })
    add("curved-rail-b", exit_curve_x + 5, lane_y - 2, {
        direction = defines.direction.east,
    })
    add("curved-rail-b", exit_curve_x + 9, lane_y - 6, {
        direction = defines.direction.southwest,
    })
    add("curved-rail-a", exit_curve_x + 11, lane_y - 11, {
        direction = defines.direction.southwest,
    })
end

local function straight_rail_count(settings)
    local total_cars = Common.total_cars(settings)
    local count = REFERENCE_STRAIGHT_RAILS
        + (total_cars - REFERENCE_TOTAL_CARS) * STRAIGHT_RAILS_PER_EXTRA_CAR

    count = math.max(MINIMUM_STRAIGHT_RAILS, count)

    return count
end

local function build_left_right_native_parallel(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)

    local track_count = settings.stacker_lanes
    local rail_count = straight_rail_count(settings)
    local straight_end_x = (rail_count - 1) * 2
    local exit_curve_x = straight_end_x + 3
    local output_x = exit_curve_x + 11
    local last_lane_y = (track_count - 1) * LANE_SPACING

    add_vertical_rails(add, -14, -12, last_lane_y - 14)
    add_vertical_rails(add, output_x, 14, last_lane_y + 12)

    for track = 0, track_count - 1 do
        local lane_y = track * LANE_SPACING

        add_left_right_entry_transition(add, lane_y)
        add_horizontal_rails(add, lane_y, rail_count)
        add_left_right_exit_transition(add, lane_y, exit_curve_x)

        add("rail-chain-signal", -1.5, lane_y - 1.5, {
            direction = defines.direction.east,
        })
        add("rail-signal", exit_curve_x + 2.5, lane_y - 0.5, {
            direction = defines.direction.eastsoutheast,
        })
    end

    add("rail-chain-signal", output_x + 1.5, last_lane_y + 12.5, {
        direction = defines.direction.south,
    })

    return builder.entities
end

local function build_right_left_native_parallel(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)

    local track_count = settings.stacker_lanes
    local rail_count = straight_rail_count(settings)
    local straight_end_x = (rail_count - 1) * 2
    local exit_curve_x = straight_end_x + 3
    local output_x = exit_curve_x + 11
    local last_lane_y = (track_count - 1) * LANE_SPACING

    -- Dedicated Right-Left geometry taken from the maintainer's manually built
    -- 1-locomotive / 4-wagon / 3-lane Factorio 2.1 reference blueprint.
    add_vertical_rails(add, -14, 14, last_lane_y + 12)
    add_vertical_rails(add, output_x, -12, last_lane_y - 14)

    for track = 0, track_count - 1 do
        local lane_y = track * LANE_SPACING

        add_right_left_left_transition(add, lane_y)
        add_horizontal_rails(add, lane_y, rail_count)
        add_right_left_right_transition(add, lane_y, exit_curve_x)

        add("rail-signal", -4.5, lane_y + 1.5, {
            direction = defines.direction.westsouthwest,
        })
        add("rail-chain-signal", exit_curve_x - 1.5, lane_y + 1.5, {
            direction = defines.direction.west,
        })
    end

    -- Preserve the chain signals at both outer ends from the manual reference.
    add("rail-chain-signal", -12.5, last_lane_y + 12.5, {
        direction = defines.direction.south,
    })
    add("rail-chain-signal", output_x + 1.5, -12.5, {
        direction = defines.direction.south,
    })

    return builder.entities
end

local function generate_native_parallel(settings)
    if normalize_stacker_type(settings.stacker_type) == "Right-Left" then
        return build_right_left_native_parallel(settings)
    end

    return build_left_right_native_parallel(settings)
end

function Stacker.generate(settings)
    return generate_native_parallel(settings)
end

return Stacker
