extends Node

const BiomeSoundscapeScript: GDScript = preload("res://scripts/biome_soundscape.gd")
const CameraImpulseMixerScript: GDScript = preload("res://scripts/camera_impulse_mixer.gd")
const FeedbackAudioScript: GDScript = preload("res://scripts/feedback_audio.gd")
const FeedbackEventScript: GDScript = preload("res://scripts/feedback_event.gd")
const FeedbackProfilesScript: GDScript = preload("res://scripts/feedback_profiles.gd")
const HapticRouterScript: GDScript = preload("res://scripts/haptic_router.gd")
const ImpactReactionAdapterScript: GDScript = preload("res://scripts/impact_reaction_adapter.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const SmashFeedbackResolverScript: GDScript = preload("res://scripts/smash_feedback_resolver.gd")
const WalkerLocomotionFeedbackScript: GDScript = preload(
	"res://scripts/walker_locomotion_feedback.gd"
)

const MAX_HISTORY: int = 64

var _effects: Node2D
var _performance_sampler: Node
var _grid_to_screen: Callable
var _camera_mixer: RefCounted = CameraImpulseMixerScript.new() as RefCounted
var _reactions: RefCounted = ImpactReactionAdapterScript.new() as RefCounted
var _haptics: RefCounted = HapticRouterScript.new() as RefCounted
var _audio: Node
var _soundscape: Node
var _locomotion_feedback: Node
var _seen_sequences: Dictionary = {}
var _history: Array[Dictionary] = []
var _submitted_count: int = 0
var _rejected_count: int = 0
var _duplicate_count: int = 0


static func install(
	parent: Node,
	camera: Camera2D,
	effects: Node2D,
	avatar: Node2D,
	enemies: Node2D,
	performance_sampler: Node,
	grid_to_screen: Callable,
	charge: Node2D,
	world: RefCounted,
) -> Node:
	var script: GDScript = load("res://scripts/feedback_router.gd") as GDScript
	var router: Node = script.new() as Node
	parent.add_child(router)
	router.call("configure", camera, effects, avatar, enemies, performance_sampler, grid_to_screen)
	router._locomotion_feedback = WalkerLocomotionFeedbackScript.new() as Node
	router.add_child(router._locomotion_feedback)
	router._locomotion_feedback.call("configure", parent, avatar, router, charge, world)
	return router


func _ready() -> void:
	_ensure_audio()
	_ensure_soundscape()
	call_deferred("_bind_accessibility")


func _process(_delta: float) -> void:
	_sync_metrics()


func configure(
	camera: Camera2D,
	effects: Node2D,
	avatar: Node2D,
	enemies: Node2D,
	performance_sampler: Node = null,
	grid_to_screen: Callable = Callable(),
) -> bool:
	_effects = effects
	_performance_sampler = performance_sampler
	_grid_to_screen = grid_to_screen
	_camera_mixer.call("bind_camera", camera)
	effects.call("bind_camera_mixer", _camera_mixer)
	_reactions.call("bind_sources", avatar, enemies)
	_ensure_audio()
	_sync_metrics()
	return camera != null and effects != null and avatar != null and enemies != null


func present_smash(
	worm_result: Dictionary,
	broken_props: Array[Dictionary],
	impact_band: int,
	source_grid: Vector2,
	fallback_cell: Vector2i,
) -> int:
	return (
		SmashFeedbackResolverScript
		. present(
			self,
			worm_result,
			broken_props,
			impact_band,
			source_grid,
			fallback_cell,
			_grid_to_screen,
		)
	)


func present_pickup(position: Vector2, amount: int) -> bool:
	return _present_outcome(
		RuntimeIdsScript.EVENT_SCRAP_COLLECTED,
		position,
		clampi(amount - 1, 0, 2),
		&"scrap",
		{&"amount": maxi(amount, 1)},
	)


func present_relay(position: Vector2, alert: int) -> bool:
	return _present_outcome(
		RuntimeIdsScript.EVENT_RELAY_COMPLETED,
		position,
		2,
		&"energy",
		{&"alert": maxi(alert, 1)},
	)


func submit(event: Dictionary) -> bool:
	if not FeedbackEventScript.validate(event):
		_rejected_count += 1
		_record_counter(&"feedback.rejected")
		return false
	var sequence_id: int = int(event[&"sequence_id"])
	if _seen_sequences.has(sequence_id):
		_duplicate_count += 1
		_record_counter(&"feedback.duplicates")
		return false
	var profile: Dictionary = FeedbackProfilesScript.resolve(event[&"event_id"])
	if profile.is_empty():
		_rejected_count += 1
		_record_counter(&"feedback.rejected")
		return false
	_seen_sequences[sequence_id] = true
	_submitted_count += 1
	var detached: Dictionary = event.duplicate(true)
	_history.append(detached)
	if _history.size() > MAX_HISTORY:
		var expired: Dictionary = _history.pop_front()
		_seen_sequences.erase(int(expired[&"sequence_id"]))
	_dispatch(detached, profile)
	_record_counter(StringName("feedback.%s" % event[&"event_id"]))
	_record_counter(&"feedback.submitted")
	_sync_metrics()
	return true


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func get_metrics() -> Dictionary:
	return {
		&"submitted": _submitted_count,
		&"rejected": _rejected_count,
		&"duplicates": _duplicate_count,
		&"history": _history.size(),
		&"camera": _camera_mixer.call("get_metrics"),
		&"audio": _audio.call("get_metrics") if _audio != null else {},
		&"soundscape": _soundscape.call("get_metrics") if _soundscape != null else {},
		&"haptics": _haptics.call("get_metrics"),
		&"reactions": int(_reactions.call("get_presentation_count")),
	}


func get_camera_mixer() -> RefCounted:
	return _camera_mixer


func notify_blocked() -> bool:
	return (
		bool(_locomotion_feedback.call("notify_blocked")) if _locomotion_feedback != null else false
	)


func apply_preferences(snapshot: Dictionary) -> void:
	if _effects != null:
		_effects.call("_apply_preferences", snapshot)
	(
		_camera_mixer
		. call(
			"set_intensity",
			float(
				snapshot.get(
					&"camera_shake_intensity", 1.0 if snapshot.get(&"camera_shake", true) else 0.0
				)
			),
		)
	)
	(
		_haptics
		. call(
			"set_intensity",
			float(
				snapshot.get(&"haptic_intensity", 1.0 if snapshot.get(&"haptics", true) else 0.0)
			),
			)
		)
	if _effects != null:
		_effects.call("_apply_preferences", snapshot)
	_ensure_audio()
	if _audio != null:
		_audio.call("set_enabled", bool(snapshot.get(&"sfx_enabled", true)))
	_ensure_soundscape()
	if _soundscape != null:
		_soundscape.call("set_volume", float(snapshot.get(&"sfx_volume", 1.0)))
		_soundscape.call("set_enabled", bool(snapshot.get(&"sfx_enabled", true)))


func _present_outcome(
	event_id: StringName,
	position: Vector2,
	strength: int,
	material: StringName,
	metadata: Dictionary,
) -> bool:
	var event: Dictionary = FeedbackEventScript.create(
		event_id, position, Vector2.UP, strength, material, -1, metadata
	)
	return submit(event)


func _dispatch(event: Dictionary, profile: Dictionary) -> void:
	var direction: Vector2 = event[&"direction"] as Vector2
	(
		_camera_mixer
		. call(
			"submit",
			float(profile[&"camera_duration_seconds"]),
			float(profile[&"camera_strength"]),
			direction,
			int(event[&"sequence_id"]),
		)
	)
	if _effects != null:
		_effects.call("emit_feedback", event, profile)
	var parent: Node = get_parent()
	var hud: Node = parent.get_node_or_null("FieldHUD") if parent != null else null
	if hud != null:
		hud.call("present_feedback", event, profile)
	_reactions.call("present", event, profile)
	_ensure_soundscape()
	if _soundscape != null:
		_soundscape.call("present", event)
	_ensure_audio()
	if _audio != null:
		_audio.call("play_event", event)
	_haptics.call("pulse", profile)


func _ensure_audio() -> void:
	if _audio != null:
		return
	_audio = FeedbackAudioScript.new() as Node
	_audio.name = "FeedbackAudio"
	add_child(_audio)


func _ensure_soundscape() -> void:
	if _soundscape != null:
		return
	_soundscape = BiomeSoundscapeScript.new() as Node
	_soundscape.name = "BiomeSoundscape"
	add_child(_soundscape)


func _bind_accessibility() -> void:
	var panel: Node = get_tree().get_first_node_in_group("accessibility_panel")
	if panel == null:
		return
	apply_preferences(panel.call("get_preferences") as Dictionary)
	panel.connect("preferences_changed", apply_preferences)


func _record_counter(counter: StringName) -> void:
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", counter)


func _sync_metrics() -> void:
	if _performance_sampler == null:
		return
	var camera: Dictionary = _camera_mixer.call("get_metrics") as Dictionary
	var audio: Dictionary = _audio.call("get_metrics") as Dictionary if _audio != null else {}
	var soundscape: Dictionary = (
		_soundscape.call("get_metrics") as Dictionary if _soundscape != null else {}
	)
	_performance_sampler.call("set_gauge", &"feedback.history", float(_history.size()))
	_performance_sampler.call("set_gauge", &"feedback.camera_active", float(camera[&"active"]))
	_performance_sampler.call("set_gauge", &"feedback.audio_active", float(audio.get(&"active", 0)))
	_performance_sampler.call(
		"set_gauge", &"feedback.ambience_active", float(soundscape.get(&"active", 0))
	)
