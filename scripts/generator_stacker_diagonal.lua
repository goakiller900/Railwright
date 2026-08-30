-- Experimental native diagonal stacker generator. It asks Factorio's own rail
-- planner to create one lane template on a temporary lab-tile surface, records
-- canonical rail/signal locations, then offsets that template for every lane.
local Builder = require("scripts.generator_builder")
local Common = require("scripts.generator_common")
local Debug = require("scripts.generator_debug")

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
    -- Preserve the existing single-headed native-rail geometry exactly while
    -- allowing the shared total-car rule to count locomotives at both ends.
    local legacy_length = rounded((2.5 * Common.total_cars(settings)) / 2) * 2 + 1
    local train_steps = math.max(2, legacy_length)

    -- A 1-4 train needs 13 native diagonal straights to clear both fan curves.
    -- Four steps beyond the lane count preserve usable holding length as either
    -- fan widens; both orientations were validated with the same rule.
    local fan_clearance_steps = settings.stacker_lanes + 4
    return math.max(train_steps, fan_clearance_steps)
end

-- Expose the pure sizing result for geometry regression tests; generation still
-- uses the same function below to construct the native rail template.
function DiagonalStacker.holding_straight_steps(settings)
    return diagonal_straight_steps(settings)
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
    -- Select the smallest signed heading change matching left/straight/right.
    -- Keep Factorio's first equal-angle candidate: rail extensions can share a
    -- heading while targeting different rail layers, and re-sorting those ties
    -- can accidentally select elevated geometry.
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

    local requested = false
    if not surface.is_chunk_generated({ x = chunk_x, y = chunk_y }) then
        surface.request_to_generate_chunks({
            x = chunk_x * 32 + 16,
            y = chunk_y * 32 + 16,
        }, 0)
        requested = true
    end

    prepared_chunks[key] = true
    return requested
end

local function prepare_position(surface, prepared_chunks, position)
    local chunk_x = math.floor(position.x / 32)
    local chunk_y = math.floor(position.y / 32)

    local requested = false
    for x = chunk_x - 1, chunk_x + 1 do
        for y = chunk_y - 1, chunk_y + 1 do
            requested = prepare_chunk(surface, prepared_chunks, x, y) or requested
        end
    end

    -- Generate the entire requested 3x3 neighborhood in one blocking call.
    if requested then surface.force_generate_chunk_requests() end
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

    local surface = game.create_surface(TEMP_SURFACE_NAME, {
        seed = 0,
        default_enable_all_autoplace_controls = false,
        peaceful_mode = true,
        no_enemies_mode = true,
    })
    surface.generate_with_lab_tiles = true
    return surface
end

local function same_end(left, right)
    return left.location.direction == right.location.direction
        and left.location.position.x == right.location.position.x
        and left.location.position.y == right.location.position.y
end

local function opposite_end(rail, current_end)
    for _, rail_direction in pairs(defines.rail_direction) do
        local candidate = rail.get_rail_end(rail_direction)
        if not same_end(candidate, current_end) then return candidate end
    end

    error(string.format(
        "Railwright could not find the opposite end of native rail '%s' at (%.3f, %.3f).",
        rail.name,
        rail.position.x,
        rail.position.y
    ))
end

local function build_lane_template(settings, heading, first_turn)
    -- Temporary entities are necessary because modern 2.1 curve/diagonal snapping
    -- is defined by the active rail planner rather than simple coordinate math.
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
        local entrance_signal = copy_location(entrance_end.out_signal_location)

        for _ = 2, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
        end

        local entry_curve_ends = {}
        for curve_step = 1, CURVE_STEPS do
            local rail = extend(surface, prepared_chunks, forward, first_turn, rail_entities)
            entry_curve_ends[curve_step] = {
                far_incoming = copy_location(forward.in_signal_location),
                far_alternative_incoming = copy_location(forward.alternative_in_signal_location),
                near_outgoing = copy_location(opposite_end(rail, forward).out_signal_location),
            }
        end

        local diagonal_in_signal_points = {}
        local straight_steps = diagonal_straight_steps(settings)

        for step = 1, straight_steps do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
            diagonal_in_signal_points[step] = copy_location(forward.in_signal_location)
        end

        local exit_curve_signal_points = {}
        for curve_step = 1, CURVE_STEPS do
            extend(surface, prepared_chunks, forward, -first_turn, rail_entities)
            exit_curve_signal_points[curve_step == 1 and 1 or 3] = copy_location(forward.in_signal_location)
            if curve_step == 1 and forward.alternative_in_signal_location then
                exit_curve_signal_points[2] = copy_location(forward.alternative_in_signal_location)
            end
        end

        for trunk_step = 1, TRUNK_STRAIGHTS do
            extend(surface, prepared_chunks, forward, 0, rail_entities)
            exit_curve_signal_points[3 + trunk_step] = copy_location(forward.in_signal_location)
        end

        return {
            rails = rail_entities,
            entrance_signal = entrance_signal,
            exit_signal = copy_location(forward.in_signal_location),
            diagonal_in_signal_points = diagonal_in_signal_points,
            entry_curve_ends = entry_curve_ends,
            exit_curve_signal_points = exit_curve_signal_points,
        }
    end)

    if surface and surface.valid then game.delete_surface(surface) end

    if not ok then error(result, 0) end
    return result
end

