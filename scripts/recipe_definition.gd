extends Resource

@export var recipe_id: StringName = &""
@export var station_tag: StringName = &""
@export_range(0, 365, 1) var duration_days: int = 0
@export var ingredients: Array[Dictionary] = []
@export var ingredient_groups: Array[Dictionary] = []
@export var outputs: Array[Dictionary] = []
@export var byproducts: Array[Dictionary] = []


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
	var groups: Array[Dictionary] = resolved_ingredient_groups()
	if groups.is_empty() or groups.size() > 8:
		return false
	for group: Dictionary in groups:
		if not _group_is_valid(group, item_ids):
			return false
	return (
		_entries_valid(ingredients, item_ids)
		and _entries_valid(outputs, item_ids)
		and (byproducts.is_empty() or _entries_valid(byproducts, item_ids))
	)


func to_dictionary() -> Dictionary:
	return {
		&"recipe_id": String(recipe_id),
		&"station_tag": String(station_tag),
		&"duration_days": duration_days,
		&"ingredients": ingredients.duplicate(true),
		&"ingredient_groups": resolved_ingredient_groups(),
		&"outputs": outputs.duplicate(true),
		&"byproducts": byproducts.duplicate(true),
	}


func resolved_ingredient_groups() -> Array[Dictionary]:
	if not ingredient_groups.is_empty():
		return ingredient_groups.duplicate(true)
	var groups: Array[Dictionary] = []
	for ingredient: Dictionary in ingredients:
		groups.append({&"options": [ingredient.duplicate(true)]})
	return groups


func _group_is_valid(group: Dictionary, item_ids: Array[StringName]) -> bool:
	if group.size() != 1 or not group.has(&"options") or not group[&"options"] is Array:
		return false
	var options: Array = group[&"options"] as Array
	return not options.is_empty() and options.size() <= 4 and _entries_valid(options, item_ids)


func _entries_valid(entries: Array, item_ids: Array[StringName]) -> bool:
	var seen: Dictionary = {}
	for value: Variant in entries:
		if not value is Dictionary:
			return false
		var entry: Dictionary = value as Dictionary
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
