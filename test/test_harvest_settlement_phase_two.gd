extends RefCounted

const CalendarStateScript: GDScript = preload("res://scripts/calendar_state.gd")
const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const ControllerScript: GDScript = preload("res://scripts/harvest_interaction_controller.gd")
const CrossDomainScript: GDScript = preload("res://scripts/cross_domain_transaction.gd")
const EconomyServiceScript: GDScript = preload("res://scripts/economy_service.gd")
const FarmSaveSchemaScript: GDScript = preload("res://scripts/farm_save_schema.gd")
const FarmStateScript: GDScript = preload("res://scripts/farm_state.gd")
const InventoryServiceScript: GDScript = preload("res://scripts/inventory_service.gd")
const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PolicyScript: GDScript = preload("res://scripts/quick_action_policy.gd")
const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")
const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const TargetBridgeScript: GDScript = preload(
	"res://scripts/harvest_interaction_target_bridge.gd"
)
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")
const ToolServiceScript: GDScript = preload("res://scripts/tool_service.gd")

const LEGACY_DESCRIPTOR_SHA256: String = (
	"c4743995be283237384034dba82290eff12e5dfe6253f9034c9430f666141905"
)
const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1024.0, 576.0),
	Vector2(844.0, 390.0),
	Vector2(720.0, 1280.0),
	Vector2(390.0, 844.0),
]


class QuickHarness:
	extends RefCounted

	var mode: StringName = &"enabled"
	var revision: int = 1
	var mutations: int = 0
	var executes: int = 0
	var terminal_opens: int = 0
	var stale_on_execute: bool = false
	var harvested: bool = false
	var reenter: Callable
	var reentry_result: Dictionary = {}

	func project(value: Vector2i) -> Vector2:
		return Vector2(value * 10)

	func player_cell() -> Vector2i:
		return Vector2i.ZERO

	func player_facing() -> StringName:
		return &"SE"

	func zoom(_direction: int) -> void:
		pass

	func target(_cell: Vector2i) -> Dictionary:
		return {&"kinds": [&"crop"], &"blocked": false, &"tool_damage": false}

	func menu_target(cell: Vector2i) -> Dictionary:
		var enabled: bool = mode != &"disabled" and not harvested
		var no_costs: Array[Dictionary] = []
		var costs: Array[Dictionary] = []
		if mode == &"costly":
			costs.append({&"cost_id": &"item.test", &"amount": 1})
		var inputs: Array[Dictionary] = [
			TargetBridgeScript.option_input(
				&"interaction.action.inspect",
				&"inspect",
				{&"cell": cell},
				true,
				&"",
				0,
				no_costs,
				OptionScript.CLOSE_NEVER,
			),
			TargetBridgeScript.option_input(
				&"interaction.action.harvest",
				&"harvest",
				{&"cell": cell, &"revision": revision},
				enabled,
				&"" if enabled else &"interaction.reason.missing_crop",
				100,
				costs,
			),
		]
		if mode == &"ambiguous":
			inputs.append(
				TargetBridgeScript.option_input(
					&"interaction.action.collect",
					&"world_collect_reward",
					{&"cell": cell, &"revision": revision},
					true,
					&"",
					200,
				)
			)
		return TargetScript.build(
			cell,
			&"crop.quick.test",
			&"crop",
			&"crop",
			&"interaction.target.crop.title",
			{&"revision": revision, &"harvested": harvested},
			inputs,
		)

	func execute(
		_intent: StringName,
		_tool: StringName,
		resolved: Dictionary,
		option: Dictionary = {},
	) -> Dictionary:
		executes += 1
		if reenter.is_valid():
			var nested: Callable = reenter
			reenter = Callable()
			reentry_result = nested.call() as Dictionary
		if stale_on_execute:
			revision += 1
		var current: Dictionary = CatalogScript.build_menu(
			menu_target(resolved[&"target_cell"] as Vector2i)
		)
		var current_option: Dictionary = _option(current, option[&"action_id"] as StringName)
		if current_option != option:
			return {&"ok": false, &"reason": &"stale_target_identity"}
		mutations += 1
		harvested = true
		return {&"ok": true, &"reason": &"harvested", &"mutation_id": mutations}

	func open_terminal() -> bool:
		terminal_opens += 1
		return true

	func state() -> Dictionary:
		return {&"revision": revision, &"mutations": mutations, &"harvested": harvested}

	func _option(menu: Dictionary, action_id: StringName) -> Dictionary:
		for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
			if option[&"action_id"] == action_id:
				return option.duplicate(true)
		return {}


