extends RefCounted

const FieldUIStateScript: GDScript = preload("res://scripts/field_ui_state.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")


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
) -> RefCounted:
	var state: RefCounted = FieldUIStateScript.new() as RefCounted
	var mobile: bool = mobile_controls != null and bool(mobile_controls.call("is_mobile_device"))
	var completed: int = int(coordinator.call("get_run_value", &"completed_relays"))
	state.call(
		"configure_vitals",
		chassis,
		max_chassis,
		scrap,
		coordinator.call("get_run_value", &"worm_cores")
	)
	state.call("configure_impact", impact.call("get_charge"), impact.call("get_band_name"))
	(
		state
		. call(
			"configure_objective",
			completed,
			relay.call("get_total_count"),
			relay.call("get_progress"),
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
			coordinator.call("get_run_value", &"active_module_ids"),
			coordinator.call("get_run_value", &"refit_purchase_used"),
		)
	)
	state.call("configure_debug", false, facing, speed_ratio, cell)
	return state if bool(state.call("seal")) else null
