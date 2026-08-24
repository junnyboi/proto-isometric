extends RefCounted

const BossScript: GDScript = preload("res://scripts/ironjaw_boss.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const SandwormVisualsScript: GDScript = preload("res://scripts/sandworm_visuals.gd")
const WormTelegraphScript: GDScript = preload("res://scripts/worm_telegraph.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_phase_contract(cases)
	_test_generated_assets(cases)
	_test_layout_and_burrow_frames(cases)
	_test_live_armor_breaks(cases)
	_test_telegraph_contract(cases)
	_test_shipping_and_standard_worm(cases)
	return cases


static func _test_phase_contract(cases: Array[Dictionary]) -> void:
	_add(cases, "Apex boss has twelve health", BossScript.MAX_HEALTH == 12)
	_add(cases, "Apex boss deals twelve contact damage", BossScript.ATTACK_DAMAGE == 12)
	_add(
		cases,
		"Apex armor stages transition at eight and four health",
		(
			BossScript.armor_stage(12) == 0
			and BossScript.armor_stage(8) == 1
			and BossScript.armor_stage(4) == 2
		),
	)
	_add(
		cases,
		"Apex armor stages select triple breach, faultline, and ringquake",
		(
			BossScript.pattern_for_stage(0) == BossScript.PATTERN_CROWN_BREACH
			and BossScript.pattern_for_stage(1) == BossScript.PATTERN_FAULTLINE_RUSH
			and BossScript.pattern_for_stage(2) == BossScript.PATTERN_RINGQUAKE
		),
	)
	_add(
		cases,
		"broken Apex phases commit faster than intact phases",
		(
			BossScript.state_duration(&"intercept", 2) < BossScript.state_duration(&"intercept", 0)
			and BossScript.state_duration(&"burrow", 2) < BossScript.state_duration(&"burrow", 0)
		),
	)
	var crown: Array[Vector2] = BossScript.strike_targets(
		BossScript.PATTERN_CROWN_BREACH, Vector2.ZERO, Vector2.RIGHT
	)
	_add(cases, "crown breach commits three lateral targets", crown.size() == 3)
	_add(
		cases,
		"faultline uses a lane rather than a point hit",
		(
			BossScript.faultline_hits(Vector2(2.0, 0.4), Vector2.ZERO, Vector2(4.0, 0.0))
			and not BossScript.faultline_hits(Vector2(2.0, 2.0), Vector2.ZERO, Vector2(4.0, 0.0))
		),
	)
	_add(
		cases,
		"ringquake resolves exactly three pulses",
		BossScript.strike_pulses(BossScript.PATTERN_RINGQUAKE) == 3
	)


static func _test_generated_assets(cases: Array[Dictionary]) -> void:
	var paths: PackedStringArray = SandwormVisualsScript.boss_texture_paths()
	paths.append_array(SandwormVisualsScript.burrow_texture_paths())
	_add(cases, "Apex renderer exposes seven armor and three burrow textures", paths.size() == 10)
	for path: String in paths:
		var image: Image = Image.load_from_file(path)
		var corners_clear: bool = not image.is_empty() and image.get_size() == Vector2i(512, 512)
		for corner: Vector2i in [
			Vector2i.ZERO, Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)
		]:
			corners_clear = corners_clear and image.get_pixelv(corner).a <= 0.001
		_add(
			cases, "%s is a transparent normalized runtime sprite" % path.get_file(), corners_clear
		)


static func _test_layout_and_burrow_frames(cases: Array[Dictionary]) -> void:
	var layout: Array[Dictionary] = SandwormVisualsScript.build_boss_layout(
		Vector2.RIGHT, 1.25, 41, &"expose"
	)
	var body_count: int = 0
	var tail_count: int = 0
	for part: Dictionary in layout:
		body_count += 1 if part[&"kind"] == &"body" else 0
		tail_count += 1 if part[&"kind"] == &"tail" else 0
	_add(
		cases,
		"Apex uses five body segments and one reinforced tail",
		body_count == 5 and tail_count == 1
	)
	_add(
		cases,
		"Apex tail is the furthest trailing modular part",
		layout[0][&"kind"] == &"tail" and (layout[0][&"offset"] as Vector2).x < -400.0,
	)
	_add(
		cases,
		"burrow emergence advances low, medium, then high",
		(
			SandwormVisualsScript.burrow_frame_index(0.0, false) == 0
			and SandwormVisualsScript.burrow_frame_index(0.5, false) == 1
			and SandwormVisualsScript.burrow_frame_index(0.9, false) == 2
		),
	)
	_add(
		cases,
		"Dive reverses the burrow frame order",
		(
			SandwormVisualsScript.burrow_frame_index(0.0, true) == 2
			and SandwormVisualsScript.burrow_frame_index(0.5, true) == 1
			and SandwormVisualsScript.burrow_frame_index(0.9, true) == 0
		),
	)


static func _test_live_armor_breaks(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2(12.0, 12.0))
	var boss_id: int = int(worms.call("_spawn_boss", Vector2.ZERO, 0.0))
	_add(
		cases,
		"Apex spawn creates one unique boss",
		boss_id >= 0 and int(worms.call("_get_boss_id")) == boss_id
	)
	_add(cases, "Apex rejects damage while Burrowed", not bool(worms.call("hit_worm", boss_id, 1)))
	_advance_to_expose(worms, boss_id)
	_add(
		cases,
		"Apex reaches a readable Expose damage window",
		worms.call("get_state", boss_id) == &"expose"
	)
	_add(
		cases, "four damage cracks the first armor stage", bool(worms.call("hit_worm", boss_id, 4))
	)
	var cracked: Dictionary = worms.call("get_combat_snapshot", boss_id) as Dictionary
	_add(
		cases,
		"first armor break cancels the attack into bounded Stagger",
		(
			int(cracked[&"health"]) == 8
			and int(cracked[&"armor_stage"]) == 1
			and cracked[&"state"] == &"staggered"
		),
	)
	_advance_to_expose(worms, boss_id)
	_add(
		cases,
		"four more damage breaks the final armor stage",
		bool(worms.call("hit_worm", boss_id, 4))
	)
	var broken: Dictionary = worms.call("get_combat_snapshot", boss_id) as Dictionary
	_add(
		cases,
		"final armor break changes behavior to ringquake",
		(
			int(broken[&"health"]) == 4
			and int(broken[&"armor_stage"]) == 2
			and broken[&"attack_pattern"] == BossScript.PATTERN_RINGQUAKE
		),
	)
	_advance_to_expose(worms, boss_id)
	_add(cases, "final four damage defeats the Apex", bool(worms.call("hit_worm", boss_id, 4)))
	_add(
		cases,
		"Apex defeat persists and prevents duplicate boss spawning",
		(
			bool(worms.call("_is_boss_defeated"))
			and int(worms.call("_spawn_boss", Vector2.ZERO, 0.0)) == -1
		),
	)
	worms.free()


static func _test_telegraph_contract(cases: Array[Dictionary]) -> void:
	var telegraph: Node2D = WormTelegraphScript.new() as Node2D
	telegraph.call("configure", Vector2(90.0, 45.0), Vector2.ZERO)
	var entity: Dictionary = BossScript.make_entity(77, Vector2.ZERO, 0.0)
	BossScript.commit_attack(entity, Vector2(2.0, 0.0), Vector2.ZERO)
	entity[&"state"] = &"intercept"
	entity[&"state_duration"] = BossScript.state_duration(&"intercept", 0)
	entity[&"state_remaining"] = entity[&"state_duration"]
	var snapshots: Array[Dictionary] = [entity]
	telegraph.call("sync_combat_snapshots", snapshots)
	var snapshot: Dictionary = telegraph.call("get_telegraph_snapshot", 77) as Dictionary
	_add(
		cases,
		"Apex Intercept exposes warning, pattern, and three targets",
		(
			bool(snapshot[&"warning_active"])
			and snapshot[&"attack_pattern"] == BossScript.PATTERN_CROWN_BREACH
			and (snapshot[&"strike_targets"] as Array).size() == 3
		),
	)
	telegraph.free()


static func _test_shipping_and_standard_worm(cases: Array[Dictionary]) -> void:
	var export_text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_add(
		cases,
		"Web export includes Apex logic and generated sandworm textures",
		"scripts/ironjaw_boss.gd" in export_text and "assets/enemies/sandworm/*.png" in export_text,
	)
	var director_source: String = FileAccess.get_file_as_string(
		"res://scripts/encounter_director.gd"
	)
	_add(
		cases,
		"Alert III director owns deterministic Apex spawning",
		"_advance_boss" in director_source
	)
	var worms: Node2D = _make_worms()
	var standard_id: int = int(worms.call("spawn_worm", Vector2.ZERO, 0.0))
	var standard: Dictionary = worms.call("get_combat_snapshot", standard_id) as Dictionary
	_add(
		cases,
		"standard Ironjaw remains four health and non-boss",
		int(standard[&"health"]) == 4 and not bool(standard.get(&"is_boss", false)),
	)
	worms.free()


static func _advance_to_expose(worms: Node2D, boss_id: int) -> void:
	for _step: int in range(8):
		if worms.call("get_state", boss_id) == &"expose":
			return
		var snapshot: Dictionary = worms.call("get_combat_snapshot", boss_id) as Dictionary
		worms.call("advance", maxf(float(snapshot.get(&"state_remaining", 0.0)), 0.001))


static func _make_worms() -> Node2D:
	var worms: Node2D = SandwormsScript.new() as Node2D
	worms.call("configure", Vector2(90.0, 45.0), Vector2(760.0, 70.0), DEFAULT_PROFILE)
	worms.call("set_auto_spawn", false)
	return worms


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
