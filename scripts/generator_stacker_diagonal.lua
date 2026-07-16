local Builder = require("scripts.generator_builder")

local DiagonalStacker = {}

local TEMP_SURFACE_NAME = "__railwright_native_rail_geometry"
local RAIL_PLANNER_NAME = "rail"
local LANE_SPACING = 4
local CURVE_STEPS = 2
local TRUNK_STRAIGHTS = 2

local function modulo(value, divisor)
    return ((value % divisor) + divisor) % divisor
end

local function rounded(value)
    return math.floor(value + 0.5)
end

local function normalize_stacker_type(stacker_type)
    return stacker_type == "Right-Left" and "Right-Left" or "Left-Right"
end

local function diagonal_straight_steps(settings)
    local double_factor = settings.double_headed and 2 or 1
    local legacy_length = rounded((2.5 * (double_factor * settings.locomotives + settings.cargo_wagons)) / 2) * 2 + 1

    -- The compatibility-era generator emitted two diagonal straight rails for
    -- every legacy length step. Keep the same scaling while letting Factorio's
    -- native rail planner choose the exact modern straight-rail sequence.
    return math.max(2, legacy_length * 2)
end

local function make_unique_adder(builder)
    local seen = {}

    return function(name, x, y, options)
        options = options or {}
        local key = table.concat({
            name,
            string.format("%.3f", x),
            string.format("%.3f", y),
            options.direction == nil and "" or tostring(options.direction),
        }, "|")

        if seen[key] then return seen[key] end

        local created = builder:add(name, x, y, options)
        seen[key] = created
        return created
    end
end

local function copy_position(position)
    return { x = position.x, y = position.y }
end

local function copy_location(location)
    if not location then return nil end

    return {
        position = copy_position(location.position),
        direction = location.direction,
    }
end

local function entity_descriptor(entity)
    return {
        name = entity.name,
        position = copy_position(entity.position),
        direction = entity.direction,
    }
end

local function signed_direction_delta(from_direction, to_direction)
    local delta = modulo(to_direction - from_direction, 16)
    if delta > 8 then delta = delta - 16 end
    return delta
end

local function connection_direction(turn)
    if turn < 0 then return defines.rail_connection_direction.left end
    if turn > 0 then return defines.rail_connection_direction.right end
    return defines.rail_connection_direction.straight
end

local function choose_extension(rail_end, turn)
    local current_direction = rail_end.location.direction
    local selected
    local selected_delta

    for _, extension in pairs(rail_end.get_rail_extensions(RAIL_PLANNER_NAME)) do
        local delta = signed_direction_delta(current_direction, extension.goal.direction)
        local matches = turn == 0 and delta == 0
            or turn < 0 and delta < 0
            or turn > 0 and delta > 0

        if matches and (not selected_delta or math.abs(delta) < math.abs(selected_delta)) then
            selected = extension
            selected_delta = delta
        end
    end

    if not selected then
        error(string.format(
            "Railwright could not find a native rail extension from direction %s for turn %s.",
            tostring(current_direction),
            tostring(turn)
        ))
    end

    return selected
end

