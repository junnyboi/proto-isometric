extends RefCounted

const ModifierServiceScript: GDScript = preload("res://scripts/modifier_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


static func relay_spacing(modifier_id: StringName) -> float:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	return float(definition.get("relay_spacing_bonus")) if definition != null else 0.0


static func relay_scrap(base: int, modifier_id: StringName) -> int:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	return base * int(definition.get("relay_scrap_multiplier")) if definition != null else base


static func worm_count(base: int, modifier_id: StringName) -> int:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	return base + int(definition.get("worm_count_bonus")) if definition != null else base


static func core_reward(base: int, worm_id: int, modifier_id: StringName) -> int:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	if definition == null:
		return base
	var modulus: int = int(definition.get("bonus_core_modulus"))
	return base + 1 if modulus > 0 and worm_id % modulus == 0 else base


static func repair_cost(base: int, modifier_id: StringName) -> int:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	return (
		maxi(base - int(definition.get("repair_cost_discount")), 1) if definition != null else base
	)


static func storm_interval(base: float, modifier_id: StringName) -> float:
	var definition: Resource = ModifierServiceScript.definition(modifier_id)
	return base * float(definition.get("storm_interval_multiplier")) if definition != null else base
