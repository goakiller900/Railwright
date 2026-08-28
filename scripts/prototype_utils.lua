-- Shared runtime prototype checks used by saved-state migration, GUI pickers,
-- and generator validation.
local PrototypeUtils = {}

local function item_prototypes()
    return prototypes and prototypes.item
end

function PrototypeUtils.item_name_or_nil(name)
    local items = item_prototypes()
    if type(name) ~= "string" or name == "" or not items or not items[name] then return nil end
    return name
end

function PrototypeUtils.locomotive_fuel_categories()
    local entities = prototypes and prototypes.entity
    local locomotive = entities and entities.locomotive
    local burner = locomotive and locomotive.burner_prototype
    local source = burner and burner.fuel_categories
    if not source then return nil end

    local categories = {}
    for category, accepted in pairs(source) do
        if accepted then categories[category] = true end
    end
    return next(categories) and categories or nil
end

function PrototypeUtils.is_locomotive_fuel(name)
    local valid_name = PrototypeUtils.item_name_or_nil(name)
    if not valid_name then return false end

    local categories = PrototypeUtils.locomotive_fuel_categories()
    local item = item_prototypes()[valid_name]
    return categories ~= nil
        and type(item.fuel_category) == "string"
        and categories[item.fuel_category] == true
end

function PrototypeUtils.has_compatible_locomotive_fuel()
    local items = item_prototypes()
    local categories = PrototypeUtils.locomotive_fuel_categories()
    if not items or not categories then return false end

    for _, item in pairs(items) do
        if type(item.fuel_category) == "string" and categories[item.fuel_category] then return true end
    end
    return false
end

function PrototypeUtils.locomotive_fuel_filters()
    local categories = PrototypeUtils.locomotive_fuel_categories()
    if not categories then return nil end

    local names = {}
    for category in pairs(categories) do names[#names + 1] = category end
    table.sort(names)

    local filters = {}
    for _, category in ipairs(names) do
        filters[#filters + 1] = {
            filter = "fuel-category",
            ["fuel-category"] = category,
        }
    end
    return filters
end

return PrototypeUtils