class FakeWorld:
	extends RefCounted


class RepositoryProbe:
	extends RefCounted

	var saves: int = 0
	var pending: Dictionary = {}
	var committed: Dictionary = {}

	func validate_envelope(envelope: Dictionary) -> Dictionary:
		var candidate: Dictionary = envelope.duplicate(true)
		var farm: Dictionary = FarmSaveSchemaScript.validate(candidate.get(&"farm", {}))
		if farm.is_empty():
			return {}
		candidate[&"farm"] = farm
		pending = candidate.duplicate(true)
		return candidate

	func save_state(
		world: Dictionary,
		active_run: Variant,
		profile: Dictionary,
		farm: Dictionary,
	) -> bool:
		saves += 1
		committed = pending.duplicate(true)
		committed[&"world"] = world.duplicate(true)
		committed[&"active_run"] = (
			active_run.duplicate(true) if active_run is Dictionary else active_run
		)
		committed[&"profile"] = profile.duplicate(true)
		committed[&"farm"] = farm.duplicate(true)
		(committed[&"metadata"] as Dictionary)[&"write_sequence"] = saves
		return true

	func get_last_committed_envelope() -> Dictionary:
		return committed.duplicate(true)


class PublisherProbe:
	extends RefCounted

	var calls: int = 0
	var current: Dictionary = {}
	var fail_once: bool = false

	func publish(envelope: Dictionary) -> bool:
		calls += 1
		if fail_once:
			fail_once = false
			return false
		current = envelope.duplicate(true)
		return true


static func evaluate(runtime: Node2D = null) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_input_contract(cases)
	_test_policy(cases)
	_test_controller_execution(cases)
	_test_fallbacks(cases)
	_test_reentry_and_modality_parity(cases)
	_test_mobile_dock(cases)
	_test_atomic_receipts(cases)
	if runtime != null:
		_test_live_integration(cases, runtime)
	return cases


static func _test_input_contract(cases: Array[Dictionary]) -> void:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	var legacy: Array[Dictionary] = []
	for action: StringName in CommandsScript.action_ids():
		if action == CommandsScript.QUICK_ACTION:
			continue
		legacy.append({&"action": action, &"descriptors": CommandsScript.descriptors_for(action)})
	context.update(var_to_bytes(legacy))
	_add(
		cases,
		"P2-01 legacy descriptors remain byte-stable after adding Quick",
		context.finish().hex_encode() == LEGACY_DESCRIPTOR_SHA256,
	)
	var descriptors: Dictionary = CommandsScript.descriptors_for(CommandsScript.QUICK_ACTION)
	var keyboard: Dictionary = (descriptors[&"keyboard"] as Array)[0] as Dictionary
	var controller: Dictionary = (descriptors[&"controller"] as Array)[0] as Dictionary
	var touch: Dictionary = (descriptors[&"touch"] as Array)[0] as Dictionary
	_add(
		cases,
		"P2-02 Quick is collision-free on G, controller left trigger, and touch slot eight",
		CommandsScript.validate_defaults()
		and int(keyboard[&"code"]) == KEY_G
		and int(controller[&"code"]) == JOY_AXIS_TRIGGER_LEFT
		and float(controller[&"value"]) == 1.0
		and touch[&"control"] == &"quick_action_button",
	)
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/harvest_interaction_controller.gd"
	)
	_add(
		cases,
		"P2-03 keyboard/controller Quick uses edge-trigger dispatch and never tool hold-repeat",
		"CommandsScript.is_just_pressed(action)" in source
		and "CommandsScript.is_pressed(CommandsScript.QUICK_ACTION)" not in source,
	)


