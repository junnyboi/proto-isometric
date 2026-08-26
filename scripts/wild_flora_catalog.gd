extends RefCounted

const SPECIES_STARFLOWER: StringName = &"flora.starflower"
const SPECIES_BRAMBLEBERRY: StringName = &"flora.brambleberry"
const SPECIES_SUNPEAR: StringName = &"flora.sunpear"
const SPECIES_WILDWHEAT: StringName = &"flora.wildwheat"
const SPECIES_COTTON: StringName = &"flora.cotton"
const SPECIES_IDS: Array[StringName] = [
	SPECIES_STARFLOWER,
	SPECIES_BRAMBLEBERRY,
	SPECIES_SUNPEAR,
	SPECIES_WILDWHEAT,
	SPECIES_COTTON,
]
const TOTAL_WEIGHT: int = 100
const DEFINITIONS: Array[Dictionary] = [
	{
		&"species_id": SPECIES_STARFLOWER,
		&"crop_id": &"crop.starflower",
		&"seed_item_id": &"item.seed.starflower",
		&"produce_item_id": &"item.produce.starflower",
		&"mature_yield": 2,
		&"spawn_weight": 28,
		&"texture_path": "res://assets/flora/flora_starflower_stages.png",
	},
	{
		&"species_id": SPECIES_BRAMBLEBERRY,
		&"crop_id": &"crop.brambleberry",
		&"seed_item_id": &"item.seed.brambleberry",
		&"produce_item_id": &"item.produce.brambleberry",
		&"mature_yield": 4,
		&"spawn_weight": 22,
		&"texture_path": "res://assets/flora/flora_brambleberry_stages.png",
	},
	{
		&"species_id": SPECIES_SUNPEAR,
		&"crop_id": &"crop.sunpear",
		&"seed_item_id": &"item.seed.sunpear",
		&"produce_item_id": &"item.produce.sunpear",
		&"mature_yield": 4,
		&"spawn_weight": 12,
		&"texture_path": "res://assets/flora/flora_sunpear_stages.png",
	},
	{
		&"species_id": SPECIES_WILDWHEAT,
		&"crop_id": &"crop.wildwheat",
		&"seed_item_id": &"item.seed.wildwheat",
		&"produce_item_id": &"item.produce.wildwheat",
		&"mature_yield": 6,
		&"spawn_weight": 22,
		&"texture_path": "res://assets/flora/flora_wildwheat_stages.png",
	},
	{
		&"species_id": SPECIES_COTTON,
		&"crop_id": &"crop.cotton",
		&"seed_item_id": &"item.seed.cotton",
		&"produce_item_id": &"item.produce.cotton",
		&"mature_yield": 4,
		&"spawn_weight": 16,
		&"texture_path": "res://assets/flora/flora_cotton_stages.png",
	},
]


static func definition(species_id: StringName) -> Dictionary:
	for candidate: Dictionary in DEFINITIONS:
		if candidate[&"species_id"] == species_id:
			return candidate.duplicate(true)
	return {}


static func species_for_weight_roll(roll: int) -> StringName:
	var bounded: int = posmod(roll, TOTAL_WEIGHT)
	var cumulative: int = 0
	for candidate: Dictionary in DEFINITIONS:
		cumulative += int(candidate[&"spawn_weight"])
		if bounded < cumulative:
			return candidate[&"species_id"] as StringName
	return SPECIES_COTTON


static func smash_reward(species_id: StringName) -> Dictionary:
	var flora: Dictionary = definition(species_id)
	if flora.is_empty():
		return {}
	return {
		&"produce_item_id": flora[&"produce_item_id"] as StringName,
		&"produce_count": maxi(1, int(flora[&"mature_yield"]) / 2),
		&"seed_item_id": flora[&"seed_item_id"] as StringName,
		&"seed_count": 1,
	}


static func validate(load_assets: bool = true) -> bool:
	var seen_species: Dictionary = {}
	var seen_crops: Dictionary = {}
	var total_weight: int = 0
	for flora: Dictionary in DEFINITIONS:
		var species_id: StringName = flora[&"species_id"] as StringName
		var crop_id: StringName = flora[&"crop_id"] as StringName
		if (
			species_id not in SPECIES_IDS
			or seen_species.has(species_id)
			or seen_crops.has(crop_id)
			or int(flora[&"mature_yield"]) <= 0
			or int(flora[&"spawn_weight"]) <= 0
		):
			return false
		if load_assets:
			var texture: Texture2D = load(str(flora[&"texture_path"])) as Texture2D
			if texture == null or texture.get_size() != Vector2(1024, 256):
				return false
		seen_species[species_id] = true
		seen_crops[crop_id] = true
		total_weight += int(flora[&"spawn_weight"])
	return seen_species.size() == SPECIES_IDS.size() and total_weight == TOTAL_WEIGHT
