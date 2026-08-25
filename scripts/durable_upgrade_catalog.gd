extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const FAMILY_TOOL: StringName = &"upgrade_family.tool"
const FAMILY_ROBOT: StringName = &"upgrade_family.robot"
const FAMILY_STORAGE: StringName = &"upgrade_family.storage"
const FAMILY_IRRIGATION: StringName = &"upgrade_family.irrigation"
const FAMILY_SAFEHOUSE: StringName = &"upgrade_family.safehouse"
const FAMILY_MACHINE: StringName = &"upgrade_family.machine"
const FAMILIES: Array[StringName] = [
	FAMILY_TOOL,
	FAMILY_ROBOT,
	FAMILY_STORAGE,
	FAMILY_IRRIGATION,
	FAMILY_SAFEHOUSE,
	FAMILY_MACHINE,
]
const DEFINITIONS: Array[Resource] = [
	preload("res://data/upgrades/watering_efficiency.tres"),
	preload("res://data/upgrades/robot_chassis.tres"),
	preload("res://data/upgrades/storage_expansion.tres"),
	preload("res://data/upgrades/irrigation_grid.tres"),
	preload("res://data/upgrades/safehouse_power.tres"),
	preload("res://data/upgrades/machine_furnace.tres"),
]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: Resource in DEFINITIONS:
		result.append(definition.get("upgrade_id") as StringName)
	return result


static func definition(upgrade_id: StringName) -> Dictionary:
	for candidate: Resource in DEFINITIONS:
		if candidate.get("upgrade_id") == upgrade_id:
			return candidate.call("to_dictionary") as Dictionary
	return {}


static func validate() -> bool:
	var seen: Dictionary = {}
	var represented_families: Dictionary = {}
	var definition_ids: Array[StringName] = ids()
	for candidate: Resource in DEFINITIONS:
		var upgrade_id: StringName = candidate.get("upgrade_id") as StringName
		if (
			seen.has(upgrade_id)
			or not bool(candidate.call("validate", FAMILIES, ItemCatalogScript.ids(), definition_ids))
		):
			return false
		seen[upgrade_id] = true
		represented_families[candidate.get("family") as StringName] = true
	return (
		seen.size() == DEFINITIONS.size()
		and represented_families.size() == FAMILIES.size()
		and ToolServiceScript.UPGRADE_WATER_EFFICIENCY in definition_ids
	)


static func capabilities_for(upgrade_ids: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for raw_upgrade: Variant in upgrade_ids:
		var definition_value: Dictionary = definition(StringName(str(raw_upgrade)))
		for raw_capability: Variant in definition_value.get(&"capabilities", []) as Array:
			var capability: StringName = StringName(str(raw_capability))
			if capability not in result:
				result.append(capability)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result
