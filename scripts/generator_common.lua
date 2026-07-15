local Common = {}

local function signal(name)
    return { type = "virtual", name = name }
end

local function item_signal(name)
    return { type = "item", name = name }
end

function Common.is_item_station(settings)
    return settings.station_type == "loading" or settings.station_type == "unloading"
end

function Common.is_fluid_station(settings)
    return settings.station_type == "fluid-loading" or settings.station_type == "fluid-unloading"
end

function Common.total_cars(settings)
    local locomotive_count = settings.locomotives * (settings.double_headed and 2 or 1)
    return locomotive_count + settings.cargo_wagons
end

function Common.train_length(settings)
    return Common.total_cars(settings) * 7
end

function Common.cargo_indices(settings)
    local result = {}
    local first = settings.locomotives * 7 - 3
    local last_exclusive = (settings.locomotives + settings.cargo_wagons) * 7 - 2

    for index = first, last_exclusive - 1 do
        result[#result + 1] = index
    end

    return result
end

function Common.front_locomotive_indices(settings)
    local result = {}
    for index = -3, settings.locomotives * 7 - 4 do
        result[#result + 1] = index
    end
    return result
end

function Common.back_locomotive_indices(settings)
    local result = {}
    if not settings.double_headed then return result end

    local first = (settings.locomotives + settings.cargo_wagons) * 7 - 3
    local last = Common.total_cars(settings) * 7 - 4
    for index = first, last do
        result[#result + 1] = index
    end
    return result
end

function Common.make_logistic_requests(request_items, request_from_buffers)
    local filters = {}

    for _, request in ipairs(request_items or {}) do
        if request.name and request.name ~= "" and request.count and request.count > 0 then
            filters[#filters + 1] = {
                index = #filters + 1,
                type = "item",
                name = request.name,
                count = request.count,
            }
        end
    end

    if #filters == 0 then return nil end

    return {
        sections = {
            {
                index = 1,
                filters = filters,
            },
        },
        request_from_buffers = request_from_buffers or false,
    }
end

function Common.add_tracks_signals_and_stop(builder, settings)
    local train_length = Common.train_length(settings)

    for y = -4, train_length - 1 do
        if y % 2 == 0 then
            builder:add("straight-rail", -2, y + 0.5)
        end
    end

    local signal_end = train_length + (settings.double_headed and 0 or 1)

    if settings.double_headed then
        builder:add("rail-chain-signal", -2.5, signal_end - 2, {
            direction = defines.direction.north,
        })
    else
        builder:add("rail-chain-signal", 0.5, -3, {
            direction = defines.direction.south,
        })
    end

    builder:add("rail-signal", 0.5, signal_end - 2, {
        direction = defines.direction.south,
    })

    local control_behavior = {}
    if settings.enabled_condition then
        control_behavior.circuit_enabled = true
        control_behavior.circuit_condition = {
            first_signal = signal("signal-red"),
            constant = 0,
            comparator = ">",
        }
    end

    if settings.train_limit == "Dynamic" then
        control_behavior.set_trains_limit = true
        control_behavior.trains_limit_signal = signal("signal-L")
    end

    local options = {
        station = settings.station_name ~= "" and settings.station_name or "Railwright Station",
    }

    if next(control_behavior) then
        options.control_behavior = control_behavior
    end

    local numeric_limit = tonumber(settings.train_limit)
    if numeric_limit then
        options.manual_trains_limit = numeric_limit
    end

    return builder:add("train-stop", 1, -1.5, options)
end

function Common.add_train(builder, settings, fluid)
    if not settings.include_train then return end

    local index = 0

    for _ = 1, settings.locomotives do
        builder:add("locomotive", -1, 1.5 + index * 7, { orientation = 0 })
        index = index + 1
    end

    local wagon_name = fluid and "fluid-wagon" or "cargo-wagon"
    for _ = 1, settings.cargo_wagons do
        builder:add(wagon_name, -1, 1.5 + index * 7, { orientation = 0 })
        index = index + 1
    end

    if settings.double_headed then
        for _ = 1, settings.locomotives do
            builder:add("locomotive", -1, 1.5 + index * 7, { orientation = 0.5 })
            index = index + 1
        end
    end
end

function Common.add_refuel(builder, settings)
    if not settings.refill_enabled then return end

    local request_filters = Common.make_logistic_requests({
        { name = settings.refill_fuel, count = settings.refill_amount },
    }, false)

    for _, y in ipairs(Common.front_locomotive_indices(settings)) do
        if y % 7 == 5 then
            builder:add("inserter", 0.5, y + 1, { direction = defines.direction.east })
            builder:add("requester-chest", 1.5, y + 1, { request_filters = request_filters })
        end
    end

    for _, y in ipairs(Common.back_locomotive_indices(settings)) do
        if y % 7 == 2 then
            builder:add("inserter", 0.5, y + 1, { direction = defines.direction.east })
            builder:add("requester-chest", 1.5, y + 1, { request_filters = request_filters })
        end
    end
end

local function dynamic_train_limit_values(settings, connected_storage_count, total_storage_count, storage_slots, fluid)
    local train_capacity
    local storage_capacity

    if fluid then
        train_capacity = settings.cargo_wagons * 25000
        storage_capacity = connected_storage_count * settings.tank_columns * 25000
    else
        local connected_fraction = total_storage_count > 0 and connected_storage_count / total_storage_count or 1
        train_capacity = settings.cargo_wagons * 40 * settings.train_limit_stack_size * connected_fraction
        storage_capacity = connected_storage_count * storage_slots * settings.train_limit_stack_size
    end

    train_capacity = math.max(1, math.floor(train_capacity))
    local maximum_trains = math.max(1, math.floor(storage_capacity / train_capacity))
    if settings.train_limit_one then maximum_trains = 1 end

    return train_capacity, maximum_trains
end

function Common.add_station_behaviors(builder, settings, source_entity, train_stop, connected_storage_count, total_storage_count, storage_slots, fluid)
    if not source_entity then return end

    if settings.enabled_condition then
        local decider = builder:add("decider-combinator", 0.5, 1.5, {
            control_behavior = {
                decider_conditions = {
                    conditions = {
                        {
                            first_signal = signal("signal-anything"),
                            constant = settings.enabled_amount,
                            comparator = settings.enabled_operator,
                        },
                    },
                    outputs = {
                        {
                            signal = signal("signal-red"),
                            copy_count_from_input = false,
                        },
                    },
                },
            },
        })

        builder:connect(source_entity, decider, "green", "circuit", "input")
        builder:connect(decider, train_stop, "green", "output", "circuit")
    end

    if settings.train_limit == "Dynamic" then
        local train_capacity, maximum_trains = dynamic_train_limit_values(
            settings,
            connected_storage_count,
            total_storage_count,
            storage_slots,
            fluid
        )

        local first = builder:add("arithmetic-combinator", 2.5, 4.5, {
            control_behavior = {
                arithmetic_conditions = {
                    first_signal = signal("signal-each"),
                    second_constant = train_capacity,
                    operation = "/",
                    output_signal = signal("signal-L"),
                },
            },
        })

        local second_conditions
        if settings.station_type == "unloading" or settings.station_type == "fluid-unloading" then
            second_conditions = {
                first_constant = maximum_trains,
                second_signal = signal("signal-L"),
                operation = "-",
                output_signal = signal("signal-L"),
            }
        else
            second_conditions = {
                first_signal = signal("signal-L"),
                second_constant = 0,
                operation = "+",
                output_signal = signal("signal-L"),
            }
        end

        local second = builder:add("arithmetic-combinator", 1.5, 4.5, {
            control_behavior = {
                arithmetic_conditions = second_conditions,
            },
        })

        builder:connect(source_entity, first, "green", "circuit", "input")
        builder:connect(first, second, "green", "output", "input")
        builder:connect(second, train_stop, "green", "output", "circuit")
    end
end

function Common.item_signal(name)
    return item_signal(name)
end

return Common
