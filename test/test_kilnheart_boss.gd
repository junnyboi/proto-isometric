extends RefCounted

const BossScript: GDScript = preload("res://scripts/kilnheart_boss.gd")
const BossVisualsScript: GDScript = preload("res://scripts/kilnheart_visuals.gd")
const EncounterDirectorScript: GDScript = preload("res://scripts/encounter_director.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const WormTelegraphScript: GDScript = preload("res://scripts/worm_telegraph.gd")
const DEFAULT_PROFILE: Resource = preload("res://data/combat/sandworm_default.tres")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_phase_and_attack_contract(cases)
	_test_animation_assets(cases)
	_test_live_damage_and_persistence(cases)
	_test_telegraph_contract(cases)
	_test_biome_exclusive_director(cases)
	_test_shipping_and_localization(cases)
	return cases


static func _test_phase_and_attack_contract(cases: Array[Dictionary]) -> void:
	_add(cases, "Kilnheart owns eighteen health", BossScript.MAX_HEALTH == 18)
	_add(
		cases,
		"Kilnheart armor stages transition at twelve and six health",
		(
			BossScript.armor_stage(18) == 0
			and BossScript.armor_stage(12) == 1
			and BossScript.armor_stage(6) == 2
		),
	)
	var boss: Dictionary = BossScript.make_entity(91, Vector2.ZERO, 0.0)
	_advance_to_warning(boss, Vector2(2.0, 0.0))
	_add(
		cases,
		"Kilnheart opens with a Forge Sweep warning",
		(
			boss[&"state"] == BossScript.STATE_WARNING
			and boss[&"attack_pattern"] == BossScript.PATTERN_FORGE_SWEEP
		),
	)
	var events: Array = _resolve_current_attack(boss, Vector2(2.0, 0.0))
	_add(
		cases,
		"Forge Sweep resolves one ten-damage fan hit",
		events.size() == 1 and int(events[0][&"amount"]) == BossScript.SWEEP_DAMAGE,
	)
	_advance_to_warning(boss, Vector2(2.0, 0.0))
	_add(
		cases,
		"second cycle rotates to Magma Ram lane",
		boss[&"attack_pattern"] == BossScript.PATTERN_MAGMA_RAM,
	)
	_add(
		cases,
		"Magma Ram commits a bounded charge target",
		(boss[&"committed_target"] as Vector2).distance_to(boss[&"intercept_start"] as Vector2)
		<= 6.61,
	)
	_resolve_current_attack(boss, boss[&"committed_target"] as Vector2)
	_advance_to_warning(boss, Vector2(2.0, 0.0))
	_add(
		cases,
		"third cycle rotates to three-cell Caldera Barrage",
		(
			boss[&"attack_pattern"] == BossScript.PATTERN_CALDERA_BARRAGE
			and (boss[&"strike_targets"] as Array).size() == BossScript.BARRAGE_PULSES
		),
	)
	var barrage: Array = _resolve_current_attack(boss, Vector2(2.0, 0.0))
	_add(cases, "Caldera Barrage resolves at most three ordered pulses", barrage.size() <= 3)


static func _test_animation_assets(cases: Array[Dictionary]) -> void:
	var paths: PackedStringArray = BossVisualsScript.texture_paths()
	_add(cases, "Kilnheart renderer exposes eight animation textures", paths.size() == 8)
	var hashes: Dictionary = {}
	for path: String in paths:
		var image: Image = Image.load_from_file(path)
		var normalized: bool = not image.is_empty() and image.get_size() == Vector2i(512, 512)
		for corner: Vector2i in [
			Vector2i.ZERO, Vector2i(511, 0), Vector2i(0, 511), Vector2i(511, 511)
		]:
			normalized = normalized and image.get_pixelv(corner).a <= 0.001
		hashes[FileAccess.get_sha256(path)] = true
		_add(cases, "%s is a transparent normalized runtime sprite" % path.get_file(), normalized)
	_add(cases, "all Kilnheart animation textures are visually distinct", hashes.size() == 8)
	var boss: Dictionary = BossScript.make_entity(92, Vector2.ZERO, 0.0)
	boss[&"state"] = BossScript.STATE_TRACK
	var walk_a: StringName = BossScript.animation_key(boss, 0.0)
	var walk_b: StringName = BossScript.animation_key(boss, 0.25)
	boss[&"state"] = BossScript.STATE_WARNING
	var windup: StringName = BossScript.animation_key(boss, 0.0)
	boss[&"state"] = BossScript.STATE_ATTACK
	var attack: StringName = BossScript.animation_key(boss, 0.0)
	_add(
		cases,
		"Kilnheart locomotion, windup, and release use distinct animation keys",
		walk_a != walk_b and windup == &"windup" and attack == &"attack",
	)


static func _test_live_damage_and_persistence(cases: Array[Dictionary]) -> void:
	var worms: Node2D = _make_worms()
	worms.call("set_player_position", Vector2(12.0, 12.0))
	var boss_id: int = int(worms.call("_spawn_kilnheart", Vector2.ZERO, 0.0))
	_add(
		cases,
		"Kilnheart spawn creates one unique volcanic boss",
		boss_id >= 0 and int(worms.call("_spawn_kilnheart", Vector2.ONE, 0.0)) == boss_id,
	)
	_add(
		cases,
		"Kilnheart rejects damage outside cooling windows",
		not bool(worms.call("hit_worm", boss_id, 1)),
	)
	_advance_worm_to_state(worms, boss_id, BossScript.STATE_RECOVER)
	_add(
		cases,
		"Kilnheart exposes a recovery counter-window",
		worms.call("get_state", boss_id) == BossScript.STATE_RECOVER,
	)
	_add(cases, "six damage cracks Kilnheart armor", bool(worms.call("hit_worm", boss_id, 6)))
	var cracked: Dictionary = worms.call("get_combat_snapshot", boss_id) as Dictionary
	_add(
		cases,
		"first core threshold enters bounded stagger",
		(
			int(cracked[&"health"]) == 12
			and int(cracked[&"armor_stage"]) == 1
			and cracked[&"state"] == BossScript.STATE_STAGGERED
		),
	)
	_add(cases, "six more damage breaches the core", bool(worms.call("hit_worm", boss_id, 6)))
	_add(cases, "final six damage defeats Kilnheart", bool(worms.call("hit_worm", boss_id, 6)))
	_add(
		cases,
		"Kilnheart defeat persists and prevents duplicate spawning",
		(
			bool(worms.call("_is_kilnheart_defeated"))
			and int(worms.call("_spawn_kilnheart", Vector2.ZERO, 0.0)) == -1
		),
	)
	worms.free()


static func _test_telegraph_contract(cases: Array[Dictionary]) -> void:
	var telegraph: Node2D = WormTelegraphScript.new() as Node2D
	telegraph.call("configure", Vector2(90.0, 45.0), Vector2.ZERO)
	var boss: Dictionary = BossScript.make_entity(93, Vector2.ZERO, 0.0)
	_advance_to_warning(boss, Vector2(2.0, 0.0))
	var snapshots: Array[Dictionary] = [boss]
	telegraph.call("sync_combat_snapshots", snapshots)
	var snapshot: Dictionary = telegraph.call("get_telegraph_snapshot", 93) as Dictionary
	_add(
		cases,
		"Kilnheart warning publishes pattern, countdown, and committed geometry",
		(
			bool(snapshot[&"warning_active"])
			and snapshot[&"attack_pattern"] == BossScript.PATTERN_FORGE_SWEEP
			and float(snapshot[&"warning_countdown"]) > 0.99
			and (snapshot[&"strike_targets"] as Array).size() == 1
		),
	)
	_add(
		cases,
		"Kilnheart telegraph uses a boss-scale target radius without a burrow trail",
		float(snapshot[&"target_radius"]) > 35.0 and int(snapshot[&"trail_points"]) == 0,
	)
	telegraph.free()


static func _test_biome_exclusive_director(cases: Array[Dictionary]) -> void:
	var lava_worms: Node2D = _make_worms()
	var lava_director: Node = EncounterDirectorScript.new() as Node
	lava_director.set("_worms", lava_worms)
	lava_director.set("_armed_alert", 3)
	lava_director.set("_active_biome", &"lava")
	lava_director.set("_boss_remaining", 0.0)
	lava_director.call("_advance_boss", 0.01, Vector2.ZERO)
	_add(
		cases,
		"Alert III Lava Fields spawn Kilnheart and not the desert Apex",
		(
			int(lava_worms.call("_get_kilnheart_id")) >= 0
			and int(lava_worms.call("_get_boss_id")) < 0
		),
	)
	lava_director.free()
	lava_worms.free()
	var frozen_worms: Node2D = _make_worms()
	var frozen_director: Node = EncounterDirectorScript.new() as Node
	frozen_director.set("_worms", frozen_worms)
	frozen_director.set("_armed_alert", 3)
	frozen_director.set("_active_biome", &"frozen")
	frozen_director.set("_boss_remaining", 0.0)
	frozen_director.call("_advance_boss", 0.01, Vector2.ZERO)
	_add(
		cases,
		"non-volcanic and non-desert biomes remain boss-free",
		(
			int(frozen_worms.call("_get_kilnheart_id")) < 0
			and int(frozen_worms.call("_get_boss_id")) < 0
		),
	)
	frozen_director.free()
	frozen_worms.free()


static func _test_shipping_and_localization(cases: Array[Dictionary]) -> void:
	var export_text: String = FileAccess.get_file_as_string("res://export_presets.cfg")
	_add(
		cases,
		"Web export includes Kilnheart logic, textures, and enemy audio",
		(
			"scripts/kilnheart_boss.gd" in export_text
			and "assets/enemies/kilnheart/*.png" in export_text
			and "assets/audio/enemies/*.wav" in export_text
		),
	)
	for locale: String in ["en", "zh-CN"]:
		var source: String = FileAccess.get_file_as_string("res://data/locales/%s.json" % locale)
		_add(
			cases,
			"%s localizes Kilnheart identity and states" % locale,
			(
				"enemy.kilnheart_colossus.name" in source
				and "hover.enemy.kilnheart_colossus.class" in source
				and "hover.state.kilnheart_warning" in source
				and "source.kilnheart_colossus" in source
			),
		)


static func _resolve_current_attack(boss: Dictionary, player: Vector2) -> Array:
	BossScript.advance(
		boss, float(boss[&"state_remaining"]), player, Vector2.ZERO, false
	)
	var result: Dictionary = BossScript.advance(
		boss, float(boss[&"state_remaining"]), player, Vector2.ZERO, false
	)
	return result[&"damage_events"] as Array


static func _advance_to_warning(boss: Dictionary, player: Vector2) -> void:
	for _step: int in range(6):
		if boss[&"state"] == BossScript.STATE_WARNING:
			return
		BossScript.advance(
			boss, maxf(float(boss[&"state_remaining"]), 0.001),
			player, Vector2.ZERO, false
		)


static func _advance_worm_to_state(
	worms: Node2D, boss_id: int, target: StringName
) -> void:
	for _step: int in range(12):
		if worms.call("get_state", boss_id) == target:
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
