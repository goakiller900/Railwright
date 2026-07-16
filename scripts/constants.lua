local Constants = {
    mod_name = "railwright",

    gui = {
        top_button = "railwright_top_button",
        frame = "railwright_main_frame",
        titlebar = "railwright_titlebar",
        close_button = "railwright_close_button",
        scroll = "railwright_scroll",
        generate_button = "railwright_generate_button",

        common_group = "railwright_common_group",
        item_group = "railwright_item_group",
        fluid_group = "railwright_fluid_group",
        behavior_group = "railwright_behavior_group",
        stacker_group = "railwright_stacker_group",

        station_type = "railwright_station_type",
        station_name = "railwright_station_name",
        locomotives = "railwright_locomotives",
        cargo_wagons = "railwright_cargo_wagons",
        double_headed = "railwright_double_headed",
        include_train = "railwright_include_train",

        sides = "railwright_sides",
        inserter = "railwright_inserter",
        chest = "railwright_chest",
        belt = "railwright_belt",
        splitter = "railwright_splitter",
        belt_flow = "railwright_belt_flow",
        filter_enabled = "railwright_filter_enabled",
        filter_item_prefix = "railwright_filter_item_",
        chest_limit = "railwright_chest_limit",
        request_from_buffers = "railwright_request_from_buffers",
        request_item_prefix = "railwright_request_item_",
        request_count_prefix = "railwright_request_count_",
        madzuri = "railwright_madzuri",

        pump_side = "railwright_pump_side",
        pump = "railwright_pump",
        storage_tank = "railwright_storage_tank",
        pipe = "railwright_pipe",
        tank_columns = "railwright_tank_columns",
        connect_pipes = "railwright_connect_pipes",

        connect_green = "railwright_connect_green",
        connect_both_green = "railwright_connect_both_green",
        connect_red = "railwright_connect_red",
        connect_both_red = "railwright_connect_both_red",
        refill_enabled = "railwright_refill_enabled",
        refill_fuel = "railwright_refill_fuel",
        refill_amount = "railwright_refill_amount",
        train_limit = "railwright_train_limit",
        train_limit_one = "railwright_train_limit_one",
        train_limit_stack_size = "railwright_train_limit_stack_size",
        enabled_condition = "railwright_enabled_condition",
        enabled_operator = "railwright_enabled_operator",
        enabled_amount = "railwright_enabled_amount",
        lamps = "railwright_lamps",

        stacker_lanes = "railwright_stacker_lanes",
        stacker_diagonal = "railwright_stacker_diagonal",
        stacker_type = "railwright_stacker_type",
    },

    station_types = {
        "Loading station",
        "Unloading station",
        "Fluid loading station",
        "Fluid unloading station",
        "Stacker",
    },

    station_type_keys = {
        "loading",
        "unloading",
        "fluid-loading",
        "fluid-unloading",
        "stacker",
    },

    sides = { "Both", "Right", "Left" },
    side_keys = { "both", "right", "left" },

    pump_sides = { "Right", "Left" },
    pump_side_keys = { "right", "left" },

    belt_flows = { "Front", "Back", "None" },
    belt_flow_keys = { "front", "back", "none" },

    train_limits = {
        "Disabled",
        "Dynamic",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
    },

    enabled_operators = { ">", "<" },

    stacker_types = {
        "Left-Right",
        "Right-Left",
    },
}

return Constants
