local State = {}

local function make_request_items()
    local items = {}
    for index = 1, 12 do
        items[index] = { name = "", count = 100 }
    end
    return items
end

local default_settings = {
    station_type = "loading",
    station_name = "Railwright Station",
    locomotives = 1,
    cargo_wagons = 2,
    double_headed = true,
    include_train = false,

    sides = "both",
    inserter_name = "fast-inserter",
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

local function deep_copy(value)
    if type(value) ~= "table" then return value end

    local result = {}
    for key, child in pairs(value) do
        result[deep_copy(key)] = deep_copy(child)
    end
    return result
end

local function merge_defaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = deep_copy(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            merge_defaults(target[key], value)
        end
    end
    return target
end

local function normalize_settings(settings)
    merge_defaults(settings, default_settings)

    if not valid_stacker_types[settings.stacker_type] then
        settings.stacker_type = "Left-Right"
    end

    -- Diagonal stackers are no longer exposed. Migrate existing saved selections
    -- to the supported parallel layout without resetting the rest of the settings.
    settings.stacker_diagonal = false

    return settings
end

function State.ensure_root()
    storage.players = storage.players or {}
end

function State.ensure_player(player_index)
    State.ensure_root()

    if not storage.players[player_index] then
        storage.players[player_index] = deep_copy(default_settings)
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
    return deep_copy(default_settings)
end

return State
