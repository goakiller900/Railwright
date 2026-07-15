local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local Stacker = {}

-- Native Factorio 2.1 rail geometry uses a different curve system than the
-- pre-2.0 rails. The parallel stacker below is built from a known-valid
-- 4-tile lane transition:
--
--   curved-rail-a -> half-diagonal-rail -> curved-rail-a
--
-- The transition is repeated as a ladder so lane count and train length stay
-- fully dynamic instead of relying on one giant fixed blueprint template.

local LANE_SPACING = 4
local FAN_STAGE_LENGTH = 14
local INPUT_LEAD = 12
local OUTPUT_LEAD = 16

local function even_at_least(value)
    local rounded = math.ceil(value)
    if rounded % 2 ~= 0 then rounded = rounded + 1 end
    return rounded
end

local function make_unique_adder(builder)
    local seen = {}

    return function(name, x, y, options)
        options = options or {}
        local direction = options.direction
        local key = table.concat({
            name,
            string.format("%.3f", x),
            string.format("%.3f", y),
            direction == nil and "" or tostring(direction),
        }, "|")

        if seen[key] then return seen[key] end

        local created = builder:add(name, x, y, options)
        seen[key] = created
        return created
    end
end

local function add_horizontal_rails(add, y, first_x, last_x)
    first_x = even_at_least(first_x)
    if first_x > last_x then return end

    for x = first_x, math.floor(last_x), 2 do
        add("straight-rail", x, y, { direction = defines.direction.east })
    end
end

local function add_downward_fan_branch(add, x, source_y)
    add("curved-rail-a", x, source_y, { direction = defines.direction.southeast })
    add("half-diagonal-rail", x + 5, source_y + 2, { direction = defines.direction.southeast })
    add("curved-rail-a", x + 10, source_y + LANE_SPACING, { direction = defines.direction.northwest })
end

local function add_upward_merge_branch(add, x, upper_y)
    add("curved-rail-a", x, upper_y + LANE_SPACING, { direction = defines.direction.northeast })
    add("half-diagonal-rail", x + 5, upper_y + 2, { direction = defines.direction.southwest })
    add("curved-rail-a", x + 10, upper_y, { direction = defines.direction.southwest })
end

local function add_horizontal_train(add, settings, lane_y, start_x)
    if not settings.include_train then return end

    local index = 0
    local train_y = lane_y + 1

    for _ = 1, settings.locomotives do
        add("locomotive", start_x + index * 7, train_y, { orientation = 0.25 })
        index = index + 1
    end

    for _ = 1, settings.cargo_wagons do
        add("cargo-wagon", start_x + index * 7, train_y, { orientation = 0.25 })
        index = index + 1
    end

    if settings.double_headed then
        for _ = 1, settings.locomotives do
            add("locomotive", start_x + index * 7, train_y, { orientation = 0.75 })
            index = index + 1
        end
    end
end

