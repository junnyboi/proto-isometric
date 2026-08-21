extends RefCounted

const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var required_paths: Array[String] = OutpostVisualsScript.get_required_paths()
	_add(cases, "five ancient outpost variants are required", required_paths.size() == 5)
	var assets_valid: bool = true
	var sizes_valid: bool = true
	for kind: StringName in OutpostVisualsScript.KINDS:
		var texture: Texture2D = OutpostVisualsScript.texture_for(kind)
		var size: Vector2 = OutpostVisualsScript.display_size_for(kind)
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
	_add(cases, "every outpost sprite is a validated 384-pixel RGBA resource", assets_valid)
	_add(cases, "outposts render larger than Walker without exceeding two hundred pixels", sizes_valid)
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
	renderer.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
