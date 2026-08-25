extends RefCounted

const CATEGORY_SEED: StringName = &"seed"
const CATEGORY_PRODUCE: StringName = &"produce"
const CATEGORY_WOOD: StringName = &"wood"
const CATEGORY_STONE: StringName = &"stone"
const CATEGORY_ORE: StringName = &"ore"
const CATEGORY_MONSTER: StringName = &"monster_material"
const CATEGORY_FOOD: StringName = &"food"
const CATEGORY_PART: StringName = &"crafted_part"
const CATEGORY_TOOL: StringName = &"tool"
const CATEGORY_CURRENCY: StringName = &"currency"
const CATEGORY_FEED: StringName = &"animal_feed"
const CATEGORY_PRODUCT: StringName = &"animal_product"

const DEFINITIONS: Array[Dictionary] = [
	{
		&"item_id": &"item.seed.glowroot",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 20,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.glowroot",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 80
	},
	{
		&"item_id": &"item.seed.coilbean",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 35,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.coilbean",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 45
	},
	{
		&"item_id": &"item.seed.ironturnip",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 30,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.ironturnip",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 65
	},
	{
		&"item_id": &"item.seed.rainleaf",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 45,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.rainleaf",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 90
	},
	{
		&"item_id": &"item.seed.starbloom",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 55,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.starbloom",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 110
	},
	{
		&"item_id": &"item.seed.sunpod",
		&"category": CATEGORY_SEED,
		&"stack_limit": 99,
		&"buy_price": 90,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.produce.sunpod",
		&"category": CATEGORY_PRODUCE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 180
	},
	{
		&"item_id": &"item.material.wood",
		&"category": CATEGORY_WOOD,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 4
	},
	{
		&"item_id": &"item.material.stone",
		&"category": CATEGORY_STONE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 5
	},
	{
		&"item_id": &"item.ore.iron",
		&"category": CATEGORY_ORE,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 12
	},
	{
		&"item_id": &"item.material.scrap",
		&"category": CATEGORY_PART,
		&"stack_limit": 999,
		&"buy_price": 0,
		&"sell_price": 2
	},
	{
		&"item_id": &"item.monster.worm_core",
		&"category": CATEGORY_MONSTER,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 75
	},
	{
		&"item_id": &"item.food.field_ration",
		&"category": CATEGORY_FOOD,
		&"stack_limit": 20,
		&"buy_price": 40,
		&"sell_price": 15
	},
	{
		&"item_id": &"item.part.irrigation_coil",
		&"category": CATEGORY_PART,
		&"stack_limit": 20,
		&"buy_price": 0,
		&"sell_price": 60
	},
	{
		&"item_id": &"item.part.iron_ingot",
		&"category": CATEGORY_PART,
		&"stack_limit": 99,
		&"buy_price": 0,
		&"sell_price": 28
	},
	{
		&"item_id": &"item.tool.hoe",
		&"category": CATEGORY_TOOL,
		&"stack_limit": 1,
		&"buy_price": 0,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.tool.watering",
		&"category": CATEGORY_TOOL,
		&"stack_limit": 1,
		&"buy_price": 0,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.tool.axe",
		&"category": CATEGORY_TOOL,
		&"stack_limit": 1,
		&"buy_price": 0,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.tool.pick",
		&"category": CATEGORY_TOOL,
		&"stack_limit": 1,
		&"buy_price": 0,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.currency.credit",
		&"category": CATEGORY_CURRENCY,
		&"stack_limit": 1_000_000_000,
		&"buy_price": 0,
		&"sell_price": 0
	},
	{
		&"item_id": &"item.feed.mossgrass_fodder",
		&"category": CATEGORY_FEED,
		&"stack_limit": 50,
		&"buy_price": 18,
		&"sell_price": 4
	},
	{
		&"item_id": &"item.feed.coilgrain_mix",
		&"category": CATEGORY_FEED,
		&"stack_limit": 50,
		&"buy_price": 14,
		&"sell_price": 3
	},
	{
		&"item_id": &"item.feed.root_mash",
		&"category": CATEGORY_FEED,
		&"stack_limit": 50,
		&"buy_price": 16,
		&"sell_price": 4
	},
	{
		&"item_id": &"item.product.mossback_milk",
		&"category": CATEGORY_PRODUCT,
		&"stack_limit": 30,
		&"buy_price": 0,
		&"sell_price": 95
	},
	{
		&"item_id": &"item.product.coilhen_egg",
		&"category": CATEGORY_PRODUCT,
		&"stack_limit": 50,
		&"buy_price": 0,
		&"sell_price": 55
	},
	{
		&"item_id": &"item.product.rustsnout_truffle",
		&"category": CATEGORY_PRODUCT,
		&"stack_limit": 20,
		&"buy_price": 0,
		&"sell_price": 125
	},
]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: Dictionary in DEFINITIONS:
		result.append(definition[&"item_id"] as StringName)
	return result


static func definition(item_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"item_id"] == item_id:
			return candidate.duplicate(true)
	return {}


static func stack_limit(item_id: StringName) -> int:
	return int(definition(item_id).get(&"stack_limit", 0))


static func buy_price(item_id: StringName) -> int:
	return int(definition(item_id).get(&"buy_price", 0))


static func sell_price(item_id: StringName) -> int:
	return int(definition(item_id).get(&"sell_price", 0))


static func category(item_id: StringName) -> StringName:
	return definition(item_id).get(&"category", &"") as StringName


static func validate() -> bool:
	var seen: Dictionary = {}
	var categories: Dictionary = {}
	for definition_value: Dictionary in DEFINITIONS:
		var item_id: StringName = definition_value[&"item_id"] as StringName
		var category_id: StringName = definition_value[&"category"] as StringName
		if seen.has(item_id) or not String(item_id).begins_with("item."):
			return false
		if int(definition_value[&"stack_limit"]) <= 0:
			return false
		if int(definition_value[&"buy_price"]) < 0 or int(definition_value[&"sell_price"]) < 0:
			return false
		seen[item_id] = true
		categories[category_id] = true
	return categories.size() == 12 and seen.size() == DEFINITIONS.size()
