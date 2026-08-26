extends RefCounted

const MOVE_UP: StringName = &"harvest_move_up"
const MOVE_DOWN: StringName = &"harvest_move_down"
const MOVE_LEFT: StringName = &"harvest_move_left"
const MOVE_RIGHT: StringName = &"harvest_move_right"
const CONTEXT: StringName = &"harvest_context"
const TOOL_ACTION: StringName = &"harvest_tool_action"
const QUICK_ACTION: StringName = &"harvest_quick_action"
const PREVIOUS_TOOL: StringName = &"harvest_previous_tool"
const NEXT_TOOL: StringName = &"harvest_next_tool"
const INVENTORY: StringName = &"harvest_inventory"
const JOURNAL_MAP: StringName = &"harvest_journal_map"
const RUN: StringName = &"harvest_run"
const CANCEL: StringName = &"harvest_cancel"
const ZOOM_IN: StringName = &"harvest_zoom_in"
const ZOOM_OUT: StringName = &"harvest_zoom_out"
const COMBAT_ATTACK: StringName = &"harvest_combat_attack"

const MOVE_ACTIONS: Array[StringName] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]
const ACTIONS: Array[StringName] = [
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	CONTEXT,
	TOOL_ACTION,
	QUICK_ACTION,
	PREVIOUS_TOOL,
	NEXT_TOOL,
	INVENTORY,
	JOURNAL_MAP,
	RUN,
	CANCEL,
	ZOOM_IN,
	ZOOM_OUT,
	COMBAT_ATTACK,
]

static var _installed: bool = false


static func install_defaults() -> bool:
	if _installed and _actions_exist():
		return true
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if InputMap.action_get_events(action).is_empty():
			for descriptor: Dictionary in _event_descriptors_for(action):
				var event: InputEvent = _event_for(descriptor)
				if event != null:
					InputMap.action_add_event(action, event)
	_installed = validate_defaults()
	return _installed


static func validate_defaults() -> bool:
	var seen_actions: Dictionary = {}
	var seen_descriptors: Dictionary = {}
	for action: StringName in ACTIONS:
		if seen_actions.has(action) or not InputMap.has_action(action):
			return false
		seen_actions[action] = true
		var descriptors: Dictionary = descriptors_for(action)
		for platform: StringName in [&"keyboard", &"controller", &"touch"]:
			var platform_descriptors: Array = descriptors.get(platform, []) as Array
			if platform_descriptors.is_empty():
				return false
			for descriptor: Dictionary in platform_descriptors:
				var signature: String = _descriptor_signature(descriptor)
				if seen_descriptors.has(signature) and seen_descriptors[signature] != action:
					return false
				seen_descriptors[signature] = action
	return seen_actions.size() == ACTIONS.size()


static func action_ids() -> Array[StringName]:
	return ACTIONS.duplicate()


static func descriptors_for(action: StringName) -> Dictionary:
	return {
		&"keyboard": (_keyboard_descriptors().get(action, []) as Array).duplicate(true),
		&"controller": (_controller_descriptors().get(action, []) as Array).duplicate(true),
		&"touch": (_touch_descriptors().get(action, []) as Array).duplicate(true),
	}


static func read_move_vector() -> Vector2:
	install_defaults()
	return Input.get_vector(MOVE_LEFT, MOVE_RIGHT, MOVE_UP, MOVE_DOWN)


static func is_pressed(action: StringName) -> bool:
	return install_defaults() and action in ACTIONS and Input.is_action_pressed(action)


static func is_just_pressed(action: StringName) -> bool:
	return install_defaults() and action in ACTIONS and Input.is_action_just_pressed(action)


static func _actions_exist() -> bool:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			return false
	return true


