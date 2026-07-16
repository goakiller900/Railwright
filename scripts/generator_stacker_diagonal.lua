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

    -- The old diagonal template used pairs of compatibility-era straight rails
    -- for each length step. Native 2.1 diagonal rails cover that path with one
    -- planner extension per step, while the modern curve transitions consume
    -- two of the old straight-length steps.
    return math.max(2, legacy_length - 2)
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

    if not surface.is_chunk_generated({ x = chunk_x, y = chunk_y }) then
        surface.request_to_generate_chunks({
            x = chunk_x * 32 + 16,
            y = chunk_y * 32 + 16,
        }, 0)
        surface.force_generate_chunk_requests()
    end

    prepared_chunks[key] = true
end

local function prepare_position(surface, prepared_chunks, position)
    local chunk_x = math.floor(position.x / 32)
    local chunk_y = math.floor(position.y / 32)

    -- Curved rails can extend several tiles beyond their entity position. Keep
    -- a one-chunk lab-tile corridor around the path so temporary geometry never
    -- depends on the active save's terrain or collision layout.
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
end

local function create_geometry_surface()
    local stale_surface = game.surfaces[TEMP_SURFACE_NAME]
    if stale_surface then game.delete_surface(stale_surface) end

    local surface = game.create_surface(TEMP_SURFACE_NAME, {
        seed = 0,
        default_enable_all_autoplace_controls = false,
        peaceful_mode = true,
        no_enemies_mode = true,
    })
    surface.generate_with_lab_tiles = true
    return surface
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
        local entrance_end = find_end_facing(seed, modulo(heading + 8, 16))
        local entrance_signal = copy_location(entrance_end.in_signal_location)

        for _ = 2, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        for _ = 1, CURVE_STEPS do
            extend(surface, prepared_chunks, forward, first_turn, rail_entities)
        end

        local diagonal_signal_points = {}
        for step = 1, diagonal_straight_steps(settings) do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
            diagonal_signal_points[step] = copy_location(forward.out_signal_location)
        end

        local first_exit_signal
        for step = 1, CURVE_STEPS do
            extend(surface, prepared_chunks, forward, -first_turn, rail_entities)
            if step == 1 then first_exit_signal = copy_location(forward.out_signal_location) end
        end

        for _ = 1, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        return {
            rails = rail_entities,
            entrance_signal = entrance_signal,
            exit_signal = copy_location(forward.out_signal_location),
            diagonal_signal_points = diagonal_signal_points,
            first_exit_signal = first_exit_signal,
        }
    end)

    if surface and surface.valid then game.delete_surface(surface) end

    if not ok then error(result, 0) end
    return result
end

local function add_signal(add, name, location, x_offset, y_offset)
    -- set_blueprint_entities() canonicalizes native rail positions by +1,+1
    -- while signals keep their supplied coordinates. Apply the same translation
    -- here so diagonal signals stay attached to the rail locations chosen on the
    -- temporary geometry surface.
    add(
        name,
        location.position.x + (x_offset or 0) + 1,
        location.position.y + (y_offset or 0) + 1,
        { direction = location.direction }
    )
end

local function append_lane(add, template, lane, lane_count, x_offset, y_offset)
    for _, rail in ipairs(template.rails) do
        add(rail.name, rail.position.x + x_offset, rail.position.y + y_offset, {
            direction = rail.direction,
        })
    end

    -- Stagger the lane-entry chain signals across the diagonal straights. This
    -- reproduces the manually verified fan layout instead of copying every
    -- signal from the same point on the lane template.
    local entry_index = math.min(#template.diagonal_signal_points, math.max(1, lane_count - lane))
    add_signal(
        add,
        "rail-chain-signal",
        template.diagonal_signal_points[entry_index],
        x_offset,
        y_offset
    )

    -- The first lane can use the first exit curve; each following lane steps
    -- one rail back along the diagonal. This keeps the regular signals clear of
    -- the converging fan and matches both verified diagonal orientations.
    local exit_location
    if lane == 0 then
        exit_location = template.first_exit_signal
    else
        local exit_index = math.max(1, #template.diagonal_signal_points - lane + 1)
        exit_location = template.diagonal_signal_points[exit_index]
    end

    add_signal(add, "rail-signal", exit_location, x_offset, y_offset)
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
        append_lane(
            add,
            template,
            lane,
            settings.stacker_lanes,
            lane * lane_step_x,
            lane * lane_step_y
        )
    end

    add_signal(add, "rail-chain-signal", template.entrance_signal, 0, 0)

    local last_lane = settings.stacker_lanes - 1
    add_signal(
        add,
        "rail-chain-signal",
        template.exit_signal,
        last_lane * lane_step_x,
        last_lane * lane_step_y
    )

    return builder.entities
end

return DiagonalStacker
