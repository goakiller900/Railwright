-- Public generation coordinator: validates settings, dispatches to the correct
-- geometry module, and writes the resulting entities into a cursor blueprint.
local Common = require("scripts.generator_common")
local Debug = require("scripts.generator_debug")
local DiagonalStacker = require("scripts.generator_stacker_diagonal")
local Fluid = require("scripts.generator_fluid")
local Normal = require("scripts.generator_normal")
local Stacker = require("scripts.generator_stacker")

local Generator = {}

-- Copy user settings before attaching runtime-only values that must never be
-- persisted in State storage.
local function generation_settings_for_player(player, settings, debug_enabled)
    local result = {}
    for key, value in pairs(settings) do result[key] = value end

    local inserter = prototypes.entity[settings.inserter_name or ""]
    if inserter and inserter.type == "inserter" then
        local capacity = 1 + (inserter.inserter_stack_size_bonus or 0)
        if inserter.uses_inserter_stack_size_bonus ~= false then
            capacity = capacity + (inserter.bulk
                and player.force.bulk_inserter_capacity_bonus
                or player.force.inserter_stack_size_bonus)
        end
        result._inserter_stack_size = math.max(1, math.floor(capacity))
    end

    if settings.stacker_diagonal and debug_enabled then
        result._diagonal_debug_enabled = true
    end

    return result
end

local function validate_entity(name, allowed_types, description)
    if not name or name == "" then
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

local function validate_item(name, description)
    if not name or name == "" then
        return false, description .. " is not selected."
    end

    if not prototypes.item[name] then
        return false, "Item prototype '" .. name .. "' does not exist in the current mod set."
    end

    return true
end

local function validate_common(settings)
    if settings.locomotives < 1 then return false, "A train needs at least one locomotive." end
    if settings.cargo_wagons < 1 then return false, "A train needs at least one wagon." end
    if settings.locomotives > 50 or settings.cargo_wagons > 200 then
        return false, "That train is a little too ambitious. Keep locomotives at 50 or fewer and wagons at 200 or fewer."
    end

    if settings.refill_enabled and settings.station_type ~= "stacker" then
        local ok, message = validate_item(settings.refill_fuel, "Refuel item")
        if not ok then return false, message end
    end

    if settings.train_limit_stack_size < 1 then
        return false, "Train-limit stack size must be at least 1."
    end

    if settings.enabled_amount < 0 then
        return false, "Enabled-condition amount cannot be negative."
    end

    return true
end

local function validate_normal(settings)
    local ok, message = validate_entity(settings.inserter_name, { inserter = true }, "Inserter")
    if not ok then return false, message end

    ok, message = validate_entity(settings.chest_name, {
        container = true,
        ["logistic-container"] = true,
        ["infinity-container"] = true,
        ["linked-container"] = true,
    }, "Chest")
    if not ok then return false, message end

    ok, message = validate_entity(settings.belt_name, { ["transport-belt"] = true }, "Transport belt")
    if not ok then return false, message end

    ok, message = validate_entity(settings.splitter_name, { splitter = true }, "Splitter")
    if not ok then return false, message end

    if settings.filter_enabled then
        for index, item_name in ipairs(settings.filter_items or {}) do
            if item_name ~= "" then
                ok, message = validate_item(item_name, "Inserter filter " .. index)
                if not ok then return false, message end
            end
        end
    end

    for index, request in ipairs(settings.request_items or {}) do
        if request.name and request.name ~= "" then
            ok, message = validate_item(request.name, "Logistic request " .. index)
            if not ok then return false, message end
            if not request.count or request.count < 1 then
                return false, "Logistic request " .. index .. " needs an amount of at least 1."
            end
        end
    end

    if settings.chest_limit < 0 then return false, "Chest limit cannot be negative." end

    return true
end

local function validate_fluid(settings)
    local ok, message = validate_entity(settings.pump_name, { pump = true }, "Pump")
    if not ok then return false, message end

    ok, message = validate_entity(settings.storage_tank_name, { ["storage-tank"] = true }, "Storage tank")
    if not ok then return false, message end

    ok, message = validate_entity(settings.pipe_name, { pipe = true }, "Pipe")
    if not ok then return false, message end

    if settings.tank_columns < 1 then return false, "Storage tank columns must be at least 1." end
    if settings.tank_columns > 100 then return false, "Storage tank columns must be 100 or fewer." end

    return true
end

