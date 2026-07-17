-- Generates cargo loading/unloading stations. The right side is authored once;
-- coordinate/direction mirroring produces the optional left side.
local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")

local Normal = {}

local function mirror_x(x)
    return -x - 2
end

local function mirror_direction(direction)
    if direction == defines.direction.east then return defines.direction.west end
    if direction == defines.direction.west then return defines.direction.east end
    return direction
end

local function selected_sides(settings)
    return settings.sides == "both" or settings.sides == "right",
        settings.sides == "both" or settings.sides == "left"
end

local function chest_slots(settings)
    local slots = {}
    local cargo_start = settings.locomotives * 7 - 3

    for wagon = 0, settings.cargo_wagons - 1 do
        for slot = 1, 6 do
            slots[#slots + 1] = {
                wagon = wagon,
                slot = slot,
                y = cargo_start + wagon * 7 + slot + 1,
            }
        end
    end

    return slots
end

local function filter_array(settings)
    if not settings.filter_enabled then return nil end

    local filters = {}
    for _, item_name in ipairs(settings.filter_items or {}) do
        if item_name and item_name ~= "" then
            filters[#filters + 1] = {
                index = #filters + 1,
                name = item_name,
            }
        end
    end

    return #filters > 0 and filters or nil
end

local function chest_options(settings, chest_prototype)
    local options = {}

    if settings.chest_limit and settings.chest_limit > 0 then
        options.bar = settings.chest_limit
    end

    local logistic_mode
    if chest_prototype and chest_prototype.type == "logistic-container" then
        logistic_mode = chest_prototype.logistic_mode
    end

    if logistic_mode == "requester" or logistic_mode == "buffer" then
        local requests = Common.make_logistic_requests(
            settings.request_items,
            logistic_mode == "requester" and settings.request_from_buffers or false
        )
        if requests then options.request_filters = requests end
    end

    return options
end

