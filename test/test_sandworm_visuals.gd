extends RefCounted

const SandwormVisualsScript: GDScript = preload("res://scripts/sandworm_visuals.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_runtime_assets(cases)
	_test_segment_layout(cases)
	_test_state_motion(cases)
	_test_shipping_contract(cases)
	return cases


static func _test_runtime_assets(cases: Array[Dictionary]) -> void:
	var texture_paths: PackedStringArray = SandwormVisualsScript.texture_paths()
	var parts: PackedStringArray = PackedStringArray(["head", "body", "tail"])
	_add(
		cases,
		"sandworm visual module exposes exactly three modular textures",
		texture_paths.size() == 3
	)
	for index: int in range(parts.size()):
		var part: String = parts[index]
		var path: String = texture_paths[index]
		var image: Image = Image.load_from_file(path)
		_add(
			cases,
			"%s sandworm texture loads from the runtime resource path" % part,
			not image.is_empty()
		)
		_add(
			cases,
			"%s sandworm texture is a normalized 512 square" % part,
			image.get_size() == Vector2i(512, 512)
		)
		var corners_clear: bool = true
		for corner: Vector2i in [
			Vector2i.ZERO, Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)
		]:
			corners_clear = corners_clear and image.get_pixelv(corner).a <= 0.001
		_add(
			cases, "%s sandworm texture has transparent rotation-safe corners" % part, corners_clear
		)


static func _test_segment_layout(cases: Array[Dictionary]) -> void:
	var layout: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.RIGHT, 2.75, 11, &"expose"
	)
	var repeated: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.RIGHT, 2.75, 11, &"expose"
	)
	var body_count: int = 0
	var tail_count: int = 0
	var trailing: bool = true
	for part: Dictionary in layout:
		body_count += 1 if part[&"kind"] == &"body" else 0
		tail_count += 1 if part[&"kind"] == &"tail" else 0
		trailing = trailing and (part[&"offset"] as Vector2).x < 0.0
	_add(
		cases,
		"exposed sandworm uses three body segments and one tail",
		body_count == 3 and tail_count == 1
	)
	_add(
		cases,
		"sandworm segment layout is deterministic for a fixed worm and time",
		layout == repeated
	)
	_add(cases, "all modular parts trail behind a right-facing head", trailing)
	_add(
		cases,
		"tail is rendered first at the furthest trailing distance",
		(
			layout[0][&"kind"] == &"tail"
			and (layout[0][&"offset"] as Vector2).x < (layout[1][&"offset"] as Vector2).x
		),
	)
	var downward: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.DOWN, 2.75, 11, &"expose"
	)
	_add(
		cases,
		"segment chain rotates behind a downward-facing head",
		(downward[0][&"offset"] as Vector2).y < SandwormVisualsScript.HEAD_RISE.y,
	)


static func _test_state_motion(cases: Array[Dictionary]) -> void:
	var exposed: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.RIGHT, 1.35, 7, &"expose"
	)
	var staggered: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.RIGHT, 1.35, 7, &"staggered"
	)
	var exposed_lateral: float = 0.0
	var staggered_lateral: float = 0.0
	for index: int in range(exposed.size()):
		exposed_lateral += absf(
			(exposed[index][&"offset"] as Vector2).y - SandwormVisualsScript.HEAD_RISE.y
		)
		staggered_lateral += absf(
			(staggered[index][&"offset"] as Vector2).y - SandwormVisualsScript.HEAD_RISE.y
		)
	_add(
		cases,
		"staggered sandworm motion tightens the body wave",
		staggered_lateral < exposed_lateral
	)
	var later: Array[Dictionary] = SandwormVisualsScript.build_layout(
		Vector2.RIGHT, 1.55, 7, &"expose"
	)
	_add(cases, "exposed body wave advances over time", later != exposed)


static func _test_shipping_contract(cases: Array[Dictionary]) -> void:
	var export_text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_add(
		cases,
		"Web export includes sandworm textures and visual module",
		(
			"assets/enemies/sandworm/*.png" in export_text
			and "scripts/sandworm_visuals.gd" in export_text
		),
	)
	var source: String = FileAccess.get_file_as_string("res://scripts/sandworms.gd")
	_add(
		cases,
		"sandworm exposed anatomy delegates to the generated sprite module",
		(
			"SandwormVisualsScript" in source
			and ". draw_exposed_body(" in source
			and "draw_circle(head" not in source
			and "draw_circle(segment_center" not in source
		),
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
