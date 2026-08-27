-- Focused non-Factorio regression checks for saved entity selections, optional
-- loader recovery, GUI picker construction, and generator validation.
package.path = "./?.lua;./?/init.lua;" .. package.path

local function equal(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)), 2)
    end
end

defines = {
    direction = {
        north = 0,
        northeast = 2,
        east = 4,
        eastsoutheast = 6,
        southeast = 6,
        south = 8,
        southwest = 10,
        westsouthwest = 10,
        west = 12,
        northwest = 14,
    },
    inventory = { cargo_wagon = 1, chest = 2 },
    wire_connector_id = {
        circuit_red = 1,
        circuit_green = 2,
        combinator_input_red = 3,
        combinator_input_green = 4,
        combinator_output_red = 5,
        combinator_output_green = 6,
        pole_copper = 7,
    },
}

local function inventory_size() return 48 end
local function wagon_inventory_size() return 40 end
local function tank_capacity() return 25000 end

prototypes = {
    entity = {
        ["fast-inserter"] = { type = "inserter" },
        ["modded-inserter"] = { type = "inserter" },
        ["steel-chest"] = { type = "container", get_inventory_size = inventory_size },
        ["fast-transport-belt"] = { type = "transport-belt" },
        ["fast-splitter"] = { type = "splitter" },
        pump = { type = "pump" },
        ["storage-tank"] = { type = "storage-tank", get_fluid_capacity = tank_capacity },
        pipe = { type = "pipe" },
        ["cargo-wagon"] = { get_inventory_size = wagon_inventory_size },
        ["fluid-wagon"] = { get_fluid_capacity = tank_capacity },
    },
    item = {
        ["solid-fuel"] = { type = "item" },
    },
}

storage = {
    players = {
        [1] = { transfer_mode = "loaders", loader_name = "" },
        [2] = { chest_name = "removed-chest" },
        [3] = { inserter_name = "modded-inserter" },
        [4] = { transfer_mode = "loaders", loader_name = "removed-loader" },
    },
}

local State = require("scripts.state")

local empty_loader = State.ensure_player(1)
equal(empty_loader.loader_name, nil, "empty loader selection is sanitized")
equal(empty_loader.transfer_mode, "inserters", "empty loader selection falls back to inserters")

local removed_entity = State.ensure_player(2)
equal(removed_entity.chest_name, nil, "removed entity prototype is sanitized")

local modded_entity = State.ensure_player(3)
equal(modded_entity.inserter_name, "modded-inserter", "valid modded entity is preserved")

local removed_loader = State.ensure_player(4)
equal(removed_loader.loader_name, nil, "removed loader prototype is sanitized")
equal(removed_loader.transfer_mode, "inserters", "removed loader falls back to inserters")

prototypes.entity["modded-loader"] = { type = "loader-1x1" }

local function gui_element(spec, parent)
    if spec.type == "choose-elem-button" and spec.elem_type == "entity" then
        if spec.entity == "" then error("GUI received an empty entity prototype name", 2) end
        if spec.entity ~= nil and not prototypes.entity[spec.entity] then
            error("GUI received an unknown entity prototype name: " .. tostring(spec.entity), 2)
        end
    end

    local element = {
        valid = true,
        children = {},
        style = {},
        parent = parent,
    }
    for key, value in pairs(spec or {}) do
        if key == "style" then
            element.style_name = value
        else
            element[key] = value
        end
    end
    if spec.type == "choose-elem-button" then
        element.elem_value = spec.entity or spec.item
    end

    element.add = function(child_spec)
        local child = gui_element(child_spec, element)
        element.children[#element.children + 1] = child
        if child.name then element[child.name] = child end
        return child
    end
    element.destroy = function()
        element.valid = false
        if element.parent then
            if element.name then element.parent[element.name] = nil end
            for index, child in ipairs(element.parent.children) do
                if child == element then
                    table.remove(element.parent.children, index)
                    break
                end
            end
        end
    end
    element.force_auto_center = function() end
    return element
end

local function find_gui_element(root, name)
    if root.name == name then return root end
    for _, child in ipairs(root.children or {}) do
        local found = find_gui_element(child, name)
        if found then return found end
    end
end

local Constants = require("scripts.constants")
local Gui = require("scripts.gui")

local function gui_player(index)
    return {
        index = index,
        gui = { screen = gui_element({ name = "screen" }) },
        mod_settings = {},
    }
end

storage.players[7] = { chest_name = "removed-chest" }
local removed_player = gui_player(7)
Gui.open(removed_player)
local removed_chest_picker = find_gui_element(removed_player.gui.screen, Constants.gui.chest)
equal(removed_chest_picker.entity, nil, "GUI opens a removed saved entity as unselected")

storage.players[5] = {
    transfer_mode = "loaders",
    loader_name = "modded-loader",
    inserter_name = "modded-inserter",
}
local modded_player = gui_player(5)
Gui.open(modded_player)
local modded_loader_picker = find_gui_element(modded_player.gui.screen, Constants.gui.loader)
equal(modded_loader_picker.entity, "modded-loader", "GUI preserves a valid modded loader")

storage.players[6] = { transfer_mode = "loaders", loader_name = "" }
local recovered_player = gui_player(6)
Gui.open(recovered_player)
local recovered_loader_picker = find_gui_element(recovered_player.gui.screen, Constants.gui.loader)
equal(recovered_loader_picker.entity, nil, "GUI opens an empty saved loader as unselected")
local recovered_settings = Gui.read_settings(recovered_player)
equal(recovered_settings.loader_name, nil, "GUI reader keeps an unselected loader nil")
equal(recovered_settings.transfer_mode, "inserters", "GUI reflects recovered inserter mode")

modded_loader_picker.elem_value = nil
local transfer_mode = find_gui_element(modded_player.gui.screen, Constants.gui.transfer_mode)
transfer_mode.selected_index = 1
local cleared_settings = Gui.read_settings(modded_player)
equal(cleared_settings.loader_name, nil, "cleared loader picker reads as nil")
State.set_player(modded_player.index, cleared_settings)
Gui.close(modded_player)
Gui.open(modded_player)
local reopened_loader_picker = find_gui_element(modded_player.gui.screen, Constants.gui.loader)
equal(reopened_loader_picker.entity, nil, "GUI reopens safely after a loader selection is cleared")

local Generator = require("scripts.generator")
local invalid_settings = State.defaults()
invalid_settings.chest_name = nil
local call_ok, generated, message = pcall(Generator.generate_into_cursor, {}, invalid_settings)
equal(call_ok, true, "missing required entity is handled without a runtime error")
equal(generated, false, "missing required entity prevents blueprint generation")
equal(message, "Chest is not selected.", "missing required entity has a readable error")

print("GUI and saved-state tests passed")
