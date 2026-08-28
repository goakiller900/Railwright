-- Applicability and validation rules for numeric settings shared by the GUI
-- reader and generator entry point.
local SettingsContext = {}

local function item_station(settings)
    return settings.station_type == "loading" or settings.station_type == "unloading"
end

local function fluid_station(settings)
    return settings.station_type == "fluid-loading" or settings.station_type == "fluid-unloading"
end

local specifications = {
    locomotives = {
        label = "Locomotives",
        minimum = 1,
        maximum = 50,
        active = function() return true end,
    },
    cargo_wagons = {
        label = "Wagons",
        minimum = 1,
        maximum = 200,
        active = function() return true end,
    },
    chest_limit = {
        label = "Chest limit",
        minimum = 0,
        active = item_station,
    },
    tank_columns = {
        label = "Storage tank columns",
        minimum = 1,
        maximum = 100,
        active = fluid_station,
    },
    refill_amount = {
        label = "Refill amount",
        minimum = 1,
        active = function(settings)
            return settings.station_type ~= "stacker" and settings.refill_enabled == true
        end,
    },
    train_limit_stack_size = {
        label = "Train-limit stack size",
        minimum = 1,
        active = function(settings)
            return item_station(settings) and settings.train_limit == "Dynamic"
        end,
    },
    enabled_amount = {
        label = "Enabled-condition amount",
        minimum = 0,
        active = function(settings)
            return settings.station_type ~= "stacker" and settings.enabled_condition == true
        end,
    },
    stacker_lanes = {
        label = "Stacker lanes",
        minimum = 1,
        maximum = 100,
        active = function(settings) return settings.station_type == "stacker" end,
    },
}

function SettingsContext.is_numeric_active(field, settings)
    local specification = specifications[field]
    return specification and specification.active(settings) or false
end

function SettingsContext.validate_integer(field, value)
    local specification = specifications[field]
    if not specification then return false, "Unknown numeric setting: " .. tostring(field) end

    if type(value) ~= "number"
        or value ~= value
        or value == math.huge
        or value == -math.huge
        or value ~= math.floor(value)
        or value < specification.minimum then
        return false, string.format(
            "%s must be a whole number of at least %d.",
            specification.label,
            specification.minimum
        )
    end

    if specification.maximum and value > specification.maximum then
        return false, string.format("%s must be %d or fewer.", specification.label, specification.maximum)
    end

    return true
end

return SettingsContext
