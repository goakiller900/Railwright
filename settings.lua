-- Settings-stage entry point. Experimental generator features are exposed
-- through per-player switches and do not alter already-generated blueprints.
data:extend({
    {
        type = "bool-setting",
        name = "railwright-enable-experimental-diagonal",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "a[railwright]-a[experimental-diagonal]",
    },
    {
        type = "bool-setting",
        name = "railwright-enable-experimental-dynamic-station-names",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "a[railwright]-b[experimental-dynamic-station-names]",
    },
})
