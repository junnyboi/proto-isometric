extends RefCounted

const ActionPresentationScript: GDScript = preload(
	"res://scripts/interaction_action_presentation_catalog.gd"
)
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const CoordinatorScript: GDScript = preload("res://scripts/interaction_dossier_coordinator.gd")
const DossierStateScript: GDScript = preload("res://scripts/interaction_dossier_state.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const HistoryScript: GDScript = preload("res://scripts/interaction_session_history.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PreviewScript: GDScript = preload("res://scripts/interaction_outcome_preview_catalog.gd")
const ProjectionScript: GDScript = preload("res://scripts/interaction_dossier_projection.gd")
const ToastScript: GDScript = preload("res://scripts/interaction_result_toast_projection.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_projection_contract(cases)
	_test_truth_whitelist(cases)
	_test_water_and_facility(cases)
	_test_result_whitelist(cases)
	_test_determinism(cases)
	_test_state_contract(cases)
	_test_action_presentation(cases)
	_test_preview(cases)
	_test_toast(cases)
	_test_history(cases)
	_test_coordinator(cases)
	return cases


static func _test_projection_contract(cases: Array[Dictionary]) -> void:
	var menu: Dictionary = _terrain_menu()
	var projection: Dictionary = ProjectionScript.project(menu)
	var sections: Array = projection.get(&"summary_sections", []) as Array
	var exact_rows: bool = not sections.is_empty()
	for section: Dictionary in sections:
		exact_rows = exact_rows and section.keys() == DossierStateScript.SECTION_KEYS
		for row: Dictionary in section[&"rows"] as Array[Dictionary]:
			exact_rows = exact_rows and row.keys() == DossierStateScript.ROW_KEYS
	_add(
		cases,
		"DOS-01 projection exposes exact bounded identity, section, row, chip, and action schemas",
		(
			ProjectionScript.validate(projection)
			and projection.keys() == ProjectionScript.PROJECTION_KEYS
			and projection[&"source_snapshot_id"] == menu[&"snapshot_id"]
			and projection[&"target_cell"] == Vector2i(4, 7)
			and projection[&"profile"] == &"terrain"
			and (projection[&"chips"] as Array).size() == 3
			and (projection[&"action_ids"] as Array).size() == 3
			and exact_rows
		),
	)
	var action_ids: Array = projection[&"action_ids"] as Array
	_add(
		cases,
		"DOS-02 action order is copied exactly from the canonical signed menu snapshot",
		action_ids == [
			&"interaction.action.inspect",
			&"interaction.action.till",
			&"interaction.action.water",
		],
	)


static func _test_truth_whitelist(cases: Array[Dictionary]) -> void:
	var state: Dictionary = _terrain_state()
	state[&"health"] = 87
	state[&"ecology"] = 73
	state[&"soil"] = &"rich"
	state[&"moisture_percent"] = 44
	state[&"canopy_maturity"] = 92
	state[&"resource_yield"] = 12
	state[&"buildable"] = true
	state[&"weather_effect"] = &"rain_bonus"
	var projection: Dictionary = ProjectionScript.project(_terrain_menu(state))
	var text: String = CodecScript.text(projection)
	_add(
		cases,
		"DOS-03 terrain emits only cell, biome, surface, and canonical condition truth",
		(
			text.contains("woodland_grass")
			and text.contains("farmable")
			and not text.contains("health")
			and not text.contains("ecology")
			and not text.contains("soil")
			and not text.contains("moisture_percent")
			and not text.contains("canopy_maturity")
			and not text.contains("resource_yield")
			and not text.contains("buildable")
			and not text.contains("weather_effect")
		),
	)
	var generic_menu: Dictionary = _menu(
		&"mystery",
		&"structure",
		&"unknown_device",
		{
			&"secret_value": &"raw_state_leak",
			&"fault": &"broken_rotor",
			&"blueprint": &"pump_mk_ii",
		},
		[_option(&"inspect", &"inspect")],
	)
	var generic: Dictionary = ProjectionScript.project(generic_menu)
	_add(
		cases,
		"DOS-04 unknown targets remain generic identity records and never dump raw state",
		(
			generic[&"profile"] == &"generic"
			and (generic[&"summary_sections"] as Array).size() == 1
			and not CodecScript.text(generic).contains("raw_state_leak")
			and not CodecScript.text(generic).contains("broken_rotor")
			and not CodecScript.text(generic).contains("pump_mk_ii")
		),
	)


static func _test_water_and_facility(cases: Array[Dictionary]) -> void:
	var water_state: Dictionary = {
		&"water_class": &"freshwater_pond",
		&"walkable": false,
		&"irrigation_relevant": true,
		&"depth": 8.5,
		&"quality": &"clean",
		&"habitat_abundance": 90,
		&"irrigation_radius": 6,
		&"safe_traversal": true,
	}
	var water: Dictionary = ProjectionScript.project(_water_menu(water_state))
	var water_text: String = CodecScript.text(water)
	_add(
		cases,
		"DOS-05 water reports only class, walkability, and irrigation relevance",
		(
			water_text.contains("freshwater_pond")
			and water_text.contains("irrigation_relevant")
			and not water_text.contains("depth")
			and not water_text.contains("quality")
			and not water_text.contains("habitat_abundance")
			and not water_text.contains("irrigation_radius")
			and not water_text.contains("safe_traversal")
		),
	)
	var water_actions: Array = water[&"action_ids"] as Array
	_add(
		cases,
		"DOS-06 water copies provider-emitted fishing actions and synthesizes no concept action",
		(
			water_actions == [
				&"interaction.action.inspect",
				&"interaction.action.fish_cast",
				&"interaction.action.fish_cast_bait",
			]
			and not CodecScript.text(water_actions).contains("sample_water")
			and not CodecScript.text(water_actions).contains("fill_tool")
			and not CodecScript.text(water_actions).contains("place_pump")
			and not CodecScript.text(water_actions).contains("waypoint")
		),
	)
	var facility_state: Dictionary = {
		&"repaired": false,
		&"powered": false,
		&"integrity_percent": 35,
		&"repair_stage": 2,
		&"network": &"offline",
		&"output_per_day": 10,
		&"ownership": &"player",
		&"maintenance_age": 42,
		&"fault": &"clogged_intake",
		&"blueprint": &"irrigation_machine",
	}
	var facility: Dictionary = ProjectionScript.project(_facility_menu(facility_state))
	var facility_text: String = CodecScript.text(facility)
	_add(
		cases,
		"DOS-07 facility summary allows repaired and powered only, omitting concept telemetry",
		(
			facility_text.contains("repaired")
			and facility_text.contains("powered")
			and not facility_text.contains("integrity_percent")
			and not facility_text.contains("repair_stage")
			and not facility_text.contains("network")
			and not facility_text.contains("output_per_day")
			and not facility_text.contains("ownership")
			and not facility_text.contains("maintenance_age")
			and not facility_text.contains("fault")
			and not facility_text.contains("blueprint")
		),
	)


static func _test_result_whitelist(cases: Array[Dictionary]) -> void:
	var menu: Dictionary = _facility_menu({&"repaired": true, &"powered": false})
	var result: Dictionary = _result(
		menu,
		&"interaction.action.inspect",
		true,
		false,
		&"",
		[
			_fact(&"interaction.inspect.fact.repaired", &"boolean", true),
			_fact(&"interaction.inspect.fact.health", &"integer", 35),
			_fact(&"interaction.inspect.fact.state", &"identifier", &"fault.clogged"),
		],
	)
	var projection: Dictionary = ProjectionScript.project(menu, result)
	var text: String = CodecScript.text(projection)
	_add(
		cases,
		"DOS-08 current result facts use a target-specific whitelist, not a global fact dump",
		(
			text.contains("repaired")
			and not text.contains("fault.clogged")
			and not text.contains("fact.health")
		),
	)
	var stale_menu: Dictionary = _facility_menu({&"repaired": false, &"powered": true})
	var stale_projection: Dictionary = ProjectionScript.project(stale_menu, result)
	_add(
		cases,
		"DOS-09 stale or target-mismatched execution results cannot enter the projection",
		not CodecScript.text(stale_projection).contains("interaction.dossier.section.inspection"),
	)


static func _test_determinism(cases: Array[Dictionary]) -> void:
	var canonical: Dictionary = ProjectionScript.project(_terrain_menu())
	var expected: String = CodecScript.digest(canonical)
	var stable: bool = true
	for index: int in 1000:
		var state_pairs: Array[Array] = [
			[&"walkable", true],
			[&"farmable", true],
			[&"surface_id", &"woodland_grass"],
			[&"plot", {}],
			[&"blocked", false],
			[&"biome_id", &"woodland"],
		]
		state_pairs.shuffle()
		var shuffled_state: Dictionary = {}
		for pair: Array in state_pairs:
			shuffled_state[pair[0]] = pair[1]
		var menu: Dictionary = _terrain_menu(shuffled_state)
		stable = stable and CodecScript.digest(ProjectionScript.project(menu)) == expected
		if not stable:
			break
	_add(
		cases,
		"DOS-10 1,000 shuffled dictionary insertion orders preserve projection determinism",
		stable,
	)


static func _test_state_contract(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = CoordinatorScript.new()
	coordinator.call("set_snapshot", _terrain_menu())
	var state: Dictionary = coordinator.call("compose") as Dictionary
	_add(
		cases,
		"DOS-11 composed dossier state has exact top-level schema and deterministic digest",
		(
			DossierStateScript.validate(state)
			and state.keys() == DossierStateScript.KEYS
			and state[&"state_id"] == DossierStateScript.digest(state)
		),
	)
	var changed: Dictionary = state.duplicate(true)
	changed[&"target_cell"] = Vector2i(99, 99)
	var extra: Dictionary = state.duplicate(true)
	extra[&"raw_state"] = {}
	_add(
		cases,
		"DOS-12 state digest tampering and decorative extra keys fail closed",
		not DossierStateScript.validate(changed) and not DossierStateScript.validate(extra),
	)
	var exposed: Dictionary = DossierStateScript.canonical_copy(state)
	((exposed[&"summary_sections"] as Array)[0] as Dictionary)[&"rows"] = []
	_add(
		cases,
		"DOS-13 canonical state copies are deeply isolated from caller mutation",
		DossierStateScript.validate(state) and not exposed == state,
	)
	var too_many_chips: Dictionary = state.duplicate(true)
	(too_many_chips[&"chips"] as Array).append_array((too_many_chips[&"chips"] as Array).duplicate())
	_add(
		cases,
		"DOS-14 state validators enforce four-chip, twelve-row, and exact nested budgets",
		not DossierStateScript.validate(too_many_chips),
	)


static func _test_action_presentation(cases: Array[Dictionary]) -> void:
	var menu: Dictionary = _facility_menu({&"repaired": false, &"powered": false})
	var repair: Dictionary = _find_option(menu, &"interaction.action.facility_repair")
	var descriptor: Dictionary = _descriptor(repair)
	var presentation: Dictionary = ActionPresentationScript.for_option(repair, descriptor)
	_add(
		cases,
		"DOS-15 action presentation metadata is exact and contains no authority fields",
		(
			ActionPresentationScript.validate(presentation)
			and presentation.keys() == ActionPresentationScript.KEYS
			and not presentation.has(&"enabled")
			and not presentation.has(&"reason_key")
			and not presentation.has(&"cost_preview")
			and not presentation.has(&"arguments")
			and not presentation.has(&"provider_id")
			and not presentation.has(&"operation")
		),
	)
	var unknown_menu: Dictionary = _menu(
		&"unknown:1,1",
		&"terrain",
		&"terrain",
		_terrain_state(),
		[_option(&"unknown_card", &"inspect", true, &"", 0, [], &"never")],
	)
	var unknown: Dictionary = _find_option(
		unknown_menu,
		&"interaction.action.unknown_card",
	)
	var unknown_presentation: Dictionary = ActionPresentationScript.for_option(
		unknown,
		_descriptor(unknown),
	)
	_add(
		cases,
		"DOS-16 unknown actions use the localized neutral procedural fallback",
		unknown_presentation == ActionPresentationScript.FALLBACK,
	)


static func _test_preview(cases: Array[Dictionary]) -> void:
	var menu: Dictionary = _facility_menu({&"repaired": false, &"powered": false})
	var repair: Dictionary = _find_option(menu, &"interaction.action.facility_repair")
	var preview: Dictionary = PreviewScript.build(menu, repair, _descriptor(repair))
	_add(
		cases,
		"DOS-17 preview copies exact sealed costs, affected cells, enabled state, and reason",
		(
			PreviewScript.validate(preview)
			and preview.keys() == PreviewScript.KEYS
			and preview[&"costs"] == repair[&"cost_preview"]
			and preview[&"affected_cells"] == repair[&"affected_cells"]
			and preview[&"enabled"] == repair[&"enabled"]
			and preview[&"reason_key"] == repair[&"reason_key"]
		),
	)
	var exposed: Dictionary = PreviewScript.canonical_copy(preview)
	(exposed[&"costs"] as Array).clear()
	_add(
		cases,
		"DOS-18 preview copies are isolated and contain no option arguments or candidate state",
		(
			not (preview[&"costs"] as Array).is_empty()
			and not preview.has(&"arguments")
			and not preview.has(&"candidate")
			and not preview.has(&"inventory")
			and not preview.has(&"reward")
		),
	)
	var changed: Dictionary = repair.duplicate(true)
	changed[&"reason_key"] = &"interaction.reason.changed"
	_add(
		cases,
		"DOS-19 preview staleness binds both source snapshot and option fingerprint",
		(
			PreviewScript.is_current(preview, menu, repair)
			and not PreviewScript.is_current(preview, menu, changed)
		),
	)
	var inspect: Dictionary = _find_option(menu, &"interaction.action.inspect")
	var inspect_preview: Dictionary = PreviewScript.build(menu, inspect, _descriptor(inspect))
	_add(
		cases,
		"DOS-20 effect rows are closed descriptor facts and mutation previews claim no effect",
		(
			(inspect_preview[&"effect_rows"] as Array).size() == 1
			and (inspect_preview[&"effect_rows"] as Array)[0][&"value_kind"] == &"text_key"
			and (
				(inspect_preview[&"effect_rows"] as Array)[0][&"value"]
				== &"interaction.effect.value.read_only"
			)
			and (preview[&"effect_rows"] as Array).is_empty()
		),
	)


static func _test_toast(cases: Array[Dictionary]) -> void:
	var menu: Dictionary = _terrain_menu()
	var success: Dictionary = _result(
		menu,
		&"interaction.action.till",
		true,
		true,
		&"",
		[],
	)
	var failure: Dictionary = _result(
		menu,
		&"interaction.action.till",
		false,
		false,
		&"interaction.reason.blocked",
		[],
	)
	var success_toast: Dictionary = ToastScript.build(success, _descriptor_for(menu, success))
	var failure_toast: Dictionary = ToastScript.build(failure, _descriptor_for(menu, failure))
	_add(
		cases,
		"DOS-21 toasts copy only validated result title, body, parameters, and failure reason",
		(
			ToastScript.validate(success_toast)
			and ToastScript.validate(failure_toast)
			and success_toast[&"tone"] == &"success"
			and failure_toast[&"tone"] == &"failure"
			and failure_toast[&"reason_key"] == failure[&"reason_key"]
			and failure_toast[&"parameters"] == (failure[&"view"] as Dictionary)[&"parameters"]
		),
	)
	var toast_text: String = CodecScript.text(success_toast)
	_add(
		cases,
		"DOS-22 result toast never invents items, water quality, radius, guide, fault, or reward",
		(
			not toast_text.contains("item.")
			and not toast_text.contains("clean_water")
			and not toast_text.contains("irrigation_radius")
			and not toast_text.contains("field_guide")
			and not toast_text.contains("fault")
			and not toast_text.contains("reward")
		),
	)
	var information: Dictionary = _result(
		menu,
		&"interaction.action.inspect",
		true,
		false,
		&"",
		[],
	)
	var info_toast: Dictionary = ToastScript.build(information, _descriptor_for(menu, information))
	_add(
		cases,
		"DOS-23 toast replacement is pooled, deterministic, and failure-immediate",
		(
			ToastScript.should_replace({}, info_toast)
			and ToastScript.should_replace(info_toast, failure_toast)
			and not ToastScript.should_replace(info_toast, info_toast)
		),
	)


static func _test_history(cases: Array[Dictionary]) -> void:
	var history: RefCounted = HistoryScript.new()
	var menus: Array[Dictionary] = [_terrain_menu(), _water_menu()]
	var accepted: bool = true
	for index: int in 20:
		var menu: Dictionary = menus[index % 2]
		var action_id: StringName = (
			&"interaction.action.inspect"
			if index % 2 == 0
			else &"interaction.action.fish_cast"
		)
		var result: Dictionary = _result(
			menu,
			action_id,
			true,
			action_id == &"interaction.action.fish_cast",
			&"",
			[],
			index,
		)
		accepted = accepted and bool(history.call(
			"append_result",
			result,
			_descriptor_for(menu, result),
		))
	var records: Array = history.call("records") as Array
	var terrain_rows: Array = history.call(
		"project_for_target",
		(_terrain_menu())[&"target_id"],
	) as Array
	_add(
		cases,
		"DOS-24 session history holds sixteen globally and projects eight newest per target",
		accepted and records.size() == 16 and terrain_rows.size() == 8,
	)
	var bounded: bool = true
	var previous: int = 2_147_483_647
	for record: Dictionary in terrain_rows:
		bounded = (
			bounded
			and record.keys() == HistoryScript.RECORD_KEYS
			and not record.has(&"timestamp")
			and not record.has(&"day")
			and int(record[&"sequence"]) < previous
		)
		previous = int(record[&"sequence"])
	_add(
		cases,
		"DOS-25 history is exact, newest-first, session-ordinal, timestamp-free, and save-free",
		bounded,
	)
	var exposed: Array = history.call("records") as Array
	(exposed[0] as Dictionary)[&"parameters"] = {&"poisoned": true}
	_add(
		cases,
		"DOS-26 history copies are deeply isolated and duplicate result IDs are rejected",
		(
			not (history.call("records") as Array) == exposed
			and not bool(history.call(
				"append_result",
				_result(_terrain_menu(), &"interaction.action.inspect", true, false, &"", [], 18),
				_descriptor(_find_option(_terrain_menu(), &"interaction.action.inspect")),
			))
		),
	)
	var last_sequence: int = int((records.back() as Dictionary)[&"sequence"])
	history.call("clear")
	var next_result: Dictionary = _result(
		_terrain_menu(),
		&"interaction.action.inspect",
		true,
		false,
		&"",
		[],
		99,
	)
	history.call("append_result", next_result, _descriptor_for(_terrain_menu(), next_result))
	var after_clear: Array = history.call("records") as Array
	_add(
		cases,
		"DOS-27 clear removes session rows while process sequence remains monotonic",
		(
			after_clear.size() == 1
			and int((after_clear[0] as Dictionary)[&"sequence"]) > last_sequence
		),
	)


static func _test_coordinator(cases: Array[Dictionary]) -> void:
	var coordinator: RefCounted = CoordinatorScript.new()
	var menu: Dictionary = _terrain_menu()
	var source_before: String = CodecScript.text(menu)
	var opened: bool = bool(coordinator.call("set_snapshot", menu))
	var first: Dictionary = coordinator.call("compose") as Dictionary
	var counters_before: Dictionary = coordinator.call("counters") as Dictionary
	var second: Dictionary = coordinator.call("compose") as Dictionary
	var counters_after: Dictionary = coordinator.call("counters") as Dictionary
	_add(
		cases,
		"DOS-28 coordinator composes pure state once and skips unchanged projection work",
		(
			opened
			and DossierStateScript.validate(first)
			and first == second
			and counters_before == counters_after
			and CodecScript.text(menu) == source_before
		),
	)
	var result: Dictionary = _result(
		menu,
		&"interaction.action.inspect",
		true,
		false,
		&"",
		[],
	)
	var observed: bool = bool(coordinator.call("observe_result", result))
	var with_result: Dictionary = coordinator.call("compose") as Dictionary
	_add(
		cases,
		"DOS-29 coordinator accepts only current validated results and composes toast plus history",
		(
			observed
			and not (with_result[&"toast"] as Dictionary).is_empty()
			and (with_result[&"history"] as Array).size() == 1
			and not bool(coordinator.call("observe_result", result))
		),
	)
	var stale_result: Dictionary = _result(
		_water_menu(),
		&"interaction.action.inspect",
		true,
		false,
		&"",
		[],
	)
	_add(
		cases,
		"DOS-30 coordinator rejects stale cross-target results and exposes no execution callable",
		(
			not bool(coordinator.call("observe_result", stale_result))
			and not coordinator.has_method("execute")
			and not coordinator.has_method("confirm")
			and not coordinator.has_method("save")
		),
	)
	var state_copy: Dictionary = coordinator.call("state") as Dictionary
	(state_copy[&"history"] as Array).clear()
	_add(
		cases,
		"DOS-31 coordinator state and counters are isolated from caller mutation",
		(
			(coordinator.call("state") as Dictionary)[&"history"] != state_copy[&"history"]
			and int((coordinator.call("counters") as Dictionary)[&"composition_rebuilds"]) >= 2
		),
	)


static func _terrain_menu(state: Dictionary = {}) -> Dictionary:
	return _menu(
		&"terrain:4,7",
		&"terrain",
		&"terrain",
		_terrain_state() if state.is_empty() else state,
		[
			_option(&"inspect", &"inspect", true, &"", 0, [], &"never"),
			_option(
				&"till",
				&"till",
				true,
				&"",
				100,
				[{&"cost_id": &"tool.stamina", &"amount": 2}],
			),
			_option(
				&"water",
				&"water",
				false,
				&"interaction.reason.requires_watering_can",
				300,
				[{&"cost_id": &"tool.stamina", &"amount": 1}],
			),
		],
	)


static func _water_menu(state: Dictionary = {}) -> Dictionary:
	var water_state: Dictionary = {
		&"water_class": &"freshwater_pond",
		&"walkable": false,
		&"irrigation_relevant": true,
	}
	return _menu(
		&"feature.water:9,3",
		&"structure",
		&"water",
		water_state if state.is_empty() else state,
		[
			_option(&"inspect", &"inspect", true, &"", 0, [], &"never"),
			_option(&"fish_cast", &"fish_cast", true, &"", 100, []),
			_option(
				&"fish_cast_bait",
				&"fish_cast",
				false,
				&"interaction.reason.missing_bait",
				200,
				[{&"cost_id": &"item.bait.luminous", &"amount": 1}],
			),
		],
		Vector2i(9, 3),
	)


static func _facility_menu(state: Dictionary) -> Dictionary:
	return _menu(
		&"facility.greenhouse",
		&"structure",
		&"facility",
		state,
		[
			_option(&"inspect", &"inspect", true, &"", 0, [], &"never"),
			_option(
				&"facility_repair",
				&"facility_repair",
				false,
				&"interaction.reason.missing_materials",
				100,
				[
					{&"cost_id": &"item.material.stone", &"amount": 2},
					{&"cost_id": &"item.material.wood", &"amount": 4},
				],
			),
			_option(
				&"facility_power",
				&"facility_power",
				false,
				&"interaction.reason.facility_not_repaired",
				200,
				[{&"cost_id": &"item.irrigation_coil", &"amount": 1}],
			),
		],
		Vector2i(6, 6),
	)


static func _terrain_state() -> Dictionary:
	return {
		&"biome_id": &"woodland",
		&"blocked": false,
		&"farmable": true,
		&"plot": {},
		&"surface_id": &"woodland_grass",
		&"walkable": true,
	}


static func _menu(
	target_id: StringName,
	target_kind: StringName,
	target_subkind: StringName,
	state: Dictionary,
	options: Array[Dictionary],
	cell: Vector2i = Vector2i(4, 7),
) -> Dictionary:
	var sealed_options: Array[Dictionary] = []
	for input: Dictionary in options:
		var costs: Array[Dictionary] = []
		for cost: Dictionary in input[&"cost_preview"] as Array[Dictionary]:
			costs.append(cost.duplicate(true))
		var cells: Array[Vector2i] = [cell]
		sealed_options.append(OptionScript.build(
			input[&"action_id"] as StringName,
			_provider_for(input[&"operation"] as StringName),
			target_id,
			target_kind,
			target_subkind,
			input[&"operation"] as StringName,
			input[&"arguments"] as Dictionary,
			bool(input[&"enabled"]),
			input[&"label_key"] as StringName,
			input[&"reason_key"] as StringName,
			int(input[&"priority"]),
			cells,
			costs,
			input[&"close_behavior"] as StringName,
		))
	return MenuScript.build(
		cell,
		target_id,
		target_kind,
		target_subkind,
		StringName("interaction.target.%s.title" % str(target_subkind)),
		state,
		sealed_options,
	)


static func _option(
	action: StringName,
	operation: StringName,
	enabled: bool = true,
	reason_key: StringName = &"",
	priority: int = 0,
	costs: Array[Dictionary] = [],
	close_behavior: StringName = &"on_success",
) -> Dictionary:
	return {
		&"action_id": StringName("interaction.action.%s" % str(action)),
		&"operation": operation,
		&"arguments": {&"fixture": true},
		&"enabled": enabled,
		&"label_key": StringName("interaction.action.%s.label" % str(action)),
		&"reason_key": reason_key,
		&"priority": priority,
		&"cost_preview": costs,
		&"close_behavior": close_behavior,
	}


static func _provider_for(operation: StringName) -> StringName:
	if operation in [&"facility_power", &"facility_repair", &"fish_cast"]:
		return OperationCatalogScript.PROVIDER_FACILITY
	return OperationCatalogScript.PROVIDER_TERRAIN


static func _find_option(menu: Dictionary, action_id: StringName) -> Dictionary:
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option.duplicate(true)
	return {}


static func _descriptor(option: Dictionary) -> Dictionary:
	return OperationCatalogScript.descriptor_for(
		option[&"operation"] as StringName,
		option[&"provider_id"] as StringName,
	)


static func _descriptor_for(menu: Dictionary, result: Dictionary) -> Dictionary:
	return _descriptor(_find_option(menu, result[&"action_id"] as StringName))


static func _result(
	menu: Dictionary,
	action_id: StringName,
	ok: bool,
	mutated: bool,
	reason_key: StringName,
	facts: Array[Dictionary],
	serial: int = 0,
) -> Dictionary:
	var option: Dictionary = _find_option(menu, action_id)
	var parameters: Dictionary = {&"serial": serial}
	return ExecutionResultScript.build(
		ok,
		reason_key,
		mutated,
		menu[&"snapshot_id"] as StringName,
		action_id,
		menu[&"target_id"] as StringName,
		menu[&"target_cell"] as Vector2i,
		{&"serial": serial},
		{
			&"title_key": menu[&"target_title_key"],
			&"body_key": (
				&"interaction.result.failure.body"
				if not ok
				else &"interaction.result.mutation_success.body" if mutated
				else &"interaction.result.ui_success.body"
			),
			&"parameters": parameters,
			&"facts": facts,
		},
		_descriptor(option),
	)


static func _fact(
	label_key: StringName,
	value_kind: StringName,
	value: Variant,
) -> Dictionary:
	return {&"label_key": label_key, &"value_kind": value_kind, &"value": value}


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
