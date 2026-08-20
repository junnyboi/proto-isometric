extends RefCounted

const CharacterHoverCardScript: GDScript = preload("res://scripts/character_hover_card.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
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


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
