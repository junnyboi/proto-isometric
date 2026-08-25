extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const STATION_WORKBENCH: StringName = &"station.workbench"
const STATION_FURNACE: StringName = &"station.furnace"
const STATION_TAGS: Array[StringName] = [STATION_WORKBENCH, STATION_FURNACE]
const RECIPE_IRRIGATION_COIL: StringName = &"recipe.workbench.irrigation_coil"
const RECIPE_IRON_INGOT: StringName = &"recipe.furnace.iron_ingot"
const DEFINITIONS: Array[Resource] = [
	preload("res://data/recipes/irrigation_coil.tres"),
	preload("res://data/recipes/iron_ingot.tres"),
]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for definition: Resource in DEFINITIONS:
		result.append(definition.get("recipe_id") as StringName)
	return result


static func definition(recipe_id: StringName) -> Dictionary:
	for candidate: Resource in DEFINITIONS:
		if candidate.get("recipe_id") == recipe_id:
			return candidate.call("to_dictionary") as Dictionary
	return {}


static func validate() -> bool:
	var seen: Dictionary = {}
	for candidate: Resource in DEFINITIONS:
		var recipe_id: StringName = candidate.get("recipe_id") as StringName
		var valid: bool = bool(
			candidate.call("validate", ItemCatalogScript.ids(), STATION_TAGS)
		)
		if seen.has(recipe_id) or not valid:
			return false
		seen[recipe_id] = true
	return seen.size() == 2
