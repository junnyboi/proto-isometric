extends RefCounted

const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const STATE_VERSION: int = 1
const HOME_ID: StringName = &"ruin.home.8.4"

var _states: Dictionary = {}


func _init() -> void:
	_states[WoodlandClearingScript.HOME_CELL] = _make_state(
		WoodlandClearingScript.HOME_CELL,
		OutpostVisualsScript.KIND_SAFEHOUSE,
		true,
		true,
		true,
		true,
	)


func stable_id_for(cell: Vector2i) -> StringName:
	if cell == WoodlandClearingScript.HOME_CELL:
		return HOME_ID
	return StringName("ruin.%d.%d" % [cell.x, cell.y])


func state_for(cell: Vector2i) -> Dictionary:
	if _states.has(cell):
		return (_states[cell] as Dictionary).duplicate(true)
	return _make_state(cell, OutpostVisualsScript.kind_for(cell), false, false, false, false)


func discover(cell: Vector2i) -> bool:
	var state: Dictionary = state_for(cell)
	if bool(state[&"discovered"]):
		return false
	state[&"discovered"] = true
	_states[cell] = state
	return true


func repair(cell: Vector2i) -> bool:
	var state: Dictionary = state_for(cell)
	if bool(state[&"home"]) or bool(state[&"repaired"]):
		return false
	state[&"discovered"] = true
	state[&"repaired"] = true
	_states[cell] = state
	return true


func set_powered(cell: Vector2i, powered: bool) -> bool:
	var state: Dictionary = state_for(cell)
	if bool(state[&"home"]) or bool(state[&"powered"]) == powered:
		return false
	if powered and not bool(state[&"repaired"]):
		return false
	state[&"discovered"] = true
	state[&"powered"] = powered
	_states[cell] = state
	return true


func is_home(cell: Vector2i) -> bool:
	return cell == WoodlandClearingScript.HOME_CELL


func is_service_active(cell: Vector2i) -> bool:
	var state: Dictionary = state_for(cell)
	return bool(state[&"home"]) or (bool(state[&"repaired"]) and bool(state[&"powered"]))


func is_sanctuary_active(cell: Vector2i) -> bool:
	return is_service_active(cell)


func legacy_kind_for(cell: Vector2i) -> StringName:
	return state_for(cell)[&"kind"] as StringName


func _make_state(
	cell: Vector2i,
	kind: StringName,
	home: bool,
	discovered: bool,
	repaired: bool,
	powered: bool,
) -> Dictionary:
	return {
		&"state_version": STATE_VERSION,
		&"id": stable_id_for(cell),
		&"cell": cell,
		&"kind": kind,
		&"home": home,
		&"discovered": discovered,
		&"repaired": repaired,
		&"powered": powered,
	}
