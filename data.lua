-- Data-stage entry point: registers the shortcut-bar prototype. Runtime click
-- handling lives in control.lua because shortcuts cannot execute generators here.
data:extend({
    {
        type = "shortcut",
        name = "railwright-open",
        order = "z[railwright]",
        action = "lua",
        toggleable = false,
        localised_name = { "shortcut-name.railwright-open" },
        icon = "__railwright__/graphics/railwright-shortcut-x56.png",
        icon_size = 56,
        small_icon = "__railwright__/graphics/railwright-shortcut-x56.png",
        small_icon_size = 56,
    },
})
