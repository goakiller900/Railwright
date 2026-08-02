-- Minimal BlueprintEntity builder. It assigns stable entity numbers, deep-copies
-- option tables, and emits Factorio 2.1's four-number BlueprintWire records.
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
        copper_wire_keys = {},
    }, Builder)
end

function Builder:add(name, x, y, options)
    -- Entity numbers are assigned in insertion order and are referenced by wires.
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

local function connector_id(color, side)
    -- Combinators have distinct input/output connectors; ordinary entities use
    -- their red or green circuit connector.
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

function Builder:connect_copper(entity_a, entity_b)
    if not entity_a or not entity_b or entity_a == entity_b then return end

    local low = math.min(entity_a.entity_number, entity_b.entity_number)
    local high = math.max(entity_a.entity_number, entity_b.entity_number)
    local key = low .. ":" .. high
    if self.copper_wire_keys[key] then return end
    self.copper_wire_keys[key] = true

    local connector = defines.wire_connector_id.pole_copper
    entity_a.wires = entity_a.wires or {}
    entity_a.wires[#entity_a.wires + 1] = {
        entity_a.entity_number,
        connector,
        entity_b.entity_number,
        connector,
    }
end

function Builder:connect_copper_chain(entities)
    for index = 2, #entities do
        self:connect_copper(entities[index - 1], entities[index])
    end
end

function Builder.deep_copy(value)
    return deep_copy(value)
end

return Builder
