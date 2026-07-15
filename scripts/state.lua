local State = {}

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
}

local function copy_table(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = value
    end
    return result
end

function State.ensure_root()
    storage.players = storage.players or {}
end

function State.ensure_player(player_index)
    State.ensure_root()
    if not storage.players[player_index] then
        storage.players[player_index] = copy_table(default_settings)
    end
    return storage.players[player_index]
end

function State.get_player(player_index)
    return State.ensure_player(player_index)
end

function State.set_player(player_index, settings)
    State.ensure_root()
    storage.players[player_index] = settings
end

function State.defaults()
    return copy_table(default_settings)
end

return State
