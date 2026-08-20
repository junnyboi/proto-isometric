extends RefCounted

const BiomeDestructiblesScript: GDScript = preload("res://scripts/biome_destructibles.gd")
const CameraImpulseMixerScript: GDScript = preload("res://scripts/camera_impulse_mixer.gd")
const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const FeedbackProfilesScript: GDScript = preload("res://scripts/feedback_profiles.gd")
const FeedbackRouterScript: GDScript = preload("res://scripts/feedback_router.gd")
const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const WalkerAvatarScript: GDScript = preload("res://scripts/walker_avatar.gd")


class FakeAvatar:
	extends Node2D
	var presentations: int = 0
	var last_hold: float = 0.0

	func _apply_impact_presentation(hold: float, _direction: Vector2, _strength: int) -> void:
		presentations += 1
		last_hold = hold


class FakeEnemies:
	extends Node2D
	var presentations: int = 0
	var last_target: int = -1

	func present_hit_feedback(
		target_id: int, _direction: Vector2, _strength: int, _hold: float
	) -> bool:
		presentations += 1
		last_target = target_id
		return true


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	FeedbackEventScript.reset_sequence_for_tests()
	_add(cases, "semantic Smash profiles validate", FeedbackProfilesScript.validate())
	_test_event_contract(cases)
	_test_router_channels(cases)
	_test_camera_mixer(cases)
	_test_runtime_reactions(cases)
	_test_material_families(cases)
	return cases


static func _test_event_contract(cases: Array[Dictionary]) -> void:
	var event: Dictionary = (
		FeedbackEventScript
		. create(
			RuntimeIdsScript.EVENT_SMASH_HIT,
			Vector2(20.0, 30.0),
			Vector2(2.0, 0.0),
			1,
			&"armored_fauna",
			12,
			{&"health_before": 4, &"health_after": 3},
		)
	)
	_add(cases, "semantic feedback event validates", FeedbackEventScript.validate(event))
	_add(
		cases,
		"semantic feedback direction is normalized",
		is_equal_approx((event[&"direction"] as Vector2).length(), 1.0),
	)
	_add(
		cases,
		"semantic feedback metadata detaches from its source",
		int((event[&"metadata"] as Dictionary)[&"health_after"]) == 3,
	)
	var invalid: Dictionary = event.duplicate(true)
	invalid[&"event_id"] = &"event.unknown"
	_add(
		cases, "unknown feedback event IDs are rejected", not FeedbackEventScript.validate(invalid)
	)


static func _test_router_channels(cases: Array[Dictionary]) -> void:
	var router: Node = FeedbackRouterScript.new() as Node
	var camera: Camera2D = Camera2D.new()
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	var avatar: FakeAvatar = FakeAvatar.new()
	var enemies: FakeEnemies = FakeEnemies.new()
	_add(
		cases,
		"feedback router binds presentation-only dependencies",
		bool(router.call("configure", camera, effects, avatar, enemies)),
	)
	var whiff: Dictionary = (
		FeedbackEventScript
		. create(
			RuntimeIdsScript.EVENT_SMASH_WHIFF,
			Vector2.ZERO,
			Vector2.RIGHT,
			0,
			&"air",
		)
	)
	_add(cases, "whiff feedback submits once", bool(router.call("submit", whiff)))
	var whiff_metrics: Dictionary = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"whiff emits no false contact-only feedback",
		(
			int((whiff_metrics[&"camera"] as Dictionary)[&"active"]) == 0
				and int(whiff_metrics[&"reactions"]) == 0
				and int(effects.call("get_particle_count")) == 0
				and int(effects.call("_get_burst_count")) == 0
				and int((whiff_metrics[&"haptics"] as Dictionary)[&"requests"]) == 0
		),
	)
	_add(cases, "duplicate semantic sequences are rejected", not bool(router.call("submit", whiff)))
	var hit: Dictionary = (
		FeedbackEventScript
		. create(
			RuntimeIdsScript.EVENT_SMASH_HIT,
			Vector2(40.0, 20.0),
			Vector2.RIGHT,
			1,
			&"armored_fauna",
			77,
		)
	)
	_add(cases, "confirmed hit feedback submits", bool(router.call("submit", hit)))
	var hit_metrics: Dictionary = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"confirmed hit fans out synchronized presentation channels",
		(
			int((hit_metrics[&"camera"] as Dictionary)[&"active"]) == 1
			and int(hit_metrics[&"reactions"]) == 1
			and avatar.presentations == 1
			and enemies.presentations == 1
				and enemies.last_target == 77
				and int(effects.call("get_particle_count")) > 0
				and int(effects.call("_get_burst_count")) == 1
				and int((hit_metrics[&"audio"] as Dictionary)[&"requests"]) == 2
			and int((hit_metrics[&"haptics"] as Dictionary)[&"requests"]) == 1
		),
	)
	var audio_before: int = int((hit_metrics[&"audio"] as Dictionary)[&"requests"])
	var haptics_before: int = int((hit_metrics[&"haptics"] as Dictionary)[&"requests"])
	(
		router
		. call(
			"apply_preferences",
			{&"camera_shake": false, &"haptics": false, &"sfx_enabled": false},
		)
	)
	var muted: Dictionary = (
		FeedbackEventScript
		. create(
			RuntimeIdsScript.EVENT_SMASH_HEAVY_HIT,
			Vector2(50.0, 20.0),
			Vector2.RIGHT,
			2,
			&"armored_fauna",
			78,
		)
	)
	_add(
		cases,
		"muted heavy feedback still submits semantic truth",
		bool(router.call("submit", muted))
	)
	var muted_metrics: Dictionary = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"disabled camera audio and haptics are true zero",
		(
			int((muted_metrics[&"camera"] as Dictionary)[&"active"]) == 0
			and (camera.offset as Vector2) == Vector2.ZERO
			and int((muted_metrics[&"audio"] as Dictionary)[&"requests"]) == audio_before
			and int((muted_metrics[&"haptics"] as Dictionary)[&"requests"]) == haptics_before
		),
	)
	for index: int in range(500):
		var event_id: StringName = (
			RuntimeIdsScript.EVENT_SMASH_WHIFF
			if index % 2 == 0
			else RuntimeIdsScript.EVENT_SMASH_HIT
		)
		var stress: Dictionary = (
			FeedbackEventScript
			. create(
				event_id,
				Vector2(index % 13, index % 17),
				Vector2.RIGHT,
				index % 3,
				&"armored_fauna" if index % 2 else &"air",
				index,
			)
		)
		router.call("submit", stress)
	var stress_metrics: Dictionary = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"five hundred semantic events remain bounded",
		(
			int(stress_metrics[&"history"]) == FeedbackRouterScript.MAX_HISTORY
			and (
				int((stress_metrics[&"camera"] as Dictionary)[&"peak"])
				<= CameraImpulseMixerScript.MAX_IMPULSES
			)
				and int(effects.call("get_particle_count")) <= ImpactEffectsScript.MAX_ACTIVE_PARTICLES
				and int(effects.call("get_created_particle_count")) == ImpactEffectsScript.MAX_POOL_SIZE
				and int(effects.call("_get_burst_count")) <= ImpactEffectsScript.MAX_ACTIVE_BURSTS
				and (
					int(effects.call("_get_created_burst_count"))
					== ImpactEffectsScript.MAX_ACTIVE_BURSTS
				)
				and int(effects.call("_get_reclaimed_burst_count")) > 0
			),
		)
	effects.call("advance", 1.01)
	_add(
		cases,
		"generated Smash contact bursts cull and return to idle",
		int(effects.call("_get_burst_count")) == 0,
	)
	router.free()
	camera.free()
	effects.free()
	avatar.free()
	enemies.free()


