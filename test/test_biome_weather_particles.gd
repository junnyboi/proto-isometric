extends RefCounted

const AtmosphereScript: GDScript = preload("res://scripts/desert_atmosphere.gd")
const CatalogScript: GDScript = preload("res://scripts/biome_weather_particle_catalog.gd")
const PROFILES: Array[StringName] = [&"sand", &"wetland", &"frozen", &"volcanic"]
const EXPECTED_KINDS: Dictionary = {
	&"sand": [&"sand", &"gust", &"grit"],
	&"wetland": [&"rain", &"mist", &"ripple"],
	&"frozen": [&"snowflake", &"ice_grain", &"snow_drift"],
	&"volcanic": [&"ash", &"ember", &"cinder"],
}


class FakeField:
	extends Node2D
	var camera_position: Vector2 = Vector2.ZERO
	var _world: RefCounted

	func get_camera_position() -> Vector2:
		return camera_position


class FakeWeatherAudio:
	extends Node
	var biome: StringName = &"sand"
	var intensity: float = 0.72

	func get_metrics() -> Dictionary:
		return {&"biome": biome, &"intensity": intensity}


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_profile_classes(cases)
	_test_deterministic_motion(cases)
	_test_camera_anchor(cases)
	_test_audio_sync_and_blend(cases)
	_test_accessibility_and_bounds(cases)
	_test_noninteractive_shipping(cases)
	return cases


static func _test_profile_classes(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	var all_kinds: Dictionary = {}
	for profile: StringName in PROFILES:
		var counts: Dictionary = CatalogScript.class_counts(profile, 128)
		var kinds: Array = EXPECTED_KINDS[profile] as Array
		var total: int = 0
		for kind: StringName in kinds:
			total += int(counts.get(kind, 0))
			all_kinds[kind] = true
		valid = valid and total == 128 and counts.size() == 3
	_add(
		cases,
		"each biome owns three distinct particle classes inside the fixed budget",
		valid and all_kinds.size() == 12,
	)


static func _test_deterministic_motion(cases: Array[Dictionary]) -> void:
	var rect: Rect2 = Rect2(-100.0, -80.0, 900.0, 620.0)
	var valid: bool = true
	var velocities: Dictionary = {}
	for profile: StringName in PROFILES:
		var counts: Dictionary = CatalogScript.class_counts(profile, 128)
		var kinds: Array = EXPECTED_KINDS[profile] as Array
		var indices: Array[int] = [0, int(counts[kinds[0]]), 127]
		for index: int in indices:
			var first: Dictionary = CatalogScript.snapshot(index, 128, profile, 1.25, rect, 0.8)
			var repeat: Dictionary = CatalogScript.snapshot(index, 128, profile, 1.25, rect, 0.8)
			var position: Vector2 = first[&"position"] as Vector2
			valid = (
				valid
				and first == repeat
				and rect.has_point(position)
				and (first[&"velocity"] as Vector2).length() > 0.0
				and float(first[&"alpha"]) > 0.0
			)
		velocities[CatalogScript.snapshot(0, 128, profile, 1.25, rect, 0.8)[&"velocity"]] = true
	_add(
		cases,
		"weather particle snapshots are deterministic, moving, visible, and viewport bounded",
		valid and velocities.size() == 4,
	)


static func _test_camera_anchor(cases: Array[Dictionary]) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var field: FakeField = FakeField.new()
	var atmosphere: Node2D = AtmosphereScript.new() as Node2D
	field.add_child(atmosphere)
	tree.root.add_child(field)
	field.camera_position = Vector2(120.0, -40.0)
	var first: Rect2 = (atmosphere.call("get_metrics") as Dictionary)[&"draw_rect"] as Rect2
	field.camera_position = Vector2(940.0, 620.0)
	var second: Rect2 = (atmosphere.call("get_metrics") as Dictionary)[&"draw_rect"] as Rect2
	_add(
		cases,
		"weather field follows the camera while preserving its padded viewport size",
		first.size == second.size and second.get_center() == field.camera_position,
	)
	field.queue_free()


static func _test_audio_sync_and_blend(cases: Array[Dictionary]) -> void:
	var atmosphere: Node2D = AtmosphereScript.new() as Node2D
	var weather: FakeWeatherAudio = FakeWeatherAudio.new()
	weather.biome = &"volcanic"
	weather.intensity = 0.95
	atmosphere.set("_weather_audio", weather)
	atmosphere.call("advance", 0.1)
	var synced: Dictionary = atmosphere.call("get_metrics") as Dictionary
	_add(
		cases,
		"particle biome and intensity follow the authoritative weather audio layer",
		(
			synced[&"profile"] == &"volcanic"
			and is_equal_approx(float(synced[&"target_intensity"]), 0.95)
			and float(synced[&"weather_intensity"]) > 0.72
			and bool(synced[&"blending"])
		),
	)
	atmosphere.call("advance", AtmosphereScript.BIOME_BLEND_SECONDS)
	var settled: Dictionary = atmosphere.call("get_metrics") as Dictionary
	_add(
		cases,
		"biome particle transitions settle without exceeding the fixed ceiling",
		(
			not bool(settled[&"blending"])
			and int(settled[&"visible_count"]) <= AtmosphereScript.PARTICLE_COUNT
		),
	)
	atmosphere.free()
	weather.free()


static func _test_accessibility_and_bounds(cases: Array[Dictionary]) -> void:
	var atmosphere: Node2D = AtmosphereScript.new() as Node2D
	atmosphere.call("_apply_preferences", {&"vfx_intensity": 1.0, &"effects_quality": &"full"})
	var full: int = int(atmosphere.call("get_visible_mark_count"))
	atmosphere.call(
		"_apply_preferences", {&"vfx_intensity": 1.0, &"effects_quality": &"reduced"}
	)
	var reduced: int = int(atmosphere.call("get_visible_mark_count"))
	atmosphere.call(
		"_apply_preferences", {&"vfx_intensity": 1.0, &"effects_quality": &"minimal"}
	)
	var minimal: int = int(atmosphere.call("get_visible_mark_count"))
	atmosphere.call("_apply_preferences", {&"vfx_intensity": 0.0, &"effects_quality": &"full"})
	var hidden: int = int(atmosphere.call("get_visible_mark_count"))
	_add(
		cases,
		"effects quality and VFX intensity scale weather to true zero within 128 marks",
		full <= 128 and full > reduced and reduced > minimal and minimal > hidden and hidden == 0,
	)
	atmosphere.free()


static func _test_noninteractive_shipping(cases: Array[Dictionary]) -> void:
	var atmosphere: Node2D = AtmosphereScript.new() as Node2D
	var source: String = FileAccess.get_file_as_string("res://scripts/desert_atmosphere.gd")
	var catalog: String = FileAccess.get_file_as_string(
		"res://scripts/biome_weather_particle_catalog.gd"
	)
	var export_text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_add(
		cases,
		"weather particles allocate no nodes, collisions, input, or physics bodies",
		(
			atmosphere.get_child_count() == 0
			and "CollisionShape2D" not in source + catalog
			and "RigidBody2D" not in source + catalog
			and "func _input" not in source + catalog
		),
	)
	_add(
		cases,
		"Web export ships the deterministic biome weather particle catalog",
		"res://scripts/biome_weather_particle_catalog.gd" in export_text,
	)
	atmosphere.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
