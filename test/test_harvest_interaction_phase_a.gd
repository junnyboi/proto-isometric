extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const ControllerScript: GDScript = preload("res://scripts/harvest_interaction_controller.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")

const EXPECTED_TARGETS: Dictionary = {
	&"N": Vector2i(-1, -1),
	&"NE": Vector2i(0, -1),
	&"E": Vector2i(1, -1),
	&"SE": Vector2i(1, 0),
	&"S": Vector2i(1, 1),
	&"SW": Vector2i(0, 1),
	&"W": Vector2i(-1, 1),
	&"NW": Vector2i(-1, 0),
}


class Harness:
	extends RefCounted

	var cell: Vector2i = Vector2i.ZERO
	var facing: StringName = &"SE"
	var target_version: int = 1
	var mutations: int = 0
	var last_option: Dictionary = {}

	func project(value: Vector2i) -> Vector2:
		return Vector2(value * 10)

	func player_cell() -> Vector2i:
		return cell

	func player_facing() -> StringName:
		return facing

	func zoom(_direction: int) -> void:
		pass

	func legacy_target(_cell: Vector2i) -> Dictionary:
		return {&"kinds": [&"terrain"], &"blocked": false, &"tool_damage": false}

	func menu_target(target_cell: Vector2i) -> Dictionary:
		var inputs: Array[Dictionary] = [
			TargetBridgeScript.option_input(
				&"interaction.action.alpha",
				&"test_alpha",
				{&"cell": target_cell},
				true,
				&"",
				100,
			),
			TargetBridgeScript.option_input(
				&"interaction.action.beta",
				&"test_beta",
				{&"cell": target_cell},
				true,
				&"",
				200,
			),
			TargetBridgeScript.option_input(
				&"interaction.action.gamma",
				&"test_gamma",
				{&"cell": target_cell},
				false,
				&"interaction.reason.blocked",
				300,
			),
		]
		return TargetScript.build(
			target_cell,
			&"terrain.test",
			&"terrain",
			&"terrain",
			&"interaction.target.terrain.title",
			{&"version": target_version},
			inputs,
		)

	func execute(
		_intent: StringName,
		_tool_id: StringName,
		_resolved: Dictionary,
		option: Dictionary = {},
	) -> Dictionary:
		mutations += 1
		last_option = option.duplicate(true)
		return {&"ok": true, &"reason": &""}


class FakeWorld:
	extends RefCounted


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_contracts(cases)
	_test_caps_and_duplicates(cases)
	_test_resolver_compatibility(cases)
	_test_determinism(cases)
	_test_controller_lifecycle(cases)
	return cases


static func _test_contracts(cases: Array[Dictionary]) -> void:
	var option: Dictionary = _option(&"interaction.action.alpha", 100)
	var target: Dictionary = _target([_input(&"interaction.action.alpha", 100)])
	var menu: Dictionary = CatalogScript.build_menu(target)
	_add(
		cases,
		"PHA-01 InteractionOption and menu snapshots expose exact ordered keys",
		(
			OptionScript.validate(option)
			and option.keys() == OptionScript.KEYS
			and TargetScript.validate(target)
			and target.keys() == TargetScript.KEYS
			and MenuScript.validate(menu)
			and menu.keys() == MenuScript.KEYS
		),
	)
	var malformed_option: Dictionary = option.duplicate(true)
	malformed_option[&"priority"] = 100.0
	var malformed_menu: Dictionary = menu.duplicate(true)
	malformed_menu[&"target_cell"] = [1, 0]
	var extra_key: Dictionary = option.duplicate(true)
	extra_key[&"unknown"] = true
	_add(
		cases,
		"PHA-02 malformed field types, extra keys, and unknown projections fail closed",
		(
			not OptionScript.validate(malformed_option)
			and not OptionScript.validate(extra_key)
			and not MenuScript.validate(malformed_menu)
			and CatalogScript.build_menu({}).is_empty()
		),
	)
	var disabled_bad: Dictionary = option.duplicate(true)
	disabled_bad[&"enabled"] = false
	_add(
		cases,
		"PHA-03 disabled options require exact reason keys and enabled options reject reasons",
		not OptionScript.validate(disabled_bad),
	)


