extends RefCounted

const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const FeedbackProfilesScript: GDScript = preload("res://scripts/feedback_profiles.gd")
const FeedbackRouterScript: GDScript = preload("res://scripts/feedback_router.gd")
const ImpactEffectsScript: GDScript = preload("res://scripts/impact_effects.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_profile_hierarchy(cases)
	_test_generated_j2_textures(cases)
	_test_vfx_intensity(cases)
	_test_reward_and_relay_routing(cases)
	return cases


static func _test_profile_hierarchy(cases: Array[Dictionary]) -> void:
	var pickup: Dictionary = FeedbackProfilesScript.resolve(
		RuntimeIdsScript.EVENT_SCRAP_COLLECTED
	)
	var relay: Dictionary = FeedbackProfilesScript.resolve(
		RuntimeIdsScript.EVENT_RELAY_COMPLETED
	)
	var charge: Dictionary = FeedbackProfilesScript.resolve(RuntimeIdsScript.EVENT_CHARGE_HIGH)
	_add(cases, "reward and relay feedback profiles validate", FeedbackProfilesScript.validate())
	_add(
		cases,
		"feedback hierarchy keeps pickups below charge and relay completion",
		(
			int(pickup.get(&"priority", -1)) < int(charge.get(&"priority", -1))
			and int(charge.get(&"priority", -1)) < int(relay.get(&"priority", -1))
		),
	)


static func _test_generated_j2_textures(cases: Array[Dictionary]) -> void:
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	var step: Dictionary = FeedbackEventScript.create(
		RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT,
		Vector2(32.0, 48.0),
		Vector2.RIGHT,
		0,
		&"snow",
	)
	effects.call("emit_feedback", step, FeedbackProfilesScript.resolve(step[&"event_id"]))
	var burst: Dictionary = effects.call("_get_last_burst_snapshot") as Dictionary
	_add(
		cases,
		"surface contacts route to the generated tintable footstep mask",
		(
			(burst.get(&"texture") as Texture2D).resource_path
			== "res://assets/vfx/juice/footstep_dust.png"
			and burst.get(&"color", Color.WHITE) == Color("c8e8ed")
		),
	)
	var charge: Dictionary = FeedbackEventScript.create(
		RuntimeIdsScript.EVENT_CHARGE_HIGH,
		Vector2(32.0, 48.0),
		Vector2.UP,
		2,
		&"energy",
	)
	effects.call("emit_feedback", charge, FeedbackProfilesScript.resolve(charge[&"event_id"]))
	burst = effects.call("_get_last_burst_snapshot") as Dictionary
	_add(
		cases,
		"high charge detents route to the generated readiness glyph",
		(
			(burst.get(&"texture") as Texture2D).resource_path
			== "res://assets/vfx/juice/charge_ready.png"
		),
	)
	effects.call("advance", 1.0)
	effects.free()


static func _test_vfx_intensity(cases: Array[Dictionary]) -> void:
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	var created_particles: int = int(effects.call("get_created_particle_count"))
	var pickup: Dictionary = FeedbackEventScript.create(
		RuntimeIdsScript.EVENT_SCRAP_COLLECTED,
		Vector2(24.0, 24.0),
		Vector2.UP,
		1,
		&"scrap",
		-1,
		{&"amount": 3},
	)
	effects.call("_apply_preferences", {&"vfx_intensity": 0.5})
	effects.call("emit_feedback", pickup, FeedbackProfilesScript.resolve(pickup[&"event_id"]))
	effects.call("emit_scrap_pickup", Vector2.ZERO, 3)
	_add(
		cases,
		"half VFX intensity halves cosmetic particle density and keeps the authored burst",
		(
			is_equal_approx(float(effects.call("_get_vfx_intensity")), 0.5)
			and int(effects.call("get_particle_count")) == 6
			and int(effects.call("_get_burst_count")) == 1
		),
	)
	effects.call("_apply_preferences", {&"vfx_intensity": 0.0})
	effects.call("emit_feedback", pickup, FeedbackProfilesScript.resolve(pickup[&"event_id"]))
	effects.call("emit_scrap_pickup", Vector2.ZERO, 3)
	_add(
		cases,
		"zero VFX intensity clears active cosmetics and suppresses new visual records",
		(
			int(effects.call("get_particle_count")) == 0
			and int(effects.call("_get_burst_count")) == 0
		),
	)
	effects.call("_apply_preferences", {&"vfx_intensity": 1.0})
	effects.call("emit_scrap_pickup", Vector2.ZERO, 3)
	_add(
		cases,
		"full VFX intensity restores density without allocating beyond the fixed pool",
		(
			int(effects.call("get_particle_count")) == 12
			and int(effects.call("get_created_particle_count")) == created_particles
		),
	)
	effects.free()


static func _test_reward_and_relay_routing(cases: Array[Dictionary]) -> void:
	var router: Node = FeedbackRouterScript.new() as Node
	var camera: Camera2D = Camera2D.new()
	var effects: Node2D = ImpactEffectsScript.new() as Node2D
	var avatar: Node2D = Node2D.new()
	var enemies: Node2D = Node2D.new()
	_add(
		cases,
		"reward feedback router configures with presentation-only dependencies",
		bool(router.call("configure", camera, effects, avatar, enemies)),
	)
	_add(
		cases,
		"authoritative pickup outcome submits once",
		bool(router.call("present_pickup", Vector2(40.0, 24.0), 3)),
	)
	var history: Array[Dictionary] = router.call("get_history") as Array[Dictionary]
	var pickup_event: Dictionary = history.back()
	var pickup_burst: Dictionary = effects.call("_get_last_burst_snapshot") as Dictionary
	var metrics: Dictionary = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"pickup feedback preserves semantic amount and generated spark asset",
		(
			pickup_event.get(&"event_id", &"") == RuntimeIdsScript.EVENT_SCRAP_COLLECTED
			and int((pickup_event.get(&"metadata", {}) as Dictionary).get(&"amount", 0)) == 3
			and (
				(pickup_burst.get(&"texture") as Texture2D).resource_path
				== "res://assets/vfx/juice/pickup_spark.png"
			)
			and str((metrics.get(&"audio", {}) as Dictionary).get(&"last_stream_path", "")).ends_with(
				"charge_ready.wav"
			)
		),
	)
	_add(
		cases,
		"authoritative relay outcome submits once",
		bool(router.call("present_relay", Vector2(80.0, 50.0), 2)),
	)
	history = router.call("get_history") as Array[Dictionary]
	var relay_event: Dictionary = history.back()
	var relay_burst: Dictionary = effects.call("_get_last_burst_snapshot") as Dictionary
	metrics = router.call("get_metrics") as Dictionary
	_add(
		cases,
		"relay completion synchronizes major visual audio camera and haptic channels",
		(
			relay_event.get(&"event_id", &"") == RuntimeIdsScript.EVENT_RELAY_COMPLETED
			and int((relay_event.get(&"metadata", {}) as Dictionary).get(&"alert", 0)) == 2
			and (
				(relay_burst.get(&"texture") as Texture2D).resource_path
				== "res://assets/vfx/juice/relay_flare.png"
			)
			and int((metrics.get(&"camera", {}) as Dictionary).get(&"active", 0)) == 1
			and int((metrics.get(&"haptics", {}) as Dictionary).get(&"requests", 0)) == 2
			and str((metrics.get(&"audio", {}) as Dictionary).get(&"last_stream_path", "")).ends_with(
				"relay_complete.wav"
			)
		),
	)
	for _index: int in range(64):
		router.call("present_pickup", Vector2(30.0, 20.0), 1)
	var counts: Dictionary = effects.call("_get_burst_event_counts") as Dictionary
	_add(
		cases,
		"pickup flood stays pooled and cannot evict major relay feedback",
		(
			int(effects.call("_get_burst_count")) <= ImpactEffectsScript.MAX_ACTIVE_BURSTS
			and (
				int(effects.call("_get_created_burst_count"))
				== ImpactEffectsScript.MAX_ACTIVE_BURSTS
			)
			and int(effects.call("_get_reclaimed_burst_count")) > 0
			and int(counts.get(RuntimeIdsScript.EVENT_RELAY_COMPLETED, 0)) == 1
		),
	)
	effects.call("advance", 0.5)
	counts = effects.call("_get_burst_event_counts") as Dictionary
	_add(
		cases,
		"frequent pickup bursts cull before major relay feedback",
		(
			int(counts.get(RuntimeIdsScript.EVENT_SCRAP_COLLECTED, 0)) == 0
			and int(counts.get(RuntimeIdsScript.EVENT_RELAY_COMPLETED, 0)) == 1
		),
	)
	effects.call("advance", 0.41)
	_add(
		cases,
		"major relay feedback culls within one second",
		int(effects.call("_get_burst_count")) == 0,
	)
	router.free()
	camera.free()
	effects.free()
	avatar.free()
	enemies.free()


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
