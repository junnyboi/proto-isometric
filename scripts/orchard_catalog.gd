extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const IRONBARK: StringName = &"tree.ironbark"
const CINDERAPPLE: StringName = &"tree.cinderapple"
const SPECIES_IDS: Array[StringName] = [CINDERAPPLE, IRONBARK]
const DEFINITIONS: Array[Dictionary] = [
	{
		&"species_id": CINDERAPPLE,
		&"sapling_item_id": &"item.sapling.cinderapple",
		&"harvest_item_id": &"item.produce.cinderapple",
		&"growth_thresholds": [0, 4, 9, 15],
		&"regrow_points": 11,
		&"yield_min": 3,
		&"yield_max": 5,
		&"favored_seasons": [&"season.spring", &"season.summer", &"season.autumn"],
		&"texture_path": "res://assets/settlement/orchard/tree_cinderapple_stages.png",
	},
	{
		&"species_id": IRONBARK,
		&"sapling_item_id": &"item.sapling.ironbark",
		&"harvest_item_id": &"item.material.wood",
		&"growth_thresholds": [0, 5, 11, 18],
		&"regrow_points": 13,
		&"yield_min": 4,
		&"yield_max": 7,
		&"favored_seasons": [&"season.spring", &"season.summer", &"season.autumn"],
		&"texture_path": "res://assets/settlement/orchard/tree_ironbark_stages.png",
	},
]


static func definition(species_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"species_id"] == species_id:
			return candidate.duplicate(true)
	return {}


static func species_for_sapling(item_id: StringName) -> StringName:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"sapling_item_id"] == item_id:
			return candidate[&"species_id"] as StringName
	return &""


static func stage_for(species_id: StringName, growth_points: int) -> int:
	var thresholds: Array = definition(species_id).get(&"growth_thresholds", []) as Array
	var stage: int = 0
	for index: int in thresholds.size():
		if growth_points >= int(thresholds[index]):
			stage = index
	return clampi(stage, 0, 3)


static func is_mature(species_id: StringName, growth_points: int) -> bool:
	return stage_for(species_id, growth_points) == 3


static func growth_increment(species_id: StringName, season_id: StringName) -> int:
	var seasons: Array = definition(species_id).get(&"favored_seasons", []) as Array
	return 1 if season_id in seasons else 0


static func deterministic_yield(
	species_id: StringName,
	cell: Vector2i,
	planted_day: int,
	harvest_sequence: int,
) -> int:
	var record: Dictionary = definition(species_id)
	if record.is_empty():
		return 0
	var value: int = cell.x * 73_856_093 ^ cell.y * 19_349_663
	value ^= planted_day * 83_492_791 ^ harvest_sequence * 2_654_435_761
	for index: int in String(species_id).length():
		value = value * 33 ^ String(species_id).unicode_at(index)
	value = absi(value ^ (value >> 16))
	var minimum: int = int(record[&"yield_min"])
	var maximum: int = int(record[&"yield_max"])
	return minimum + posmod(value, maximum - minimum + 1)


static func validate(load_assets: bool = true) -> bool:
	var seen: Dictionary = {}
	for record: Dictionary in DEFINITIONS:
		var species_id: StringName = record[&"species_id"] as StringName
		var thresholds: Array = record[&"growth_thresholds"] as Array
		if species_id not in SPECIES_IDS or seen.has(species_id) or thresholds.size() != 4:
			return false
		if record[&"sapling_item_id"] not in ItemCatalogScript.ids():
			return false
		if record[&"harvest_item_id"] not in ItemCatalogScript.ids():
			return false
		if int(record[&"regrow_points"]) >= int(thresholds[3]):
			return false
		if load_assets:
			var texture: Texture2D = load(str(record[&"texture_path"])) as Texture2D
			if texture == null or texture.get_size() != Vector2(1024, 320):
				return false
		seen[species_id] = true
	return seen.size() == SPECIES_IDS.size()
