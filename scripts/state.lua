-- Persistent per-player configuration and lightweight save migration helpers.
-- New settings belong in default_settings so older saves receive them on access.
local PrototypeUtils = require("scripts.prototype_utils")

local State = {}

local FILTER_SLOT_COUNT = 5
local REQUEST_SLOT_COUNT = 12

local function make_request_items()
    local items = {}
    for index = 1, REQUEST_SLOT_COUNT do
        items[index] = { name = "", count = 100 }
    end
    return items
end

local default_settings = {
    station_type = "loading",
    station_name = "Railwright Station",
    dynamic_station_name = false,
    locomotives = 1,
    cargo_wagons = 2,
    double_headed = true,
    include_train = false,

    sides = "both",
    transfer_mode = "inserters",
    inserter_name = "fast-inserter",
    loader_name = "fast-transport-belt-loader",
    chest_name = "steel-chest",
    belt_name = "fast-transport-belt",
    splitter_name = "fast-splitter",
    belt_flow = "front",
    filter_enabled = false,
    filter_items = { "", "", "", "", "" },
    chest_limit = 0,
    request_from_buffers = true,
    request_items = make_request_items(),
    madzuri = true,

    pump_side = "right",
    pump_name = "pump",
    storage_tank_name = "storage-tank",
    pipe_name = "pipe",
    tank_columns = 1,
    connect_pipes = true,

    connect_green = true,
    connect_both_green = true,
    connect_red = false,
    connect_both_red = false,

    refill_enabled = true,
    refill_fuel = "solid-fuel",
    refill_amount = 20,

    train_limit = "Dynamic",
    train_limit_one = true,
    train_limit_stack_size = 50,

    enabled_condition = false,
    enabled_operator = ">",
    enabled_amount = 4000,
    lamps = false,

    stacker_lanes = 3,
    stacker_diagonal = false,
    stacker_type = "Left-Right",
}

local valid_stacker_types = {
    ["Left-Right"] = true,
    ["Right-Left"] = true,
}

local entity_setting_keys = {
    "inserter_name",
    "loader_name",
    "chest_name",
    "belt_name",
    "splitter_name",
    "pump_name",
    "storage_tank_name",
    "pipe_name",
}

local function deep_copy(value)
    if type(value) ~= "table" then return value end

    local result = {}
    for key, child in pairs(value) do
        result[deep_copy(key)] = deep_copy(child)
    end
    return result
end

local function merge_defaults(target, defaults)
    -- Recursively add missing keys without overwriting a player's saved choices.
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = deep_copy(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            merge_defaults(target[key], value)
        end
    end
    return target
end

local function clear_missing_entity_prototypes(settings)
    local entity_prototypes = prototypes and prototypes.entity

    for _, key in ipairs(entity_setting_keys) do
        local name = settings[key]
        if name == ""
            or (name ~= nil and type(name) ~= "string")
            or (entity_prototypes and name and not entity_prototypes[name]) then
            settings[key] = nil
        end
    end

    -- Loader support is optional. Fall back to the always-available inserter mode
    -- when a saved/default loader prototype is absent from the current mod set.
    if settings.transfer_mode == "loaders" and not settings.loader_name then
        settings.transfer_mode = "inserters"
    end
end

local function normalize_item_settings(settings)
    local filter_items = type(settings.filter_items) == "table" and settings.filter_items or {}
    local normalized_filters = {}
    for index = 1, FILTER_SLOT_COUNT do
        normalized_filters[index] = PrototypeUtils.item_name_or_nil(filter_items[index]) or ""
    end
    settings.filter_items = normalized_filters

    local request_items = type(settings.request_items) == "table" and settings.request_items or {}
    local normalized_requests = {}
    for index = 1, REQUEST_SLOT_COUNT do
        local request = type(request_items[index]) == "table" and request_items[index] or {}
        normalized_requests[index] = {
            name = PrototypeUtils.item_name_or_nil(request.name) or "",
            count = request.count == nil and 100 or request.count,
        }
    end
    settings.request_items = normalized_requests

    if not PrototypeUtils.is_locomotive_fuel(settings.refill_fuel) then
        settings.refill_fuel = PrototypeUtils.is_locomotive_fuel(default_settings.refill_fuel)
            and default_settings.refill_fuel
            or nil
    end
end

local function normalize_settings(settings)
    merge_defaults(settings, default_settings)
    clear_missing_entity_prototypes(settings)
    normalize_item_settings(settings)

    if not valid_stacker_types[settings.stacker_type] then
        settings.stacker_type = "Left-Right"
    end

    return settings
end

function State.ensure_root()
    storage.players = storage.players or {}
    -- Remove state written by the pre-0.3.5 hidden diagonal console toggle.
    storage.experimental_diagonal_players = nil
end

function State.ensure_player(player_index)
    State.ensure_root()

    if not storage.players[player_index] then
        storage.players[player_index] = normalize_settings(deep_copy(default_settings))
    else
        normalize_settings(storage.players[player_index])
    end

    return storage.players[player_index]
end

function State.get_player(player_index)
    return State.ensure_player(player_index)
end

function State.set_player(player_index, settings)
    State.ensure_root()
    storage.players[player_index] = normalize_settings(settings)
end

function State.defaults()
    return normalize_settings(deep_copy(default_settings))
end

return State