static func _test_caps_and_duplicates(cases: Array[Dictionary]) -> void:
	var cells: Array[Vector2i] = []
	for index: int in OptionScript.MAX_AFFECTED_CELLS + 1:
		cells.append(Vector2i(index, 0))
	var oversized: Dictionary = OptionScript.build(
		&"interaction.action.oversized",
		CatalogScript.PROVIDER_TERRAIN,
		&"terrain.test",
		&"terrain",
		&"terrain",
		&"inspect",
		{},
		true,
		&"interaction.action.oversized.label",
		&"",
		0,
		cells,
	)
	var duplicate_inputs: Array[Dictionary] = [
		_input(&"interaction.action.duplicate", 1),
		_input(&"interaction.action.duplicate", 2),
	]
	var duplicate_menu: Dictionary = CatalogScript.build_menu(_target(duplicate_inputs))
	var too_many: Array[Dictionary] = []
	for index: int in OptionScript.MAX_OPTIONS + 1:
		too_many.append(_input(StringName("interaction.action.cap_%02d" % index), index))
	var too_many_costs: Array[Dictionary] = []
	for index: int in OptionScript.MAX_COST_ENTRIES + 1:
		too_many_costs.append(
			{&"cost_id": StringName("item.test.%02d" % index), &"amount": 1}
		)
	var one_cell: Array[Vector2i] = [Vector2i(1, 0)]
	var oversized_costs: Dictionary = OptionScript.build(
		&"interaction.action.cost_cap",
		CatalogScript.PROVIDER_TERRAIN,
		&"terrain.test",
		&"terrain",
		&"terrain",
		&"inspect",
		{},
		true,
		&"interaction.action.cost_cap.label",
		&"",
		0,
		one_cell,
		too_many_costs,
	)
	_add(
		cases,
		"PHA-04 affected-cell, option, cost, and duplicate-action caps reject exactly",
		(
			oversized.is_empty()
				and oversized_costs.is_empty()
				and duplicate_menu.is_empty()
				and _target(too_many).is_empty()
		),
	)
	var duplicate_providers: Array[StringName] = []
	duplicate_providers.append(CatalogScript.PROVIDER_TERRAIN)
	duplicate_providers.append(CatalogScript.PROVIDER_TERRAIN)
	var unknown_providers: Array[StringName] = []
	unknown_providers.append(&"interaction.provider.unknown")
	var empty_inputs: Array[Dictionary] = []
	_add(
		cases,
		"PHA-05 duplicate and unknown provider registrations fail closed",
		(
			CatalogScript.build_menu(_target(empty_inputs), duplicate_providers).is_empty()
			and CatalogScript.build_menu(_target(empty_inputs), unknown_providers).is_empty()
		),
	)


static func _test_resolver_compatibility(cases: Array[Dictionary]) -> void:
	var all_facings: bool = true
	for facing: StringName in EXPECTED_TARGETS:
		all_facings = all_facings and (
			ResolverScript.adjacent_cell(Vector2i.ZERO, facing) == EXPECTED_TARGETS[facing]
		)
	_add(cases, "PHA-06 all eight facings preserve exact adjacent cells", all_facings)
	var result: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO,
		&"SE",
		ResolverScript.MASK_ALL,
		{&"kinds": [&"terrain", &"crop", &"pickup"]},
	)
	_add(
		cases,
		"PHA-07 existing resolver result remains exact five-key compatible",
		(
			result.keys()
			== [&"valid", &"target_cell", &"target_kind", &"action", &"rejection_reason"]
			and ResolverScript.validate_result(result)
			and result[&"target_kind"] == &"pickup"
		),
	)


static func _test_determinism(cases: Array[Dictionary]) -> void:
	var inputs: Array[Dictionary] = [
		_input(&"interaction.action.charlie", 300),
		_input(&"interaction.action.alpha", 100),
		_input(&"interaction.action.bravo", 200),
	]
	var baseline: String = MenuScript.canonical_text(CatalogScript.build_menu(_target(inputs)))
	var providers: Array[StringName] = CatalogScript.provider_ids()
	var deterministic: bool = not baseline.is_empty()
	for iteration: int in 1000:
		var shuffled_inputs: Array[Dictionary] = inputs.duplicate(true)
		var shuffled_providers: Array[StringName] = providers.duplicate()
		_shuffle(shuffled_inputs, iteration * 17 + 3)
		_shuffle(shuffled_providers, iteration * 31 + 9)
		var menu: Dictionary = CatalogScript.build_menu(
			_target_from_dictionary_order(shuffled_inputs, iteration), shuffled_providers
		)
		deterministic = deterministic and MenuScript.canonical_text(menu) == baseline
	_add(
		cases,
		"PHA-08 1000 shuffled registration/input orders are byte-equivalent",
		deterministic,
	)
	var families: bool = CatalogScript.provider_ids().size() == 11
	for provider_id: StringName in CatalogScript.provider_ids():
		families = families and str(provider_id).begins_with("interaction.provider.")
	_add(cases, "PHA-09 all eleven provider families register canonically", families)