local function build_native_parallel_horizontal(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)
    local lanes = settings.stacker_lanes

    local fan_end_x = FAN_STAGE_LENGTH * math.max(0, lanes - 1)
    local waiting_length = even_at_least(Common.train_length(settings) + 16)
    local merge_start_x = fan_end_x + waiting_length + 1 -- curve anchors use the odd rail-grid column
    local final_merge_x = merge_start_x + FAN_STAGE_LENGTH * math.max(0, lanes - 2)
    local output_end_x = final_merge_x + FAN_STAGE_LENGTH + OUTPUT_LEAD

    -- Entry ladder. Each stage branches the previous lane down by four tiles.
    for lane = 2, lanes do
        local source_y = (lane - 2) * LANE_SPACING
        local branch_x = 1 + (lane - 2) * FAN_STAGE_LENGTH
        add_downward_fan_branch(add, branch_x, source_y)
    end

    -- Exit ladder. The same proven transition is mirrored horizontally to
    -- merge the outer lanes back into lane 1 without legacy curved rails.
    for lane = lanes, 2, -1 do
        local upper_y = (lane - 2) * LANE_SPACING
        local merge_x = merge_start_x + (lanes - lane) * FAN_STAGE_LENGTH
        add_upward_merge_branch(add, merge_x, upper_y)
    end

    -- Lane 1 is the through line. Every other lane begins after its entry
    -- transition and ends immediately before its own merge transition.
    add_horizontal_rails(add, 0, -INPUT_LEAD, output_end_x)

    for lane = 2, lanes do
        local lane_y = (lane - 1) * LANE_SPACING
        local lane_start_x = FAN_STAGE_LENGTH * (lane - 1)
        local lane_merge_x = merge_start_x + (lanes - lane) * FAN_STAGE_LENGTH
        add_horizontal_rails(add, lane_y, lane_start_x, lane_merge_x - 1)
    end

    -- One-way eastbound signalling. Signals are deliberately placed on long
    -- straight sections, away from the new curve pieces, to keep attachment
    -- positions stable across all lane counts and train lengths.
    add("rail-chain-signal", -INPUT_LEAD + 1.5, -1.5, {
        direction = defines.direction.east,
    })

    local waiting_signal_x = fan_end_x + 1.5
    for lane = 1, lanes do
        local lane_y = (lane - 1) * LANE_SPACING
        add("rail-signal", waiting_signal_x, lane_y - 1.5, {
            direction = defines.direction.east,
        })

        local lane_merge_x = lane == 1
            and merge_start_x
            or merge_start_x + (lanes - lane) * FAN_STAGE_LENGTH
        add("rail-chain-signal", lane_merge_x - 2.5, lane_y - 1.5, {
            direction = defines.direction.east,
        })
    end

    add("rail-signal", final_merge_x + 14.5, -1.5, {
        direction = defines.direction.east,
    })

    local train_start_x = fan_end_x + 5
    for lane = 1, lanes do
        add_horizontal_train(add, settings, (lane - 1) * LANE_SPACING, train_start_x)
    end

    return builder.entities
end

local function modulo(value, divisor)
    return ((value % divisor) + divisor) % divisor
end

local function transform_direction(direction, mirror_x, mirror_y, rotate_ccw)
    if direction == nil then return nil end

    local result = direction
    if mirror_x then result = modulo(16 - result, 16) end
    if mirror_y then result = modulo(8 - result, 16) end
    if rotate_ccw then result = modulo(result - 4, 16) end
    return result
end

local function transform_orientation(orientation, mirror_x, mirror_y, rotate_ccw)
    if orientation == nil then return nil end

    local result = orientation
    if mirror_x then result = modulo(1 - result, 1) end
    if mirror_y then result = modulo(0.5 - result, 1) end
    if rotate_ccw then result = modulo(result - 0.25, 1) end
    return result
end

local function transform_entities(entities, settings)
    local mirror_x = settings.stacker_type == "Right-Left" or settings.stacker_type == "Right-Right"
    local mirror_y = settings.stacker_type == "Left-Left" or settings.stacker_type == "Right-Right"

    for _, item in ipairs(entities) do
        local x = item.position.x
        local y = item.position.y

        if mirror_x then x = -x end
        if mirror_y then y = -y end

        item.direction = transform_direction(item.direction, mirror_x, mirror_y, true)
        item.orientation = transform_orientation(item.orientation, mirror_x, mirror_y, true)

        -- Rotate the canonical eastbound layout 90 degrees counter-clockwise
        -- so the non-diagonal stacker remains vertically oriented like the
        -- original Railwright/Burnys layout.
        item.position.x = y
        item.position.y = -x
    end

    return entities
end

local function generate_native_vertical(settings)
    return transform_entities(build_native_parallel_horizontal(settings), settings)
end

-- Legacy diagonal generator retained temporarily while the second native 2.1
-- transition family is rebuilt. Keeping it isolated here lets the parallel
-- modern geometry be tested independently before the old rail dependency is
-- removed completely.

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
    local stacker_type = settings.stacker_type == "Right-Left" and "Right-Left" or "Left-Right"

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
    return generate_native_vertical(settings)
end

return Stacker