static func _event_descriptors_for(action: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var descriptors: Dictionary = descriptors_for(action)
	for platform: StringName in [&"keyboard", &"controller"]:
		for value: Variant in descriptors[platform] as Array:
			result.append((value as Dictionary).duplicate(true))
	return result


static func _keyboard_descriptors() -> Dictionary:
	return {
		MOVE_UP: [_physical_key(KEY_W), _logical_key(KEY_UP)],
		MOVE_DOWN: [_physical_key(KEY_S), _logical_key(KEY_DOWN)],
		MOVE_LEFT: [_physical_key(KEY_A), _logical_key(KEY_LEFT)],
		MOVE_RIGHT: [_physical_key(KEY_D), _logical_key(KEY_RIGHT)],
		CONTEXT: [_physical_key(KEY_E)],
		TOOL_ACTION: [_physical_key(KEY_F)],
		QUICK_ACTION: [_physical_key(KEY_G)],
		PREVIOUS_TOOL: [_physical_key(KEY_Q)],
		NEXT_TOOL: [_physical_key(KEY_R)],
		INVENTORY: [_physical_key(KEY_I)],
		JOURNAL_MAP: [_physical_key(KEY_M)],
		RUN: [_logical_key(KEY_SHIFT)],
		CANCEL: [_logical_key(KEY_ESCAPE)],
		ZOOM_IN: [_logical_key(KEY_EQUAL)],
		ZOOM_OUT: [_logical_key(KEY_MINUS)],
		COMBAT_ATTACK: [
			_logical_key(KEY_SPACE),
			_physical_key(KEY_J),
			_physical_key(KEY_K),
		],
	}


static func _controller_descriptors() -> Dictionary:
	return {
		MOVE_UP: [_joy_axis(JOY_AXIS_LEFT_Y, -1.0), _joy_button(JOY_BUTTON_DPAD_UP)],
		MOVE_DOWN: [_joy_axis(JOY_AXIS_LEFT_Y, 1.0), _joy_button(JOY_BUTTON_DPAD_DOWN)],
		MOVE_LEFT: [_joy_axis(JOY_AXIS_LEFT_X, -1.0), _joy_button(JOY_BUTTON_DPAD_LEFT)],
		MOVE_RIGHT: [_joy_axis(JOY_AXIS_LEFT_X, 1.0), _joy_button(JOY_BUTTON_DPAD_RIGHT)],
		CONTEXT: [_joy_button(JOY_BUTTON_A)],
		TOOL_ACTION: [_joy_button(JOY_BUTTON_Y)],
		QUICK_ACTION: [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		PREVIOUS_TOOL: [_joy_button(JOY_BUTTON_LEFT_SHOULDER)],
		NEXT_TOOL: [_joy_button(JOY_BUTTON_RIGHT_STICK)],
		INVENTORY: [_joy_button(JOY_BUTTON_BACK)],
		JOURNAL_MAP: [_joy_button(JOY_BUTTON_START)],
		RUN: [
			_joy_button(JOY_BUTTON_LEFT_STICK),
			_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0),
		],
		CANCEL: [_joy_button(JOY_BUTTON_B)],
		ZOOM_IN: [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		ZOOM_OUT: [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		COMBAT_ATTACK: [
			_joy_button(JOY_BUTTON_X),
			_joy_button(JOY_BUTTON_RIGHT_SHOULDER),
		],
	}


static func _touch_descriptors() -> Dictionary:
	return {
		MOVE_UP: [_touch(&"joystick", &"up")],
		MOVE_DOWN: [_touch(&"joystick", &"down")],
		MOVE_LEFT: [_touch(&"joystick", &"left")],
		MOVE_RIGHT: [_touch(&"joystick", &"right")],
		CONTEXT: [_touch(&"context_button")],
		TOOL_ACTION: [_touch(&"tool_button")],
		QUICK_ACTION: [_touch(&"quick_action_button")],
		PREVIOUS_TOOL: [_touch(&"previous_tool_button")],
		NEXT_TOOL: [_touch(&"next_tool_button")],
		INVENTORY: [_touch(&"inventory_button")],
		JOURNAL_MAP: [_touch(&"journal_map_button")],
		RUN: [_touch(&"joystick_outer_ring")],
		CANCEL: [_touch(&"cancel_button")],
		ZOOM_IN: [_touch(&"camera_zoom_in")],
		ZOOM_OUT: [_touch(&"camera_zoom_out")],
		COMBAT_ATTACK: [_touch(&"smash_button")],
	}


static func _physical_key(code: Key) -> Dictionary:
	return {&"type": &"physical_key", &"code": int(code)}


static func _logical_key(code: Key) -> Dictionary:
	return {&"type": &"key", &"code": int(code)}


static func _joy_button(code: JoyButton) -> Dictionary:
	return {&"type": &"joy_button", &"code": int(code)}


static func _joy_axis(code: JoyAxis, value: float) -> Dictionary:
	return {&"type": &"joy_axis", &"code": int(code), &"value": value}


static func _touch(control: StringName, direction: StringName = &"") -> Dictionary:
	return {&"type": &"touch", &"control": control, &"direction": direction}


static func _event_for(descriptor: Dictionary) -> InputEvent:
	var kind: StringName = descriptor[&"type"] as StringName
	if kind in [&"key", &"physical_key"]:
		var key: InputEventKey = InputEventKey.new()
		if kind == &"physical_key":
			key.physical_keycode = int(descriptor[&"code"])
		else:
			key.keycode = int(descriptor[&"code"])
		return key
	if kind == &"joy_button":
		var button: InputEventJoypadButton = InputEventJoypadButton.new()
		button.button_index = int(descriptor[&"code"])
		return button
	if kind == &"joy_axis":
		var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
		motion.axis = int(descriptor[&"code"])
		motion.axis_value = float(descriptor[&"value"])
		return motion
	return null


static func _descriptor_signature(descriptor: Dictionary) -> String:
	if descriptor[&"type"] == &"touch":
		return "touch:%s:%s" % [descriptor[&"control"], descriptor[&"direction"]]
	return "%s:%s:%s" % [
		descriptor[&"type"],
		descriptor.get(&"code", -1),
		signf(float(descriptor.get(&"value", 0.0))),
	]
