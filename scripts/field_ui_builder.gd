extends RefCounted

const FieldUIStateScript: GDScript = preload("res://scripts/field_ui_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

static var _performance_sampler: Node
static var _signature: Array = []


static func configure_performance(sampler: Node) -> void:
	_performance_sampler = sampler
	_signature = []


static func build(
	coordinator: RefCounted,
	relay: Node2D,
	impact: Node2D,
	mobile_controls: CanvasLayer,
	chassis: int,
	max_chassis: int,
	scrap: int,
	context: String,
	shutdown: bool,
	outpost_linked: bool,
	facing: StringName,
	speed_ratio: float,
	cell: Vector2i,
	current_biome: StringName = &"desert",
	terrain_surface: StringName = &"sand",
) -> RefCounted:
	var mobile: bool = mobile_controls != null and bool(mobile_controls.call("is_mobile_device"))
	var completed: int = int(coordinator.call("get_run_value", &"completed_relays"))
	var charge: float = float(impact.call("get_charge"))
	var band: StringName = impact.call("get_band_name") as StringName
	var relay_progress: float = float(relay.call("get_progress"))
	var active_modules: Array = coordinator.call("get_run_value", &"active_module_ids") as Array
	var signature: Array = [
		chassis,
		max_chassis,
		scrap,
		int(coordinator.call("get_run_value", &"worm_cores")),
		roundi(charge * 100.0),
		band,
		completed,
		int(relay.call("get_total_count")),
		roundi(relay_progress * 100.0),
		relay.call("get_state"),
		relay.call("get_signal_hint"),
		context,
		coordinator.call("get_run_value", &"active_modifier_id"),
		not shutdown and outpost_linked,
		mobile,
		active_modules,
		bool(coordinator.call("get_run_value", &"refit_purchase_used")),
		current_biome,
		terrain_surface,
	]
	if signature == _signature:
		_record_counter(&"hud.build_skips")
		return null
	var started_usec: int = _begin_scope()
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	state.call(
		"configure_vitals",
		chassis,
		max_chassis,
		scrap,
		coordinator.call("get_run_value", &"worm_cores")
	)
	state.call("configure_impact", charge, band)
	(
		state
		. call(
			"configure_objective",
			completed,
			relay.call("get_total_count"),
			relay_progress,
			relay.call("get_state"),
			completed,
			relay.call("get_signal_hint"),
		)
	)
	(
		state
		. call(
			"configure_context",
			context,
			coordinator.call("get_run_value", &"active_modifier_id"),
			not shutdown and outpost_linked,
			mobile,
				active_modules,
				coordinator.call("get_run_value", &"refit_purchase_used"),
				current_biome,
				terrain_surface,
			)
	)
	state.call("configure_debug", false, facing, speed_ratio, cell)
	var result: RefCounted = state if bool(state.call("seal")) else null
	if result != null:
		_signature = signature.duplicate(true)
		_record_counter(&"hud.state_builds")
	_end_scope(&"hud.refresh", started_usec)
	return result


static func _record_counter(counter: StringName) -> void:
	if _performance_sampler != null:
		_performance_sampler.call("increment_counter", counter)


static func _begin_scope() -> int:
	return (
		int(_performance_sampler.call("begin_scope"))
		if _performance_sampler != null
		else Time.get_ticks_usec()
	)


static func _end_scope(scope: StringName, started_usec: int) -> void:
	if _performance_sampler != null:
		_performance_sampler.call("end_scope", scope, started_usec)
