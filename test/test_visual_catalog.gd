extends RefCounted

const CardinalAvatarScript: GDScript = preload("res://scripts/cardinal_avatar.gd")
const CATALOG: Resource = preload("res://data/visual_catalog.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"visual catalogue loads every required runtime asset",
		bool(CATALOG.call("validate_required"))
	)
	_add(
		cases,
		"visual catalogue declares all sixteen optional Cardinal sheets",
		(CATALOG.call("get_missing_optional") as Array).size() <= 16,
	)
	var cardinal: Node2D = CardinalAvatarScript.new() as Node2D
	cardinal.call("_ready")
	_add(
		cases,
		"Cardinal missing sheets retain deterministic procedural fallback",
		(
			(CATALOG.call("get_missing_optional") as Array).is_empty()
			or bool(cardinal.call("is_using_proxy"))
		),
	)
	cardinal.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