local function add_signal(add, name, location, x_offset, y_offset, diagnostic)
    -- These locations come from real rail entities on the temporary geometry
    -- surface and are already in Factorio's canonical native-rail coordinate
    -- system. Unlike the hand-authored parallel layout, they need no +1,+1 shift.
    local x = location.position.x + (x_offset or 0)
    local y = location.position.y + (y_offset or 0)
    add(
        name,
        x,
        y,
        { direction = location.direction }
    )

    if diagnostic and diagnostic.enabled then
        Debug.log_diagonal_signal({
            lane = diagnostic.lane,
            lane_number = diagnostic.lane == nil and nil or diagnostic.lane + 1,
            signal_type = name,
            role = diagnostic.role,
            source = diagnostic.source,
            source_index = diagnostic.source_index,
            source_position = copy_position(location.position),
            final_position = { x = x, y = y },
            direction = location.direction,
        })
    end
end

local function left_right_entry_location(template, lane, last_lane)
    local distance_from_outer_lane = last_lane - lane
    if distance_from_outer_lane == 0 then return template.diagonal_in_signal_points[1], "diagonal", 1 end

    local last_curve = template.entry_curve_ends[CURVE_STEPS]
    if distance_from_outer_lane == 1 then return last_curve.far_incoming, "entry curve", 1 end
    if distance_from_outer_lane == 2 then return last_curve.near_outgoing, "entry curve", 2 end

    local first_curve = template.entry_curve_ends[1]
    if distance_from_outer_lane == 3 then return first_curve.far_incoming, "entry curve", 3 end
    return first_curve.far_alternative_incoming or first_curve.near_outgoing, "entry curve", 4
end

local function left_right_exit_location(template, lane, last_lane)
    local fan_offset = lane * 2 - last_lane
    if fan_offset <= 0 then
        local index = math.max(1, #template.diagonal_in_signal_points + fan_offset)
        return template.diagonal_in_signal_points[index], "diagonal", index
    end

    local index = math.min(fan_offset, #template.exit_curve_signal_points)
    return template.exit_curve_signal_points[index], "exit curve", index
end

local function append_lane(add, template, stacker_type, lane, last_lane, x_offset, y_offset, debug_enabled)
    for _, rail in ipairs(template.rails) do
        add(rail.name, rail.position.x + x_offset, rail.position.y + y_offset, {
            direction = rail.direction,
        })
    end

    local entry_location = template.diagonal_in_signal_points[1]
    local entry_source = "diagonal_in_signal_points"
    local entry_index = 1
    if stacker_type == "Left-Right" then
        entry_location, entry_source, entry_index = left_right_entry_location(template, lane, last_lane)
    end

    add_signal(
        add,
        "rail-chain-signal",
        entry_location,
        x_offset,
        y_offset,
        {
            enabled = debug_enabled,
            lane = lane,
            role = "lane entry",
            source = entry_source,
            source_index = entry_index,
        }
    )

    local exit_index = #template.diagonal_in_signal_points
    local exit_location = template.diagonal_in_signal_points[exit_index]
    local exit_source = "diagonal_in_signal_points"
    if stacker_type == "Left-Right" then
        exit_location, exit_source, exit_index = left_right_exit_location(template, lane, last_lane)
    end

    add_signal(add, "rail-signal", exit_location, x_offset, y_offset, {
        enabled = debug_enabled,
        lane = lane,
        role = "lane exit",
        source = exit_source,
        source_index = exit_index,
    })
end

function DiagonalStacker.generate(settings)
    local builder = Builder.new()
    local add = make_unique_adder(builder)
    local stacker_type = normalize_stacker_type(settings.stacker_type)

    local template_configuration

    -- Signalled travel is opposite the direction used to construct each native
    -- template. The two diagonal fans also have different handedness; rotating
    -- one generic south/east template cannot produce both horizontal layouts.
    if stacker_type == "Left-Right" then
        template_configuration = {
            heading = defines.direction.west,
            first_turn = -1,
            lane_step_x = LANE_SPACING,
            lane_step_y = 0,
        }
    else
        template_configuration = {
            heading = defines.direction.east,
            first_turn = 1,
            lane_step_x = LANE_SPACING,
            lane_step_y = 0,
        }
    end

    local template = build_lane_template(
        settings,
        template_configuration.heading,
        template_configuration.first_turn
    )
    local last_lane = settings.stacker_lanes - 1

    for lane = 0, last_lane do
        append_lane(
            add,
            template,
            stacker_type,
            lane,
            last_lane,
            lane * template_configuration.lane_step_x,
            lane * template_configuration.lane_step_y,
            settings._diagonal_debug_enabled
        )
    end

    local entrance_location = stacker_type == "Left-Right" and template.exit_signal or template.entrance_signal
    add_signal(add, "rail-chain-signal", entrance_location, 0, 0, {
        enabled = settings._diagonal_debug_enabled,
        lane = 0,
        role = "entrance",
        source = stacker_type == "Left-Right" and "exit_signal" or "entrance_signal",
    })

    local exit_location = stacker_type == "Left-Right" and template.entrance_signal or template.exit_signal
    add_signal(
        add,
        "rail-chain-signal",
        exit_location,
        last_lane * template_configuration.lane_step_x,
        last_lane * template_configuration.lane_step_y,
        {
            enabled = settings._diagonal_debug_enabled,
            lane = last_lane,
            role = "outer exit",
            source = stacker_type == "Left-Right" and "entrance_signal" or "exit_signal",
        }
    )

    return builder.entities
end

return DiagonalStacker
