local MARKER = "railwright-station-name-combinator"
local Generator = require("__railwright__/scripts/generator")

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

local function count_entities(entities, names)
    local count = 0
    for _, value in ipairs(entities) do
        if names[value.name] then count = count + 1 end
    end
    return count
end

local function diagonal_settings(direction, locomotives, wagons, lanes, double_headed)
    return {
        station_type = "stacker",
        locomotives = locomotives,
        cargo_wagons = wagons,
        double_headed = not double_headed,
        stacker_double_headed = double_headed,
        include_train = true,
        stacker_lanes = lanes,
        stacker_diagonal = true,
        stacker_type = direction,
    }
end

local RAIL_NAMES = {
    ["straight-rail"] = true,
    ["half-diagonal-rail"] = true,
    ["curved-rail-a"] = true,
    ["curved-rail-b"] = true,
}

local ROLLING_STOCK = {
    locomotive = true,
    ["cargo-wagon"] = true,
    ["fluid-wagon"] = true,
}

local DIAGONAL_CASES = {
    { direction = "Left-Right", locomotives = 1, wagons = 1, lanes = 1, double_headed = false },
    { direction = "Left-Right", locomotives = 1, wagons = 1, lanes = 1, double_headed = true },
    { direction = "Left-Right", locomotives = 1, wagons = 4, lanes = 1, double_headed = false,
        entities = 25, rails = 21 },
    { direction = "Left-Right", locomotives = 1, wagons = 4, lanes = 1, double_headed = true,
        entities = 29, rails = 25 },
    { direction = "Left-Right", locomotives = 1, wagons = 4, lanes = 3, double_headed = false },
    { direction = "Left-Right", locomotives = 1, wagons = 4, lanes = 3, double_headed = true },
    { direction = "Right-Left", locomotives = 1, wagons = 1, lanes = 1, double_headed = false },
    { direction = "Right-Left", locomotives = 1, wagons = 1, lanes = 1, double_headed = true },
    { direction = "Right-Left", locomotives = 1, wagons = 4, lanes = 1, double_headed = false,
        entities = 25, rails = 21 },
    { direction = "Right-Left", locomotives = 1, wagons = 4, lanes = 1, double_headed = true,
        entities = 29, rails = 25 },
    { direction = "Right-Left", locomotives = 1, wagons = 4, lanes = 3, double_headed = false },
    { direction = "Right-Left", locomotives = 1, wagons = 4, lanes = 3, double_headed = true },
}

local function create_geometry_test_surface(family, suffix)
    local surface = game.create_surface("__railwright_" .. family .. "_test_" .. suffix, {
        seed = 0,
        default_enable_all_autoplace_controls = false,
        peaceful_mode = true,
        no_enemies_mode = true,
    })
    surface.generate_with_lab_tiles = true
    surface.request_to_generate_chunks({ 0, 0 }, 2)
    surface.force_generate_chunk_requests()
    return surface
end

local function parallel_output_curve(entities, direction, lane_y)
    local first_x
    local last_x
    for _, descriptor in ipairs(entities) do
        if descriptor.name == "straight-rail"
            and descriptor.direction == defines.direction.east
            and descriptor.position.y == lane_y then
            first_x = math.min(first_x or descriptor.position.x, descriptor.position.x)
            last_x = math.max(last_x or descriptor.position.x, descriptor.position.x)
        end
    end
    if not first_x then error(direction .. " parallel lane has no holding rails") end

    local selected
    for _, descriptor in ipairs(entities) do
        if descriptor.name == "curved-rail-a" and descriptor.position.y == lane_y then
            local output_side = direction == "Left-Right" and descriptor.position.x > last_x
                or direction == "Right-Left" and descriptor.position.x < first_x
            if output_side then
                if selected then error(direction .. " parallel lane has multiple output curves") end
                selected = descriptor
            end
        end
    end
    if not selected then error(direction .. " parallel lane has no output curve") end
    return selected
end

local function forward_signal_location(rail, direction)
    local selected
    for _, rail_direction in pairs(defines.rail_direction) do
        local rail_end = rail.get_rail_end(rail_direction)
        if not selected
            or direction == "Left-Right" and rail_end.location.position.x > selected.location.position.x
            or direction == "Right-Left" and rail_end.location.position.x < selected.location.position.x then
            selected = rail_end
        end
    end

    if not selected.move_natural() then error("Parallel output curve is not connected to its next rail") end
    selected.flip_direction()
    return selected.out_signal_location
end

