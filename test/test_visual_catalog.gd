extends RefCounted

const CardinalAvatarScript: GDScript = preload("res://scripts/cardinal_avatar.gd")
const CATALOG: Resource = preload("res://data/visual_catalog.tres")
const DIRECTIONS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add(
		cases,
		"visual catalogue loads every required runtime asset",
		bool(CATALOG.call("validate_required")),
	)
	_add(
		cases,
		"combined Cardinal atlas is a required runtime asset",
		(
			"res://assets/cardinal/grunt_sprite_atlas.png"
			in (CATALOG.call("get_required_paths") as Array)
		),
	)
	var required: Array = CATALOG.call("get_required_paths") as Array
	_add(
		cases,
		"desktop and mobile title compositions are required",
		(
			"res://assets/title/title_scene_desktop.png" in required
			and "res://assets/title/title_scene_mobile.png" in required
		),
	)
	var cardinal: Node2D = CardinalAvatarScript.new() as Node2D
	cardinal.call("_ready")
	_add(
		cases,
		"Cardinal uses the validated combined atlas",
		not bool(cardinal.call("is_using_proxy"))
	)
	_add(
		cases,
		"all eight walk directions are available",
		(cardinal.call("get_missing_directions", &"walk") as Array).is_empty(),
	)
	_add(
		cases,
		"all eight attack directions are available",
		(cardinal.call("get_missing_directions", &"attack") as Array).is_empty(),
	)
	var frame_contract_valid: bool = true
	for direction: StringName in DIRECTIONS:
		frame_contract_valid = (
			frame_contract_valid
			and (
				int(cardinal.call("get_animation_frame_count", &"walk", direction)) == 25
				and int(cardinal.call("get_animation_frame_count", &"attack", direction)) == 25
				and is_equal_approx(
					float(cardinal.call("get_animation_speed", &"walk", direction)), 12.0
				)
				and is_equal_approx(
					float(cardinal.call("get_animation_speed", &"attack", direction)), 12.0
				)
				and bool(cardinal.call("is_animation_looping", &"walk", direction))
				and not bool(cardinal.call("is_animation_looping", &"attack", direction))
			)
		)
	_add(
		cases, "all sixteen animations preserve the 25-frame 12-FPS contract", frame_contract_valid
	)
	_add(
		cases,
		"attack gameplay contact uses atlas frame 11",
		int(cardinal.call("get_attack_event_frame")) == 11
	)
	var impact_count: Array[int] = [0]
	cardinal.connect("impact_frame", func() -> void: impact_count[0] += 1)
	var direction_contract_valid: bool = true
	for direction: StringName in DIRECTIONS:
		cardinal.call("set_motion", direction, false, 0.0)
		cardinal.call("play_attack")
		var before: int = impact_count[0]
		cardinal.call("_process", float(cardinal.call("get_attack_contact_time")) - 0.01)
		direction_contract_valid = (
			direction_contract_valid
			and (
				(
					cardinal.call("get_active_animation")
					== cardinal.call("get_animation_name", &"attack", direction)
				)
				and int(cardinal.call("get_active_frame")) == 10
				and impact_count[0] == before
			)
		)
		cardinal.call("_process", 0.02)
		direction_contract_valid = (
			direction_contract_valid
			and (int(cardinal.call("get_active_frame")) >= 11 and impact_count[0] == before + 1)
		)
		cardinal.call("_process", float(cardinal.call("get_attack_duration")))
		direction_contract_valid = (
			direction_contract_valid and not bool(cardinal.call("is_attacking"))
		)
	_add(
		cases,
		"all eight attack directions reach frame 11 once and recover",
		direction_contract_valid,
	)
	cardinal.free()
	return cases


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
