extends RefCounted

const OutpostEnergyScript: GDScript = preload("res://scripts/outpost_energy.gd")
const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var required_paths: Array[String] = OutpostVisualsScript.get_required_paths()
	_add(cases, "five ancient outpost variants are required", required_paths.size() == 5)
	var assets_valid: bool = true
	var sizes_valid: bool = true
	var anchors_valid: bool = true
	for kind: StringName in OutpostVisualsScript.KINDS:
		var texture: Texture2D = OutpostVisualsScript.texture_for(kind)
		var size: Vector2 = OutpostVisualsScript.display_size_for(kind)
		var anchor: Vector2 = OutpostVisualsScript.beacon_offset_for(kind)
		assets_valid = (
			assets_valid
			and texture != null
			and texture.get_width() == 384
			and texture.get_height() == 384
			and texture.resource_path in required_paths
		)
		sizes_valid = (
			sizes_valid
			and size.x >= 178.0
			and size.x <= 198.0
			and is_equal_approx(size.x, size.y)
		)
		anchors_valid = (
			anchors_valid
			and is_finite(anchor.x)
			and is_finite(anchor.y)
			and absf(anchor.x) <= size.x * 0.5
			and anchor.y >= OutpostVisualsScript.BASE_OFFSET.y - size.y
			and anchor.y <= OutpostVisualsScript.BASE_OFFSET.y
		)
	_add(cases, "every outpost sprite is a validated 384-pixel RGBA resource", assets_valid)
	_add(cases, "outposts render larger than Walker without exceeding two hundred pixels", sizes_valid)
	_add(cases, "every energy beacon is anchored inside its structure silhouette", anchors_valid)
	var observed: Dictionary = {}
	for y: int in range(-12, 13):
		for x: int in range(-12, 13):
			observed[OutpostVisualsScript.kind_for(Vector2i(x, y))] = true
	_add(
		cases,
		"deterministic cell selection reaches every ancient outpost family",
		observed.size() == 5,
	)
	var sample: Vector2i = Vector2i(8, 4)
	var stable_kind: StringName = OutpostVisualsScript.kind_for(sample)
	var stable: bool = true
	for _index: int in range(12):
		stable = stable and OutpostVisualsScript.kind_for(sample) == stable_kind
	_add(
		cases,
		"outpost selection is stable for the same world cell",
		stable,
	)
	var renderer: Node2D = WorldObjectsScript.new() as Node2D
	renderer.call(
		"configure",
		{},
		{},
		{sample: true},
		func(cell: Vector2i) -> Vector2: return Vector2(cell),
	)
	_add(
		cases,
		"world renderer routes outposts through the generated sprite catalog",
		(
			renderer.call("get_outpost_kind", sample) == OutpostVisualsScript.kind_for(sample)
			and str(renderer.call("get_outpost_texture_path", sample)) in required_paths
		),
	)
	var energy: Node2D = renderer.get_node("OutpostEnergy") as Node2D
	energy.call("set_visible_cells", [sample] as Array[Vector2i])
	_add(
		cases,
		"one shared renderer owns all visible outpost energy",
		(
			renderer.get_child_count() == 1
			and int(energy.call("get_visible_beacon_count")) == 1
		),
	)
	var snapshot_before: Dictionary = energy.call("_get_animation_snapshot", sample) as Dictionary
	var static_redraws: int = int(renderer.call("get_redraw_request_count"))
	var redraws_before: int = int(energy.call("get_redraw_request_count"))
	energy.call("advance", OutpostEnergyScript.UPDATE_INTERVAL_SECONDS * 0.5)
	var redraws_mid: int = int(energy.call("get_redraw_request_count"))
	energy.call("advance", OutpostEnergyScript.UPDATE_INTERVAL_SECONDS * 0.6)
	var snapshot_after: Dictionary = energy.call("_get_animation_snapshot", sample) as Dictionary
	_add(
		cases,
		"beacon animation is deterministic and redraw-capped to twelve hertz",
		(
			redraws_mid == redraws_before
			and int(energy.call("get_redraw_request_count")) == redraws_before + 1
			and int(renderer.call("get_redraw_request_count")) == static_redraws
			and snapshot_before[&"anchor"] == snapshot_after[&"anchor"]
			and not is_equal_approx(
				float(snapshot_before[&"pulse"]), float(snapshot_after[&"pulse"])
			)
		),
	)
	energy.call("_apply_preferences", {&"vfx_intensity": 0.5, &"effects_quality": &"reduced"})
	_add(
		cases,
		"beacon strength composes VFX intensity with the certified quality tier",
		is_equal_approx(float(energy.call("get_effect_strength")), 0.36),
	)
	energy.call("_apply_preferences", {&"vfx_intensity": 0.0, &"effects_quality": &"full"})
	_add(
		cases,
		"zero VFX intensity suppresses and idles ambient outpost energy",
		(
			is_zero_approx(float(energy.call("get_effect_strength")))
			and not energy.is_processing()
		),
	)
	renderer.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
