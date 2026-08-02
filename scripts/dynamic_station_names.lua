-- Runtime ownership for Railwright station-name markers. Persistent records keep
-- only scalar identifiers and configuration; Lua runtime objects are resolved on
-- demand and never written to storage.
local Constants = require("scripts.constants")

local DynamicStationNames = {}

local MARKER_NAME = Constants.entities.station_name_combinator
local SCHEMA_VERSION = 1
local UPDATE_INTERVAL = 60

local valid_station_types = {
    loading = true,
    unloading = true,
    ["fluid-loading"] = true,
    ["fluid-unloading"] = true,
}

local function registrations()
    storage.dynamic_station_names = storage.dynamic_station_names or {}
    storage.dynamic_station_names.registrations = storage.dynamic_station_names.registrations or {}
    return storage.dynamic_station_names.registrations
end

local function is_real_marker(entity)
    return entity
        and entity.valid
        and entity.name == MARKER_NAME
        and entity.unit_number ~= nil
end

local function normalized_station_type(value)
    return valid_station_types[value] and value or "loading"
end

local function register_marker(entity, tags)
    if not is_real_marker(entity) then return nil end

    local records = registrations()
    local unit_number = entity.unit_number
    local record = records[unit_number]
    local tagged = tags and tags.railwright_dynamic_station_name == true

    if not record then
        record = {
            marker_unit_number = unit_number,
            surface_index = entity.surface.index,
            station_type = "loading",
            schema = SCHEMA_VERSION,
        }
        records[unit_number] = record
    end

    record.marker_unit_number = unit_number
    record.surface_index = entity.surface.index

    if tagged then
        record.base_name = type(tags.railwright_base_name) == "string"
            and tags.railwright_base_name
            or ""
        record.station_type = normalized_station_type(tags.railwright_station_type)
        record.schema = tonumber(tags.railwright_dynamic_name_schema) or SCHEMA_VERSION
        record.stop_unit_number = nil
        record.initial_name = nil
        record.last_signal_type = nil
        record.last_signal_name = nil
        record.last_applied_name = nil
    end

    return record
end

local function marker_for_record(record)
    local marker = game.get_entity_by_unit_number(record.marker_unit_number)
    if not is_real_marker(marker) then return nil end
    return marker
end