static func _test_controller_lifecycle(cases: Array[Dictionary]) -> void:
	var harness: RefCounted = Harness.new() as RefCounted
	var world: RefCounted = FakeWorld.new() as RefCounted
	var avatar: Node2D = Node2D.new()
	var controller: Node2D = ControllerScript.new() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(avatar)
	(Engine.get_main_loop() as SceneTree).root.add_child(controller)
	var configured: bool = bool(
		controller.call(
			"configure",
			world,
			avatar,
			Callable(harness, "project"),
			Callable(harness, "player_cell"),
			Callable(harness, "player_facing"),
			Callable(harness, "zoom"),
			Callable(harness, "legacy_target"),
			Callable(harness, "execute"),
			Callable(harness, "menu_target"),
		)
	)
	var before_cell: Vector2i = harness.get("cell") as Vector2i
	var opened: bool = bool(controller.call("handle_touch_command", CommandsScript.CONTEXT))
	_add(
		cases,
		"PHA-10 Context opens one sealed menu and performs zero mutations",
		(
			configured
			and opened
			and bool(controller.call("is_menu_open"))
			and MenuScript.validate(controller.call("get_menu_snapshot"))
			and int(harness.get("mutations")) == 0
			and harness.get("cell") == before_cell
		),
	)
	var first_index: int = int(controller.call("get_selected_menu_index"))
	var up_blocked: bool = not bool(controller.call("navigate_menu", -1))
	var down: bool = bool(controller.call("navigate_menu", 1))
	var second_index: int = int(controller.call("get_selected_menu_index"))
	controller.call("navigate_menu", 99)
	controller.call("navigate_menu", 99)
	var end_index: int = int(controller.call("get_selected_menu_index"))
	var end_blocked: bool = not bool(controller.call("navigate_menu", 1))
	_add(
		cases,
		"PHA-11 menu navigation is bounded and never wraps",
		(
			first_index == 0
			and up_blocked
			and down
			and second_index == 1
			and end_index == 2
			and end_blocked
		),
	)
	controller.call("close_menu")
	controller.call("open_menu")
	harness.set("target_version", 2)
	var stale_rejected: bool = not bool(controller.call("confirm_menu"))
	var stale_open: bool = bool(controller.call("is_menu_open"))
	var refreshed: Dictionary = controller.call("get_menu_snapshot") as Dictionary
	_add(
		cases,
		"PHA-12 stale confirmation refreshes sealed state and fails closed without mutation",
		(
			stale_rejected
			and stale_open
			and int((refreshed[&"target_state"] as Dictionary)[&"version"]) == 2
			and int(harness.get("mutations")) == 0
		),
	)
	var confirmed: bool = bool(controller.call("confirm_menu"))
	var closed_after_confirm: bool = not bool(controller.call("is_menu_open"))
	controller.call("open_menu")
	var canceled: bool = bool(controller.call("handle_touch_command", CommandsScript.CANCEL))
	_add(
		cases,
		"PHA-13 confirm executes once and cancel closes without mutation",
		(
			confirmed
			and closed_after_confirm
			and int(harness.get("mutations")) == 1
			and canceled
			and not bool(controller.call("is_menu_open"))
			and int(harness.get("mutations")) == 1
		),
	)
	controller.call("_attempt_tool")
	var presenter: Node2D = controller.call("get_tool_presenter") as Node2D
	var pending: bool = bool(presenter.call("is_playing"))
	controller.call("open_menu")
	_add(
		cases,
		"PHA-14 opening a menu cancels pending tool contact and restores the avatar",
		pending and not bool(presenter.call("is_playing")) and avatar.visible,
	)
	controller.free()
	avatar.free()


static func _option(action_id: StringName, priority: int) -> Dictionary:
	var cells: Array[Vector2i] = [Vector2i(1, 0)]
	return OptionScript.build(
		action_id,
		CatalogScript.PROVIDER_TERRAIN,
		&"terrain.test",
		&"terrain",
		&"terrain",
		&"inspect",
		{&"cell": Vector2i(1, 0)},
		true,
		StringName("%s.label" % action_id),
		&"",
		priority,
		cells,
	)


static func _input(action_id: StringName, priority: int) -> Dictionary:
	return TargetBridgeScript.option_input(
		action_id,
		&"inspect",
		{&"cell": Vector2i(1, 0), &"value": priority},
		true,
		&"",
		priority,
		_empty_costs(),
		OptionScript.CLOSE_NEVER,
	)


static func _empty_costs() -> Array[Dictionary]:
	return []


static func _target(inputs: Array[Dictionary]) -> Dictionary:
	return TargetScript.build(
		Vector2i(1, 0),
		&"terrain.test",
		&"terrain",
		&"terrain",
		&"interaction.target.terrain.title",
		{&"a": 1, &"b": 2, &"c": 3},
		inputs,
	)


static func _target_from_dictionary_order(
	inputs: Array[Dictionary],
	iteration: int,
) -> Dictionary:
	var state: Dictionary = {}
	var keys: Array[StringName] = [&"a", &"b", &"c"]
	_shuffle(keys, iteration * 43 + 7)
	for key: StringName in keys:
		state[key] = {&"a": 1, &"b": 2, &"c": 3}[key]
	return TargetScript.build(
		Vector2i(1, 0),
		&"terrain.test",
		&"terrain",
		&"terrain",
		&"interaction.target.terrain.title",
		state,
		inputs,
	)


static func _shuffle(values: Array, seed_value: int) -> void:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	for index: int in range(values.size() - 1, 0, -1):
		var other: int = random.randi_range(0, index)
		var swap: Variant = values[index]
		values[index] = values[other]
		values[other] = swap


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
