local Constants = require("scripts.constants")
local Generator = require("scripts.generator")
local Gui = require("scripts.gui")
local State = require("scripts.state")

local function setup_player(player)
    State.ensure_player(player.index)
    Gui.ensure_button(player)
end

local function setup_all_players()
    State.ensure_root()
    for _, player in pairs(game.players) do
        setup_player(player)
    end
end

script.on_init(setup_all_players)
script.on_configuration_changed(setup_all_players)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if player then
        setup_player(player)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    if element.name == Constants.gui.top_button then
        Gui.toggle(player)
        return
    end

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
    if frame and event.element == frame then
        Gui.close(player)
    end
end)
