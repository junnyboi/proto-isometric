extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const SECTION_VITALS: int = 1
const SECTION_IMPACT: int = 2
const SECTION_OBJECTIVE: int = 4
const SECTION_CONTEXT: int = 8
const SECTION_DEBUG: int = 16
const REQUIRED_SECTIONS: int = (
	SECTION_VITALS | SECTION_IMPACT | SECTION_OBJECTIVE | SECTION_CONTEXT | SECTION_DEBUG
)
const VALID_RELAY_STATES: Array[StringName] = [&"dormant", &"signaling", &"linking", &"completed"]
const VALID_IMPACT_BANDS: Array[StringName] = [&"CONTACT", &"SHOCK LINE", &"AFTERSHOCK"]
const VALID_FACINGS: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
const MAX_TEXT_LENGTH: int = 96

var _sections: int = 0
var _sealed: bool = false
var _chassis: int = 0
var _max_chassis: int = 0
var _run_scrap: int = 0
var _worm_cores: int = 0
var _impact_charge: float = 0.0
var _impact_band: StringName = &"CONTACT"
var _completed_relays: int = 0
var _total_relays: int = 0
var _relay_progress: float = 0.0
var _relay_state: StringName = &"dormant"
var _alert_level: int = 0
var _active_modifier_id: StringName = RuntimeIdsScript.MODIFIER_NEUTRAL
var _objective_guidance: String = "SEARCHING"
var _context_event: String = "HEAVY FRAME ONLINE"
var _outpost_linked: bool = false
var _mobile_controls: bool = false
var _debug_visible: bool = false
var _debug_facing: StringName = &"SE"
var _debug_speed_ratio: float = 0.0
var _debug_cell: Vector2i = Vector2i.ZERO


func configure_vitals(chassis: int, max_chassis: int, run_scrap: int, worm_cores: int) -> bool:
	if not _can_configure() or max_chassis <= 0 or chassis < 0 or chassis > max_chassis:
		return false
	if run_scrap < 0 or run_scrap > 1_000_000_000 or worm_cores < 0 or worm_cores > 999:
		return false
	_chassis = chassis
	_max_chassis = max_chassis
	_run_scrap = run_scrap
	_worm_cores = worm_cores
	_sections |= SECTION_VITALS
	return true


func configure_impact(charge: float, band: StringName) -> bool:
	if not _can_configure() or not is_finite(charge) or charge < 0.0 or charge > 1.0:
		return false
	if band not in VALID_IMPACT_BANDS:
		return false
	_impact_charge = charge
	_impact_band = band
	_sections |= SECTION_IMPACT
	return true


func configure_objective(
	completed: int,
	total: int,
	progress: float,
	state: StringName,
	alert_level: int,
	guidance: String,
) -> bool:
	if not _objective_values_are_valid(completed, total, progress, state, alert_level, guidance):
		return false
	_completed_relays = completed
	_total_relays = total
	_relay_progress = progress
	_relay_state = state
	_alert_level = alert_level
	_objective_guidance = guidance
	_sections |= SECTION_OBJECTIVE
	return true


func configure_context(
	context_event: String,
	active_modifier_id: StringName,
	outpost_linked: bool,
	mobile_controls: bool,
) -> bool:
	var modifier_ids: Array = RuntimeIdsScript.catalog()[&"modifiers"] as Array
	if (
		not _can_configure()
		or context_event.is_empty()
		or context_event.length() > MAX_TEXT_LENGTH
		or active_modifier_id not in modifier_ids
	):
		return false
	_context_event = context_event
	_active_modifier_id = active_modifier_id
	_outpost_linked = outpost_linked
	_mobile_controls = mobile_controls
	_sections |= SECTION_CONTEXT
	return true


func configure_debug(
	visible: bool,
	facing: StringName,
	speed_ratio: float,
	cell: Vector2i,
) -> bool:
	if (
		not _can_configure()
		or not is_finite(speed_ratio)
		or speed_ratio < 0.0
		or speed_ratio > 2.0
		or facing not in VALID_FACINGS
		or absi(cell.x) > 1_000_000
		or absi(cell.y) > 1_000_000
	):
		return false
	_debug_visible = visible
	_debug_facing = facing
	_debug_speed_ratio = speed_ratio
	_debug_cell = cell
	_sections |= SECTION_DEBUG
	return true


func seal() -> bool:
	if _sealed or _sections != REQUIRED_SECTIONS:
		return false
	_sealed = true
	return true


func is_sealed() -> bool:
	return _sealed


func get_value(key: StringName) -> Variant:
	if not _sealed:
		return null
	var value: Variant = null
	match key:
		&"chassis":
			value = _chassis
		&"max_chassis":
			value = _max_chassis
		&"run_scrap":
			value = _run_scrap
		&"worm_cores":
			value = _worm_cores
		&"impact_charge":
			value = _impact_charge
		&"impact_band":
			value = _impact_band
		&"completed_relays":
			value = _completed_relays
		&"total_relays":
			value = _total_relays
		&"relay_progress":
			value = _relay_progress
		&"relay_state":
			value = _relay_state
		&"alert_level":
			value = _alert_level
		&"active_modifier_id":
			value = _active_modifier_id
		&"objective_guidance":
			value = _objective_guidance
		&"context_event":
			value = _context_event
		&"outpost_linked":
			value = _outpost_linked
		&"mobile_controls":
			value = _mobile_controls
		&"debug_visible":
			value = _debug_visible
		&"debug_facing":
			value = _debug_facing
		&"debug_speed_ratio":
			value = _debug_speed_ratio
		&"debug_cell":
			value = _debug_cell
	return value


func to_dictionary() -> Dictionary:
	if not _sealed:
		return {}
	return _snapshot()


func _snapshot() -> Dictionary:
	return {
		&"chassis": _chassis,
		&"max_chassis": _max_chassis,
		&"run_scrap": _run_scrap,
		&"worm_cores": _worm_cores,
		&"impact_charge": _impact_charge,
		&"impact_band": _impact_band,
		&"completed_relays": _completed_relays,
		&"total_relays": _total_relays,
		&"relay_progress": _relay_progress,
		&"relay_state": _relay_state,
		&"alert_level": _alert_level,
		&"active_modifier_id": _active_modifier_id,
		&"objective_guidance": _objective_guidance,
		&"context_event": _context_event,
		&"outpost_linked": _outpost_linked,
		&"mobile_controls": _mobile_controls,
		&"debug_visible": _debug_visible,
		&"debug_facing": _debug_facing,
		&"debug_speed_ratio": _debug_speed_ratio,
		&"debug_cell": _debug_cell,
	}


func _can_configure() -> bool:
	return not _sealed


func _objective_values_are_valid(
	completed: int,
	total: int,
	progress: float,
	state: StringName,
	alert_level: int,
	guidance: String,
) -> bool:
	return (
		_can_configure()
		and total >= 0
		and total <= 3
		and completed >= 0
		and completed <= total
		and is_finite(progress)
		and progress >= 0.0
		and progress <= 1.0
		and state in VALID_RELAY_STATES
		and alert_level >= 0
		and alert_level <= 3
		and not guidance.is_empty()
		and guidance.length() <= 64
	)
