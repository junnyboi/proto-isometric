extends RefCounted

const BiomeMusicScript: GDScript = preload("res://scripts/biome_music.gd")
const ClearingMusicScript: GDScript = preload("res://scripts/clearing_music_catalog.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const HomesteadPresentationScript: GDScript = preload(
	"res://scripts/homestead_presentation_catalog.gd"
)
const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const MachineServiceScript: GDScript = preload("res://scripts/machine_service.gd")
const RelationshipServiceScript: GDScript = preload("res://scripts/relationship_service.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")
const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const VisualCatalogScript: GDScript = preload("res://scripts/visual_catalog.gd")

const PHASE_FIVE_VISUALS: Array[String] = [
	"res://assets/title/protos_harvest_title_desktop.png",
	"res://assets/title/protos_harvest_title_mobile.png",
	"res://assets/title/protos_harvest_icon.png",
	"res://assets/facilities/facility_home.png",
	"res://assets/facilities/facility_greenhouse.png",
	"res://assets/facilities/facility_workshop.png",
	"res://assets/facilities/facility_clinic_kitchen.png",
	"res://assets/residents/resident_lyra.png",
	"res://assets/residents/resident_rook.png",
	"res://assets/residents/resident_mira.png",
	"res://assets/livestock/livestock_mossback_spritesheet.png",
	"res://assets/livestock/livestock_coilhen_spritesheet.png",
	"res://assets/livestock/livestock_rustsnout_spritesheet.png",
]


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_catalog_and_dimensions(cases)
	_test_facility_state_art(cases)
	_test_resident_and_livestock_records(cases)
	_test_batched_renderer(cases, runtime)
	_test_music(cases, runtime)
	_test_brand_and_locales(cases)
	_test_live_bridge(cases, runtime)
	return cases


static func _fresh_farm() -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, 77)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	farm = MachineServiceScript.ensure_default(farm)
	farm = HomesteadServiceScript.ensure_default(farm)
	farm = ResidentServiceScript.ensure_default(farm)
	farm = RelationshipServiceScript.ensure_default(farm)
	farm = LivestockServiceScript.ensure_default(farm)
	return FarmSaveSchemaScript.validate(farm)


static func _test_catalog_and_dimensions(cases: Array[Dictionary]) -> void:
	var catalog: Resource = VisualCatalogScript.new() as Resource
	var paths: Array[String] = catalog.call("get_required_paths") as Array[String]
	_add(
		cases,
		"Phase 5 visual catalog contains every generated runtime image",
		(
			catalog.call("validate_required")
			and PHASE_FIVE_VISUALS.all(func(path: String) -> bool: return path in paths)
		),
	)
	var dimensions_valid: bool = true
	for path: String in PHASE_FIVE_VISUALS:
		var texture: Texture2D = load(path) as Texture2D
		if texture == null:
			dimensions_valid = false
			break
		if path.contains("livestock_"):
			dimensions_valid = dimensions_valid and texture.get_size() == Vector2(1024.0, 512.0)
		elif path.ends_with("title_desktop.png"):
			dimensions_valid = dimensions_valid and texture.get_size() == Vector2(1920.0, 1080.0)
		elif path.ends_with("title_mobile.png"):
			dimensions_valid = dimensions_valid and texture.get_size() == Vector2(1080.0, 1920.0)
		elif path.ends_with("icon.png"):
			dimensions_valid = dimensions_valid and texture.get_size() == Vector2(512.0, 512.0)
		else:
			dimensions_valid = dimensions_valid and texture.get_size() == Vector2(256.0, 256.0)
	_add(cases, "Phase 5 generated visuals retain exact runtime dimensions", dimensions_valid)


