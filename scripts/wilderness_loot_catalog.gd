extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const FARM_VALUE_PER_HOUR: Dictionary = {1: 420, 2: 620, 3: 840}
const DEFINITIONS: Array[Dictionary] = [
	{
		"item_id": &"item.wild.glass_chitin",
		"source": &"glassback_scarab",
		"tier": 1,
		"routine": true,
		"units_per_hour": 16,
		"capability": &"capability.farm.water_retention"
	},
	{
		"item_id": &"item.wild.dune_fiber",
		"source": &"dune_grazer",
		"tier": 1,
		"routine": false,
		"units_per_hour": 8,
		"capability": &"capability.farm.water_retention"
	},
	{
		"item_id": &"item.wild.dune_sinew",
		"source": &"sandworm",
		"tier": 2,
		"routine": true,
		"units_per_hour": 6,
		"capability": &"capability.farm.water_retention"
	},
	{
		"item_id": &"item.hazard.silica_loam",
		"source": &"quicksand_collapse",
		"tier": 2,
		"routine": false,
		"units_per_hour": 5,
		"capability": &"capability.farm.water_retention"
	},
	{
		"item_id": &"item.wild.mire_spore",
		"source": &"mire_tick",
		"tier": 1,
		"routine": true,
		"units_per_hour": 16,
		"capability": &"capability.farm.compost_yield"
	},
	{
		"item_id": &"item.wild.reed_resin",
		"source": &"reedback",
		"tier": 1,
		"routine": false,
		"units_per_hour": 8,
		"capability": &"capability.farm.compost_yield"
	},
	{
		"item_id": &"item.wild.mire_membrane",
		"source": &"mud_skimmer",
		"tier": 2,
		"routine": true,
		"units_per_hour": 6,
		"capability": &"capability.farm.compost_yield"
	},
	{
		"item_id": &"item.hazard.bloom_compost",
		"source": &"bog_gas_bloom",
		"tier": 2,
		"routine": false,
		"units_per_hour": 5,
		"capability": &"capability.farm.compost_yield"
	},
	{
		"item_id": &"item.wild.rime_shard",
		"source": &"rime_shardling",
		"tier": 1,
		"routine": true,
		"units_per_hour": 14,
		"capability": &"capability.farm.frost_ward"
	},
	{
		"item_id": &"item.wild.rime_wool",
		"source": &"rimehorn",
		"tier": 1,
		"routine": false,
		"units_per_hour": 7,
		"capability": &"capability.farm.frost_ward"
	},
	{
		"item_id": &"item.wild.rime_lens",
		"source": &"rime_stalker",
		"tier": 2,
		"routine": true,
		"units_per_hour": 5,
		"capability": &"capability.farm.frost_ward"
	},
	{
		"item_id": &"item.hazard.ice_crystal",
		"source": &"ice_shear",
		"tier": 2,
		"routine": false,
		"units_per_hour": 4,
		"capability": &"capability.farm.frost_ward"
	},
	{
		"item_id": &"item.wild.ember_shell",
		"source": &"ember_skitter",
		"tier": 1,
		"routine": true,
		"units_per_hour": 12,
		"capability": &"capability.farm.furnace_flux"
	},
	{
		"item_id": &"item.wild.ember_fleece",
		"source": &"ember_ram",
		"tier": 1,
		"routine": false,
		"units_per_hour": 6,
		"capability": &"capability.farm.furnace_flux"
	},
	{
		"item_id": &"item.wild.cinder_gland",
		"source": &"cinder_crawler",
		"tier": 3,
		"routine": true,
		"units_per_hour": 4,
		"capability": &"capability.farm.furnace_flux"
	},
	{
		"item_id": &"item.hazard.vent_glass",
		"source": &"magma_vent",
		"tier": 3,
		"routine": false,
		"units_per_hour": 3,
		"capability": &"capability.farm.furnace_flux"
	},
	{
		"item_id": &"item.boss.burrow_core",
		"source": &"ironjaw_apex",
		"tier": 3,
		"routine": false,
		"units_per_hour": 1,
		"capability": &"capability.farm.deep_tilling"
	},
]


static func definition(item_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"item_id"] == item_id:
			return candidate.duplicate(true)
	return {}


static func items_for_capability(capability: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"capability"] == capability:
			result.append(candidate[&"item_id"] as StringName)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func validate() -> bool:
	var seen: Dictionary = {}
	var capabilities: Dictionary = {}
	for candidate: Dictionary in DEFINITIONS:
		var item_id: StringName = candidate[&"item_id"] as StringName
		var tier: int = int(candidate[&"tier"])
		var value_per_hour: int = (
			ItemCatalogScript.sell_price(item_id) * int(candidate[&"units_per_hour"])
		)
		if (
			seen.has(item_id)
			or ItemCatalogScript.definition(item_id).is_empty()
			or tier not in FARM_VALUE_PER_HOUR
		):
			return false
		if bool(candidate[&"routine"]) and value_per_hour > int(FARM_VALUE_PER_HOUR[tier]):
			return false
		if String(candidate[&"capability"]).is_empty():
			return false
		seen[item_id] = true
		capabilities[candidate[&"capability"]] = true
	return seen.size() == DEFINITIONS.size() and capabilities.size() == 5


static func routine_value_is_bounded(item_id: StringName) -> bool:
	var entry: Dictionary = definition(item_id)
	if entry.is_empty() or not bool(entry[&"routine"]):
		return true
	return (
		ItemCatalogScript.sell_price(item_id) * int(entry[&"units_per_hour"])
		<= int(FARM_VALUE_PER_HOUR[int(entry[&"tier"])])
	)