static func _test_camera_mixer(cases: Array[Dictionary]) -> void:
	var camera: Camera2D = Camera2D.new()
	var mixer: RefCounted = CameraImpulseMixerScript.new() as RefCounted
	mixer.call("bind_camera", camera)
	for index: int in range(16):
		mixer.call("submit", 0.12, 8.0, Vector2.RIGHT.rotated(float(index)), index)
	_add(
		cases,
		"camera impulse aggregation is hard capped",
		(camera.offset as Vector2).length() <= CameraImpulseMixerScript.MAX_OFFSET + 0.001,
	)
	mixer.call("advance", 0.2)
	_add(cases, "camera impulses recover exactly to zero", camera.offset == Vector2.ZERO)
	mixer.call("set_enabled", false)
	_add(
		cases,
		"disabled camera mixer rejects impulses",
		not bool(mixer.call("submit", 0.1, 4.0, Vector2.RIGHT, 99)),
	)
	camera.free()


static func _test_runtime_reactions(cases: Array[Dictionary]) -> void:
	var avatar: Node2D = WalkerAvatarScript.new() as Node2D
	avatar.call("_apply_impact_presentation", 0.04, Vector2.RIGHT, 2)
	var presentation: Dictionary = avatar.call("_get_impact_presentation") as Dictionary
	_add(
		cases,
		"Walker contact hold is local and bounded",
		(
			float(presentation[&"hold"]) > 0.0
			and float(presentation[&"hold"]) <= 0.12
			and (presentation[&"offset"] as Vector2).x < 0.0
		),
	)
	avatar.call("_process", 0.2)
	avatar.call("_process", 0.2)
	presentation = avatar.call("_get_impact_presentation") as Dictionary
	_add(
		cases,
		"Walker local reaction recovers without global time mutation",
		(
			float(presentation[&"hold"]) == 0.0
			and (presentation[&"offset"] as Vector2) == Vector2.ZERO
		),
	)
	var enemies: Node2D = SandwormsScript.new() as Node2D
	enemies.call("configure", Vector2(90.0, 45.0), Vector2.ZERO)
	enemies.call("set_auto_spawn", false)
	var enemy_id: int = int(enemies.call("spawn_worm", Vector2(2.0, 2.0), 0.0))
	_add(
		cases,
		"fauna accepts presentation-only directional reaction",
		bool(enemies.call("present_hit_feedback", enemy_id, Vector2.RIGHT, 2, 0.04)),
	)
	enemies.call("advance", 0.05)
	_add(
		cases,
		"fauna directional reaction becomes visibly nonzero",
		(enemies.call("get_feedback_offset", enemy_id) as Vector2).length() > 0.0,
	)
	enemies.call("advance", 0.2)
	_add(
		cases,
		"fauna directional reaction recovers cleanly",
		(enemies.call("get_feedback_offset", enemy_id) as Vector2) == Vector2.ZERO,
	)
	avatar.free()
	enemies.free()


static func _test_material_families(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"J1 distinguishes dry stone and wet wood breaks",
		(
			(
				BiomeDestructiblesScript.material_family_for(
					BiomeDestructiblesScript.KIND_DESERT_ROCK
				)
				== &"dry_stone"
			)
			and (
				BiomeDestructiblesScript.material_family_for(
					BiomeDestructiblesScript.KIND_WETLAND_MANGROVE
				)
				== &"wet_wood"
			)
		),
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