static func _test_facility_state_art(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var greenhouse_id: StringName = HomesteadServiceScript.GREENHOUSE_ID
	var ruin_path: String = HomesteadPresentationScript.facility_texture_path(farm, greenhouse_id)
	_set_facility_state(farm, greenhouse_id, true, true)
	var restored_path: String = HomesteadPresentationScript.facility_texture_path(
		farm, greenhouse_id
	)
	_add(
		cases,
		"Phase 5 facility presentation changes from legacy ruin art to generated restoration",
		(
			ruin_path == "res://assets/outposts/ancient_temple.png"
			and restored_path == "res://assets/facilities/facility_greenhouse.png"
		),
	)
	var records: Array[Dictionary] = HomesteadPresentationScript.build_records(farm)
	var home: Dictionary = _record(records, HomesteadServiceScript.HOME_ID)
	var greenhouse: Dictionary = _record(records, greenhouse_id)
	_add(
		cases,
		"Phase 5 home and powered facility records expose stable state without duplicate nodes",
		(
			home.get(&"texture_path", "") == "res://assets/facilities/facility_home.png"
			and greenhouse.get(&"repaired", false)
			and greenhouse.get(&"powered", false)
			and greenhouse.get(&"service_active", false)
		),
	)


static func _test_resident_and_livestock_records(cases: Array[Dictionary]) -> void:
	var farm: Dictionary = _fresh_farm()
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var residents: Array = homestead[&"residents"] as Array
	for index: int in residents.size():
		var resident: Dictionary = residents[index] as Dictionary
		resident[&"arrived"] = true
		resident[&"arrival_day"] = index + 1
		residents[index] = resident
	homestead[&"residents"] = residents
	homestead[&"animals"] = [
		_animal("animal.moss", LivestockServiceScript.MOSSBACK_ID, &"housing.home_paddock"),
		_animal("animal.coil", LivestockServiceScript.COILHEN_ID, &"housing.greenhouse_coop"),
		_animal("animal.rust", LivestockServiceScript.RUSTSNOUT_ID, &"housing.home_rooter_pen"),
	]
	farm[&"homestead"] = homestead
	var records: Array[Dictionary] = HomesteadPresentationScript.build_records(farm)
	var resident_count: int = _count_type(records, &"resident")
	var livestock_count: int = _count_type(records, &"livestock")
	_add(
		cases,
		"Phase 5 schedule snapshot renders all three arrived residents deterministically",
		resident_count == 3 and HomesteadPresentationScript.build_records(farm) == records,
	)
	var atlas_valid: bool = livestock_count == 3
	for record: Dictionary in records:
		if record.get(&"type", &"") != &"livestock":
			continue
		var region: Rect2 = record[&"atlas_region"] as Rect2
		atlas_valid = (
			atlas_valid
			and region.size == Vector2(256.0, 256.0)
			and region.position.x >= 0.0
			and region.position.x <= 768.0
			and region.position.y in [0.0, 256.0]
		)
	_add(cases, "Phase 5 all three livestock use stable 4x2 atlas records", atlas_valid)


static func _test_batched_renderer(cases: Array[Dictionary], runtime: Node2D) -> void:
	var farm: Dictionary = _fresh_farm()
	var renderer: Node2D = FarmRendererScript.new() as Node2D
	runtime.add_child(renderer)
	var configured: bool = renderer.call("configure", Callable(runtime, "grid_to_screen"), 8)
	var indexes: Dictionary = HomesteadPresentationScript.build_chunk_indexes(farm)
	var chunks: Array[Vector2i] = []
	for value: Variant in indexes:
		chunks.append(value as Vector2i)
	var accepted: bool = renderer.call("consume_indexes", indexes)
	renderer.call("set_visible_chunks", chunks)
	var first: Array[Dictionary] = renderer.call("get_visible_records") as Array[Dictionary]
	renderer.call("consume_indexes", indexes)
	var second: Array[Dictionary] = renderer.call("get_visible_records") as Array[Dictionary]
	_add(
		cases,
		"Phase 5 homestead presentation is batched depth-stable and node-free",
		(
			configured
			and accepted
			and not renderer.call("has_per_entity_nodes")
			and first == second
			and first.size() >= 4
		),
	)
	renderer.queue_free()


static func _test_music(cases: Array[Dictionary], runtime: Node2D) -> void:
	var music: Node = BiomeMusicScript.new() as Node
	runtime.add_child(music)
	var loops_valid: bool = true
	for path_value: Variant in ClearingMusicScript.PATHS.values():
		var stream: AudioStreamWAV = load(str(path_value)) as AudioStreamWAV
		loops_valid = (
			loops_valid
			and stream != null
			and stream.get_length() > 80.0
			and stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
		)
	_add(cases, "Phase 5 clearing WAV imports are long-form forward loops", loops_valid)
	var day: StringName = music.call("set_clearing_context", true, 720, &"weather.clear")
	var unchanged_changes: int = int((music.call("get_metrics") as Dictionary)[&"track_changes"])
	music.call("set_clearing_context", true, 720, &"weather.clear")
	var after_repeat: Dictionary = music.call("get_metrics") as Dictionary
	var rain: StringName = music.call("set_clearing_context", true, 720, &"weather.rain")
	var night: StringName = music.call("set_clearing_context", true, 60, &"weather.clear")
	_add(
		cases,
		"Phase 5 clearing music prioritizes rain then deterministic day and night",
		(
			day == ClearingMusicScript.TRACK_DAY
			and rain == ClearingMusicScript.TRACK_RAIN
			and night == ClearingMusicScript.TRACK_NIGHT
		),
	)
	_add(
		cases,
		"Phase 5 clearing music avoids restart spam and preserves legacy biome state",
		(
			int(after_repeat[&"track_changes"]) == unchanged_changes
			and music.call("set_clearing_context", false, 720, &"weather.clear") == &""
			and (music.call("get_metrics") as Dictionary)[&"biome"] == &"sand"
			and BiomeMusicScript.stream_paths_for(&"wetland").size() == 2
		),
	)
	music.queue_free()


static func _test_brand_and_locales(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"Phase 5 project identity and icon are Protos Harvest 2.0",
		(
			ProjectSettings.get_setting("application/config/name") == "Protos Harvest"
			and ProjectSettings.get_setting("application/config/version") == "2.0.0"
			and ProjectSettings.get_setting("application/config/icon")
			== "res://assets/title/protos_harvest_icon.png"
		),
	)
	var english: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/locales/en.json")
	) as Dictionary
	var chinese: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/locales/zh-CN.json")
	) as Dictionary
	_add(
		cases,
		"Phase 5 English and Chinese identity keys remain exactly paired",
		(
			english.keys().size() == chinese.keys().size()
			and english.keys().all(func(key: Variant) -> bool: return chinese.has(key))
			and english["title.name"] == "PROTOS HARVEST"
			and chinese["title.name"] == "原型收获"
		),
	)