static func _test_policy(cases: Array[Dictionary]) -> void:
	var allowed: Dictionary = {
		&"interaction.action.harvest": &"harvest",
		&"interaction.action.machine_claim": &"craft_claim",
		&"interaction.action.animal_product": &"animal_product",
		&"interaction.action.collect": &"world_collect_reward",
	}
	var all_allowed: bool = true
	for action: StringName in allowed:
		all_allowed = all_allowed and PolicyScript.is_low_risk(
			_option(action, allowed[action] as StringName, true)
		)
	_add(cases, "P2-04 the initial allowlist contains only collect/harvest/claim actions", all_allowed)
	var blocked: Array[StringName] = [
		&"gift", &"ship", &"sleep", &"upgrade", &"construction_place",
		&"applicant_invite", &"worker_assign",
	]
	var all_blocked: bool = true
	for operation: StringName in blocked:
		all_blocked = all_blocked and not PolicyScript.is_low_risk(
			_option(StringName("interaction.action.%s" % operation), operation, true)
		)
	all_blocked = all_blocked and not PolicyScript.is_low_risk(
		_option(&"interaction.action.harvest", &"harvest", true, true)
	)
	_add(
		cases,
		"P2-05 costly, irreversible, applicant, assignment, and construction choices are rejected",
		all_blocked,
	)
	var harness: QuickHarness = QuickHarness.new()
	var menu: Dictionary = CatalogScript.build_menu(harness.menu_target(Vector2i(1, 0)))
	var decision: Dictionary = PolicyScript.decide(menu)
	_add(
		cases,
		"P2-06 one uniquely enabled low-risk option returns its exact sealed dictionary",
		decision[&"decision"] == PolicyScript.EXECUTE
		and decision[&"option"] == _menu_option(menu, &"interaction.action.harvest"),
	)


static func _test_controller_execution(cases: Array[Dictionary]) -> void:
	var harness: QuickHarness = QuickHarness.new()
	var setup: Dictionary = _controller(harness)
	var controller: Node2D = setup[&"controller"] as Node2D
	var results: Array[Dictionary] = []
	controller.connect("quick_action_result", func(result: Dictionary) -> void: results.append(result))
	var result: Dictionary = controller.call("attempt_quick_action") as Dictionary
	_add(
		cases,
		"P2-07 one Quick press executes one sealed option through one mutation boundary",
		result[&"result_id"] == &"quick.executed"
		and bool(result[&"mutated"])
		and harness.executes == 1
		and harness.mutations == 1
		and results.size() == 1,
	)
	var duplicate: Dictionary = controller.call("attempt_quick_action") as Dictionary
	_add(
		cases,
		"P2-08 a second press after state change cannot duplicate the mutation",
		duplicate[&"result_id"] == &"quick.terminal_opened"
		and harness.executes == 1
		and harness.mutations == 1
		and controller.call("is_menu_open"),
	)
	_free_controller(setup)


static func _test_fallbacks(cases: Array[Dictionary]) -> void:
	for mode: StringName in [&"disabled", &"ambiguous", &"costly"]:
		var harness: QuickHarness = QuickHarness.new()
		harness.mode = mode
		var setup: Dictionary = _controller(harness)
		var controller: Node2D = setup[&"controller"] as Node2D
		var result: Dictionary = controller.call("attempt_quick_action") as Dictionary
		_add(
			cases,
			"P2-09 %s Quick opens the terminal with zero writes" % mode,
			result[&"result_id"] == &"quick.terminal_opened"
			and harness.executes == 0
			and harness.mutations == 0
			and controller.call("is_menu_open"),
		)
		_free_controller(setup)
	var stale: QuickHarness = QuickHarness.new()
	stale.stale_on_execute = true
	var stale_setup: Dictionary = _controller(stale)
	var stale_controller: Node2D = stale_setup[&"controller"] as Node2D
	var stale_result: Dictionary = stale_controller.call("attempt_quick_action") as Dictionary
	_add(
		cases,
		"P2-10 changed exact option identity writes nothing and opens the refreshed terminal",
		stale_result[&"result_id"] == &"quick.terminal_opened"
		and stale_result[&"reason"] == &"stale_target_identity"
		and stale.executes == 1
		and stale.mutations == 0
		and stale_controller.call("is_menu_open"),
	)
	_free_controller(stale_setup)


