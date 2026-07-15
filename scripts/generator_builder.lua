local Builder = {}
Builder.__index = Builder

local function deep_copy(value)
    if type(value) ~= "table" then return value end

    local result = {}
    for key, child in pairs(value) do
        result[deep_copy(key)] = deep_copy(child)
    end
    return result
end

function Builder.new()
    return setmetatable({
        entities = {},
    }, Builder)
end

function Builder:add(name, x, y, options)
    local entity = {
        entity_number = #self.entities + 1,
        name = name,
        position = { x = x, y = y },
    }

    for key, value in pairs(options or {}) do
        if value ~= nil then
            entity[key] = deep_copy(value)
        end
    end

    self.entities[#self.entities + 1] = entity
    return entity
end

function Builder:copy_entity(entity, x_offset, y_offset)
    local options = deep_copy(entity)
    options.entity_number = nil
    options.name = nil
    options.position = nil
    options.wires = nil

    return self:add(
        entity.name,
        entity.position.x + (x_offset or 0),
        entity.position.y + (y_offset or 0),
        options
    )
end

local function connector_id(color, side)
    if side == "input" then
        return color == "red"
            and defines.wire_connector_id.combinator_input_red
            or defines.wire_connector_id.combinator_input_green
    end

    if side == "output" then
        return color == "red"
            and defines.wire_connector_id.combinator_output_red
            or defines.wire_connector_id.combinator_output_green
    end

    return color == "red"
        and defines.wire_connector_id.circuit_red
        or defines.wire_connector_id.circuit_green
end

function Builder:connect(entity_a, entity_b, color, side_a, side_b)
    if not entity_a or not entity_b then return end

    local wire = {
        entity_a.entity_number,
        connector_id(color, side_a or "circuit"),
        entity_b.entity_number,
        connector_id(color, side_b or "circuit"),
    }

    entity_a.wires = entity_a.wires or {}
    entity_a.wires[#entity_a.wires + 1] = wire
end

function Builder:connect_chain(entities, color)
    for index = 2, #entities do
        self:connect(entities[index - 1], entities[index], color)
    end
end

function Builder:append_template(template, x_offset, y_offset)
    local created = {}
    for _, entity in ipairs(template) do
        created[#created + 1] = self:add(
            entity.name,
            entity.position.x + (x_offset or 0),
            entity.position.y + (y_offset or 0),
            entity.options
        )
    end
    return created
end

function Builder.deep_copy(value)
    return deep_copy(value)
end

return Builder
