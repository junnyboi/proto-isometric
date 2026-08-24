extends RefCounted

const FeedbackAudioScript: GDScript = preload("res://scripts/feedback_audio.gd")
const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const ImpactChargeScript: GDScript = preload("res://scripts/impact_charge.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const WalkerAvatarScript: GDScript = preload("res://scripts/walker_avatar.gd")
const WalkerLocomotionFeedbackScript: GDScript = preload(
	"res://scripts/walker_locomotion_feedback.gd"
)


class FakeField:
	extends Node
	var velocity: Vector2 = Vector2.ZERO
	var robot_position: Vector2 = Vector2(120.0, 80.0)
	var robot_grid: Vector2i = Vector2i(4, 4)
	var _is_running: bool = false

	func get_velocity() -> Vector2:
		return velocity

	func get_robot_position() -> Vector2:
		return robot_position

	func get_robot_grid() -> Vector2i:
		return robot_grid


class FakeAvatar:
	extends Node2D
	var animation: StringName = &"walk_se"
	var frame: int = 0
	var attacking: bool = false
	var presentations: Array[Dictionary] = []

	func get_active_animation() -> StringName:
		return animation

	func get_active_frame() -> int:
		return frame

	func is_attacking() -> bool:
		return attacking

	func _apply_locomotion_presentation(event_id: StringName, strong: bool) -> void:
		presentations.append({&"event_id": event_id, &"strong": strong})


class FakeRouter:
	extends Node
	var events: Array[Dictionary] = []
	var biomes: Array[StringName] = []

	func submit(event: Dictionary) -> bool:
		if not FeedbackEventScript.validate(event):
			return false
		events.append(event.duplicate(true))
		return true

	func present_biome(biome: StringName) -> bool:
		if not biomes.is_empty() and biomes[-1] == biome:
			return false
		biomes.append(biome)
		return true


class FakeWorld:
	extends RefCounted
	var terrain: StringName = &"sand"

	func terrain_at(_cell: Vector2i) -> StringName:
		return terrain


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_static_contracts(cases)
	_test_locomotion_classification(cases)
	_test_charge_detents(cases)
	_test_real_avatar_recovery(cases)
	_test_audio_roles(cases)
	return cases


static func _test_static_contracts(cases: Array[Dictionary]) -> void:
	var valid_contacts: bool = true
	for frame: int in range(8):
		valid_contacts = (
			valid_contacts
			and (WalkerLocomotionFeedbackScript.is_gait_contact_frame(frame) == (frame in [1, 5]))
		)
	_add(cases, "visible gait contacts are pinned to frames one and five", valid_contacts)
	_add(
		cases,
		"J2 surface families cover every shipped traversal material",
		(
			WalkerLocomotionFeedbackScript.surface_family_for(&"sand") == &"sand"
			and WalkerLocomotionFeedbackScript.surface_family_for(&"mud") == &"mud"
			and WalkerLocomotionFeedbackScript.surface_family_for(&"blue_ice") == &"snow"
			and WalkerLocomotionFeedbackScript.surface_family_for(&"lava") == &"volcanic"
		),
	)


static func _test_locomotion_classification(cases: Array[Dictionary]) -> void:
	FeedbackEventScript.reset_sequence_for_tests()
	var field: FakeField = FakeField.new()
	var avatar: FakeAvatar = FakeAvatar.new()
	var router: FakeRouter = FakeRouter.new()
	var world: FakeWorld = FakeWorld.new()
	var charge: Node2D = ImpactChargeScript.new() as Node2D
	var feedback: Node = WalkerLocomotionFeedbackScript.new() as Node
	_add(
		cases,
		"locomotion feedback binds presentation-only sources",
		bool(feedback.call("configure", field, avatar, router, charge, world)),
	)
	_add(
		cases,
		"locomotion feedback synchronizes the initial biome",
		router.biomes == [&"sand"],
	)
	field.velocity = Vector2(100.0, 0.0)
	avatar.frame = 1
	feedback.call("_process", 0.016)
	_add(
		cases,
		"movement start and first visible gait contact dispatch once",
		(
			_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_START) == 1
			and _count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT) == 1
		),
	)
	var velocity_after: Vector2 = field.velocity
	feedback.call("_process", 0.016)
	_add(
		cases,
		"same visible frame cannot duplicate gait contact",
		_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT) == 1,
	)
	avatar.frame = 5
	world.terrain = &"mud"
	feedback.call("_process", 0.016)
	_add(
		cases,
		"second visible gait contact carries current surface family",
		(
			_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT) == 2
			and (router.events[-1][&"material"] as StringName) == &"mud"
			and router.biomes == [&"sand", &"mud"]
		),
	)
	field._is_running = true
	avatar.frame = 1
	feedback.call("_process", 0.016)
	_add(
		cases,
		"run threshold and run gait contact remain distinct",
		(
			_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_RUN) == 1
			and _count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_RUN_CONTACT) == 1
		),
	)
	field.velocity = Vector2(-100.0, 0.0)
	avatar.frame = 2
	feedback.call("_process", 0.016)
	_add(
		cases,
		"direction reversal dispatches one low-priority event",
		_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_REVERSE) == 1,
	)
	field.velocity = Vector2.ZERO
	field._is_running = false
	feedback.call("_process", 0.016)
	_add(
		cases,
		"full stop dispatches once",
		_count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_STOP) == 1,
	)
	var contacts_before_border: int = _count(
		router.events, RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT
	)
	world.terrain = &"blue_ice"
	feedback.call("_process", 0.016)
	_add(
		cases,
		"terrain border changes notify audio without waiting for a gait contact",
		(
			router.biomes == [&"sand", &"mud", &"snow"]
			and _count(router.events, RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT)
			== contacts_before_border
		),
	)
	_add(cases, "blocked transition dispatches", bool(feedback.call("notify_blocked")))
	_add(
		cases,
		"blocked transition cooldown suppresses repeats",
		not bool(feedback.call("notify_blocked"))
	)
	_add(
		cases,
		"locomotion feedback never mutates authoritative velocity",
		velocity_after == Vector2(100.0, 0.0) and field.velocity == Vector2.ZERO,
	)
	_add(
		cases,
		"every accepted locomotion event drives a reversible Walker pose",
		avatar.presentations.size() == router.events.size(),
	)
	feedback.free()
	charge.free()
	field.free()
	avatar.free()
	router.free()


