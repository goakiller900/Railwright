-- Runtime entry point: owns Factorio event/command registration and coordinates
-- state, GUI input, validation, and blueprint generation.
local Constants = require("scripts.constants")
local Debug = require("scripts.generator_debug")
local Generator = require("scripts.generator")
local Gui = require("scripts.gui")
local State = require("scripts.state")

local SHORTCUT_NAME = "railwright-open"
local DEBUG_COMMAND = "railwright-debug-stackers"

local function setup_player(player)
    -- Ensure migration-friendly defaults exist before this player opens the UI.
    State.ensure_player(player.index)

    -- Remove the legacy 0.1.x/0.2.1 top-GUI launcher when upgrading an existing save.
    local legacy_button = player.gui.top[Constants.gui.top_button]
    if legacy_button then legacy_button.destroy() end
end

local function setup_all_players()
    State.ensure_root()
    for _, player in pairs(game.players) do
        setup_player(player)
    end
end

commands.add_command(DEBUG_COMMAND, "Toggle Railwright stacker blueprint diagnostics.", function(command)
    if not command.player_index then
        log("[Railwright] /" .. DEBUG_COMMAND .. " can only be used by a player.")
        return
    end

    local player = game.get_player(command.player_index)
    if not player then return end

    local enabled = Debug.toggle(player.index)
    if enabled then
        player.print({ "", "[Railwright] Stacker blueprint diagnostics enabled. Generate a stacker, then check factorio-current.log." })
    else
        player.print({ "", "[Railwright] Stacker blueprint diagnostics disabled." })
    end
end)

script.on_init(setup_all_players)
script.on_configuration_changed(setup_all_players)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then setup_player(player) end
end)

script.on_event(defines.events.on_lua_shortcut, function(event)
    if event.prototype_name ~= SHORTCUT_NAME then return end

    local player = game.get_player(event.player_index)
    if player then Gui.toggle(player) end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
    local element = event.element
    if not element or not element.valid or element.name ~= Constants.gui.station_type then return end

    local player = game.get_player(event.player_index)
    if player then Gui.update_visibility(player) end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    if element.name == Constants.gui.close_button then
        Gui.close(player)
        return
    end

    if element.name ~= Constants.gui.generate_button then return end

    local settings, read_error = Gui.read_settings(player)
    if not settings then
        player.print({ "", "[Railwright] ", read_error })
        return
    end

    -- Geometry can involve modded prototypes and native rail planning, so keep
    -- unexpected generator failures contained to a readable player message.
    local call_ok, generated, result = pcall(Generator.generate_into_cursor, player, settings)
    if not call_ok then
        player.print({ "", "[Railwright] Unexpected error: ", generated })
        return
    end

    if not generated then
        player.print({ "", "[Railwright] ", result })
        return
    end

    State.set_player(player.index, settings)
    Gui.close(player)
    player.print({ "", "[Railwright] Blueprint created with ", tostring(result), " entities." })
end)

script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local frame = player.gui.screen[Constants.gui.frame]
    if frame and event.element == frame then Gui.close(player) end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if event.setting ~= Constants.settings.enable_experimental_diagonal or not event.player_index then return end

    local player = game.get_player(event.player_index)
    if player then Gui.close(player) end
end)