local function check_parallel_stacker(direction, locomotives, wagons, lanes, double_headed, case_index)
    local surface = create_geometry_test_surface("parallel", direction .. "_" .. case_index)
    local entities = Generator.create_entities({
        station_type = "stacker",
        locomotives = locomotives,
        cargo_wagons = wagons,
        stacker_double_headed = double_headed,
        stacker_lanes = lanes,
        stacker_diagonal = false,
        stacker_type = direction,
    })
    local placed_rails = {}

    for _, descriptor in ipairs(entities) do
        if RAIL_NAMES[descriptor.name] then
            local rail = surface.create_entity({
                name = descriptor.name,
                position = descriptor.position,
                direction = descriptor.direction,
                force = game.forces.player,
                create_build_effect_smoke = false,
                raise_built = false,
            })
            if not rail then error("Could not place parallel runtime-test rail") end
            placed_rails[descriptor.entity_number] = rail
        end
    end

    local expected_direction = direction == "Left-Right"
        and defines.direction.eastsoutheast
        or defines.direction.westsouthwest
    local matched = {}
    local label = string.format(
        "%s %s %d-%d %d-lane parallel",
        direction,
        double_headed and "double-headed" or "single-headed",
        locomotives,
        wagons,
        lanes
    )

    check(count_entities(entities, { ["rail-signal"] = true }), lanes, label .. " rail-signal count")
    check(count_entities(entities, ROLLING_STOCK), 0, label .. " rolling-stock count")

    for lane = 0, lanes - 1 do
        local anchor = parallel_output_curve(entities, direction, lane * 4)
        local location = forward_signal_location(placed_rails[anchor.entity_number], direction)
        local signal
        for _, descriptor in ipairs(entities) do
            if descriptor.name == "rail-signal"
                and descriptor.position.x + 1 == location.position.x
                and descriptor.position.y + 1 == location.position.y
                and descriptor.direction == location.direction then
                signal = descriptor
                break
            end
        end
        if not signal then error(label .. " lane exit signal does not use Factorio's forward rail attachment") end
        check(signal.direction, expected_direction, label .. " lane exit-signal direction")
        matched[signal.entity_number] = true
    end

    check(table_size(matched), lanes, label .. " matched exit-signal count")
    game.delete_surface(surface)
end

local function check_parallel_stackers()
    local cases = {
        { locomotives = 1, wagons = 1, lanes = 3, double_headed = false },
        { locomotives = 1, wagons = 4, lanes = 1, double_headed = true },
    }
    for _, direction in ipairs({ "Left-Right", "Right-Left" }) do
        for case_index, test_case in ipairs(cases) do
            check_parallel_stacker(
                direction,
                test_case.locomotives,
                test_case.wagons,
                test_case.lanes,
                test_case.double_headed,
                case_index
            )
        end
    end
    log("[Railwright automated runtime test] Parallel stackers PASS")
end

local function same_rail_location(descriptor, location)
    return location
        and descriptor.position.x == location.position.x
        and descriptor.position.y == location.position.y
        and descriptor.direction == location.direction
end

local function matching_signal_ends(descriptor, placed_rails, terminal_only)
    local matches = { incoming = 0, outgoing = 0 }

    for _, rail in pairs(placed_rails) do
        for _, rail_direction in pairs(defines.rail_direction) do
            local rail_end = rail.get_rail_end(rail_direction)
            local terminal = not rail_end.move_natural()
            if not terminal_only or terminal then
                rail_end = rail.get_rail_end(rail_direction)
                if same_rail_location(descriptor, rail_end.in_signal_location) then
                    matches.incoming = matches.incoming + 1
                end
                if same_rail_location(descriptor, rail_end.out_signal_location) then
                    matches.outgoing = matches.outgoing + 1
                end
            end
        end
    end

    return matches
end

local function sort_lane_signals(signals, direction)
    table.sort(signals, function(a, b)
        if direction == "Left-Right" then
            if a.position.y ~= b.position.y then return a.position.y < b.position.y end
            return a.position.x < b.position.x
        end
        if a.position.x ~= b.position.x then return a.position.x < b.position.x end
        return a.position.y < b.position.y
    end)
end

