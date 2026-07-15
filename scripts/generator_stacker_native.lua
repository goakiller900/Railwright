local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local NativeStacker = {}

-- Factorio 2.1 uses a different rail geometry from the legacy rail system.
--
-- This generator uses an exact native four-tile lane-change motif taken from
-- a known-valid 2.1 rail blueprint. For an eastbound branch from one horizontal
-- lane to the lane four tiles below it, the connected anchors are:
--
--   curved-rail-a       x + 0,  y + 0   direction southeast
--   half-diagonal-rail  x + 5,  y + 2   direction southeast
--   curved-rail-a       x + 10, y + 4   direction northwest
--
-- Repeating that motif every fourteen tiles creates a scalable fan without
-- relying on any legacy rail prototypes.

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
    last_x = math.floor(last_x)
    if first_x > last_x then return end

    for x = first_x, last_x, 2 do
        add("straight-rail", x, y, { direction = defines.direction.east })
    end
end

-- Exact native 2.1 transition from lane y to lane y + 4.
local function add_downward_branch(add, x, source_y)
    add("curved-rail-a", x, source_y, {
        direction = defines.direction.southeast,
    })
    add("half-diagonal-rail", x + 5, source_y + 2, {
        direction = defines.direction.southeast,
    })
    add("curved-rail-a", x + 10, source_y + LANE_SPACING, {
        direction = defines.direction.northwest,
    })
end

-- Horizontal mirror of the exact branch above. This merges lane y + 4 back
-- into lane y while continuing toward the east.
local function add_upward_merge(add, x, lower_y)
    add("curved-rail-a", x, lower_y, {
        direction = defines.direction.northeast,
    })
    add("half-diagonal-rail", x + 5, lower_y - 2, {
        direction = defines.direction.southwest,
    })
    add("curved-rail-a", x + 10, lower_y - LANE_SPACING, {
        direction = defines.direction.southwest,
    })
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

local function build_horizontal(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)
    local lanes = settings.stacker_lanes
    local waiting_length = even_at_least(Common.train_length(settings) + 16)

    if lanes == 1 then
        local output_end_x = waiting_length + OUTPUT_LEAD
        add_horizontal_rails(add, 0, -INPUT_LEAD, output_end_x)

        add("rail-chain-signal", -INPUT_LEAD + 1.5, -1.5, {
            direction = defines.direction.east,
        })
        add("rail-signal", output_end_x - 1.5, -1.5, {
            direction = defines.direction.east,
        })

        add_horizontal_train(add, settings, 0, 4)
        return builder.entities
    end

    -- Each new lane is reached from the previous lane using the exact native
    -- transition above. The next stage begins fourteen tiles later, leaving a
    -- short straight section between consecutive junctions.
    for lane = 2, lanes do
        local source_y = (lane - 2) * LANE_SPACING
        local branch_x = 1 + (lane - 2) * FAN_STAGE_LENGTH
        add_downward_branch(add, branch_x, source_y)
    end

    local fan_end_x = FAN_STAGE_LENGTH * (lanes - 1)

    -- The outermost lane merges first. Each inner lane then merges fourteen
    -- tiles later, producing the reverse ladder back to lane one.
    local first_merge_x = fan_end_x + waiting_length + 1
    for lane = lanes, 2, -1 do
        local lower_y = (lane - 1) * LANE_SPACING
        local merge_x = first_merge_x + (lanes - lane) * FAN_STAGE_LENGTH
        add_upward_merge(add, merge_x, lower_y)
    end

    local final_merge_x = first_merge_x + (lanes - 2) * FAN_STAGE_LENGTH
    local output_end_x = final_merge_x + 13 + OUTPUT_LEAD

    -- Lane one is the through line and must remain continuous through every
    -- branch and merge junction.
    add_horizontal_rails(add, 0, -INPUT_LEAD, output_end_x)

    -- A newly-created lane connects to its entry curve at branch_x + 10. The
    -- first straight rail centre after that curve is branch_x + 13. Before a
    -- merge, the final straight rail centre is merge_x - 3. These offsets are
    -- taken directly from the valid 2.1 motif rather than guessed from sprites.
    for lane = 2, lanes do
        local lane_y = (lane - 1) * LANE_SPACING
        local branch_x = 1 + (lane - 2) * FAN_STAGE_LENGTH
        local lane_start_x = branch_x + 13
        local merge_x = first_merge_x + (lanes - lane) * FAN_STAGE_LENGTH
        local lane_end_x = merge_x - 3

        add_horizontal_rails(add, lane_y, lane_start_x, lane_end_x)
    end

    -- Keep signals on ordinary straight rail sections; none are placed on the
    -- transition pieces themselves.
    add("rail-chain-signal", -INPUT_LEAD + 1.5, -1.5, {
        direction = defines.direction.east,
    })

    for lane = 1, lanes do
        local lane_y = (lane - 1) * LANE_SPACING
        local lane_start_x = lane == 1
            and -INPUT_LEAD
            or (1 + (lane - 2) * FAN_STAGE_LENGTH) + 13
        local merge_x = lane == 1
            and final_merge_x + 10
            or first_merge_x + (lanes - lane) * FAN_STAGE_LENGTH

        add("rail-signal", lane_start_x + 1.5, lane_y - 1.5, {
            direction = defines.direction.east,
        })

        if lane > 1 then
            add("rail-chain-signal", merge_x - 5.5, lane_y - 1.5, {
                direction = defines.direction.east,
            })
        end
    end

    add("rail-signal", output_end_x - 1.5, -1.5, {
        direction = defines.direction.east,
    })

    local train_start_x = fan_end_x + 4
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
        -- so Railwright keeps its original vertical stacker presentation.
        item.position.x = y
        item.position.y = -x
    end

    return entities
end

function NativeStacker.generate(settings)
    return transform_entities(build_horizontal(settings), settings)
end

return NativeStacker
