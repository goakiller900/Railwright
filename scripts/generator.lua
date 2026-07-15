local Common = require("scripts.generator_common")
local Fluid = require("scripts.generator_fluid")
local Normal = require("scripts.generator_normal")
local Stacker = require("scripts.generator_stacker")

local Generator = {}

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
    if settings.stacker_lanes < 1 then return false, "A stacker needs at least one lane." end
    if settings.stacker_lanes > 100 then return false, "Stacker lanes must be 100 or fewer." end

    local modern_rails = {
        "straight-rail",
        "half-diagonal-rail",
        "curved-rail-a",
    }

    for _, rail_name in ipairs(modern_rails) do
        if not prototypes.entity[rail_name] then
            return false, "This Factorio build does not provide the native rail prototype '" .. rail_name .. "'."
        end
    end

    -- The parallel stacker is already fully native. The diagonal template is
    -- kept on legacy rails only while its 2.1 transition geometry is rebuilt
    -- on the modern-rails development branch.
    if settings.stacker_diagonal then
        if not prototypes.entity["legacy-straight-rail"] or not prototypes.entity["legacy-curved-rail"] then
            return false, "The current diagonal stacker transition is still being migrated and needs compatibility rail prototypes."
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

function Generator.create_entities(settings)
    if Common.is_item_station(settings) then return Normal.generate(settings) end
    if Common.is_fluid_station(settings) then return Fluid.generate(settings) end
    if settings.station_type == "stacker" then return Stacker.generate(settings) end
    return {}
end

function Generator.generate_into_cursor(player, settings)
    local valid, error_message = Generator.validate_settings(settings)
    if not valid then return false, error_message end

    local entities = Generator.create_entities(settings)
    if #entities == 0 then return false, "The selected settings produced an empty blueprint." end

    if not player.clear_cursor() then
        return false, "Could not clear your cursor. Make some inventory space and try again."
    end

    local cursor = player.cursor_stack
    if not cursor or not cursor.valid then return false, "Could not access the cursor stack." end

    if not cursor.set_stack({ name = "blueprint", count = 1 }) then
        return false, "Could not create a blueprint in your cursor."
    end

    cursor.set_blueprint_entities(entities)

    local label
    if settings.station_type == "stacker" then
        label = string.format("Railwright %d-lane Stacker", settings.stacker_lanes)
    else
        label = settings.station_name ~= "" and settings.station_name or "Railwright Station"
    end
    cursor.label = label

    return true, #entities
end

return Generator