static func _test_charge_detents(cases: Array[Dictionary]) -> void:
	var field: FakeField = FakeField.new()
	var avatar: FakeAvatar = FakeAvatar.new()
	var router: FakeRouter = FakeRouter.new()
	var world: FakeWorld = FakeWorld.new()
	var charge: Node2D = ImpactChargeScript.new() as Node2D
	var feedback: Node = WalkerLocomotionFeedbackScript.new() as Node
	feedback.call("configure", field, avatar, router, charge, world)
	charge.call("set_charge", 0.39)
	charge.call("set_charge", 0.41)
	charge.call("set_charge", 0.79)
	charge.call("set_charge", 0.81)
	charge.call("set_charge", 0.95)
	_add(
		cases,
		"charge detents emit once per upward forty and eighty percent crossing",
		(
			_count(router.events, RuntimeIdsScript.EVENT_CHARGE_LOW) == 1
			and _count(router.events, RuntimeIdsScript.EVENT_CHARGE_HIGH) == 1
		),
	)
	charge.call("consume_attack")
	charge.call("set_charge", 0.41)
	_add(
		cases,
		"charge detents rearm after authoritative consumption",
		_count(router.events, RuntimeIdsScript.EVENT_CHARGE_LOW) == 2,
	)
	feedback.free()
	charge.free()
	field.free()
	avatar.free()
	router.free()


static func _test_real_avatar_recovery(cases: Array[Dictionary]) -> void:
	var avatar: Node2D = WalkerAvatarScript.new() as Node2D
	avatar.call("_apply_locomotion_presentation", RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED, false)
	var presentation: Dictionary = avatar.call("_get_locomotion_presentation") as Dictionary
	_add(
		cases,
		"blocked locomotion pose is compact and presentation-only",
		(
			(presentation[&"offset"] as Vector2).length() <= 4.0
			and absf(float(presentation[&"tilt"])) <= 0.025
		),
	)
	avatar.call("_process", 0.2)
	presentation = avatar.call("_get_locomotion_presentation") as Dictionary
	_add(
		cases,
		"locomotion pose recovers exactly to neutral",
		(
			presentation[&"offset"] == Vector2.ZERO
			and is_zero_approx(float(presentation[&"tilt"]))
			and is_zero_approx(float(presentation[&"recovery"]))
		),
	)
	avatar.free()


static func _test_audio_roles(cases: Array[Dictionary]) -> void:
	var audio: Node = FeedbackAudioScript.new() as Node
	var roles: Array[StringName] = [
		RuntimeIdsScript.EVENT_LOCOMOTION_START,
		RuntimeIdsScript.EVENT_LOCOMOTION_WALK_CONTACT,
		RuntimeIdsScript.EVENT_LOCOMOTION_RUN_CONTACT,
		RuntimeIdsScript.EVENT_LOCOMOTION_BLOCKED,
		RuntimeIdsScript.EVENT_CHARGE_HIGH,
	]
	var all_playable: bool = true
	for role: StringName in roles:
		var event: Dictionary = FeedbackEventScript.create(
			role, Vector2.ZERO, Vector2.RIGHT, 0, &"sand"
		)
		all_playable = all_playable and bool(audio.call("play_event", event))
	_add(cases, "J2 locomotion and charge events have bounded audio roles", all_playable)
	_add(
		cases,
		"J2 audio uses no new voice allocation beyond the shared cap",
		(
			int((audio.call("get_metrics") as Dictionary)[&"capacity"])
			== FeedbackAudioScript.MAX_VOICES
		),
	)
	audio.free()


static func _count(events: Array[Dictionary], event_id: StringName) -> int:
	var result: int = 0
	for event: Dictionary in events:
		if event.get(&"event_id", &"") == event_id:
			result += 1
	return result


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