static func _test_reentry_and_modality_parity(cases: Array[Dictionary]) -> void:
	var reentrant: QuickHarness = QuickHarness.new()
	var reentry_setup: Dictionary = _controller(reentrant)
	var reentry_controller: Node2D = reentry_setup[&"controller"] as Node2D
	reentrant.reenter = Callable(reentry_controller, "attempt_quick_action")
	var outer: Dictionary = reentry_controller.call("attempt_quick_action") as Dictionary
	_add(
		cases,
		"P2-11 synchronous re-entry is busy and cannot publish a second mutation",
		outer[&"result_id"] == &"quick.executed"
		and reentrant.reentry_result[&"result_id"] == &"quick.busy"
		and reentrant.executes == 1
		and reentrant.mutations == 1,
	)
	_free_controller(reentry_setup)
	var result_ids: Array[StringName] = []
	var states: Array[Dictionary] = []
	for modality: StringName in [&"keyboard", &"controller", &"touch"]:
		var harness: QuickHarness = QuickHarness.new()
		var setup: Dictionary = _controller(harness)
		var controller: Node2D = setup[&"controller"] as Node2D
		var results: Array[Dictionary] = []
		controller.connect("quick_action_result", func(value: Dictionary) -> void: results.append(value))
		if modality == &"touch":
			controller.call("handle_touch_command", CommandsScript.QUICK_ACTION)
		else:
			controller.call("_dispatch", CommandsScript.QUICK_ACTION)
		result_ids.append(results[0][&"result_id"] as StringName)
		states.append(harness.state())
		_free_controller(setup)
	_add(
		cases,
		"P2-12 keyboard, controller, and touch produce equal result IDs and canonical state",
		result_ids == [&"quick.executed", &"quick.executed", &"quick.executed"]
		and states[0] == states[1]
		and states[1] == states[2],
	)
	var modal: QuickHarness = QuickHarness.new()
	var modal_setup: Dictionary = _controller(modal)
	var modal_controller: Node2D = modal_setup[&"controller"] as Node2D
	modal_controller.call("open_menu")
	var consumed: bool = bool(
		modal_controller.call("handle_touch_command", CommandsScript.QUICK_ACTION)
	)
	_add(
		cases,
		"P2-13 an open terminal consumes Quick without hidden execution",
		consumed and modal.executes == 0 and modal.mutations == 0,
	)
	_free_controller(modal_setup)


static func _test_mobile_dock(cases: Array[Dictionary]) -> void:
	var valid_all: bool = true
	for viewport: Vector2 in VIEWPORTS:
		for left_handed: bool in [false, true]:
			var mobile: CanvasLayer = MobileControlsScript.new() as CanvasLayer
			(Engine.get_main_loop() as SceneTree).root.add_child(mobile)
			mobile.call("force_mobile", true)
			mobile.call(
				"_apply_preferences",
				{&"left_handed": left_handed, &"haptics": true, &"haptic_intensity": 1.0},
			)
			valid_all = valid_all and bool(mobile.call("apply_layout", viewport))
			var buttons: Dictionary = mobile.get("_command_buttons") as Dictionary
			var dock: Control = mobile.get("_command_dock") as Control
			var dock_bounds: Rect2 = mobile.call("_get_command_dock_bounds") as Rect2
			var exclusions: Array[Rect2] = mobile.call("get_touch_exclusions") as Array[Rect2]
			var portrait: bool = viewport.y > viewport.x
			var zoom_x: float = viewport.x * 0.5 - 94.0
			if portrait:
				zoom_x = viewport.x - 198.0 if left_handed else 10.0
			var zoom: Rect2 = Rect2(
				Vector2(zoom_x, viewport.y - (232.0 if portrait else 76.0)),
				Vector2(188.0, 52.0),
			)
			var smash: Rect2 = (mobile.call("get_layout_snapshot") as Dictionary)[&"smash_button"]
			var rects: Array[Rect2] = []
			for action: Variant in buttons:
				var button: Button = buttons[action] as Button
				var rect: Rect2 = Rect2(dock.position + button.position, button.size)
				valid_all = valid_all and Rect2(Vector2.ZERO, viewport).encloses(rect)
				valid_all = valid_all and not rect.intersects(smash)
				for prior: Rect2 in rects:
					valid_all = valid_all and not rect.intersects(prior)
				rects.append(rect)
			valid_all = valid_all and buttons.size() == 8
			valid_all = valid_all and CommandsScript.QUICK_ACTION in buttons
			valid_all = valid_all and dock_bounds in exclusions
			valid_all = valid_all and zoom in exclusions and not dock_bounds.intersects(zoom)
			valid_all = valid_all and not zoom.intersects(smash)
			mobile.free()
	_add(
		cases,
		"P2-14 eight touch slots avoid Smash and zoom controls in all five viewports",
		valid_all,
	)
	var touch: CanvasLayer = MobileControlsScript.new() as CanvasLayer
	(Engine.get_main_loop() as SceneTree).root.add_child(touch)
	touch.call("force_mobile", true)
	var events: Array[StringName] = []
	touch.connect("command_pressed", func(action: StringName) -> void: events.append(action))
	touch.call("trigger_command", CommandsScript.QUICK_ACTION)
	_add(
		cases,
		"P2-15 one touch tap emits one Quick command",
		events == [CommandsScript.QUICK_ACTION],
	)
	touch.free()


