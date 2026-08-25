extends RefCounted

const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const ControllerScript: GDScript = preload("res://scripts/harvest_interaction_controller.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PresenterScript: GDScript = preload("res://scripts/harvest_interaction_presenter.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")

const MAP_PATH: String = "res://scripts/isometric_map.gd"
const TERRAIN_PATH: String = "res://scripts/terrain_renderer.gd"
const RETICLE_PATH: String = "res://scripts/target_reticle.gd"
const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1024.0, 576.0),
	Vector2(844.0, 390.0),
	Vector2(720.0, 1280.0),
	Vector2(390.0, 844.0),
]


class Harness:
	extends RefCounted

	var version: int = 1
	var mutations: int = 0

	func project(value: Vector2i) -> Vector2:
		return Vector2(value * 10)

	func player_cell() -> Vector2i:
		return Vector2i.ZERO

	func player_facing() -> StringName:
		return &"SE"

	func zoom(_direction: int) -> void:
		pass

	func legacy_target(_cell: Vector2i) -> Dictionary:
		return {&"kinds": [&"terrain"], &"blocked": false, &"tool_damage": false}

	func menu_target(cell: Vector2i) -> Dictionary:
		var no_costs: Array[Dictionary] = []
		var stamina_cost: Array[Dictionary] = [
			{&"cost_id": &"tool.stamina", &"amount": 2}
		]
		var inputs: Array[Dictionary] = [
			TargetBridgeScript.option_input(
				&"interaction.action.inspect", &"inspect", {&"cell": cell}, true, &"", 0,
				no_costs, OptionScript.CLOSE_NEVER
			),
			TargetBridgeScript.option_input(
				&"interaction.action.till", &"till", {&"cell": cell}, true, &"", 100,
				stamina_cost
			),
			TargetBridgeScript.option_input(
				&"interaction.action.water", &"water", {&"cell": cell}, false,
				&"interaction.reason.requires_watering", 200
			),
		]
		return TargetScript.build(
			cell, &"terrain.phase_c", &"terrain", &"terrain",
			&"interaction.target.terrain.title", {&"version": version}, inputs
		)

	func execute(
		_intent: StringName,
		_tool: StringName,
		_resolved: Dictionary,
		_option: Dictionary = {},
	) -> Dictionary:
		mutations += 1
		return {&"ok": true, &"reason": &""}


class FakeWorld:
	extends RefCounted


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_source_contracts(cases)
	_test_layouts(cases)
	_test_locale_contract(cases)
	_test_controller_and_presenter(cases)
	_test_live_integration(cases, runtime)
	return cases


static func _test_source_contracts(cases: Array[Dictionary]) -> void:
	var map_source: String = FileAccess.get_file_as_string(MAP_PATH)
	var terrain_source: String = FileAccess.get_file_as_string(TERRAIN_PATH)
	var reticle_source: String = FileAccess.get_file_as_string(RETICLE_PATH)
	_add(
		cases,
		"PHC-01 player-foot arrow helper and call are absent",
		"draw_drive_vector" not in map_source and "draw_drive_vector" not in terrain_source,
	)
	_add(
		cases,
		"PHC-02 adjacent target diamond remains the spatial authority",
		"draw_colored_polygon(diamond" in reticle_source and "draw_polyline(diamond" in reticle_source,
	)
	_add(
		cases,
		"PHC-03 isometric map remains within its 1000-line cap",
		map_source.split("\n").size() - 1 <= 1000,
	)


