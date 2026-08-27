extends RefCounted

const ItemCatalogScript: GDScript = preload("res://scripts/item_catalog.gd")

const WOODLAND_POND: StringName = &"fish.spot.woodland_pond"
const MIRE_POOL: StringName = &"fish.spot.mire_pool"
const RIME_MELT: StringName = &"fish.spot.rime_melt"
const MIRE_POOL_CELL: Vector2i = Vector2i(40, 0)
const RIME_MELT_CELL: Vector2i = Vector2i(12, -15)
const SPOT_IDS: Array[StringName] = [MIRE_POOL, RIME_MELT, WOODLAND_POND]
const SPOTS: Array[Dictionary] = [
	{&"spot_id": MIRE_POOL, &"water_class": &"mire_pool", &"capacity": 5},
	{&"spot_id": RIME_MELT, &"water_class": &"rime_melt", &"capacity": 4},
	{&"spot_id": WOODLAND_POND, &"water_class": &"freshwater_pond", &"capacity": 4},
]

const RELAY_MINNOW: StringName = &"fish.relay_minnow"
const RUSTFIN_PERCH: StringName = &"fish.rustfin_perch"
const GLASSLAMP_EEL: StringName = &"fish.glasslamp_eel"
const MOSSBACK_CARP: StringName = &"fish.mossback_carp"
const FISH_IDS: Array[StringName] = [
	GLASSLAMP_EEL, MOSSBACK_CARP, RELAY_MINNOW, RUSTFIN_PERCH,
]
const FISH: Array[Dictionary] = [
	{
		&"fish_id": GLASSLAMP_EEL,
		&"item_id": &"item.fish.glasslamp_eel",
		&"spots": [WOODLAND_POND, MIRE_POOL],
		&"seasons": [&"season.autumn", &"season.winter"],
		&"weather": [&"weather.cloudy", &"weather.rain"],
		&"weight": 8,
		&"bait_bonus": 12,
		&"icon_path": "res://assets/fishing/fish_glasslamp_eel.png",
	},
	{
		&"fish_id": MOSSBACK_CARP,
		&"item_id": &"item.fish.mossback_carp",
		&"spots": [WOODLAND_POND],
		&"seasons": [&"season.spring", &"season.autumn"],
		&"weather": [&"weather.rain", &"weather.cloudy"],
		&"weight": 10,
		&"bait_bonus": 8,
		&"icon_path": "res://assets/fishing/fish_mossback_carp.png",
	},
	{
		&"fish_id": RELAY_MINNOW,
		&"item_id": &"item.fish.relay_minnow",
		&"spots": SPOT_IDS,
		&"seasons": [
			&"season.spring", &"season.summer", &"season.autumn", &"season.winter"
		],
		&"weather": [
			&"weather.clear", &"weather.cloudy", &"weather.rain", &"weather.wind"
		],
		&"weight": 35,
		&"bait_bonus": 0,
		&"icon_path": "res://assets/fishing/fish_relay_minnow.png",
	},
	{
		&"fish_id": RUSTFIN_PERCH,
		&"item_id": &"item.fish.rustfin_perch",
		&"spots": [WOODLAND_POND, RIME_MELT],
		&"seasons": [&"season.spring", &"season.summer"],
		&"weather": [&"weather.clear", &"weather.cloudy", &"weather.wind"],
		&"weight": 20,
		&"bait_bonus": 3,
		&"icon_path": "res://assets/fishing/fish_rustfin_perch.png",
	},
]


static func spot(spot_id: StringName) -> Dictionary:
	for candidate: Dictionary in SPOTS:
		if candidate[&"spot_id"] == spot_id:
			return candidate.duplicate(true)
	return {}


static func spot_for_water_class(water_class: StringName) -> StringName:
	for candidate: Dictionary in SPOTS:
		if candidate[&"water_class"] == water_class:
			return candidate[&"spot_id"] as StringName
	return &""


static func live_water_class(
	cell: Vector2i, biome_id: StringName, is_woodland_pond: bool
) -> StringName:
	if is_woodland_pond:
		return &"freshwater_pond"
	if cell == MIRE_POOL_CELL and biome_id == &"oasis":
		return &"mire_pool"
	if cell == RIME_MELT_CELL and biome_id == &"frozen":
		return &"rime_melt"
	return &""


static func fish(fish_id: StringName) -> Dictionary:
	for candidate: Dictionary in FISH:
		if candidate[&"fish_id"] == fish_id:
			return candidate.duplicate(true)
	return {}


static func eligible(
	spot_id: StringName, season_id: StringName, weather_id: StringName
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate: Dictionary in FISH:
		if (
			spot_id in (candidate[&"spots"] as Array)
			and season_id in (candidate[&"seasons"] as Array)
			and weather_id in (candidate[&"weather"] as Array)
		):
			result.append(candidate.duplicate(true))
	return result


static func validate(load_assets: bool = true) -> bool:
	var seen_spots: Dictionary = {}
	for record: Dictionary in SPOTS:
		if record[&"spot_id"] not in SPOT_IDS or seen_spots.has(record[&"spot_id"]):
			return false
		if int(record[&"capacity"]) <= 0:
			return false
		seen_spots[record[&"spot_id"]] = true
	var seen_fish: Dictionary = {}
	for record: Dictionary in FISH:
		if record[&"fish_id"] not in FISH_IDS or seen_fish.has(record[&"fish_id"]):
			return false
		if record[&"item_id"] not in ItemCatalogScript.ids():
			return false
		if (record[&"spots"] as Array).is_empty() or int(record[&"weight"]) <= 0:
			return false
		if load_assets:
			var texture: Texture2D = load(str(record[&"icon_path"])) as Texture2D
			if texture == null or texture.get_size() != Vector2(320, 192):
				return false
		seen_fish[record[&"fish_id"]] = true
	return seen_spots.size() == SPOT_IDS.size() and seen_fish.size() == FISH_IDS.size()