static func _test_atomic_receipts(cases: Array[Dictionary]) -> void:
	var cells: Array[Vector2i] = [Vector2i(10, 7), Vector2i(11, 7)]
	var farm: Dictionary = _mature_farm(cells)
	var source: Dictionary = {
		&"save_format_version": 5,
		&"metadata": {&"write_sequence": 0},
		&"world": {},
		&"active_run": null,
		&"profile": {},
		&"farm": farm,
	}
	var repository: RepositoryProbe = RepositoryProbe.new()
	var publisher: PublisherProbe = PublisherProbe.new()
	var transaction: RefCounted = CrossDomainScript.new() as RefCounted
	var configured: bool = bool(
		transaction.call(
			"configure",
			source,
			repository,
			repository,
			Callable(publisher, "publish"),
			77,
		)
	)
	var payload: Dictionary = {
		&"action_id": "interaction.action.harvest",
		&"operation": "harvest",
		&"option_digest": "a".repeat(64),
		&"source_revision": 0,
	}
	var deterministic: Dictionary = {
		&"result_id": "quick.result.atomic-a",
		&"action_id": "interaction.action.harvest",
		&"operation": "harvest",
		&"source_revision": 0,
	}
	var before: int = InventoryServiceScript.count_all(farm, &"item.produce.glowroot")
	var first: Dictionary = transaction.call(
		"transact_exact_once",
		&"harvest",
		{&"cell": cells[0]},
		"quick:0:atomic-a",
		payload,
		deterministic,
	) as Dictionary
	var first_farm: Dictionary = (first[&"candidate"] as Dictionary)[&"farm"] as Dictionary
	var after_first: int = InventoryServiceScript.count_all(
		first_farm, &"item.produce.glowroot"
	)
	_add(
		cases,
		"P2-17 gameplay mutation and Quick receipt share one save and one publish",
		configured
		and bool(first[&"ok"])
		and not bool(first[&"replayed"])
		and repository.saves == 1
		and publisher.calls == 1
		and after_first > before
		and ((first_farm[&"receipts"] as Dictionary)[&"entries"] as Array).size() == 1
		and transaction.call("get_snapshot") == repository.committed
		and publisher.current == repository.committed,
	)
	var replay: Dictionary = transaction.call(
		"transact_exact_once",
		&"harvest",
		{&"cell": cells[0]},
		"quick:0:atomic-a",
		payload,
		deterministic,
	) as Dictionary
	var conflict_payload: Dictionary = payload.duplicate(true)
	conflict_payload[&"option_digest"] = "b".repeat(64)
	var conflict: Dictionary = transaction.call(
		"transact_exact_once",
		&"harvest",
		{&"cell": cells[0]},
		"quick:0:atomic-a",
		conflict_payload,
		deterministic,
	) as Dictionary
	_add(
		cases,
		"P2-18 receipt replay and conflict perform zero additional saves or publishes",
		bool(replay[&"ok"])
		and bool(replay[&"replayed"])
		and replay[&"receipt_result"] == deterministic
		and not bool(conflict[&"ok"])
		and conflict[&"receipt_status"] == &"conflict"
		and repository.saves == 1
		and publisher.calls == 1,
	)
	var second_payload: Dictionary = payload.duplicate(true)
	second_payload[&"option_digest"] = "c".repeat(64)
	second_payload[&"source_revision"] = 1
	var second_result: Dictionary = deterministic.duplicate(true)
	second_result[&"result_id"] = "quick.result.atomic-b"
	second_result[&"source_revision"] = 1
	var second: Dictionary = transaction.call(
		"transact_exact_once",
		&"harvest",
		{&"cell": cells[1]},
		"quick:1:atomic-b",
		second_payload,
		second_result,
	) as Dictionary
	var second_farm: Dictionary = (second[&"candidate"] as Dictionary)[&"farm"] as Dictionary
	_add(
		cases,
		"P2-19 sequential Quick commits adopt the repository-committed envelope",
		bool(second[&"ok"])
		and repository.saves == 2
		and publisher.calls == 2
		and int((second[&"candidate"] as Dictionary)[&"metadata"][&"write_sequence"]) == 2
		and ((second_farm[&"receipts"] as Dictionary)[&"entries"] as Array).size() == 2
		and InventoryServiceScript.count_all(second_farm, &"item.produce.glowroot") > after_first,
	)
	var rollback_repository: RepositoryProbe = RepositoryProbe.new()
	var rollback_publisher: PublisherProbe = PublisherProbe.new()
	rollback_publisher.fail_once = true
	var rollback: RefCounted = CrossDomainScript.new() as RefCounted
	rollback.call(
		"configure",
		source,
		rollback_repository,
		rollback_repository,
		Callable(rollback_publisher, "publish"),
		77,
	)
	var failed: Dictionary = rollback.call(
		"transact", &"harvest", {&"cell": cells[0]}
	) as Dictionary
	_add(
		cases,
		"P2-20 publish failure compensates to complete source gameplay and committed revision",
		not bool(failed[&"ok"])
		and failed[&"reason"] == &"publish_failed"
		and rollback_repository.saves == 2
		and rollback_publisher.calls == 2
		and rollback.call("get_snapshot") == rollback_repository.committed
		and (rollback_repository.committed[&"farm"] as Dictionary) == farm,
	)


