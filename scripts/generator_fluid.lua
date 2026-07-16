-- Generates fluid loading/unloading stations with pumps, alternating tank rows,
-- optional inter-row pipes, circuit wiring, and shared station behaviors.
local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local Fluid = {}

local function mirror_x(x)
    return -x - 2
end

local function mirror_direction(direction)
    if direction == defines.direction.east then return defines.direction.west end
    if direction == defines.direction.west then return defines.direction.east end
    return direction
end

local function mirror_tank_direction(direction)
    if direction == defines.direction.north then return defines.direction.east end
    if direction == defines.direction.east then return defines.direction.north end
    return direction
end

local function side_x(settings, x)
    return settings.pump_side == "left" and mirror_x(x) or x
end

local function side_direction(settings, direction, tank)
    if settings.pump_side ~= "left" then return direction end
    return tank and mirror_tank_direction(direction) or mirror_direction(direction)
end

local function serpentine_tanks(rows)
    -- Alternating row order creates a short continuous circuit-wire chain.
    local ordered = {}

    for row_index, row in ipairs(rows) do
        if row_index % 2 == 1 then
            for index = 1, #row do ordered[#ordered + 1] = row[index] end
        else
            for index = #row, 1, -1 do ordered[#ordered + 1] = row[index] end
        end
    end

    return ordered
end

function Fluid.generate(settings)
    local builder = Builder.new()
    local train_stop = Common.add_tracks_signals_and_stop(builder, settings)
    local cargo_start = settings.locomotives * 7 - 3
    local loading = settings.station_type == "fluid-loading"
    local pump_direction = loading and defines.direction.west or defines.direction.east
    local tank_rows_for_wiring = {}

    for wagon = 0, settings.cargo_wagons - 1 do
        local pump_y_top = cargo_start + wagon * 7 + 2
        local pump_y_bottom = cargo_start + wagon * 7 + 7

        builder:add(settings.pump_name, side_x(settings, 1), pump_y_top, {
            direction = side_direction(settings, pump_direction, false),
        })
        builder:add(settings.pump_name, side_x(settings, 1), pump_y_bottom, {
            direction = side_direction(settings, pump_direction, false),
        })

        local tank_rows = {
            cargo_start + wagon * 7 + 3,
            cargo_start + wagon * 7 + 6,
        }

        for row_index, y in ipairs(tank_rows) do
            local created_row = {}

            for column = 0, settings.tank_columns - 1 do
                local direction
                if row_index == 1 then
                    direction = column % 2 == 0 and defines.direction.north or defines.direction.east
                else
                    direction = column % 2 == 0 and defines.direction.east or defines.direction.north
                end

                local x = (column + 1) * 3 + 0.5
                created_row[#created_row + 1] = builder:add(settings.storage_tank_name, side_x(settings, x), y, {
                    direction = side_direction(settings, direction, true),
                })
            end

            tank_rows_for_wiring[#tank_rows_for_wiring + 1] = created_row
        end
    end

    if settings.connect_pipes and settings.cargo_wagons > 1 then
        for boundary = 1, settings.cargo_wagons - 1 do
            local y = cargo_start + boundary * 7 + 1
            for column = 0, settings.tank_columns - 1 do
                local x_offset = column % 2 == 0
                    and math.floor(column / 2) * 6
                    or math.floor(column / 2) * 6 + 5
                builder:add(settings.pipe_name, side_x(settings, 2.5 + x_offset), y)
            end
        end
    end

    local poles = {}
    for boundary = 0, settings.cargo_wagons do
        local y = cargo_start + boundary * 7 + 1
        poles[#poles + 1] = builder:add("medium-electric-pole", side_x(settings, 0.5), y)
        if settings.lamps then
            builder:add("small-lamp", side_x(settings, 1.5), y)
        end
    end

    local tanks = serpentine_tanks(tank_rows_for_wiring)
    if settings.connect_green then builder:connect_chain(tanks, "green") end
    if settings.connect_red then builder:connect_chain(tanks, "red") end

    Common.add_refuel(builder, settings)
    Common.add_train(builder, settings, true)

    local source = tanks[1] or poles[1]
    local connected_count = settings.connect_green and #tanks or 1
    Common.add_station_behaviors(
        builder,
        settings,
        source,
        train_stop,
        connected_count,
        #tanks,
        1,
        true
    )

    return builder.entities
end

return Fluid