static func _test_live_bridge(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var records: Array[Dictionary] = (
		bridge.call("get_live_presentation_records") as Array[Dictionary] if bridge != null else []
	)
	_add(
		cases,
		"Phase 5 live fresh-farm bridge exposes home plus three facility records",
		(
			bridge != null
			and bridge.call("is_ready_for_commands")
			and records.size() >= 4
			and not (bridge.call("get_farm_renderer") as Node2D).call("has_per_entity_nodes")
			and bridge.call("get_selected_clearing_track") == ClearingMusicScript.TRACK_DAY
		),
	)


static func _set_facility_state(
	farm: Dictionary, facility_id: StringName, repaired: bool, powered: bool
) -> void:
	var homestead: Dictionary = farm[&"homestead"] as Dictionary
	var facilities: Array = homestead[&"facilities"] as Array
	for index: int in facilities.size():
		var state: Dictionary = facilities[index] as Dictionary
		if StringName(state[&"facility_id"]) == facility_id:
			state[&"repaired"] = repaired
			state[&"powered"] = powered
			state[&"repair_token"] = "repair:%s" % facility_id if repaired else ""
			state[&"power_token"] = "power:%s" % facility_id if powered else ""
			facilities[index] = state
			break
	homestead[&"facilities"] = facilities
	farm[&"homestead"] = homestead


static func _animal(
	animal_id: String, species_id: StringName, housing_id: StringName
) -> Dictionary:
	return {
		&"animal_id": animal_id,
		&"species_id": String(species_id),
		&"housing_id": String(housing_id),
		&"bond": 0,
		&"last_feed_day": 0,
		&"last_pet_day": 0,
		&"last_product_day": 0,
		&"care_tokens": [],
	}


static func _record(records: Array[Dictionary], stable_id: StringName) -> Dictionary:
	for record: Dictionary in records:
		if record.get(&"stable_id", &"") == stable_id:
			return record
	return {}


static func _count_type(records: Array[Dictionary], type_id: StringName) -> int:
	var count: int = 0
	for record: Dictionary in records:
		if record.get(&"type", &"") == type_id:
			count += 1
	return count


static func _add(
	cases: Array[Dictionary], label: String, passed: bool
) -> void:
	cases.append({&"label": label, &"passed": passed})
