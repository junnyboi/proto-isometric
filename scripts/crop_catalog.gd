extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const CROP_IDS: Array[StringName] = [
	&"crop.glowroot",
	&"crop.coilbean",
	&"crop.ironturnip",
	&"crop.rainleaf",
	&"crop.starbloom",
	&"crop.sunpod",
	&"crop.starflower",
	&"crop.brambleberry",
	&"crop.sunpear",
	&"crop.wildwheat",
	&"crop.cotton",
]
const DEFINITIONS: Array[Dictionary] = [
	{
		&"crop_id": &"crop.glowroot",
		&"role": &"fast_staple",
		&"seed_item_id": &"item.seed.glowroot",
		&"produce_item_id": &"item.produce.glowroot",
		&"stage_growth": [0, 1, 2, 3],
		&"yield_min": 2,
		&"yield_max": 2,
		&"regrow_days": 0,
		&"texture_path": "res://assets/crops/crop_glowroot_stages.png",
		&"favored_seasons": [&"season.spring", &"season.autumn"],
		&"traits": []
	},
	{
		&"crop_id": &"crop.coilbean",
		&"role": &"regrowing_bean",
		&"seed_item_id": &"item.seed.coilbean",
		&"produce_item_id": &"item.produce.coilbean",
		&"stage_growth": [0, 2, 4, 6],
		&"yield_min": 2,
		&"yield_max": 4,
		&"regrow_days": 3,
		&"texture_path": "res://assets/crops/crop_coilbean_stages.png",
		&"favored_seasons": [&"season.summer", &"season.autumn"],
		&"traits": [&"regrows"]
	},
	{
		&"crop_id": &"crop.ironturnip",
		&"role": &"hardy_root",
		&"seed_item_id": &"item.seed.ironturnip",
		&"produce_item_id": &"item.produce.ironturnip",
		&"stage_growth": [0, 2, 4, 5],
		&"yield_min": 1,
		&"yield_max": 3,
		&"regrow_days": 0,
		&"texture_path": "res://assets/crops/crop_ironturnip_stages.png",
		&"favored_seasons": [&"season.autumn", &"season.winter"],
		&"traits": [&"hardy"]
	},
	{
		&"crop_id": &"crop.rainleaf",
		&"role": &"rain_loving",
		&"seed_item_id": &"item.seed.rainleaf",
		&"produce_item_id": &"item.produce.rainleaf",
		&"stage_growth": [0, 2, 4, 6],
		&"yield_min": 2,
		&"yield_max": 3,
		&"regrow_days": 0,
		&"texture_path": "res://assets/crops/crop_rainleaf_stages.png",
		&"favored_seasons": [&"season.spring", &"season.summer"],
		&"traits": [&"rain_bonus"]
	},
	{
		&"crop_id": &"crop.starbloom",
		&"role": &"forage_derived",
		&"seed_item_id": &"item.seed.starbloom",
		&"produce_item_id": &"item.produce.starbloom",
		&"stage_growth": [0, 2, 5, 7],
		&"yield_min": 1,
		&"yield_max": 2,
		&"regrow_days": 0,
		&"texture_path": "res://assets/crops/crop_starbloom_stages.png",
		&"favored_seasons": [&"season.spring"],
		&"traits": [&"forage_seed"]
	},
	{
		&"crop_id": &"crop.sunpod",
		&"role": &"desert_premium",
		&"seed_item_id": &"item.seed.sunpod",
		&"produce_item_id": &"item.produce.sunpod",
		&"stage_growth": [0, 3, 6, 9],
		&"yield_min": 2,
		&"yield_max": 4,
		&"regrow_days": 0,
		&"texture_path": "res://assets/crops/crop_sunpod_stages.png",
		&"favored_seasons": [&"season.summer"],
		&"traits": [&"desert_affinity"]
	},
	{
		&"crop_id": &"crop.starflower",
		&"role": &"wild_flower",
		&"seed_item_id": &"item.seed.starflower",
		&"produce_item_id": &"item.produce.starflower",
		&"stage_growth": [0, 1, 2, 3],
		&"yield_min": 2,
		&"yield_max": 2,
		&"regrow_days": 0,
		&"texture_path": "res://assets/flora/flora_starflower_stages.png",
		&"favored_seasons": [&"season.spring", &"season.summer"],
		&"traits": [&"forage_seed", &"wild_discovery"]
	},
	{
		&"crop_id": &"crop.brambleberry",
		&"role": &"wild_berry",
		&"seed_item_id": &"item.seed.brambleberry",
		&"produce_item_id": &"item.produce.brambleberry",
		&"stage_growth": [0, 1, 2, 4],
		&"yield_min": 4,
		&"yield_max": 4,
		&"regrow_days": 2,
		&"texture_path": "res://assets/flora/flora_brambleberry_stages.png",
		&"favored_seasons": [&"season.summer", &"season.autumn"],
		&"traits": [&"forage_seed", &"regrows", &"wild_discovery"]
	},
	{
		&"crop_id": &"crop.sunpear",
		&"role": &"compact_orchard",
		&"seed_item_id": &"item.seed.sunpear",
		&"produce_item_id": &"item.produce.sunpear",
		&"stage_growth": [0, 2, 4, 6],
		&"yield_min": 4,
		&"yield_max": 4,
		&"regrow_days": 3,
		&"texture_path": "res://assets/flora/flora_sunpear_stages.png",
		&"favored_seasons": [&"season.summer", &"season.autumn"],
		&"traits": [&"forage_seed", &"regrows", &"orchard", &"wild_discovery"]
	},
	{
		&"crop_id": &"crop.wildwheat",
		&"role": &"wild_grain",
		&"seed_item_id": &"item.seed.wildwheat",
		&"produce_item_id": &"item.produce.wildwheat",
		&"stage_growth": [0, 1, 2, 4],
		&"yield_min": 6,
		&"yield_max": 6,
		&"regrow_days": 0,
		&"texture_path": "res://assets/flora/flora_wildwheat_stages.png",
		&"favored_seasons": [&"season.spring", &"season.autumn"],
		&"traits": [&"forage_seed", &"grain", &"wild_discovery"]
	},
	{
		&"crop_id": &"crop.cotton",
		&"role": &"wild_fiber",
		&"seed_item_id": &"item.seed.cotton",
		&"produce_item_id": &"item.produce.cotton",
		&"stage_growth": [0, 2, 3, 5],
		&"yield_min": 4,
		&"yield_max": 4,
		&"regrow_days": 0,
		&"texture_path": "res://assets/flora/flora_cotton_stages.png",
		&"favored_seasons": [&"season.summer", &"season.autumn"],
		&"traits": [&"forage_seed", &"fiber", &"wild_discovery"]
	},
]


