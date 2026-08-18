extends RefCounted


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


static func is_run_pressed() -> bool:
	return Input.is_key_pressed(KEY_SHIFT)


static func is_attack_pressed() -> bool:
	return (
		Input.is_key_pressed(KEY_SPACE)
		or Input.is_physical_key_pressed(KEY_J)
		or Input.is_physical_key_pressed(KEY_K)
	)