static func _test_layouts(cases: Array[Dictionary]) -> void:
	var valid_all: bool = true
	var scroll_all: bool = true
	for viewport: Vector2 in VIEWPORTS:
		for left_handed: bool in [false, true]:
			for scale_value: float in [0.85, 1.0, 1.25]:
				var layout: Dictionary = PresenterScript.layout_for(
					viewport, left_handed, scale_value, viewport.x < 1100.0, 32
				)
				valid_all = valid_all and PresenterScript.validate_layout(layout)
				valid_all = valid_all and (
					(layout[&"safe_bounds"] as Rect2).encloses(layout[&"popup"] as Rect2)
				)
				scroll_all = scroll_all and bool(layout[&"scroll_required"])
	_add(
		cases,
		"PHC-04 popup is contained for five target viewports, both handedness modes, and all UI scales",
		valid_all,
	)
	_add(
		cases,
		"PHC-05 maximum bounded rows scroll without overlap at every certification viewport",
		scroll_all,
	)
	var right: Dictionary = PresenterScript.layout_for(Vector2(844.0, 390.0), false, 1.0, true, 8)
	var left: Dictionary = PresenterScript.layout_for(Vector2(844.0, 390.0), true, 1.0, true, 8)
	_add(
		cases,
		"PHC-06 left-handed mobile layout mirrors the terminal away from joystick ownership",
		(right[&"popup"] as Rect2).position.x < (left[&"popup"] as Rect2).position.x,
	)


static func _test_locale_contract(cases: Array[Dictionary]) -> void:
	var english: Array[String] = LocalizationScript.get_catalog_keys(&"en")
	var chinese: Array[String] = LocalizationScript.get_catalog_keys(&"zh-CN")
	var complete: bool = english == chinese
	for key: String in [
		"interaction.menu.bindings",
		"interaction.action.inspect.label",
		"interaction.action.chop.label",
		"interaction.action.hazard_stabilize.label",
		"interaction.reason.requires_axe",
		"interaction.reason.inventory_full",
		"interaction.target.hostile.title",
		"interaction.target.livestock.title",
		"tool.stamina",
		"item.currency.credit",
	]:
		complete = complete and key in english
	_add(cases, "PHC-07 English and Simplified Chinese interaction keys have exact parity", complete)


static func _test_controller_and_presenter(cases: Array[Dictionary]) -> void:
	var harness: RefCounted = Harness.new() as RefCounted
	var avatar: Node2D = Node2D.new()
	var controller: Node2D = ControllerScript.new() as Node2D
	var presenter: CanvasLayer = PresenterScript.new() as CanvasLayer
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(avatar)
	tree.root.add_child(controller)
	tree.root.add_child(presenter)
	var configured: bool = bool(
		controller.call(
			"configure", FakeWorld.new(), avatar, Callable(harness, "project"),
			Callable(harness, "player_cell"), Callable(harness, "player_facing"),
			Callable(harness, "zoom"), Callable(harness, "legacy_target"),
			Callable(harness, "execute"), Callable(harness, "menu_target")
		)
	)
	var bound: bool = bool(presenter.call("bind", controller))
	var opening_press: bool = bool(controller.call("handle_touch_command", CommandsScript.CONTEXT))
	_add(
		cases,
		"PHC-08 first Context press opens one pooled presenter with zero mutation",
		configured and bound and opening_press and presenter.call("is_open")
		and int(harness.get("mutations")) == 0 and int(presenter.call("get_pool_size")) == 3,
	)
	controller.call("navigate_menu", 1)
	var action_before_locale: StringName = controller.call("get_selected_action_id") as StringName
	LocalizationScript.set_locale(&"zh-CN")
	var locale_preserved: bool = (
		controller.call("get_selected_action_id") == action_before_locale
		and presenter.call("get_selected_action_id") == action_before_locale
	)
	LocalizationScript.set_locale(&"en")
	_add(cases, "PHC-09 locale refresh preserves selected action identity", locale_preserved)
	var confirmed: bool = bool(controller.call("handle_touch_command", CommandsScript.CONTEXT))
	_add(
		cases,
		"PHC-10 touch Context second press confirms exactly once",
		confirmed and int(harness.get("mutations")) == 1 and not controller.call("is_menu_open"),
	)
	controller.call("open_menu")
	controller.call("select_menu_index", 2)
	var disabled: bool = not bool(controller.call("confirm_menu"))
	_add(
		cases,
		"PHC-11 disabled row blocks mutation and remains visibly selectable",
		disabled and int(harness.get("mutations")) == 1 and controller.call("is_menu_open"),
	)
	controller.call("select_menu_index", 1)
	harness.set("version", 2)
	var stale: bool = not bool(controller.call("confirm_menu"))
	_add(
		cases,
		"PHC-12 stale confirmation refreshes without mutation and preserves action identity",
		stale and int(harness.get("mutations")) == 1
		and controller.call("get_selected_action_id") == &"interaction.action.till",
	)
	var cancel_event: InputEventKey = _key(KEY_ESCAPE)
	var cancel_owned: bool = bool(presenter.call("handle_modal_event", cancel_event))
	_add(
		cases,
		"PHC-13 keyboard/controller Cancel is consumed before map fallback",
		cancel_owned and not controller.call("is_menu_open"),
	)
	controller.call("open_menu")
	var down_event: InputEventKey = _key(KEY_DOWN)
	var down_owned: bool = bool(presenter.call("handle_modal_event", down_event))
	var outside: InputEventMouseButton = InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(1270.0, 710.0)
	var mouse_owned: bool = bool(presenter.call("handle_modal_event", outside))
	_add(
		cases,
		"PHC-14 keyboard navigation and mouse/touch outside-close share modal ownership",
		down_owned and mouse_owned and not controller.call("is_menu_open"),
	)
	presenter.free()
	controller.free()
	avatar.free()


