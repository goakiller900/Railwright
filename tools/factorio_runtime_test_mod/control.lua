local MARKER = "railwright-station-name-combinator"

local function check(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected '%s', got '%s'", label, expected, tostring(actual)))
    end
end

local function entity(unit_number)
    local result = game.get_entity_by_unit_number(unit_number)
    if not result or not result.valid then error("Missing test entity " .. tostring(unit_number)) end
    return result
end

local function placed_entity(name, position)
    local result = game.surfaces[1].find_entity(name, position)
    if not result or not result.valid then error("Missing test entity " .. name) end
    return result
end

local function connect(source, source_id, target, target_id)
    local source_connector = source.get_wire_connector(source_id, true)
    local target_connector = target.get_wire_connector(target_id, true)
    if not source_connector.connect_to(target_connector, false) then
        error("Could not create test circuit connection")
    end
end

local function set_signals(combinator, filters)
    local behavior = combinator.get_or_create_control_behavior()
    local section = behavior.get_section(1) or behavior.add_section()
    section.filters = filters
end

local function filter(signal_type, name, count)
    local value = { type = signal_type, name = name }
    if signal_type == "item" then
        value.quality = "normal"
        value.comparator = "="
    end
    return { value = value, min = count }
end

local function signal_summary(marker)
    local signals = marker.get_signals(
        defines.wire_connector_id.combinator_input_red,
        defines.wire_connector_id.combinator_input_green
    ) or {}
    local parts = {}
    for _, value in pairs(signals) do
        parts[#parts + 1] = string.format("%s:%s=%s", value.signal.type, value.signal.name, value.count)
    end
    table.sort(parts)
    return table.concat(parts, ",")
end

script.on_init(function()
    local surface = game.surfaces[1]
    local force = game.forces.player

    local stop = surface.create_entity({ name = "train-stop", position = { 0, 0 }, force = force })
    local marker = surface.create_entity({ name = MARKER, position = { 3, 0 }, force = force })
    local green = surface.create_entity({ name = "constant-combinator", position = { 5, 0 }, force = force })
    local red = surface.create_entity({ name = "constant-combinator", position = { 5, 2 }, force = force })
    local tank = surface.create_entity({ name = "storage-tank", position = { 8, 2 }, force = force })
    if not stop or not marker or not green or not red or not tank then error("Could not create primary test station") end
    stop.backer_name = "Load"

    connect(green, defines.wire_connector_id.circuit_green, marker,
        defines.wire_connector_id.combinator_input_green)
    connect(red, defines.wire_connector_id.circuit_red, marker,
        defines.wire_connector_id.combinator_input_red)
    connect(tank, defines.wire_connector_id.circuit_red, marker,
        defines.wire_connector_id.combinator_input_red)
    connect(marker, defines.wire_connector_id.combinator_output_red, stop,
        defines.wire_connector_id.circuit_red)

    script.raise_script_revive({
        entity = marker,
        tags = {
            railwright_dynamic_station_name = true,
            railwright_dynamic_name_schema = 1,
            railwright_base_name = "Load",
            railwright_station_type = "loading",
        },
    })

    set_signals(green, { filter("item", "iron-ore", 100) })
    set_signals(red, {})
    storage.primary = {
        marker = marker.unit_number,
        stop = stop.unit_number,
        green_position = { x = green.position.x, y = green.position.y },
        red_position = { x = red.position.x, y = red.position.y },
        tank_position = { x = tank.position.x, y = tank.position.y },
    }

    local manual_stop = surface.create_entity({ name = "train-stop", position = { 0, 10 }, force = force })
    local manual_marker = surface.create_entity({ name = MARKER, position = { 3, 10 }, force = force })
    local manual_signal = surface.create_entity({ name = "constant-combinator", position = { 5, 10 }, force = force })
    if not manual_stop or not manual_marker or not manual_signal then error("Could not create manual test station") end
    manual_stop.backer_name = "Unload"
    connect(manual_signal, defines.wire_connector_id.circuit_green, manual_marker,
        defines.wire_connector_id.combinator_input_green)
    connect(manual_marker, defines.wire_connector_id.combinator_output_red, manual_stop,
        defines.wire_connector_id.circuit_red)
    script.raise_script_built({ entity = manual_marker })
    set_signals(manual_signal, { filter("item", "copper-plate", 25) })
    storage.manual = {
        marker = manual_marker.unit_number,
        stop = manual_stop.unit_number,
    }
end)

script.on_event(defines.events.on_tick, function(event)
    local primary = storage.primary
    local stop = entity(primary.stop)
    local marker = game.get_entity_by_unit_number(primary.marker)
    local green = placed_entity("constant-combinator", primary.green_position)
    local red = placed_entity("constant-combinator", primary.red_position)
    local tank = placed_entity("storage-tank", primary.tank_position)

    if event.tick == 61 then
        check(stop.backer_name, "[item=iron-ore] Load", "one item (signals: " .. signal_summary(marker) .. ")")
        check(entity(storage.manual.stop).backer_name, "[item=copper-plate] Unload", "script-built manual marker")
        set_signals(green, { filter("item", "copper-plate", 50) })
    elseif event.tick == 121 then
        check(stop.backer_name, "[item=copper-plate] Load", "signal change")
        set_signals(green, {})
    elseif event.tick == 181 then
        check(stop.backer_name, "[item=copper-plate] Load", "no signal preservation")
        set_signals(green, {
            filter("item", "iron-ore", 10),
            filter("item", "copper-plate", 10),
        })
    elseif event.tick == 241 then
        check(stop.backer_name, "[item=copper-plate] Load", "ambiguous item preservation")
        set_signals(green, { filter("item", "iron-ore", 10) })
        set_signals(red, { filter("item", "iron-ore", 20) })
    elseif event.tick == 301 then
        check(stop.backer_name, "[item=iron-ore] Load", "same item on red and green")
        set_signals(red, {})
        tank.set_fluid(1, { name = "crude-oil", amount = 20, temperature = 25 })
    elseif event.tick == 361 then
        check(stop.backer_name, "[item=iron-ore] Load", "item and fluid ambiguity")
        set_signals(green, {})
    elseif event.tick == 421 then
        check(stop.backer_name, "[fluid=crude-oil] Load", "one fluid (signals: " .. signal_summary(marker) .. ")")
        stop.backer_name = "Manual edit"
    elseif event.tick == 481 then
        check(stop.backer_name, "[fluid=crude-oil] Load", "manual rename restoration")
        local output = marker.get_wire_connector(defines.wire_connector_id.combinator_output_red, false)
        local stop_input = stop.get_wire_connector(defines.wire_connector_id.circuit_red, false)
        output.disconnect_from(stop_input)
        stop.backer_name = "Disconnected"
    elseif event.tick == 541 then
        check(stop.backer_name, "Disconnected", "disconnected output stays pending")
        connect(marker, defines.wire_connector_id.combinator_output_red, stop,
            defines.wire_connector_id.circuit_red)
    elseif event.tick == 601 then
        check(stop.backer_name, "[fluid=crude-oil] Load", "reconnected output recovers")
        local second = game.surfaces[1].create_entity({
            name = "train-stop",
            position = { 0, 4 },
            force = game.forces.player,
        })
        if not second then error("Could not create second train stop") end
        second.backer_name = "Second"
        connect(marker, defines.wire_connector_id.combinator_output_red, second,
            defines.wire_connector_id.circuit_red)
        stop.backer_name = "Ambiguous association"
        storage.second_stop = second.unit_number
    elseif event.tick == 661 then
        check(stop.backer_name, "Ambiguous association", "two-stop ambiguity")
        entity(storage.second_stop).destroy({ raise_destroy = true })
    elseif event.tick == 721 then
        check(stop.backer_name, "[fluid=crude-oil] Load", "ambiguity removal recovers")
        stop.destroy({ raise_destroy = true })
        local replacement = game.surfaces[1].create_entity({
            name = "train-stop",
            position = { 0, 0 },
            force = game.forces.player,
        })
        if not replacement then error("Could not create replacement train stop") end
        replacement.backer_name = "Replacement"
        connect(marker, defines.wire_connector_id.combinator_output_red, replacement,
            defines.wire_connector_id.circuit_red)
        primary.stop = replacement.unit_number
    elseif event.tick == 781 then
        check(entity(primary.stop).backer_name, "[fluid=crude-oil] Load", "destroyed stop replacement")
        marker.destroy({ raise_destroy = true })
        entity(primary.stop).backer_name = "Unmanaged"
    elseif event.tick == 841 then
        check(entity(primary.stop).backer_name, "Unmanaged", "marker removal disables management")
        log("[Railwright automated runtime test] PASS")
    end
end)