static func definition(crop_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"crop_id"] == crop_id:
			return candidate.duplicate(true)
	return {}


static func crop_for_seed(seed_item_id: StringName) -> StringName:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"seed_item_id"] == seed_item_id:
			return candidate[&"crop_id"] as StringName
	return &""


static func stage_for(crop_id: StringName, growth_points: int) -> int:
	var thresholds: Array = definition(crop_id).get(&"stage_growth", []) as Array
	var stage: int = 0
	for index: int in thresholds.size():
		if growth_points >= int(thresholds[index]):
			stage = index
	return clampi(stage, 0, 3)


static func is_favored(crop_id: StringName, season_id: StringName) -> bool:
	return season_id in (definition(crop_id).get(&"favored_seasons", []) as Array)


static func growth_increment(crop_id: StringName, season_id: StringName) -> int:
	return 2 if is_favored(crop_id, season_id) else 0


static func deterministic_yield(
	crop_id: StringName, cell: Vector2i, planted_day: int, harvest_sequence: int
) -> int:
	var crop: Dictionary = definition(crop_id)
	if crop.is_empty():
		return 0
	var minimum: int = int(crop[&"yield_min"])
	var maximum: int = int(crop[&"yield_max"])
	var value: int = cell.x * 73_856_093 ^ cell.y * 19_349_663
	value ^= planted_day * 83_492_791 ^ harvest_sequence * 2_654_435_761
	for index: int in String(crop_id).length():
		value = value * 33 ^ String(crop_id).unicode_at(index)
	value = absi(value ^ (value >> 16))
	return minimum + posmod(value, maximum - minimum + 1)


static func validate(load_assets: bool = true) -> bool:
	var seen: Dictionary = {}
	var roles: Dictionary = {}
	for crop: Dictionary in DEFINITIONS:
		var crop_id: StringName = crop[&"crop_id"] as StringName
		var stages: Array = crop[&"stage_growth"] as Array
		var seasons: Array = crop.get(&"favored_seasons", []) as Array
		if seen.has(crop_id) or crop_id not in CROP_IDS or stages.size() != 4:
			return false
		if not _strictly_increasing(stages) or seasons.is_empty():
			return false
		for season_id: Variant in seasons:
			if season_id not in [
				&"season.spring", &"season.summer", &"season.autumn", &"season.winter"
			]:
				return false
		if (
			crop[&"seed_item_id"] not in ItemCatalogScript.ids()
			or crop[&"produce_item_id"] not in ItemCatalogScript.ids()
			or int(crop[&"yield_min"]) <= 0
			or int(crop[&"yield_max"]) < int(crop[&"yield_min"])
		):
			return false
		if load_assets:
			var texture: Texture2D = load(str(crop[&"texture_path"])) as Texture2D
			if texture == null or texture.get_size() != Vector2(1024, 256):
				return false
		seen[crop_id] = true
		roles[crop[&"role"]] = true
	return seen.size() == CROP_IDS.size() and roles.size() == CROP_IDS.size()


static func _strictly_increasing(values: Array) -> bool:
	if values.is_empty() or int(values[0]) != 0:
		return false
	for index: int in range(1, values.size()):
		if int(values[index]) <= int(values[index - 1]):
			return false
	return true
