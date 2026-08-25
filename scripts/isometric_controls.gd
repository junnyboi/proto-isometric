extends RefCounted

const HarvestCommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const FACING_NAMES: Array[StringName] = [&"N", &"NE", &"E", &"SE", &"S", &"SW", &"W", &"NW"]
const CONTROLLER_DEAD_ZONE: float = 0.16
const CONTROLLER_RESPONSE_EXPONENT: float = 1.15
const CONTROLLER_ACTIVITY_THRESHOLD: float = 0.08
const RUN_TRIGGER_THRESHOLD: float = 0.35

static var _active_joypad: int = -1


static func screen_to_grid_delta(screen_direction: Vector2i) -> Vector2i:
	var direction: Vector2i = Vector2i(
		clampi(screen_direction.x, -1, 1), clampi(screen_direction.y, -1, 1)
	)
	var directions: Dictionary = {
		Vector2i(0, -1): Vector2i(-1, -1),
		Vector2i(1, -1): Vector2i(0, -1),
		Vector2i(1, 0): Vector2i(1, -1),
		Vector2i(1, 1): Vector2i(1, 0),
		Vector2i(0, 1): Vector2i(1, 1),
		Vector2i(-1, 1): Vector2i(0, 1),
		Vector2i(-1, 0): Vector2i(-1, 1),
		Vector2i(-1, -1): Vector2i(-1, 0),
	}
	return directions.get(direction, Vector2i.ZERO) as Vector2i


static func direction_name(screen_direction: Vector2i) -> StringName:
	var names: Dictionary = {
		Vector2i(0, -1): &"N",
		Vector2i(1, -1): &"NE",
		Vector2i(1, 0): &"E",
		Vector2i(1, 1): &"SE",
		Vector2i(0, 1): &"S",
		Vector2i(-1, 1): &"SW",
		Vector2i(-1, 0): &"W",
		Vector2i(-1, -1): &"NW",
	}
	return names.get(screen_direction, &"IDLE") as StringName


static func facing_to_screen_direction(facing: StringName) -> Vector2i:
	var directions: Dictionary = {
		&"N": Vector2i(0, -1),
		&"NE": Vector2i(1, -1),
		&"E": Vector2i(1, 0),
		&"SE": Vector2i(1, 1),
		&"S": Vector2i(0, 1),
		&"SW": Vector2i(-1, 1),
		&"W": Vector2i(-1, 0),
		&"NW": Vector2i(-1, -1),
	}
	return directions.get(facing, Vector2i.ZERO) as Vector2i


static func facing_names() -> Array[StringName]:
	return FACING_NAMES.duplicate()


static func read_drive_vector() -> Vector2:
	var keyboard: Vector2i = read_screen_direction()
	if keyboard != Vector2i.ZERO:
		return Vector2(keyboard).normalized()
	var remapped: Vector2 = HarvestCommandsScript.read_move_vector()
	if not remapped.is_zero_approx():
		return remapped
	return read_controller_vector()


static func read_screen_direction() -> Vector2i:
	var horizontal: int = 0
	var vertical: int = 0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		horizontal -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		horizontal += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		vertical -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		vertical += 1
	return Vector2i(horizontal, vertical)


static func read_controller_vector() -> Vector2:
	var strongest: Vector2 = Vector2.ZERO
	var strongest_device: int = -1
	for device: int in Input.get_connected_joypads():
		var candidate: Vector2 = _raw_controller_vector(device)
		if candidate.length_squared() > strongest.length_squared():
			strongest = candidate
			strongest_device = device
	if strongest.length() >= CONTROLLER_ACTIVITY_THRESHOLD:
		_active_joypad = strongest_device
	return shape_controller_vector(strongest)


static func shape_controller_vector(
	raw: Vector2,
	dead_zone: float = CONTROLLER_DEAD_ZONE,
	response_exponent: float = CONTROLLER_RESPONSE_EXPONENT,
) -> Vector2:
	var magnitude: float = minf(raw.length(), 1.0)
	if magnitude <= dead_zone:
		return Vector2.ZERO
	var normalized_strength: float = (magnitude - dead_zone) / (1.0 - dead_zone)
	var response: float = pow(normalized_strength, response_exponent)
	return raw.normalized() * clampf(response, 0.0, 1.0)


static func is_run_pressed() -> bool:
	if HarvestCommandsScript.is_pressed(HarvestCommandsScript.RUN):
		return true
	for device: int in Input.get_connected_joypads():
		if (
			Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_STICK)
			or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > RUN_TRIGGER_THRESHOLD
		):
			_active_joypad = device
			return true
	return false


static func is_attack_pressed() -> bool:
	if (
		HarvestCommandsScript.is_pressed(HarvestCommandsScript.COMBAT_ATTACK)
		or Input.is_key_pressed(KEY_SPACE)
		or Input.is_physical_key_pressed(KEY_J)
		or Input.is_physical_key_pressed(KEY_K)
	):
		return true
	for device: int in Input.get_connected_joypads():
		if (
			Input.is_joy_button_pressed(device, JOY_BUTTON_X)
			or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
		):
			_active_joypad = device
			return true
	return false


static func get_active_joypad() -> int:
	return _active_joypad


static func _raw_controller_vector(device: int) -> Vector2:
	var digital: Vector2i = Vector2i(
		(
			int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT))
			- int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT))
		),
		(
			int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN))
			- int(Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP))
		),
	)
	if digital != Vector2i.ZERO:
		return Vector2(digital).normalized()
	return Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device, JOY_AXIS_LEFT_Y),
	)


static func _reset_active_joypad_for_test() -> void:
	_active_joypad = -1