local function resolve_train_stop(record, marker)
    local connector = marker.get_wire_connector(
        defines.wire_connector_id.combinator_output_red,
        false
    )
    if not connector or not connector.valid then
        record.stop_unit_number = nil
        return nil
    end

    local candidates = {}
    local candidate_units = {}
    for _, connection in pairs(connector.real_connections) do
        local target = connection.target
        local owner = target and target.valid and target.owner or nil
        if owner and owner.valid and owner.type == "train-stop" and owner.unit_number then
            local unit_number = owner.unit_number
            if not candidates[unit_number] then
                candidates[unit_number] = owner
                candidate_units[#candidate_units + 1] = unit_number
            end
        end
    end

    table.sort(candidate_units)
    if #candidate_units ~= 1 then
        record.stop_unit_number = nil
        return nil
    end

    local stop = candidates[candidate_units[1]]
    record.stop_unit_number = stop.unit_number
    if record.base_name == nil then record.base_name = stop.backer_name end
    if record.initial_name == nil then record.initial_name = stop.backer_name end
    return stop
end

local function select_resource_signal(marker)
    local signals = marker.get_signals(
        defines.wire_connector_id.combinator_input_red,
        defines.wire_connector_id.combinator_input_green
    ) or {}
    local totals = {}

    for _, circuit_signal in pairs(signals) do
        local signal = circuit_signal.signal
        -- Factorio omits SignalID.type for the default item signal type.
        local signal_type = signal and (signal.type or "item")
        local signal_name = signal and signal.name
        if (signal_type == "item" or signal_type == "fluid")
            and type(signal_name) == "string"
            and type(circuit_signal.count) == "number" then
            -- Quality is intentionally omitted from the key in schema 1.
            local key = signal_type .. "\0" .. signal_name
            local total = totals[key]
            if total then
                total.count = total.count + circuit_signal.count
            else
                totals[key] = {
                    type = signal_type,
                    name = signal_name,
                    count = circuit_signal.count,
                }
            end
        end
    end

    local eligible_keys = {}
    for key, signal in pairs(totals) do
        if signal.count > 0 then eligible_keys[#eligible_keys + 1] = key end
    end
    table.sort(eligible_keys)

    if #eligible_keys ~= 1 then return nil end
    return totals[eligible_keys[1]]
end

local function dynamic_name(signal, base_name)
    local icon = string.format("[%s=%s]", signal.type, signal.name)
    if not base_name or base_name == "" then return icon end
    return icon .. " " .. base_name
end

local function process_record(unit_number, record)
    local marker = marker_for_record(record)
    if not marker then
        registrations()[unit_number] = nil
        return
    end

    local stop = resolve_train_stop(record, marker)
    if not stop or not stop.valid then return end

    local signal = select_resource_signal(marker)
    if signal then
        local desired_name = dynamic_name(signal, record.base_name)
        if stop.backer_name ~= desired_name then stop.backer_name = desired_name end
        record.last_signal_type = signal.type
        record.last_signal_name = signal.name
        record.last_applied_name = desired_name
        return
    end

    -- No signal and ambiguous input both preserve the last valid dynamic name.
    -- Before the first valid signal, preserve the stop name captured at pairing.
    local preserved_name = record.last_applied_name or record.initial_name
    if preserved_name and stop.backer_name ~= preserved_name then
        stop.backer_name = preserved_name
    end
end

local function process_all()
    local records = registrations()
    local unit_numbers = {}
    for unit_number in pairs(records) do unit_numbers[#unit_numbers + 1] = unit_number end
    table.sort(unit_numbers)

    for _, unit_number in ipairs(unit_numbers) do
        local record = records[unit_number]
        if record then process_record(unit_number, record) end
    end
end

local function rebuild_registrations()
    local records = registrations()
    local found = {}

    for _, surface in pairs(game.surfaces) do
        local markers = surface.find_entities_filtered({ name = MARKER_NAME })
        table.sort(markers, function(a, b) return a.unit_number < b.unit_number end)
        for _, marker in ipairs(markers) do
            found[marker.unit_number] = true
            register_marker(marker, nil)
        end
    end

    for unit_number in pairs(records) do
        if not found[unit_number] then records[unit_number] = nil end
    end

    process_all()
end

local function blueprint_tags(record)
    return {
        railwright_dynamic_station_name = true,
        railwright_dynamic_name_schema = record.schema or SCHEMA_VERSION,
        railwright_base_name = record.base_name or "",
        railwright_station_type = normalized_station_type(record.station_type),
    }
end

function DynamicStationNames.on_init()
    registrations()
    rebuild_registrations()
end

function DynamicStationNames.on_configuration_changed()
    registrations()
    rebuild_registrations()
end

function DynamicStationNames.on_built(event)
    register_marker(event.entity, event.tags)
end

function DynamicStationNames.on_blueprint_settings_pasted(event)
    register_marker(event.entity, event.tags)
end

function DynamicStationNames.on_entity_settings_pasted(event)
    if not is_real_marker(event.source) or not is_real_marker(event.destination) then return end

    local source_record = register_marker(event.source, nil)
    local destination_record = register_marker(event.destination, nil)
    if not source_record or not destination_record then return end

    resolve_train_stop(source_record, event.source)
    destination_record.base_name = source_record.base_name
    destination_record.station_type = normalized_station_type(source_record.station_type)
    destination_record.schema = source_record.schema or SCHEMA_VERSION
    destination_record.stop_unit_number = nil
    destination_record.initial_name = nil
    destination_record.last_signal_type = nil
    destination_record.last_signal_name = nil
    destination_record.last_applied_name = nil
end

function DynamicStationNames.on_removed(event)
    local entity = event.entity
    if not entity or not entity.valid or not entity.unit_number then return end

    local records = registrations()
    if entity.name == MARKER_NAME then
        records[entity.unit_number] = nil
        return
    end

    if entity.type == "train-stop" then
        for _, record in pairs(records) do
            if record.stop_unit_number == entity.unit_number then
                record.stop_unit_number = nil
            end
        end
    end
end

function DynamicStationNames.on_player_setup_blueprint(event)
    local blueprint = event.stack
    if not blueprint or not blueprint.valid_for_read then blueprint = event.record end
    local lazy_mapping = event.mapping
    if not blueprint or not lazy_mapping or not lazy_mapping.valid then return end

    local mapping = lazy_mapping.get()
    for blueprint_index, marker in pairs(mapping) do
        if is_real_marker(marker) then
            local record = register_marker(marker, nil)
            if record then
                resolve_train_stop(record, marker)
                blueprint.set_blueprint_entity_tags(blueprint_index, blueprint_tags(record))
            end
        end
    end
end

function DynamicStationNames.on_nth_tick()
    process_all()
end

DynamicStationNames.update_interval = UPDATE_INTERVAL

return DynamicStationNames
