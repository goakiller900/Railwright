local Generator = {}

local function add_entity(entities, name, x, y, options)
    options = options or {}

    local entity = {
        entity_number = #entities + 1,
        name = name,
        position = { x = x, y = y },
    }

    for key, value in pairs(options) do
        if value ~= nil then
            entity[key] = value
        end
    end

    entities[#entities + 1] = entity
    return entity
end

local function mirror_x(x)
    -- The station rail is centered around x = -1. This matches the geometry used by
    -- the original Train Station Blueprint Creator and the Railwright web generator.
    return -x - 2
end

local function mirror_direction(direction)
    if direction == defines.direction.east then
        return defines.direction.west
    elseif direction == defines.direction.west then
        return defines.direction.east
    end
    return direction
end

local function add_side_entity(entities, settings, name, x, y, options)
    local use_right = settings.sides == "both" or settings.sides == "right"
    local use_left = settings.sides == "both" or settings.sides == "left"

    if use_right then
        add_entity(entities, name, x, y, options)
    end

    if use_left then
        local mirrored_options = {}
        for key, value in pairs(options or {}) do
            mirrored_options[key] = value
        end
        if mirrored_options.direction then
            mirrored_options.direction = mirror_direction(mirrored_options.direction)
        end
        add_entity(entities, name, mirror_x(x), y, mirrored_options)
    end
end

local function validate_entity(name, allowed_types, description)
    if not name then
        return false, description .. " is not selected."
    end

    local prototype = prototypes.entity[name]
    if not prototype then
        return false, "Entity prototype '" .. name .. "' does not exist in the current mod set."
    end

    if allowed_types and not allowed_types[prototype.type] then
        return false,
            string.format("%s '%s' has prototype type '%s', which Railwright cannot use here.", description, name, prototype.type)
    end

    return true
end

function Generator.validate_settings(settings)
    if settings.locomotives < 1 then
        return false, "A station needs at least one locomotive."
    end
    if settings.cargo_wagons < 1 then
        return false, "A station needs at least one cargo wagon."
    end
    if settings.locomotives > 50 or settings.cargo_wagons > 200 then
        return false, "That train is a little too ambitious. Keep locomotives at 50 or fewer and cargo wagons at 200 or fewer."
    end

    local ok, error_message = validate_entity(settings.inserter_name, { inserter = true }, "Inserter")
    if not ok then return false, error_message end

    ok, error_message = validate_entity(settings.chest_name, {
        container = true,
        ["logistic-container"] = true,
        ["infinity-container"] = true,
        ["linked-container"] = true,
    }, "Chest")
    if not ok then return false, error_message end

    ok, error_message = validate_entity(settings.belt_name, { ["transport-belt"] = true }, "Belt")
    if not ok then return false, error_message end

    return true
end

local function add_tracks_and_signals(entities, settings)
    local locomotive_count = settings.locomotives * (settings.double_headed and 2 or 1)
    local total_cars = locomotive_count + settings.cargo_wagons
    local train_length = total_cars * 7

    for y = -4, train_length - 1 do
        if y % 2 == 0 then
            add_entity(entities, "straight-rail", -2, y + 0.5)
        end
    end

    local signal_end = train_length + (settings.double_headed and 0 or 1)

    if settings.double_headed then
        add_entity(entities, "rail-chain-signal", -2.5, signal_end - 2, {
            direction = defines.direction.north,
        })
    else
        add_entity(entities, "rail-chain-signal", 0.5, -3, {
            direction = defines.direction.south,
        })
    end

    add_entity(entities, "rail-signal", 0.5, signal_end - 2, {
        direction = defines.direction.south,
    })

    add_entity(entities, "train-stop", 1, -1.5, {
        station = settings.station_name ~= "" and settings.station_name or "Railwright Station",
    })
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

local function add_cargo_handling(entities, settings)
    local inserter_direction = settings.station_type == "loading" and defines.direction.east or defines.direction.west
    local belt_directions = settings.station_type == "loading" and loading_belt_directions or unloading_belt_directions
    local cargo_start = settings.locomotives * 7 - 3

    for wagon = 0, settings.cargo_wagons - 1 do
        for slot = 1, 6 do
            local y = cargo_start + wagon * 7 + slot + 1

            add_side_entity(entities, settings, settings.inserter_name, 0.5, y, {
                direction = inserter_direction,
            })
            add_side_entity(entities, settings, settings.chest_name, 1.5, y)
            add_side_entity(entities, settings, settings.inserter_name, 2.5, y, {
                direction = inserter_direction,
            })
            add_side_entity(entities, settings, settings.belt_name, 3.5, y, {
                direction = belt_directions[slot],
            })
        end
    end
end

local function add_train(entities, settings)
    if not settings.include_train then return end

    local index = 0

    for _ = 1, settings.locomotives do
        add_entity(entities, "locomotive", -1, 1.5 + index * 7, {
            orientation = 0,
        })
        index = index + 1
    end

    for _ = 1, settings.cargo_wagons do
        add_entity(entities, "cargo-wagon", -1, 1.5 + index * 7, {
            orientation = 0,
        })
        index = index + 1
    end

    if settings.double_headed then
        for _ = 1, settings.locomotives do
            add_entity(entities, "locomotive", -1, 1.5 + index * 7, {
                orientation = 0.5,
            })
            index = index + 1
        end
    end
end

function Generator.create_entities(settings)
    local entities = {}

    add_tracks_and_signals(entities, settings)
    add_cargo_handling(entities, settings)
    add_train(entities, settings)

    return entities
end

function Generator.generate_into_cursor(player, settings)
    local valid, error_message = Generator.validate_settings(settings)
    if not valid then
        return false, error_message
    end

    local entities = Generator.create_entities(settings)

    if not player.clear_cursor() then
        return false, "Could not clear your cursor. Make some inventory space and try again."
    end

    local cursor = player.cursor_stack
    if not cursor or not cursor.valid then
        return false, "Could not access the cursor stack."
    end

    if not cursor.set_stack({ name = "blueprint", count = 1 }) then
        return false, "Could not create a blueprint in your cursor."
    end

    cursor.set_blueprint_entities(entities)
    cursor.label = settings.station_name ~= "" and settings.station_name or "Railwright Station"

    return true, #entities
end

return Generator
