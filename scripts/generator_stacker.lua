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

    -- The supplied reference blueprints do not contain trains. When train
    -- placement is requested, lengthen the straight waiting section enough to
    -- keep every rolling-stock centre on straight rail.
    if settings.include_train then
        local train_span = math.max(0, total_cars - 1) * 7 + 8
        local required = math.ceil(train_span / 2) + 1
        count = math.max(count, required)
    end

    return count
end

local function add_horizontal_train(add, settings, lane_y, right_to_left)
    local index = 0
    local first_x = 4
    local forward_orientation = right_to_left and 0.75 or 0.25
    local rear_orientation = right_to_left and 0.25 or 0.75

    for _ = 1, settings.locomotives do
        add("locomotive", first_x + index * 7, lane_y, {
            orientation = forward_orientation,
        })
        index = index + 1
    end

    for _ = 1, settings.cargo_wagons do
        add("cargo-wagon", first_x + index * 7, lane_y, {
            orientation = forward_orientation,
        })
        index = index + 1
    end

    if settings.double_headed then
        for _ = 1, settings.locomotives do
            add("locomotive", first_x + index * 7, lane_y, {
                orientation = rear_orientation,
            })
            index = index + 1
        end
    end
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

    if settings.include_train then
        for lane = 0, track_count - 1 do
            add_horizontal_train(add, settings, lane * LANE_SPACING, false)
        end
    end

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

    if settings.include_train then
        for lane = 0, track_count - 1 do
            add_horizontal_train(add, settings, lane * LANE_SPACING, true)
        end
    end

    return builder.entities
end

local function generate_native_parallel(settings)
    if normalize_stacker_type(settings.stacker_type) == "Right-Left" then
        return build_right_left_native_parallel(settings)
    end

    return build_left_right_native_parallel(settings)
end

-- Legacy diagonal generator retained temporarily while its separate native 2.1
-- geometry is rebuilt. It is isolated so the supplied parallel stacker can be
-- verified independently before the final legacy dependency is removed.

local function legacy_direction(old_direction)
    return old_direction and old_direction * 2 or nil
end

local function legacy_entity(name, x, y, old_direction)
    if name == "straight-rail" then name = "legacy-straight-rail" end
    if name == "curved-rail" then name = "legacy-curved-rail" end

    return {
        name = name,
        x = x,
        y = y,
        direction = legacy_direction(old_direction),
    }
end

local diagonal_curves = {
    front_left = {
        legacy_entity("curved-rail", -2, -2, 5),
        legacy_entity("straight-rail", -1, -7, 0),
        legacy_entity("straight-rail", -1, -9, 0),
        legacy_entity("rail-chain-signal", -3.5, 2.5, 5),
    },
    front_right = {
        legacy_entity("straight-rail", 1, 0, 7),
        legacy_entity("curved-rail", 4, -2, 6),
        legacy_entity("straight-rail", 9, -3, 2),
        legacy_entity("straight-rail", 11, -3, 2),
        legacy_entity("rail-chain-signal", 2.5, 0.5, 5),
    },
    back_left = {
        legacy_entity("straight-rail", -15, 9, 2),
        legacy_entity("straight-rail", -13, 9, 2),
        legacy_entity("curved-rail", -8, 8, 2),
        legacy_entity("straight-rail", -5, 5, 3),
        legacy_entity("rail-signal", -3.5, 6.5, 5),
    },
    back_right = {
        legacy_entity("straight-rail", -7, 9, 0),
        legacy_entity("straight-rail", -7, 11, 0),
        legacy_entity("curved-rail", -6, 4, 1),
        legacy_entity("rail-signal", -3.5, 2.5, 5),
    },
}

local function add_template(builder, template, x_offset, y_offset)
    for _, item in ipairs(template) do
        builder:add(item.name, item.x + (x_offset or 0), item.y + (y_offset or 0), {
            direction = item.direction,
        })
    end
end

local function rounded(value)
    return math.floor(value + 0.5)
end

local function generate_legacy_diagonal(settings)
    local builder = Builder.new()
    local double_factor = settings.double_headed and 2 or 1
    local diagonal_length = rounded((2.5 * (double_factor * settings.locomotives + settings.cargo_wagons)) / 2) * 2 + 1
    local lanes = settings.stacker_lanes
    local stacker_type = normalize_stacker_type(settings.stacker_type)

    local front_curve
    local back_curve
    local front_x
    local front_y = 0
    local back_x
    local back_y
    local entrance_x
    local entrance_y
    local entrance_direction

    if stacker_type == "Left-Right" then
        front_curve = diagonal_curves.front_right
        back_curve = diagonal_curves.back_left
        front_x = 4
        back_x = 8 - diagonal_length * 2
        back_y = -4 + diagonal_length * 2
        entrance_x = -3.5 - diagonal_length * 2
        entrance_y = 6.5 + diagonal_length * 2
        entrance_direction = legacy_direction(6)
    else
        front_curve = diagonal_curves.front_left
        back_curve = diagonal_curves.back_right
        front_x = 8
        back_x = 8 - diagonal_length * 2
        back_y = diagonal_length * 2
        entrance_x = 2.5 - diagonal_length * 2
        entrance_y = 3.5 + diagonal_length * 2 + 4 * lanes
        entrance_direction = legacy_direction(4)
    end

    local lane_template = {}
    for index = 0, diagonal_length - 1 do
        lane_template[#lane_template + 1] = legacy_entity("straight-rail", 3 - index * 2, 3 + index * 2, 7)
        lane_template[#lane_template + 1] = legacy_entity("straight-rail", 3 - index * 2, 1 + index * 2, 3)
    end

    for _, item in ipairs(front_curve) do
        lane_template[#lane_template + 1] = {
            name = item.name,
            x = item.x + front_x,
            y = item.y + front_y,
            direction = item.direction,
        }
    end
    for _, item in ipairs(back_curve) do
        lane_template[#lane_template + 1] = {
            name = item.name,
            x = item.x + back_x,
            y = item.y + back_y,
            direction = item.direction,
        }
    end

    for lane = 0, lanes - 1 do
        local x_offset = stacker_type == "Left-Right" and lane * 4 or 0
        local y_offset = stacker_type == "Right-Left" and lane * 4 or 0
        add_template(builder, lane_template, x_offset, y_offset)
    end

    builder:add("rail-chain-signal", entrance_x, entrance_y, {
        direction = entrance_direction,
    })

    return builder.entities
end

function Stacker.generate(settings)
    if settings.stacker_diagonal then
        return generate_legacy_diagonal(settings)
    end
    return generate_native_parallel(settings)
end

return Stacker
