extends RefCounted

signal modality_changed(modality: StringName)

const KEYBOARD_MOUSE: StringName = &"keyboard_mouse"
const CONTROLLER: StringName = &"controller"
const TOUCH: StringName = &"touch"
const MODALITIES: Array[StringName] = [KEYBOARD_MOUSE, CONTROLLER, TOUCH]

var _modality: StringName = KEYBOARD_MOUSE


func get_modality() -> StringName:
	return _modality


func set_modality(modality: StringName) -> bool:
	if modality not in MODALITIES:
		return false
	if modality == _modality:
		return true
	_modality = modality
	modality_changed.emit(_modality)
	return true


func observe_event(event: InputEvent) -> bool:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return set_modality(TOUCH)
	if event is InputEventJoypadButton:
		return set_modality(CONTROLLER) if (event as InputEventJoypadButton).pressed else false
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return set_modality(CONTROLLER) if absf(motion.axis_value) > 0.3 else false
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return set_modality(KEYBOARD_MOUSE) if key.pressed and not key.echo else false
	if event is InputEventMouseButton:
		return set_modality(KEYBOARD_MOUSE) if (event as InputEventMouseButton).pressed else false
	return false