local function chunk_key(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

local function prepare_chunk(surface, prepared_chunks, chunk_x, chunk_y)
    local key = chunk_key(chunk_x, chunk_y)
    if prepared_chunks[key] then return end

    local center = {
        x = chunk_x * 32 + 16,
        y = chunk_y * 32 + 16,
    }

    if not surface.is_chunk_generated({ x = chunk_x, y = chunk_y }) then
        surface.request_to_generate_chunks(center, 1)
        surface.force_generate_chunk_requests()
    end

    local tiles = {}
    for x = chunk_x * 32, chunk_x * 32 + 31 do
        for y = chunk_y * 32, chunk_y * 32 + 31 do
            tiles[#tiles + 1] = {
                name = "landfill",
                position = { x = x, y = y },
            }
        end
    end
    surface.set_tiles(tiles)

    prepared_chunks[key] = true
end

local function prepare_position(surface, prepared_chunks, position)
    local chunk_x = math.floor(position.x / 32)
    local chunk_y = math.floor(position.y / 32)

    -- Curved rails can extend several tiles beyond their entity position. Keep
    -- a one-chunk land corridor around the path so script-created test rails do
    -- not fail because a generated chunk happened to contain water or cliffs.
    for x = chunk_x - 1, chunk_x + 1 do
        for y = chunk_y - 1, chunk_y + 1 do
            prepare_chunk(surface, prepared_chunks, x, y)
        end
    end
end

local function find_end_facing(rail, wanted_direction)
    for _, rail_direction in pairs(defines.rail_direction) do
        local rail_end = rail.get_rail_end(rail_direction)
        if rail_end.location.direction == wanted_direction then return rail_end end
    end

    error(string.format(
        "Railwright could not find the %s-facing end of native rail '%s' at (%.3f, %.3f).",
        tostring(wanted_direction),
        rail.name,
        rail.position.x,
        rail.position.y
    ))
end

local function extend(surface, prepared_chunks, rail_end, turn, rail_entities)
    local extension = choose_extension(rail_end, turn)
    prepare_position(surface, prepared_chunks, extension.position)

    local rail = surface.create_entity({
        name = extension.name,
        position = extension.position,
        direction = extension.direction,
        force = game.forces.player,
        create_build_effect_smoke = false,
        raise_built = false,
    })

    if not rail then
        error(string.format(
            "Railwright could not place temporary native rail '%s' at (%.3f, %.3f).",
            extension.name,
            extension.position.x,
            extension.position.y
        ))
    end

    rail_entities[#rail_entities + 1] = entity_descriptor(rail)

    if not rail_end.move_forward(connection_direction(turn)) then
        error(string.format(
            "Railwright placed native rail '%s' but could not traverse into it.",
            extension.name
        ))
    end

    return rail
end

local function create_geometry_surface()
    local stale_surface = game.surfaces[TEMP_SURFACE_NAME]
    if stale_surface then game.delete_surface(stale_surface) end

    return game.create_surface(TEMP_SURFACE_NAME, {
        seed = 0,
        default_enable_all_autoplace_controls = false,
        peaceful_mode = true,
        no_enemies_mode = true,
    })
end

local function build_lane_template(settings, heading, first_turn)
    local surface = create_geometry_surface()
    local prepared_chunks = {}

    local ok, result = pcall(function()
        prepare_position(surface, prepared_chunks, { x = 0, y = 0 })

        local seed = surface.create_entity({
            name = "straight-rail",
            position = { x = 0, y = 0 },
            direction = heading,
            force = game.forces.player,
            create_build_effect_smoke = false,
            raise_built = false,
        })

        if not seed then error("Railwright could not create the temporary native seed rail.") end

        local rail_entities = { entity_descriptor(seed) }
        local forward = find_end_facing(seed, heading)
        local entrance = copy_location(find_end_facing(seed, modulo(heading + 8, 16)).out_signal_location)

        for _ = 2, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        for _ = 1, CURVE_STEPS do
            extend(surface, prepared_chunks, forward, first_turn, rail_entities)
        end
        local lane_entry_signal = copy_location(forward.out_signal_location)

        for _ = 1, diagonal_straight_steps(settings) do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        for _ = 1, CURVE_STEPS do
            extend(surface, prepared_chunks, forward, -first_turn, rail_entities)
        end
        local lane_exit_signal = copy_location(forward.out_signal_location)

        for _ = 1, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        return {
            rails = rail_entities,
            entrance_signal = entrance,
            lane_entry_signal = lane_entry_signal,
            lane_exit_signal = lane_exit_signal,
        }
    end)

    if surface and surface.valid then game.delete_surface(surface) end

    if not ok then error(result, 0) end
    return result
end

local function append_lane(builder, add, template, x_offset, y_offset)
    for _, rail in ipairs(template.rails) do
        add(rail.name, rail.position.x + x_offset, rail.position.y + y_offset, {
            direction = rail.direction,
        })
    end

    add(
        "rail-chain-signal",
        template.lane_entry_signal.position.x + x_offset,
        template.lane_entry_signal.position.y + y_offset,
        { direction = template.lane_entry_signal.direction }
    )

    add(
        "rail-signal",
        template.lane_exit_signal.position.x + x_offset,
        template.lane_exit_signal.position.y + y_offset,
        { direction = template.lane_exit_signal.direction }
    )
end

function DiagonalStacker.generate(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)
    local stacker_type = normalize_stacker_type(settings.stacker_type)

    local heading
    local first_turn
    local lane_step_x
    local lane_step_y

    if stacker_type == "Left-Right" then
        heading = defines.direction.east
        first_turn = 1
        lane_step_x = LANE_SPACING
        lane_step_y = 0
    else
        heading = defines.direction.south
        first_turn = 1
        lane_step_x = 0
        lane_step_y = LANE_SPACING
    end

    local template = build_lane_template(settings, heading, first_turn)

    for lane = 0, settings.stacker_lanes - 1 do
        append_lane(builder, add, template, lane * lane_step_x, lane * lane_step_y)
    end

    add(
        "rail-chain-signal",
        template.entrance_signal.position.x,
        template.entrance_signal.position.y,
        { direction = template.entrance_signal.direction }
    )

    return builder.entities
end

return DiagonalStacker