static func _test_live_integration(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var controller: Node = (
		bridge.call("get_interaction_controller") as Node if bridge != null else null
	)
	var mobile: CanvasLayer = runtime.get("_mobile_controls") as CanvasLayer
	var buttons: Dictionary = (
		mobile.get("_command_buttons") as Dictionary if mobile != null else {}
	)
	_add(
		cases,
		"P2-16 live bridge owns one configured coordinator and the eighth touch slot",
		bridge != null
		and controller != null
		and controller.call("get_quick_action_coordinator") != null
		and CommandsScript.QUICK_ACTION in buttons,
	)
	var boundary: RefCounted = bridge.call("get_transaction_boundary") as RefCounted
	var farm_runtime: RefCounted = bridge.call("get_farm_runtime") as RefCounted
	if boundary == null or farm_runtime == null:
		_add(
			cases,
			"P2-21 legacy expedition maps omit the fresh-farm transaction boundary safely",
			true,
		)
		return
	var source: Dictionary = boundary.call("get_snapshot") as Dictionary
	var source_revision: int = int(
		((source[&"farm"] as Dictionary)[&"revisions"] as Dictionary)[&"result_revision"]
	)
	var candidate_farm: Dictionary = (source[&"farm"] as Dictionary).duplicate(true)
	(candidate_farm[&"economy"] as Dictionary)[&"money"] += 1
	candidate_farm = FarmSaveSchemaScript.validate(candidate_farm)
	var original_publish: Callable = boundary.get("_publish")
	var publisher: PublisherProbe = PublisherProbe.new()
	publisher.fail_once = true
	boundary.set("_publish", Callable(publisher, "publish"))
	var failed: Dictionary = boundary.call(
		"transact", &"farm_candidate", {&"farm": candidate_farm}
	) as Dictionary
	boundary.set("_publish", original_publish)
	var restored: Dictionary = boundary.call("get_snapshot") as Dictionary
	var restored_farm: Dictionary = restored[&"farm"] as Dictionary
	farm_runtime.call("sync_committed", restored_farm)
	var restored_revision: int = int(
		(restored_farm[&"revisions"] as Dictionary)[&"result_revision"]
	)
	_add(
		cases,
		"P2-21 real repository compensation restores gameplay with a continuous revision",
		not bool(failed[&"ok"])
		and failed[&"reason"] == &"publish_failed"
		and publisher.calls == 2
		and restored_revision == source_revision + 2
		and _same_gameplay(source, restored),
	)


static func _controller(harness: QuickHarness) -> Dictionary:
	var avatar: Node2D = Node2D.new()
	var controller: Node2D = ControllerScript.new() as Node2D
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.root.add_child(avatar)
	tree.root.add_child(controller)
	var configured: bool = bool(
		controller.call(
			"configure",
			FakeWorld.new(),
			avatar,
			Callable(harness, "project"),
			Callable(harness, "player_cell"),
			Callable(harness, "player_facing"),
			Callable(harness, "zoom"),
			Callable(harness, "target"),
			Callable(harness, "execute"),
			Callable(harness, "menu_target"),
		)
	)
	return {&"controller": controller, &"avatar": avatar, &"configured": configured}


static func _free_controller(setup: Dictionary) -> void:
	(setup[&"controller"] as Node2D).free()
	(setup[&"avatar"] as Node2D).free()


static func _option(
	action_id: StringName,
	operation: StringName,
	enabled: bool,
	costly: bool = false,
) -> Dictionary:
	var costs: Array[Dictionary] = []
	if costly:
		costs.append({&"cost_id": &"item.test", &"amount": 1})
	var cells: Array[Vector2i] = [Vector2i(1, 0)]
	return OptionScript.build(
		action_id,
		&"interaction.provider.test",
		&"target.test",
		&"crop",
		&"crop",
		operation,
		{&"cell": Vector2i(1, 0)},
		enabled,
		action_id,
		&"" if enabled else &"reason.disabled",
		100,
		cells,
		costs,
	)


static func _mature_farm(cells: Array[Vector2i]) -> Dictionary:
	var farm: Dictionary = FarmSaveSchemaScript.make_neutral(RuntimeIdsScript.MODE_FRESH_FARM)
	farm = InventoryServiceScript.ensure_default(farm)
	farm = CalendarStateScript.ensure_default(farm, 77)
	farm = ToolServiceScript.ensure_default(farm)
	farm = EconomyServiceScript.ensure_default(farm)
	for cell: Vector2i in cells:
		farm = FarmStateScript.till(farm, cell)[&"candidate"]
		farm = FarmStateScript.plant(farm, cell, &"item.seed.glowroot", 1)[&"candidate"]
	for day: int in range(1, 4):
		farm = FarmStateScript.apply_rain(farm, day)
		farm = FarmStateScript.grow(farm, day)
	return FarmSaveSchemaScript.validate(farm)


static func _menu_option(menu: Dictionary, action_id: StringName) -> Dictionary:
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option.duplicate(true)
	return {}


static func _same_gameplay(first: Dictionary, second: Dictionary) -> bool:
	var first_copy: Dictionary = first.duplicate(true)
	var second_copy: Dictionary = second.duplicate(true)
	(first_copy[&"farm"] as Dictionary)[&"revisions"] = StateHashScript.make_neutral_revisions()
	(second_copy[&"farm"] as Dictionary)[&"revisions"] = StateHashScript.make_neutral_revisions()
	return StateHashScript.state_hash(first_copy) == StateHashScript.state_hash(second_copy)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
