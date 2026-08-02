-- The station-name marker deliberately reuses every visual and physical detail
-- of the vanilla decider combinator for 0.3.8. Its distinct prototype name is
-- what lets runtime code identify managed stations without positional guesses.
local prototype_name = "railwright-station-name-combinator"

local entity = table.deepcopy(data.raw["decider-combinator"]["decider-combinator"])
entity.name = prototype_name
entity.localised_name = { "entity-name." .. prototype_name }
entity.localised_description = { "entity-description." .. prototype_name }
entity.minable.result = prototype_name
entity.flags = entity.flags or {}
local has_unit_lookup = false
for _, flag in pairs(entity.flags) do
    if flag == "get-by-unit-number" then has_unit_lookup = true end
end
if not has_unit_lookup then entity.flags[#entity.flags + 1] = "get-by-unit-number" end

local item = table.deepcopy(data.raw.item["decider-combinator"])
item.name = prototype_name
item.localised_name = { "item-name." .. prototype_name }
item.localised_description = { "item-description." .. prototype_name }
item.place_result = prototype_name
item.order = "c[combinators]-d[railwright-station-name]"

local recipe = table.deepcopy(data.raw.recipe["decider-combinator"])
recipe.name = prototype_name
recipe.localised_name = { "recipe-name." .. prototype_name }
recipe.enabled = false
recipe.result = nil
recipe.result_count = nil
recipe.results = {
    { type = "item", name = prototype_name, amount = 1 },
}

data:extend({ entity, item, recipe })

local circuit_network = data.raw.technology["circuit-network"]
circuit_network.effects = circuit_network.effects or {}
circuit_network.effects[#circuit_network.effects + 1] = {
    type = "unlock-recipe",
    recipe = prototype_name,
}
