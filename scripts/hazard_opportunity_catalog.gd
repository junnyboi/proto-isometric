extends RefCounted

const FarmCapabilityServiceScript: GDScript = preload("res://scripts/farm_capability_service.gd")

const DEFINITIONS: Dictionary = {
	&"quicksand_collapse":
	{
		&"biome": &"desert",
		&"forecast": &"forecast.ground_hollow",
		&"telegraph": &"telegraph.sand_rings",
		&"preparation": FarmCapabilityServiceScript.WATER_RETENTION,
		&"mitigation_numerator": 1,
		&"mitigation_denominator": 2,
		&"stabilize_from": 0.45,
		&"stabilize_until": 1.35,
		&"reward_item_id": &"item.hazard.silica_loam",
		&"reward_count": 1
	},
	&"bog_gas_bloom":
	{
		&"biome": &"oasis",
		&"forecast": &"forecast.spores_rising",
		&"telegraph": &"telegraph.green_bubbles",
		&"preparation": FarmCapabilityServiceScript.COMPOST_YIELD,
		&"mitigation_numerator": 1,
		&"mitigation_denominator": 2,
		&"stabilize_from": 0.55,
		&"stabilize_until": 1.70,
		&"reward_item_id": &"item.hazard.bloom_compost",
		&"reward_count": 1
	},
	&"ice_shear":
	{
		&"biome": &"frozen",
		&"forecast": &"forecast.ice_humming",
		&"telegraph": &"telegraph.blue_fracture",
		&"preparation": FarmCapabilityServiceScript.FROST_WARD,
		&"mitigation_numerator": 1,
		&"mitigation_denominator": 3,
		&"stabilize_from": 0.35,
		&"stabilize_until": 1.05,
		&"reward_item_id": &"item.hazard.ice_crystal",
		&"reward_count": 1
	},
	&"magma_vent":
	{
		&"biome": &"lava",
		&"forecast": &"forecast.vent_pressure",
		&"telegraph": &"telegraph.orange_fissure",
		&"preparation": FarmCapabilityServiceScript.FURNACE_FLUX,
		&"mitigation_numerator": 1,
		&"mitigation_denominator": 2,
		&"stabilize_from": 0.40,
		&"stabilize_until": 1.20,
		&"reward_item_id": &"item.hazard.vent_glass",
		&"reward_count": 1
	},
}


static func definition(kind: StringName) -> Dictionary:
	return (DEFINITIONS.get(kind, {}) as Dictionary).duplicate(true)


static func forecast(
	biome: StringName, cell: Vector2i, absolute_day: int, world_seed: int
) -> Dictionary:
	var candidates: Array[StringName] = []
	for kind: StringName in DEFINITIONS:
		if DEFINITIONS[kind][&"biome"] == biome:
			candidates.append(kind)
	if candidates.is_empty():
		return {}
	var kind: StringName = candidates[posmod(
		cell.x * 31 + cell.y * 17 + absolute_day * 13 + world_seed, candidates.size()
	)]
	var result: Dictionary = definition(kind)
	result[&"kind"] = kind
	result[&"cell"] = cell
	result[&"absolute_day"] = absolute_day
	return result


static func mitigated_damage(kind: StringName, damage: int, prepared: bool) -> int:
	var entry: Dictionary = definition(kind)
	if entry.is_empty() or not prepared:
		return maxi(damage, 0)
	return ceili(
		(
			float(maxi(damage, 0) * int(entry[&"mitigation_numerator"]))
			/ float(int(entry[&"mitigation_denominator"]))
		)
	)


static func can_stabilize(kind: StringName, age: float, prepared: bool) -> bool:
	var entry: Dictionary = definition(kind)
	return (
		not entry.is_empty()
		and prepared
		and age >= float(entry[&"stabilize_from"])
		and age <= float(entry[&"stabilize_until"])
	)


static func validate() -> bool:
	var biomes: Dictionary = {}
	for kind: StringName in DEFINITIONS:
		var entry: Dictionary = DEFINITIONS[kind] as Dictionary
		if (
			str(entry[&"forecast"]).is_empty()
			or str(entry[&"telegraph"]).is_empty()
			or int(entry[&"reward_count"]) < 1
		):
			return false
		if float(entry[&"stabilize_from"]) >= float(entry[&"stabilize_until"]):
			return false
		biomes[entry[&"biome"]] = true
	return DEFINITIONS.size() == 4 and biomes.size() == 4
