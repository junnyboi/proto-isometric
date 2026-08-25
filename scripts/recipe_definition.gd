extends Resource

@export var recipe_id: StringName = &""
@export var station_tag: StringName = &""
@export_range(0, 365, 1) var duration_days: int = 0
@export var ingredients: Array[Dictionary] = []
@export var outputs: Array[Dictionary] = []


func validate(item_ids: Array[StringName], station_ids: Array[StringName]) -> bool:
	if (
		not String(recipe_id).begins_with("recipe.")
		or station_tag not in station_ids
		or duration_days < 0
		or duration_days > 365
		or ingredients.is_empty()
		or outputs.is_empty()
	):
		return false
	return _entries_valid(ingredients, item_ids) and _entries_valid(outputs, item_ids)


func to_dictionary() -> Dictionary:
	return {
		&"recipe_id": String(recipe_id),
		&"station_tag": String(station_tag),
		&"duration_days": duration_days,
		&"ingredients": ingredients.duplicate(true),
		&"outputs": outputs.duplicate(true),
	}


func _entries_valid(entries: Array[Dictionary], item_ids: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for entry: Dictionary in entries:
		if entry.size() != 2 or not entry.has(&"item_id") or not entry.has(&"count"):
			return false
		var item_id: StringName = StringName(str(entry[&"item_id"]))
		var count: Variant = entry[&"count"]
		if (
			item_id not in item_ids
			or seen.has(item_id)
			or not count is int
			or int(count) <= 0
			or int(count) > 999
		):
			return false
		seen[item_id] = true
	return true
