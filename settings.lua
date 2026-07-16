-- Settings-stage entry point. This per-user switch only controls whether the
-- experimental diagonal checkbox is exposed; it does not alter saved blueprints.
data:extend({
    {
        type = "bool-setting",
        name = "railwright-enable-experimental-diagonal",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "a[railwright]-a[experimental-diagonal]",
    },
})
