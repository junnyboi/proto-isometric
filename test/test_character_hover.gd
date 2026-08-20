extends RefCounted

const CharacterHoverCardScript: GDScript = preload("res://scripts/character_hover_card.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const WalkerAvatarScript: GDScript = preload("res://scripts/walker_avatar.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var walker_profile: Dictionary = (
		CharacterHoverCardScript
		. walker_profile(
			{&"chassis": 74, &"max_chassis": 100, &"impact_charge": 0.63},
			118.0,
			177.0,
		)
	)
	_add(
		cases,
		"Walker hover dossier validates live chassis and drive stats",
		(
			CharacterHoverCardScript.validate_profile(walker_profile)
			and walker_profile[&"name_key"] == &"hover.walker.name"
			and "074 / 100" in str((walker_profile[&"stats"] as Array)[0][&"value"])
			and "063%" in str((walker_profile[&"stats"] as Array)[1][&"value"])
		),
	)
	var target: Dictionary = {
		&"id": 7,
		&"kind": &"rime_stalker",
		&"name_key": &"enemy.rime_stalker.name",
		&"state": &"expose",
		&"health": 3,
		&"max_health": 4,
		&"attack_damage": 10,
		&"attack_range": 0.72,
	}
	var enemy_profile: Dictionary = CharacterHoverCardScript.enemy_profile(target)
	_add(
		cases,
		"enemy hover dossier maps kind, state, vitals, and combat facts",
		(
			CharacterHoverCardScript.validate_profile(enemy_profile)
			and enemy_profile[&"class_key"] == &"hover.enemy.rime_stalker.class"
			and enemy_profile[&"lore_key"] == &"hover.enemy.rime_stalker.lore"
			and (enemy_profile[&"stats"] as Array)[3][&"value_key"] == &"hover.state.expose"
		),
	)
	_add_touch_cases(cases)
	LocalizationScript.set_locale(&"zh-CN", false)
	_add(
		cases,
		"all recovered hover dossiers have Simplified Chinese copy",
		(
			LocalizationScript.t(&"hover.eyebrow") == "战地档案 // 实时接触"
			and LocalizationScript.has_key(&"zh-CN", &"hover.walker.lore")
			and LocalizationScript.has_key(&"zh-CN", &"hover.enemy.sandworm.lore")
			and LocalizationScript.has_key(&"zh-CN", &"hover.enemy.mud_skimmer.lore")
			and LocalizationScript.has_key(&"zh-CN", &"hover.enemy.rime_stalker.lore")
			and LocalizationScript.has_key(&"zh-CN", &"hover.enemy.cinder_crawler.lore")
		),
	)
	LocalizationScript.set_locale(&"en", false)
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", Vector2(90.0, 45.0), Vector2(760.0, 70.0))
	enemies.call("set_auto_spawn", false)
	var enemy_id: int = int(enemies.call("spawn_worm", Vector2(4.0, 3.0), 0.0))
	var targets: Array = enemies.call("_get_character_hover_targets") as Array
	_add(
		cases,
		"enemy runtime exposes one bounded hover target",
		(
			enemy_id > 0
			and targets.size() == 1
			and int((targets[0] as Dictionary)[&"id"]) == enemy_id
			and float((targets[0] as Dictionary)[&"hover_radius"]) == 56.0
		),
	)
	enemies.call("_set_hovered_enemy", enemy_id)
	_add(
		cases,
		"enemy hover highlight is explicit and reversible",
		int(enemies.call("_get_hovered_enemy")) == enemy_id,
	)
	enemies.call("_set_hovered_enemy", -1)
	var avatar: Node2D = WalkerAvatarScript.new() as Node2D
	avatar.call("set_hovered", true)
	_add(
		cases,
		"Walker hover highlight is explicit and reversible",
		bool(avatar.call("is_hovered")) and avatar.scale.x > 1.0,
	)
	avatar.call("set_hovered", false)
	_add(cases, "Walker highlight clears cleanly", not bool(avatar.call("is_hovered")))
	avatar.free()
	enemies.free()
	return cases


static func _add_touch_cases(cases: Array[Dictionary]) -> void:
	var scene_tree: SceneTree = Engine.get_main_loop() as SceneTree
	var presentation: CanvasLayer = CanvasLayer.new()
	presentation.layer = 80
	scene_tree.root.add_child(presentation)
	var avatar: Node2D = WalkerAvatarScript.new() as Node2D
	avatar.position = Vector2(320.0, 360.0)
	presentation.add_child(avatar)
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("set_auto_spawn", false)
	enemies.call("configure", Vector2(90.0, 45.0), Vector2(700.0, 300.0))
	presentation.add_child(enemies)
	enemies.call("spawn_worm", Vector2.ZERO, 0.0)
	var card: Control = CharacterHoverCardScript.new() as Control
	presentation.add_child(card)
	card.call(
		"bind_sources",
		avatar,
		enemies,
		func() -> Dictionary:
			return {&"chassis": 80, &"max_chassis": 100, &"impact_charge": 0.25},
		150.0,
		225.0,
	)
	var controls: CanvasLayer = MobileControlsScript.new() as CanvasLayer
	scene_tree.root.add_child(controls)
	controls.call("force_mobile", true)
	controls.call("set_character_dossier", card)
	var walker_touch: Vector2 = Vector2(320.0, 286.0)
	_add(
		cases,
		"Walker touch is reserved from joystick ownership",
		not bool(controls.call("begin_touch", 7, walker_touch))
		and bool(card.call("is_long_press_active", 7)),
	)
	_add(
		cases,
		"character dossier waits for the full hold threshold",
		not bool(card.call("advance_long_press", 0.54))
		and not bool(card.call("is_card_visible"))
		and float(card.call("get_long_press_progress")) > 0.9,
	)
	_add(
		cases,
		"completed hold pins a live Walker dossier",
		bool(card.call("advance_long_press", 0.02))
		and bool(card.call("is_touch_pinned"))
		and bool(card.call("is_card_visible")),
	)
	_add(
		cases,
		"touch release preserves the pinned dossier",
		bool(controls.call("end_touch", 7)) and bool(card.call("is_touch_pinned")),
	)
	var joystick_origin: Vector2 = Vector2(123.0, 602.0)
	_add(
		cases,
		"blank touch dismisses dossier and retains joystick",
		bool(controls.call("begin_touch", 8, joystick_origin))
		and not bool(card.call("is_touch_pinned"))
		and bool(controls.call("is_joystick_visible")),
	)
	controls.call("end_touch", 8)
	controls.call("begin_touch", 9, walker_touch)
	controls.call("drag_touch", 9, walker_touch + Vector2(24.0, 0.0))
	_add(
		cases,
		"drag beyond tolerance cancels inspection without opening a dossier",
		not bool(card.call("is_long_press_active")) and not bool(card.call("is_card_visible")),
	)
	var enemy_touch: Vector2 = Vector2(700.0, 276.0)
	card.call("begin_long_press", 10, enemy_touch)
	card.call("advance_long_press", 0.56)
	_add(
		cases,
		"hostile touch hold opens the enemy dossier",
		bool(card.call("is_touch_pinned"))
		and String(card.call("get_displayed_name")) == "SANDWORM",
	)
	controls.call("set_controls_enabled", false)
	_add(
		cases,
		"input suspension dismisses pinned touch dossiers",
		not bool(card.call("is_touch_pinned")) and not bool(card.call("is_card_visible")),
	)
	controls.free()
	presentation.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
