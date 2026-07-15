local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local Stacker = {}

local function direction(old_direction)
    return old_direction and old_direction * 2 or nil
end

local function rail(name)
    if name == "straight-rail" then return "legacy-straight-rail" end
    if name == "curved-rail" then return "legacy-curved-rail" end
    return name
end

local function entity(name, x, y, old_direction)
    return {
        name = rail(name),
        x = x,
        y = y,
        direction = direction(old_direction),
    }
end

local vertical_curves = {
    front_left = {
        entity("curved-rail", 0, 0),
        entity("straight-rail", -4, -4, 1),
        entity("curved-rail", -6, -6, 3),
        entity("straight-rail", -11, -8, 2),
        entity("straight-rail", -13, -8, 2),
    },
    front_right = {
        entity("curved-rail", 2, 0, 1),
        entity("straight-rail", 5, -3, 7),
        entity("curved-rail", 8, -6, 6),
        entity("straight-rail", 13, -7, 2),
        entity("straight-rail", 15, -7, 2),
    },
    back_left = {
        entity("curved-rail", 0, 6, 5),
        entity("straight-rail", -3, 9, 3),
        entity("curved-rail", -6, 12, 2),
        entity("straight-rail", -11, 13, 2),
        entity("straight-rail", -13, 13, 2),
    },
    back_right = {
        entity("curved-rail", 2, 5, 4),
        entity("straight-rail", 5, 9, 5),
        entity("curved-rail", 8, 11, 7),
        entity("straight-rail", 13, 13, 2),
        entity("straight-rail", 15, 13, 2),
    },
}

local diagonal_curves = {
    front_left = {
        entity("curved-rail", -2, -2, 5),
        entity("straight-rail", -1, -7, 0),
        entity("straight-rail", -1, -9, 0),
        entity("rail-chain-signal", -3.5, 2.5, 5),
    },
    front_right = {
        entity("straight-rail", 1, 0, 7),
        entity("curved-rail", 4, -2, 6),
        entity("straight-rail", 9, -3, 2),
        entity("straight-rail", 11, -3, 2),
        entity("rail-chain-signal", 2.5, 0.5, 5),
    },
    back_left = {
        entity("straight-rail", -15, 9, 2),
        entity("straight-rail", -13, 9, 2),
        entity("curved-rail", -8, 8, 2),
        entity("straight-rail", -5, 5, 3),
        entity("rail-signal", -3.5, 6.5, 5),
    },
    back_right = {
        entity("straight-rail", -7, 9, 0),
        entity("straight-rail", -7, 11, 0),
        entity("curved-rail", -6, 4, 1),
        entity("rail-signal", -3.5, 2.5, 5),
    },
}

local function add_template(builder, template, x_offset, y_offset)
    for _, item in ipairs(template) do
        builder:add(item.name, item.x + (x_offset or 0), item.y + (y_offset or 0), {
            direction = item.direction,
        })
    end
end

local function add_vertical_lane(builder, settings, lane_offset, front_curve, back_curve, back_y_offset)
    local total_length = Common.train_length(settings)

    for y = -4, total_length - 1 do
        if y % 2 == 0 then
            builder:add("legacy-straight-rail", -2 + lane_offset, y + 0.5)
        end
    end

    local signal_end = total_length + (settings.double_headed and 0 or 1)
    builder:add("rail-chain-signal", 0.5 + lane_offset, -3, {
        direction = defines.direction.south,
    })
    builder:add("rail-signal", 0.5 + lane_offset, signal_end - 2, {
        direction = defines.direction.south,
    })

    add_template(builder, front_curve, -1.5 + lane_offset, -7.5)
    add_template(builder, back_curve, -1.5 + lane_offset, back_y_offset + 0.5)

    if settings.include_train then
        local index = 0
        for _ = 1, settings.locomotives do
            builder:add("locomotive", -1 + lane_offset, 1.5 + index * 7, { orientation = 0 })
            index = index + 1
        end
        for _ = 1, settings.cargo_wagons do
            builder:add("cargo-wagon", -1 + lane_offset, 1.5 + index * 7, { orientation = 0 })
            index = index + 1
        end
        if settings.double_headed then
            for _ = 1, settings.locomotives do
                builder:add("locomotive", -1 + lane_offset, 1.5 + index * 7, { orientation = 0.5 })
                index = index + 1
            end
        end
    end
end

local function generate_vertical(settings)
    local builder = Builder.new()
    local total_cars = Common.total_cars(settings)
    local train_length = math.floor(Common.train_length(settings) / 2) * 2
    local back_end_y_offset = total_cars % 2 == 1 and 2 or 0
    local lanes = settings.stacker_lanes

    local front_curve
    if settings.stacker_type == "Left-Left" or settings.stacker_type == "Right-Left" then
        front_curve = vertical_curves.front_left
    else
        front_curve = vertical_curves.front_right
    end

    local back_curve
    local entrance_x
    local entrance_y
    local entrance_direction

    if settings.stacker_type == "Left-Left" or settings.stacker_type == "Left-Right" then
        back_curve = vertical_curves.back_left
        entrance_x = -11.5
        entrance_y = 12.5 + train_length + back_end_y_offset
        entrance_direction = direction(6)
    else
        back_curve = vertical_curves.back_right
        entrance_x = 5.5 + 4 * lanes
        entrance_y = 9.5 + train_length + back_end_y_offset
        entrance_direction = direction(2)
    end

    local back_y_offset = train_length - 2 + back_end_y_offset
    for lane = 0, lanes - 1 do
        add_vertical_lane(builder, settings, lane * 4, front_curve, back_curve, back_y_offset)
    end

    builder:add("rail-chain-signal", entrance_x, entrance_y, {
        direction = entrance_direction,
    })

    return builder.entities
end

local function rounded(value)
    return math.floor(value + 0.5)
end

local function generate_diagonal(settings)
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
        entrance_direction = direction(6)
    else
        front_curve = diagonal_curves.front_left
        back_curve = diagonal_curves.back_right
        front_x = 8
        back_x = 8 - diagonal_length * 2
        back_y = diagonal_length * 2
        entrance_x = 2.5 - diagonal_length * 2
        entrance_y = 3.5 + diagonal_length * 2 + 4 * lanes
        entrance_direction = direction(4)
    end

    local lane_template = {}
    for index = 0, diagonal_length - 1 do
        lane_template[#lane_template + 1] = entity("straight-rail", 3 - index * 2, 3 + index * 2, 7)
        lane_template[#lane_template + 1] = entity("straight-rail", 3 - index * 2, 1 + index * 2, 3)
    end

    for _, item in ipairs(front_curve) do
        lane_template[#lane_template + 1] = entity(item.name, item.x + front_x, item.y + front_y, item.direction and item.direction / 2 or nil)
    end
    for _, item in ipairs(back_curve) do
        lane_template[#lane_template + 1] = entity(item.name, item.x + back_x, item.y + back_y, item.direction and item.direction / 2 or nil)
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
        return generate_diagonal(settings)
    end
    return generate_vertical(settings)
end

return Stacker