static func _test_live_integration(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var controller: Node = bridge.call("get_interaction_controller") as Node
	var presenter: CanvasLayer = bridge.call("get_interaction_presenter") as CanvasLayer
	var reticle: Node2D = controller.call("get_reticle") as Node2D
	var world_nodes_before: int = runtime.get_node("WorldObjectLayer").get_child_count()
	controller.call("open_menu")
	var world_nodes_open: int = runtime.get_node("WorldObjectLayer").get_child_count()
	controller.call("close_menu")
	controller.call("open_menu")
	controller.call("close_menu")
	var world_nodes_after: int = runtime.get_node("WorldObjectLayer").get_child_count()
	_add(
		cases,
		"PHC-15 live map has one pooled CanvasLayer presenter and no per-target world nodes or leaks",
		(
			presenter != null
			and runtime.find_children(
				"HarvestInteractionPresenter", "CanvasLayer", true, false
			).size() == 1
			and world_nodes_before == world_nodes_open
			and world_nodes_before == world_nodes_after
		),
	)
	_add(
		cases,
		"PHC-16 live target reticle diamond remains retained after menu cycles",
		reticle != null and reticle.name == "AdjacentTargetReticle" and reticle.is_inside_tree(),
	)
	var mobile: CanvasLayer = runtime.get("_mobile_controls") as CanvasLayer
	mobile.call("force_mobile", true)
	controller.call("open_menu")
	var popup: Rect2 = presenter.call("get_popup_bounds") as Rect2
	var exclusions: Array[Rect2] = mobile.call("get_touch_exclusions") as Array[Rect2]
	var smash_events: Array[int] = [0]
	mobile.connect("smash_pressed", func() -> void: smash_events[0] += 1)
	mobile.call("trigger_smash")
	_add(
		cases,
		(
			"PHC-17 open popup bounds join mobile touch exclusions while "
			+ "Smash and settings controls remain allocated"
		),
		popup in exclusions and mobile.call("get_smash_button") != null
		and runtime.get("_hud") != null and exclusions.size() == 5,
	)
	_add(
		cases,
		"PHC-18 movement, Tool, and Smash inputs are suppressed while the modal is open",
		Vector2(runtime.call("get_velocity")) == Vector2.ZERO
		and bool(mobile.call("is_modal_input_suppressed"))
		and not bool(mobile.call("begin_touch", 77, Vector2(120.0, 220.0)))
		and bool(controller.call("handle_touch_command", CommandsScript.TOOL_ACTION))
		and smash_events[0] == 0,
	)
	controller.call("close_menu")
	mobile.call("force_mobile", false)


static func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