local function add_poles_and_lamps(builder, settings, right_poles, left_poles)
    local use_right, use_left = selected_sides(settings)
    local cargo_start = settings.locomotives * 7 - 3

    for boundary = 0, settings.cargo_wagons do
        local y = cargo_start + boundary * 7 + 1

        if use_right then
            local pole = builder:add("medium-electric-pole", 0.5, y)
            right_poles[#right_poles + 1] = pole
            if settings.lamps then builder:add("small-lamp", 1.5, y) end
        end

        if use_left then
            local pole = builder:add("medium-electric-pole", mirror_x(0.5), y)
            left_poles[#left_poles + 1] = pole
            if settings.lamps then builder:add("small-lamp", mirror_x(1.5), y) end
        end
    end
end

local loading_belt_directions = {
    defines.direction.west,
    defines.direction.north,
    defines.direction.north,
    defines.direction.south,
    defines.direction.south,
    defines.direction.west,
}

local unloading_belt_directions = {
    defines.direction.south,
    defines.direction.south,
    defines.direction.east,
    defines.direction.east,
    defines.direction.north,
    defines.direction.north,
}

local function add_vertical_belts(builder, settings, splitters, right_side, x_offset)
    if settings.belt_flow == "none" or #splitters == 0 then return end

    table.sort(splitters, function(a, b) return a.position.y < b.position.y end)
    if settings.belt_flow == "back" then
        local reversed = {}
        for index = #splitters, 1, -1 do reversed[#reversed + 1] = splitters[index] end
        splitters = reversed
    end

    local loading = settings.station_type == "loading"
    local belt_x = 5.5 + (x_offset or 0)
    local x = right_side and belt_x or mirror_x(belt_x)

    for _, splitter in ipairs(splitters) do
        local anchor_y = splitters[1].position.y
        local step = splitter.position.y >= anchor_y and 1 or -1
        local belt_direction

        if settings.belt_flow == "front" then
            belt_direction = loading and defines.direction.south or defines.direction.north
        else
            belt_direction = loading and defines.direction.north or defines.direction.south
        end

        local y = anchor_y
        while (step > 0 and y <= splitter.position.y) or (step < 0 and y >= splitter.position.y) do
            builder:add(settings.belt_name, x, y, { direction = belt_direction })
            y = y + step
        end

        local from_x = splitter.position.x + (right_side and 1 or -1)
        local horizontal_direction = right_side and defines.direction.east or defines.direction.west
        if loading then horizontal_direction = mirror_direction(horizontal_direction) end

        local cursor_x = from_x
        while (right_side and cursor_x < x) or ((not right_side) and cursor_x > x) do
            builder:add(settings.belt_name, cursor_x, splitter.position.y, { direction = horizontal_direction })
            cursor_x = cursor_x + (right_side and 1 or -1)
        end

        x = x + (right_side and 1 or -1)
    end
end

local function loader_options(direction, connection_type, filters)
    return {
        direction = direction,
        type = connection_type,
        filters = filters,
        filter_mode = filters and "whitelist" or nil,
    }
end

local function add_loader_splitter_chain(builder, settings, wagon, right_side)
    if settings.belt_flow == "none" then return end

    local loading = settings.station_type == "loading"
    local cargo_start = settings.locomotives * 7 - 3
    local first_y = cargo_start + wagon * 7 + 2
    local direction
    if right_side then
        direction = loading and defines.direction.west or defines.direction.east
    else
        direction = loading and defines.direction.east or defines.direction.west
    end

    -- Compact loaders connect directly to belts. Pair their six lanes at the
    -- wagon, then cascade those pairs through two offset splitters. This is a
    -- separate topology from the inserter station's vertical belt collector.
    local near_x = right_side and 4.5 or mirror_x(4.5)
    local far_x = right_side and 5.5 or mirror_x(5.5)
    for offset = 0, 4, 2 do
        builder:add(settings.splitter_name, near_x, first_y + offset + 0.5, {
            direction = direction,
        })
    end
    for offset = 1, 3, 2 do
        builder:add(settings.splitter_name, far_x, first_y + offset + 0.5, {
            direction = direction,
        })
    end

    local belt_y = first_y + (loading and 1 or 3)
    local x_step = right_side and 1 or -1
    local belt_x = far_x + x_step
    for _ = 1, 3 do
        builder:add(settings.belt_name, belt_x, belt_y, { direction = direction })
        belt_x = belt_x + x_step
    end
end

local function inserter_stack_size(settings)
    -- Generator.generate_into_cursor calculates this from the selected inserter
    -- prototype and the generating player's force bonuses.
    return settings._inserter_stack_size or 1
end

local function add_madzuri(builder, settings, chests, inserters, right_side)
    -- Madzuri balancing compares each chest with the side average and enables its
    -- outer inserter only when moving items helps restore that balance.
    if not settings.madzuri or #chests == 0 or #inserters == 0 then return end

    local side_multiplier = settings.sides == "both" and settings.connect_both_green and 2 or 1
    local arithmetic_x = right_side and (settings.lamps and 2.5 or 1.5) or (settings.lamps and -5.5 or -4.5)
    local arithmetic = builder:add("arithmetic-combinator", arithmetic_x, 11.5, {
        direction = right_side and defines.direction.east or defines.direction.west,
        control_behavior = {
            arithmetic_conditions = {
                first_signal = { type = "virtual", name = "signal-each" },
                second_constant = -6 * settings.cargo_wagons * side_multiplier,
                operation = "/",
                output_signal = { type = "virtual", name = "signal-each" },
            },
        },
    })

    builder:connect(chests[math.min(6, #chests)], arithmetic, "green", "circuit", "input")
    builder:connect(arithmetic, inserters[math.min(6, #inserters)], "green", "output", "circuit")

    for index, chest in ipairs(chests) do
        if inserters[index] then builder:connect(chest, inserters[index], "red") end
    end

    builder:connect_chain(inserters, "green")
end

function Normal.generate(settings)
    local builder = Builder.new()
    local train_stop = Common.add_tracks_signals_and_stop(builder, settings)
    local use_right, use_left = selected_sides(settings)
    local loading = settings.station_type == "loading"
    local using_loaders = settings.transfer_mode == "loaders"
    local inserter_direction = loading and defines.direction.east or defines.direction.west
    local belt_directions = loading and loading_belt_directions or unloading_belt_directions
    local filters = filter_array(settings)
    local chest_prototype = prototypes.entity[settings.chest_name]
    local bot_chest = chest_prototype and chest_prototype.type == "logistic-container"
    local madzuri_enabled = settings.madzuri and not bot_chest and not using_loaders
    local chest_settings = chest_options(settings, chest_prototype)

    local right_chests, left_chests = {}, {}
    local right_outer, left_outer = {}, {}
    local right_splitters, left_splitters = {}, {}
    local right_poles, left_poles = {}, {}

    for _, position in ipairs(chest_slots(settings)) do
        local inserter_options = { direction = inserter_direction }
        if filters then
            inserter_options.filters = filters
            inserter_options.use_filters = true
        end

        local outer_options = Builder.deep_copy(inserter_options)
        if madzuri_enabled then
            outer_options.control_behavior = {
                circuit_enabled = true,
                circuit_condition = {
                    first_signal = { type = "virtual", name = "signal-everything" },
                    constant = loading and inserter_stack_size(settings) or 0,
                    comparator = loading and "<" or ">",
                },
            }
        end

        if use_right then
            if using_loaders then
                local transfer_type = loading and "input" or "output"
                local chest_type = loading and "output" or "input"
                local loader_direction = loading and defines.direction.west or defines.direction.east
                builder:add(settings.loader_name, 0.5, position.y,
                    loader_options(loader_direction, transfer_type, filters))
                builder:add(settings.loader_name, 1.5, position.y,
                    loader_options(loader_direction, chest_type, filters))
                right_chests[#right_chests + 1] = builder:add(settings.chest_name, 2.5, position.y, chest_settings)
                if not bot_chest then
                    builder:add(settings.loader_name, 3.5, position.y,
                        loader_options(loader_direction, transfer_type, filters))
                end
            else
                builder:add(settings.inserter_name, 0.5, position.y, inserter_options)
                right_chests[#right_chests + 1] = builder:add(settings.chest_name, 1.5, position.y, chest_settings)
                if not bot_chest then
                    right_outer[#right_outer + 1] = builder:add(settings.inserter_name, 2.5, position.y, outer_options)
                    builder:add(settings.belt_name, 3.5, position.y, { direction = belt_directions[position.slot] })
                end
            end
        end

        if use_left then
            if using_loaders then
                local transfer_type = loading and "input" or "output"
                local chest_type = loading and "output" or "input"
                local loader_direction = loading and defines.direction.east or defines.direction.west
                builder:add(settings.loader_name, mirror_x(0.5), position.y,
                    loader_options(loader_direction, transfer_type, filters))
                builder:add(settings.loader_name, mirror_x(1.5), position.y,
                    loader_options(loader_direction, chest_type, filters))
                left_chests[#left_chests + 1] = builder:add(settings.chest_name, mirror_x(2.5), position.y, chest_settings)
                if not bot_chest then
                    builder:add(settings.loader_name, mirror_x(3.5), position.y,
                        loader_options(loader_direction, transfer_type, filters))
                end
            else
                builder:add(settings.inserter_name, mirror_x(0.5), position.y, {
                    direction = mirror_direction(inserter_direction),
                    filters = filters,
                    use_filters = filters and true or nil,
                })
                left_chests[#left_chests + 1] = builder:add(settings.chest_name, mirror_x(1.5), position.y, chest_settings)

                if not bot_chest then
                    local left_outer_options = Builder.deep_copy(outer_options)
                    left_outer_options.direction = mirror_direction(inserter_direction)
                    left_outer[#left_outer + 1] = builder:add(settings.inserter_name, mirror_x(2.5), position.y, left_outer_options)
                    builder:add(settings.belt_name, mirror_x(3.5), position.y, {
                        direction = mirror_direction(belt_directions[position.slot]),
                    })
                end
            end
        end
    end

    if not bot_chest then
        local cargo_start = settings.locomotives * 7 - 3
        for wagon = 0, settings.cargo_wagons - 1 do
            if using_loaders then
                if use_right then add_loader_splitter_chain(builder, settings, wagon, true) end
                if use_left then add_loader_splitter_chain(builder, settings, wagon, false) end
            else
                local y = cargo_start + wagon * 7 + 4.5
                local splitter_direction = loading and defines.direction.west or defines.direction.east

                if use_right then
                    right_splitters[#right_splitters + 1] = builder:add(settings.splitter_name, 4.5, y, {
                        direction = splitter_direction,
                    })
                end
                if use_left then
                    left_splitters[#left_splitters + 1] = builder:add(settings.splitter_name, mirror_x(4.5), y, {
                        direction = mirror_direction(splitter_direction),
                    })
                end
            end
        end

        if not using_loaders then
            add_vertical_belts(builder, settings, right_splitters, true)
            add_vertical_belts(builder, settings, left_splitters, false)
        end
    end

    add_poles_and_lamps(builder, settings, right_poles, left_poles)

    if settings.connect_green then
        builder:connect_chain(right_chests, "green")
        builder:connect_chain(left_chests, "green")
        if settings.connect_both_green and right_chests[1] and left_chests[1] then
            builder:connect(right_chests[1], left_chests[1], "green")
        end
    end

    if settings.connect_red then
        builder:connect_chain(right_chests, "red")
        builder:connect_chain(left_chests, "red")
        if settings.connect_both_red and right_chests[1] and left_chests[1] then
            builder:connect(right_chests[1], left_chests[1], "red")
        end
    end

    if madzuri_enabled then
        add_madzuri(builder, settings, right_chests, right_outer, true)
        add_madzuri(builder, settings, left_chests, left_outer, false)
    end

    Common.add_refuel(builder, settings)
    Common.add_train(builder, settings, false)

    local all_chests = {}
    for _, chest in ipairs(right_chests) do all_chests[#all_chests + 1] = chest end
    for _, chest in ipairs(left_chests) do all_chests[#all_chests + 1] = chest end

    local source = right_chests[1] or left_chests[1]
    local connected_count
    if settings.connect_green then
        if settings.sides == "both" and settings.connect_both_green then
            connected_count = #all_chests
        else
            connected_count = math.max(#right_chests, #left_chests)
        end
    else
        connected_count = 1
    end

    local chest_slots_count = chest_prototype
        and chest_prototype.get_inventory_size(defines.inventory.chest)
        or 48
    if settings.chest_limit and settings.chest_limit > 0 then
        chest_slots_count = math.min(chest_slots_count, settings.chest_limit)
    end

    Common.add_station_behaviors(
        builder,
        settings,
        source,
        train_stop,
        connected_count,
        #all_chests,
        chest_slots_count,
        false
    )

    return builder.entities
end

return Normal
