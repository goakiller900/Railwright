-- Opt-in stacker diagnostics. Snapshots record exact and translation-normalized
-- entities so Factorio's blueprint canonicalization can be inspected in logs.
local Debug = {}

local STORAGE_KEY = "railwright_blueprint_debug_players"
local POSITION_PRECISION = 6

local function sorted_keys(value)
    local keys = {}
    for key in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        local left_type = type(left)
        local right_type = type(right)
        if left_type == right_type then
            if left_type == "number" or left_type == "string" then
                return left < right
            end
            return tostring(left) < tostring(right)
        end
        return left_type < right_type
    end)

    return keys
end

local function serialize_value(value, seen)
    local value_type = type(value)

    if value_type == "nil" then return "nil" end
    if value_type == "boolean" or value_type == "number" then return tostring(value) end
    if value_type == "string" then return string.format("%q", value) end
    if value_type ~= "table" then return string.format("%q", "<" .. value_type .. ">") end

    seen = seen or {}
    if seen[value] then return string.format("%q", "<cycle>") end
    seen[value] = true

    local parts = {}
    for _, key in ipairs(sorted_keys(value)) do
        parts[#parts + 1] = "[" .. serialize_value(key, seen) .. "]=" .. serialize_value(value[key], seen)
    end

    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function rounded(value)
    return tonumber(string.format("%." .. POSITION_PRECISION .. "f", value or 0))
end

local function normalization_origin(entities)
    local min_x
    local min_y

    for _, entity in ipairs(entities or {}) do
        local position = entity.position or {}
        local x = position.x or 0
        local y = position.y or 0
        min_x = min_x == nil and x or math.min(min_x, x)
        min_y = min_y == nil and y or math.min(min_y, y)
    end

    return min_x or 0, min_y or 0
end

local function normalized_entity(entity, origin_x, origin_y)
    local position = entity.position or {}
    return {
        name = entity.name,
        x = rounded((position.x or 0) - origin_x),
        y = rounded((position.y or 0) - origin_y),
        direction = entity.direction or defines.direction.north,
        orientation = entity.orientation == nil and nil or rounded(entity.orientation),
    }
end

local function normalized_key(entity)
    return table.concat({
        entity.name or "",
        string.format("%.6f", entity.x or 0),
        string.format("%.6f", entity.y or 0),
        tostring(entity.direction or defines.direction.north),
        entity.orientation == nil and "" or string.format("%.6f", entity.orientation),
    }, "|")
end

local function increment(counts, key)
    counts[key] = (counts[key] or 0) + 1
end

local function expand_difference(counts)
    local result = {}
    local keys = sorted_keys(counts)
    for _, key in ipairs(keys) do
        for _ = 1, counts[key] do
            result[#result + 1] = key
        end
    end
    return result
end

function Debug.normalize_entities(entities)
    local origin_x, origin_y = normalization_origin(entities)
    local normalized = {}

    for _, entity in ipairs(entities or {}) do
        normalized[#normalized + 1] = normalized_entity(entity, origin_x, origin_y)
    end

    table.sort(normalized, function(left, right)
        return normalized_key(left) < normalized_key(right)
    end)

    return normalized
end

function Debug.compare_entities(expected, actual)
    local expected_counts = {}
    local actual_counts = {}

    for _, entity in ipairs(Debug.normalize_entities(expected)) do
        increment(expected_counts, normalized_key(entity))
    end
    for _, entity in ipairs(Debug.normalize_entities(actual)) do
        increment(actual_counts, normalized_key(entity))
    end

    local missing = {}
    local extra = {}
    local all_keys = {}

    for key in pairs(expected_counts) do all_keys[key] = true end
    for key in pairs(actual_counts) do all_keys[key] = true end

    for key in pairs(all_keys) do
        local expected_count = expected_counts[key] or 0
        local actual_count = actual_counts[key] or 0
        if expected_count > actual_count then
            missing[key] = expected_count - actual_count
        elseif actual_count > expected_count then
            extra[key] = actual_count - expected_count
        end
    end

    local missing_list = expand_difference(missing)
    local extra_list = expand_difference(extra)
    return {
        equal = #missing_list == 0 and #extra_list == 0,
        missing = missing_list,
        extra = extra_list,
    }
end

function Debug.is_enabled(player_index)
    local players = storage[STORAGE_KEY]
    return players ~= nil and players[player_index] == true
end

function Debug.toggle(player_index)
    storage[STORAGE_KEY] = storage[STORAGE_KEY] or {}
    local enabled = not storage[STORAGE_KEY][player_index]
    storage[STORAGE_KEY][player_index] = enabled or nil
    return enabled
end

function Debug.log_snapshot(stage, entities)
    log(string.format(
        "[Railwright][blueprint-debug][%s][exact] %s",
        stage,
        serialize_value(entities or {})
    ))
    log(string.format(
        "[Railwright][blueprint-debug][%s][normalized] %s",
        stage,
        serialize_value(Debug.normalize_entities(entities or {}))
    ))
end

function Debug.log_settings(settings)
    log("[Railwright][blueprint-debug][settings] " .. serialize_value(settings or {}))
end

function Debug.log_diagonal_signal(details)
    log("[Railwright][blueprint-debug][diagonal-signal] " .. serialize_value(details or {}))
end

function Debug.log_comparison(label, expected, actual)
    local comparison = Debug.compare_entities(expected, actual)
    log(string.format(
        "[Railwright][blueprint-debug][compare:%s] equal=%s missing=%s extra=%s",
        label,
        tostring(comparison.equal),
        serialize_value(comparison.missing),
        serialize_value(comparison.extra)
    ))
    return comparison
end

return Debug