local function check_diagonal_signal_geometry(entities, test_case, label)
    local surface = create_geometry_test_surface("diagonal", tostring(test_case.runtime_index))
    local placed_rails = {}
    local normal_signals = {}
    local chain_signals = {}

    for _, descriptor in ipairs(entities) do
        if RAIL_NAMES[descriptor.name] then
            local rail = surface.create_entity({
                name = descriptor.name,
                position = descriptor.position,
                direction = descriptor.direction,
                force = game.forces.player,
                create_build_effect_smoke = false,
                raise_built = false,
            })
            if not rail then error(label .. " could not place a runtime-test rail") end
            placed_rails[#placed_rails + 1] = rail
        elseif descriptor.name == "rail-signal" then
            normal_signals[#normal_signals + 1] = descriptor
        elseif descriptor.name == "rail-chain-signal" then
            chain_signals[#chain_signals + 1] = descriptor
        end
    end

    local terminal_incoming = {}
    local terminal_outgoing = {}
    local lane_chains = {}

    for _, signal in ipairs(normal_signals) do
        local matches = matching_signal_ends(signal, placed_rails, false)
        if matches.incoming == 0 then
            error(label .. " normal signal is not attached to an incoming rail end")
        end
    end

    for _, signal in ipairs(chain_signals) do
        local all_matches = matching_signal_ends(signal, placed_rails, false)
        if all_matches.incoming == 0 and all_matches.outgoing == 0 then
            error(label .. " chain signal is not attached to a rail end")
        end

        local terminal_matches = matching_signal_ends(signal, placed_rails, true)
        if terminal_matches.incoming > 0 then
            terminal_incoming[#terminal_incoming + 1] = signal
        elseif terminal_matches.outgoing > 0 then
            terminal_outgoing[#terminal_outgoing + 1] = signal
        else
            if all_matches.incoming == 0 then
                error(label .. " lane chain signal is not attached to an incoming rail end")
            end
            lane_chains[#lane_chains + 1] = signal
        end
    end

    check(#terminal_incoming, 1, label .. " terminal entrance chain-signal count")
    check(#terminal_outgoing, 1, label .. " terminal exit chain-signal count")
    check(#lane_chains, test_case.lanes, label .. " lane chain-signal count")

    local entrance = terminal_incoming[1]
    local exit = terminal_outgoing[1]
    if test_case.direction == "Left-Right" and exit.position.x <= entrance.position.x then
        error(label .. " entrance and exit sides describe Right-Left travel")
    elseif test_case.direction == "Right-Left" and exit.position.x >= entrance.position.x then
        error(label .. " entrance and exit sides describe Left-Right travel")
    end

    sort_lane_signals(normal_signals, test_case.direction)
    sort_lane_signals(lane_chains, test_case.direction)

    for lane = 1, test_case.lanes do
        local normal = normal_signals[lane]
        local chain = lane_chains[lane]
        check(normal.direction, chain.direction, label .. " lane signal direction " .. lane)
        if test_case.direction == "Left-Right" and chain.position.x <= normal.position.x then
            error(label .. " lane " .. lane .. " normal signal is not before its exit chain signal")
        elseif test_case.direction == "Right-Left" and chain.position.x >= normal.position.x then
            error(label .. " lane " .. lane .. " normal signal is not before its exit chain signal")
        end

        if lane > 1 then
            local previous_normal = normal_signals[lane - 1]
            local previous_chain = lane_chains[lane - 1]
            if test_case.direction == "Left-Right" then
                check(normal.position.x, previous_normal.position.x, label .. " normal-signal lane X")
                check(normal.position.y - previous_normal.position.y, 4, label .. " normal-signal lane Y step")
                check(chain.position.x, previous_chain.position.x, label .. " chain-signal lane X")
                check(chain.position.y - previous_chain.position.y, 4, label .. " chain-signal lane Y step")
            else
                check(normal.position.x - previous_normal.position.x, 4, label .. " normal-signal lane X step")
                check(normal.position.y, previous_normal.position.y, label .. " normal-signal lane Y")
                check(chain.position.x - previous_chain.position.x, 4, label .. " chain-signal lane X step")
                check(chain.position.y, previous_chain.position.y, label .. " chain-signal lane Y")
            end
        end
    end

    game.delete_surface(surface)
end

local function check_diagonal_stacker(test_case)
    -- The native geometry surface cannot be deleted and recreated in one tick,
    -- so the runtime suite schedules one generation case per tick.
    local entities = Generator.create_entities(diagonal_settings(
        test_case.direction,
        test_case.locomotives,
        test_case.wagons,
        test_case.lanes,
        test_case.double_headed
    ))
    local heading = test_case.double_headed and "double-headed" or "single-headed"
    local label = string.format(
        "%s %s %d-%d %d-lane diagonal",
        test_case.direction,
        heading,
        test_case.locomotives,
        test_case.wagons,
        test_case.lanes
    )
    local rail_count = count_entities(entities, RAIL_NAMES)

    check(count_entities(entities, ROLLING_STOCK), 0, label .. " rolling-stock count")
    check(count_entities(entities, { ["rail-signal"] = true }), test_case.lanes,
        label .. " rail-signal count")
    check(count_entities(entities, { ["rail-chain-signal"] = true }), test_case.lanes + 2,
        label .. " chain-signal count")

    if test_case.entities then
        check(#entities, test_case.entities, label .. " entity count")
        check(rail_count, test_case.rails, label .. " rail count")
    end

    local sizing_key = table.concat({
        test_case.direction,
        test_case.locomotives,
        test_case.wagons,
        test_case.lanes,
    }, ":")
    if not test_case.double_headed then
        storage.diagonal_single_rails[sizing_key] = rail_count
    elseif rail_count <= (storage.diagonal_single_rails[sizing_key] or math.huge) then
        error(label .. " did not lengthen its holding rails")
    end

    check_diagonal_signal_geometry(entities, test_case, label)
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
    storage.diagonal_single_rails = {}
    check_parallel_stackers()
end)

script.on_event(defines.events.on_tick, function(event)
    local diagonal_case = DIAGONAL_CASES[event.tick]
    if diagonal_case then
        diagonal_case.runtime_index = event.tick
        check_diagonal_stacker(diagonal_case)
        if event.tick == #DIAGONAL_CASES then
            log("[Railwright automated runtime test] Diagonal stackers PASS")
        end
    end

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