local function validate_stacker(settings)
    if settings.stacker_lanes < 1 then return false, "A stacker needs at least one holding lane." end
    if settings.stacker_lanes > 100 then return false, "Stacker holding lanes must be 100 or fewer." end

    local modern_rails = {
        "straight-rail",
        "curved-rail-a",
        "curved-rail-b",
    }

    if settings.stacker_diagonal then
        modern_rails[#modern_rails + 1] = "half-diagonal-rail"
    end

    for _, rail_name in ipairs(modern_rails) do
        if not prototypes.entity[rail_name] then
            return false, "This Factorio build does not provide the native rail prototype '" .. rail_name .. "'."
        end
    end

    if settings.stacker_diagonal then
        local rail_planner = prototypes.item["rail"]
        if not rail_planner or rail_planner.type ~= "rail-planner" then
            return false, "This Factorio build does not provide the native 'rail' rail-planner item required for this stacker geometry."
        end
    end

    return true
end

function Generator.validate_settings(settings)
    local ok, message = validate_common(settings)
    if not ok then return false, message end

    if Common.is_item_station(settings) then return validate_normal(settings) end
    if Common.is_fluid_station(settings) then return validate_fluid(settings) end
    if settings.station_type == "stacker" then return validate_stacker(settings) end

    return false, "Unknown station type: " .. tostring(settings.station_type)
end

local function stacker_generation_settings(settings)
    local result = {}
    for key, value in pairs(settings) do result[key] = value end

    -- Stackers use the selected train length only as a sizing reference. Station
    -- options that place or alter an actual train are intentionally ignored.
    result.double_headed = false
    result.include_train = false

    return result
end

function Generator.create_entities(settings)
    -- Keep each station family isolated so geometry changes do not leak between
    -- item, fluid, parallel stacker, and experimental diagonal implementations.
    if Common.is_item_station(settings) then return Normal.generate(settings) end
    if Common.is_fluid_station(settings) then return Fluid.generate(settings) end
    if settings.station_type == "stacker" then
        local stacker_settings = stacker_generation_settings(settings)
        if stacker_settings.stacker_diagonal then return DiagonalStacker.generate(stacker_settings) end
        return Stacker.generate(stacker_settings)
    end
    return {}
end

local function compensate_native_parallel_signal_positions(settings, entities)
    if settings.station_type ~= "stacker" or settings.stacker_diagonal then return entities end

    -- Factorio 2.1 canonicalizes native rail entity positions by +1,+1 when
    -- set_blueprint_entities() stores the blueprint, while rail signals keep the
    -- exact supplied coordinates. Apply the same translation to parallel-stacker
    -- signals first so the exported blueprint preserves their intended placement
    -- relative to the rails.
    for _, entity in ipairs(entities) do
        if entity.name == "rail-signal" or entity.name == "rail-chain-signal" then
            entity.position.x = entity.position.x + 1
            entity.position.y = entity.position.y + 1
        end
    end

    return entities
end

function Generator.generate_into_cursor(player, settings)
    local valid, error_message = Generator.validate_settings(settings)
    if not valid then return false, error_message end

    local debug_enabled = settings.station_type == "stacker" and Debug.is_enabled(player.index)
    local generation_settings = generation_settings_for_player(player, settings, debug_enabled)

    local entities = compensate_native_parallel_signal_positions(settings, Generator.create_entities(generation_settings))
    if #entities == 0 then return false, "The selected settings produced an empty blueprint." end

    if not player.clear_cursor() then
        return false, "Could not clear your cursor. Make some inventory space and try again."
    end

    local cursor = player.cursor_stack
    if not cursor or not cursor.valid then return false, "Could not access the cursor stack." end

    if not cursor.set_stack({ name = "blueprint", count = 1 }) then
        return false, "Could not create a blueprint in your cursor."
    end

    if debug_enabled then
        Debug.log_settings(settings)
        Debug.log_snapshot("pre-set", entities)
    end

    cursor.set_blueprint_entities(entities)

    if debug_enabled then
        local stored_entities = cursor.get_blueprint_entities() or {}
        Debug.log_snapshot("post-set", stored_entities)
        Debug.log_comparison("pre-set-vs-post-set", entities, stored_entities)
    end

    local label
    if settings.station_type == "stacker" then
        label = string.format("Railwright %d-lane Stacker", settings.stacker_lanes)
    else
        label = settings.station_name ~= "" and settings.station_name or "Railwright Station"
    end
    cursor.label = label

    if debug_enabled then
        log("[Railwright][blueprint-debug][export] " .. cursor.export_stack())
    end

    return true, #entities
end

return Generator
