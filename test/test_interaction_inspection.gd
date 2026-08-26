extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/interaction_option_catalog.gd")
const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const ReadCatalogScript: GDScript = preload("res://scripts/interaction_read_result_catalog.gd")
const TargetScript: GDScript = preload("res://scripts/interaction_target_snapshot.gd")


static func evaluate() -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_operation_catalog(cases)
	_test_result_contract(cases)
	_test_result_caps_and_malformed_values(cases)
	_test_result_invariants(cases)
	_test_determinism(cases)
	_test_terrain_cards(cases)
	_test_fallback(cases)
	_test_current_provider_cards(cases)
	_test_read_operation_reachability(cases)
	return cases


static func _test_operation_catalog(cases: Array[Dictionary]) -> void:
	var descriptors: Array[Dictionary] = OperationCatalogScript.descriptors()
	var exact: bool = OperationCatalogScript.validate_catalog(descriptors)
	for descriptor: Dictionary in descriptors:
		exact = exact and descriptor.keys() == OperationCatalogScript.KEYS
	var inspected: Dictionary = OperationCatalogScript.descriptor_for(
		&"inspect",
		OperationCatalogScript.PROVIDER_TERRAIN,
	)
	_add(
		cases,
		"INS-01 operation catalog is closed, exact-key, sorted, and classifies audited emissions",
		(
			exact
			and descriptors.size() >= 50
			and OperationCatalogScript.operations().has(&"review_threat")
			and OperationCatalogScript.operations().has(&"inspect_construction")
			and OperationCatalogScript.operations().has(&"inspect_deposit")
			and OperationCatalogScript.operations().has(&"world_collect_reward")
			and inspected[&"route"] == OperationCatalogScript.ROUTE_READ
			and OperationCatalogScript.descriptor_for(
				&"inspect", &"interaction.provider.unknown"
			).is_empty()
			and OperationCatalogScript.descriptor_for(&"unknown_operation").is_empty()
		),
	)
	var duplicate: Array[Dictionary] = descriptors.duplicate(true)
	duplicate.insert(1, duplicate[0].duplicate(true))
	var malformed: Dictionary = inspected.duplicate(true)
	malformed[&"allowed_provider_ids"] = [
		OperationCatalogScript.PROVIDER_TERRAIN,
		OperationCatalogScript.PROVIDER_CONSTRUCTION,
	]
	var read_with_domain: Dictionary = inspected.duplicate(true)
	read_with_domain[&"persistence_domains"] = [OperationCatalogScript.DOMAIN_FARM]
	_add(
		cases,
		"INS-02 duplicate, unsorted, unknown, and impure operation descriptors fail closed",
		(
			not OperationCatalogScript.validate_catalog(duplicate)
			and not OperationCatalogScript.validate(malformed)
			and not OperationCatalogScript.validate(read_with_domain)
		),
	)


static func _test_result_contract(cases: Array[Dictionary]) -> void:
	var fixture: Dictionary = _read_fixture(&"terrain", _terrain_state())
	var result: Dictionary = _build_read(fixture)
	var view: Dictionary = result.get(&"view", {}) as Dictionary
	var facts: Array = view.get(&"facts", []) as Array
	var facts_exact: bool = not facts.is_empty()
	for fact: Dictionary in facts:
		facts_exact = facts_exact and fact.keys() == ExecutionResultScript.FACT_KEYS
	_add(
		cases,
		"INS-03 execution results and views expose exact ordered keys with valid digest",
		(
			ExecutionResultScript.validate(
				result,
				fixture[&"descriptor"] as Dictionary,
			)
			and result.keys() == ExecutionResultScript.KEYS
			and view.keys() == ExecutionResultScript.VIEW_KEYS
			and facts_exact
			and result[&"result_id"] == ExecutionResultScript.digest(result)
		),
	)
	var changed: Dictionary = result.duplicate(true)
	changed[&"target_cell"] = Vector2i(99, 99)
	_add(
		cases,
		"INS-04 changing a signed payload field invalidates the deterministic result digest",
		not ExecutionResultScript.validate(changed),
	)


static func _test_result_caps_and_malformed_values(cases: Array[Dictionary]) -> void:
	var fixture: Dictionary = _read_fixture(&"terrain", _terrain_state())
	var result: Dictionary = _build_read(fixture)
	var extra_key: Dictionary = result.duplicate(true)
	extra_key[&"unknown"] = true
	var malformed_type: Dictionary = result.duplicate(true)
	malformed_type[&"target_cell"] = [1, 0]
	var oversized_observation: Dictionary = {}
	for index: int in CodecScript.MAX_DICTIONARY_KEYS + 1:
		oversized_observation[StringName("field_%02d" % index)] = index
	var too_many_facts: Array[Dictionary] = []
	for index: int in ExecutionResultScript.MAX_FACTS + 1:
		too_many_facts.append(_fact(
			StringName("interaction.inspect.fact.cap_%02d" % index),
			ExecutionResultScript.VALUE_INTEGER,
			index,
		))
	var oversized_view: Dictionary = _view(too_many_facts)
	_add(
		cases,
		"INS-05 exact-key, codec dictionary budget, and twelve-fact cap reject overflow",
		(
			not ExecutionResultScript.validate(extra_key)
			and not ExecutionResultScript.validate(malformed_type)
			and ExecutionResultScript.build(
				true,
				&"",
				false,
				&"interaction.snapshot.cap",
				&"interaction.action.inspect",
				&"terrain.cap",
				Vector2i.ZERO,
				oversized_observation,
				_view([]),
			).is_empty()
			and oversized_view.is_empty()
		),
	)
	var invalid_fact: Dictionary = _fact(
		&"interaction.inspect.fact.bad",
		ExecutionResultScript.VALUE_BOOLEAN,
		1,
	)
	var nan_fact: Dictionary = _fact(
		&"interaction.inspect.fact.nan",
		ExecutionResultScript.VALUE_DECIMAL,
		NAN,
	)
	var prose_fact: Dictionary = _fact(
		&"interaction.inspect.fact.prose",
		ExecutionResultScript.VALUE_TEXT_KEY,
		"Already localized prose",
	)
	_add(
		cases,
		"INS-06 malformed fact kinds, non-finite decimals, and localized prose values fail closed",
		(
			_view([invalid_fact]).is_empty()
			and _view([nan_fact]).is_empty()
			and _view([prose_fact]).is_empty()
		),
	)


static func _test_result_invariants(cases: Array[Dictionary]) -> void:
	var read_descriptor: Dictionary = OperationCatalogScript.descriptor_for(
		&"inspect",
		OperationCatalogScript.PROVIDER_TERRAIN,
	)
	var mutation_descriptor: Dictionary = OperationCatalogScript.descriptor_for(
		&"till",
		OperationCatalogScript.PROVIDER_TERRAIN,
	)
	var failure_with_empty_reason: Dictionary = ExecutionResultScript.build(
		false,
		&"",
		false,
		&"interaction.snapshot.failure",
		&"interaction.action.inspect",
		&"terrain.failure",
		Vector2i.ZERO,
		{},
		_view([]),
		read_descriptor,
	)
	var success_with_reason: Dictionary = ExecutionResultScript.build(
		true,
		&"interaction.reason.unavailable",
		false,
		&"interaction.snapshot.success",
		&"interaction.action.inspect",
		&"terrain.success",
		Vector2i.ZERO,
		{},
		_view([]),
		read_descriptor,
	)
	var failed_mutation: Dictionary = ExecutionResultScript.build(
		false,
		&"interaction.reason.rejected",
		true,
		&"interaction.snapshot.failed_mutation",
		&"interaction.action.till",
		&"terrain.failed_mutation",
		Vector2i.ZERO,
		{},
		_view([]),
		mutation_descriptor,
	)
	var read_mutation: Dictionary = ExecutionResultScript.build(
		true,
		&"",
		true,
		&"interaction.snapshot.read_mutation",
		&"interaction.action.inspect",
		&"terrain.read_mutation",
		Vector2i.ZERO,
		{},
		_view([]),
		read_descriptor,
	)
	var committed: Dictionary = ExecutionResultScript.build(
		true,
		&"",
		true,
		&"interaction.snapshot.committed",
		&"interaction.action.till",
		&"terrain.committed",
		Vector2i.ZERO,
		{&"committed": true},
		_view([]),
		mutation_descriptor,
	)
	_add(
		cases,
		"INS-07 success, reason, mutated, and descriptor mutability invariants are exact",
		(
			failure_with_empty_reason.is_empty()
			and success_with_reason.is_empty()
			and failed_mutation.is_empty()
			and read_mutation.is_empty()
			and ExecutionResultScript.validate(committed, mutation_descriptor)
		),
	)


static func _test_determinism(cases: Array[Dictionary]) -> void:
	var baseline_fixture: Dictionary = _read_fixture(&"crop", _crop_state(true, true))
	var baseline: Dictionary = _build_read(baseline_fixture)
	var baseline_text: String = CodecScript.text(baseline)
	var deterministic: bool = not baseline.is_empty()
	for iteration: int in 1000:
		var state: Dictionary = _shuffled_dictionary(
			baseline_fixture[&"state"] as Dictionary,
			iteration * 31 + 5,
		)
		var fixture: Dictionary = _read_fixture(&"crop", state, iteration * 17 + 9)
		var current: Dictionary = _build_read(fixture)
		deterministic = deterministic and CodecScript.text(current) == baseline_text
	_add(
		cases,
		"INS-08 1000 shuffled state and option input orders build byte-equivalent results",
		deterministic,
	)


static func _test_terrain_cards(cases: Array[Dictionary]) -> void:
	var terrain: Dictionary = _build_read(_read_fixture(&"terrain", _terrain_state()))
	var nonfarmable_state: Dictionary = _terrain_state()
	nonfarmable_state[&"farmable"] = false
	var nonfarmable: Dictionary = _build_read(_read_fixture(&"terrain", nonfarmable_state))
	var plot: Dictionary = _build_read(_read_fixture(&"plot", _plot_state(true)))
	var dry_crop: Dictionary = _build_read(_read_fixture(&"crop", _crop_state(false, false)))
	var watered_crop: Dictionary = _build_read(_read_fixture(&"crop", _crop_state(true, false)))
	var ready_crop: Dictionary = _build_read(_read_fixture(&"crop", _crop_state(true, true)))
	_add(
		cases,
		"INS-09 terrain and walkable-but-not-farmable cards expose distinct authoritative signals",
		(
			_result_has_fact(terrain, &"interaction.inspect.fact.surface")
			and _result_has_fact(terrain, &"interaction.inspect.fact.biome")
			and _fact_value(terrain, &"interaction.inspect.fact.walkable") == true
			and _fact_value(nonfarmable, &"interaction.inspect.fact.walkable") == true
			and _fact_value(nonfarmable, &"interaction.inspect.fact.farmable") == false
			and _next_action_count(terrain) == 2
		),
	)
	_add(
		cases,
		"INS-10 tilled plot cards expose plot and current water state",
		(
			_result_has_fact(plot, &"interaction.inspect.fact.plot_state")
			and (
				_fact_value(plot, &"interaction.inspect.fact.water_state")
				== &"interaction.value.water.watered"
			)
		),
	)
	_add(
		cases,
		"INS-11 dry, watered-growing, and ready crop cards are useful and distinct",
		(
			_fact_value(dry_crop, &"interaction.inspect.fact.water_state")
			== &"interaction.value.water.dry"
			and _fact_value(watered_crop, &"interaction.inspect.fact.water_state")
			== &"interaction.value.water.watered"
			and _fact_value(watered_crop, &"interaction.inspect.fact.ready") == false
			and _fact_value(ready_crop, &"interaction.inspect.fact.ready") == true
			and _fact_value(ready_crop, &"interaction.inspect.fact.crop")
			== &"interaction.value.crop.glowroot"
			and _result_fact_count(ready_crop) <= ExecutionResultScript.MAX_FACTS
		),
	)


static func _test_fallback(cases: Array[Dictionary]) -> void:
	var state: Dictionary = {&"active": true, &"internal_detail": &"bounded"}
	var fixture: Dictionary = _read_fixture(&"wilderness", state)
	var before_menu: Dictionary = (fixture[&"menu"] as Dictionary).duplicate(true)
	var before_option: Dictionary = (fixture[&"option"] as Dictionary).duplicate(true)
	var result: Dictionary = _build_read(fixture)
	var parameters: Dictionary = (result[&"view"] as Dictionary)[&"parameters"] as Dictionary
	_add(
		cases,
		"INS-12 unknown subkinds receive a bounded generic card without raw-state dumping or mutation",
		(
			ExecutionResultScript.validate(result, fixture[&"descriptor"] as Dictionary)
			and ((result[&"view"] as Dictionary)[&"body_key"]
					== &"interaction.inspect.current.body")
			and (result[&"observed_state"] as Dictionary) == state
			and _result_fact_count(result) == 2
			and parameters.size() <= 6
			and fixture[&"menu"] == before_menu
			and fixture[&"option"] == before_option
			and not bool(result[&"mutated"])
		),
	)
	var stale_option: Dictionary = (fixture[&"option"] as Dictionary).duplicate(true)
	stale_option[&"priority"] = int(stale_option[&"priority"]) + 1
	_add(
		cases,
		"INS-13 fallback still requires a fresh menu and exact current option",
		ReadCatalogScript.build(
			fixture[&"menu"],
			stale_option,
			fixture[&"descriptor"],
		).is_empty(),
		)


static func _test_current_provider_cards(cases: Array[Dictionary]) -> void:
	var fixtures: Array[Dictionary] = [
		_provider_fixture(
			&"home",
			{
				&"bed": true,
				&"storage": true,
				&"safehouse": true,
				&"animal_capacity": 4,
				&"item_count": 12,
				&"occupied_slots": 1,
				&"capacity_slots": 48,
			},
		),
		_provider_fixture(
			&"storage",
			{
				&"available": true,
				&"item_count": 12,
				&"occupied_slots": 1,
				&"capacity_slots": 48,
				&"robot_item_count": 5,
			},
		),
		_provider_fixture(&"shipping", {&"item_count": 6, &"money": 84}),
		_provider_fixture(&"facility", {&"repaired": true, &"powered": false}),
		_provider_fixture(&"machine", {&"state": &"machine.running", &"complete_day": 9}),
		_provider_fixture(&"resident", {&"points": 42, &"last_talk_day": 8}),
		_provider_fixture(&"livestock", {&"bond": 31}),
		_provider_fixture(&"tree", {&"reward": {&"count": 3}}),
		_provider_fixture(&"resource", {&"reward": {&"count": 2}}),
		_provider_fixture(&"pickup", {&"count": 5}),
		_provider_fixture(&"herd", {&"population": 7, &"trust": 12, &"active": true}),
		_provider_fixture(
			&"hostile", {&"health": 33, &"max_health": 50, &"is_boss": false}
		),
		_provider_fixture(&"hazard", {&"age": 0.75, &"prepared": true}),
		_provider_fixture(&"ruin", {&"activated": false}),
		_provider_fixture(
			&"expedition_gate", {&"unbanked_scrap": 18, &"worm_cores": 1}
		),
		_provider_fixture(
			&"construction",
			{&"state": "constructing", &"level": 2, &"orientation": 1},
			&"inspect_construction",
		),
		_provider_fixture(
			&"deposit_salvage", _deposit_state(&"depleted"), &"inspect_deposit"
		),
		_provider_fixture(
			&"deposit_mineral", _deposit_state(&"rich"), &"inspect_deposit"
		),
		_provider_fixture(
			&"deposit_biomass", _deposit_state(&"renewing"), &"inspect_deposit"
		),
		_provider_fixture(&"settler", {&"settler_id": "settler.amara_voss"}),
	]
	var valid: bool = true
	var localized: bool = true
	var result_by_subkind: Dictionary = {}
	for fixture: Dictionary in fixtures:
		var result: Dictionary = _build_read(fixture)
		var view: Dictionary = result.get(&"view", {}) as Dictionary
		var facts: Array = view.get(&"facts", []) as Array
		var subkind: StringName = (fixture[&"menu"] as Dictionary)[&"target_subkind"]
		valid = (
			valid
			and ExecutionResultScript.validate(result, fixture[&"descriptor"] as Dictionary)
			and not bool(result[&"mutated"])
			and result[&"observed_state"] == fixture[&"state"]
			and facts.size() in range(2, ExecutionResultScript.MAX_FACTS + 1)
			and _fact_value(result, &"interaction.inspect.fact.target_subkind")
			== StringName("interaction.subkind.%s" % str(subkind))
		)
		localized = localized and _view_is_localized(view)
		result_by_subkind[subkind] = result
	_add(
		cases,
		"INS-14 every current provider family returns a bounded non-mutating card",
		valid and fixtures.size() == 20,
	)
	_add(
		cases,
		"INS-15 construction, deposits, herds, and hostiles expose actionable state",
		(
			_fact_value(result_by_subkind[&"construction"], &"interaction.inspect.fact.level")
			== 2
			and _fact_value(
				result_by_subkind[&"deposit_salvage"], &"interaction.inspect.fact.remaining"
			) == 0
			and _fact_value(
				result_by_subkind[&"deposit_mineral"], &"interaction.inspect.fact.remaining"
			) == 3
			and _fact_value(
				result_by_subkind[&"herd"], &"interaction.inspect.fact.population"
			) == 7
			and _fact_value(
				result_by_subkind[&"hostile"], &"interaction.inspect.fact.health"
			) == 33
			and _fact_value(
				result_by_subkind[&"home"], &"interaction.inspect.fact.occupied_slots"
			) == 1
			and _fact_value(
				result_by_subkind[&"storage"], &"interaction.inspect.fact.robot_item_count"
			) == 5
		),
	)
	_add(
		cases,
		"INS-16 all provider card fields have exact English and Simplified Chinese keys",
		localized,
	)
	_add(
		cases,
		"INS-17 emitted threat review has one canonical name and no dead alias",
		(
			OperationCatalogScript.operations().has(&"review_threat")
			and not OperationCatalogScript.operations().has(&"read_threat")
		),
	)


static func _test_read_operation_reachability(cases: Array[Dictionary]) -> void:
	var read_count: int = 0
	var reachable: bool = true
	for descriptor: Dictionary in OperationCatalogScript.descriptors():
		if descriptor[&"route"] != OperationCatalogScript.ROUTE_READ:
			continue
		read_count += 1
		var provider_id: StringName = descriptor[&"allowed_provider_ids"][0]
		var fixture: Dictionary = _read_route_fixture(
			descriptor[&"operation"] as StringName,
			provider_id,
			descriptor[&"allowed_close_behaviors"][0] as StringName,
		)
		var result: Dictionary = _build_read(fixture)
		reachable = (
			reachable
			and not fixture.is_empty()
			and (fixture[&"option"] as Dictionary)[&"provider_id"] == provider_id
			and ExecutionResultScript.validate(result, descriptor)
			and not bool(result[&"mutated"])
		)
	_add(
		cases,
		"INS-18 every registered read operation reaches one deterministic adapter",
		reachable and read_count >= 20,
	)


static func _view_is_localized(view: Dictionary) -> bool:
	for locale: StringName in [&"en", &"zh-CN"]:
		if (
			not LocalizationScript.has_key(locale, view[&"title_key"] as StringName)
			or not LocalizationScript.has_key(locale, view[&"body_key"] as StringName)
		):
			return false
		for fact: Dictionary in view[&"facts"] as Array[Dictionary]:
			if not LocalizationScript.has_key(locale, fact[&"label_key"] as StringName):
				return false
			if (
				fact[&"value_kind"] == ExecutionResultScript.VALUE_TEXT_KEY
				and not LocalizationScript.has_key(locale, fact[&"value"] as StringName)
			):
				return false
	return true


static func _read_fixture(
	subkind: StringName,
	state: Dictionary,
	shuffle_seed: int = -1,
) -> Dictionary:
	var inputs: Array[Dictionary] = [
		_input(
			&"interaction.action.inspect",
			&"inspect",
			0,
			OptionScript.CLOSE_NEVER,
		),
		_input(
			&"interaction.action.till",
			&"till",
			100,
			OptionScript.CLOSE_ON_SUCCESS,
		),
		_input(
			&"interaction.action.water",
			&"water",
			200,
			OptionScript.CLOSE_ON_SUCCESS,
		),
	]
	if shuffle_seed >= 0:
		_shuffle(inputs, shuffle_seed)
	var target: Dictionary = TargetScript.build(
		Vector2i(4, 7),
		StringName("%s.test" % str(subkind)),
		subkind if subkind in [&"terrain", &"plot", &"crop"] else &"structure",
		subkind,
		StringName("interaction.target.%s.title" % str(subkind)),
		state,
		inputs,
	)
	var menu: Dictionary = CatalogScript.build_menu(target)
	var option: Dictionary = _action(menu, &"interaction.action.inspect")
	return {
		&"descriptor": OperationCatalogScript.descriptor_for(
			&"inspect",
			option.get(&"provider_id", &"") as StringName,
		),
		&"menu": menu,
		&"option": option,
		&"state": state,
	}


static func _provider_fixture(
	subkind: StringName,
	state: Dictionary,
	operation: StringName = &"inspect",
	close_behavior: StringName = OptionScript.CLOSE_NEVER,
) -> Dictionary:
	var action_id: StringName = StringName("interaction.action.route.%s" % str(operation))
	if operation == &"inspect":
		action_id = &"interaction.action.inspect"
	if operation == &"inspect_construction":
		action_id = &"interaction.action.inspect_construction"
	elif operation == &"inspect_deposit":
		action_id = &"interaction.action.inspect_deposit"
	var inputs: Array[Dictionary] = [
		_input(action_id, operation, 0, close_behavior),
	]
	var target: Dictionary = TargetScript.build(
		Vector2i(7, 9),
		StringName("%s.provider_fixture" % str(subkind)),
		_target_kind_for(subkind),
		subkind,
		StringName("interaction.target.%s.title" % str(subkind)),
		state,
		inputs,
	)
	var menu: Dictionary = CatalogScript.build_menu(target)
	var option: Dictionary = _action(menu, action_id)
	return {
		&"descriptor": OperationCatalogScript.descriptor_for(
			operation,
			option.get(&"provider_id", &"") as StringName,
		),
		&"menu": menu,
		&"option": option,
		&"state": state,
	}


static func _read_route_fixture(
	operation: StringName,
	provider_id: StringName,
	close_behavior: StringName,
) -> Dictionary:
	var subkind: StringName = &"home"
	var state: Dictionary = {}
	match provider_id:
		OperationCatalogScript.PROVIDER_CONSTRUCTION:
			subkind = &"construction"
			state = {&"state": "complete", &"level": 1, &"orientation": 0}
		OperationCatalogScript.PROVIDER_DEPOSIT:
			subkind = &"deposit_salvage"
			state = _deposit_state(&"rich")
		OperationCatalogScript.PROVIDER_LEGACY:
			subkind = &"expedition_gate"
			state = {&"unbanked_scrap": 8, &"worm_cores": 1}
		OperationCatalogScript.PROVIDER_LIVESTOCK:
			subkind = &"livestock"
			state = {&"bond": 3}
		OperationCatalogScript.PROVIDER_MACHINE:
			subkind = &"machine"
			state = {&"state": &"machine.idle", &"complete_day": 0}
		OperationCatalogScript.PROVIDER_PICKUP:
			subkind = &"pickup"
			state = {&"count": 1}
		OperationCatalogScript.PROVIDER_RESIDENT:
			subkind = &"resident"
			state = {&"points": 1, &"last_talk_day": 0}
		OperationCatalogScript.PROVIDER_RESOURCE:
			subkind = &"tree"
			state = {&"reward": {&"count": 2}}
		OperationCatalogScript.PROVIDER_TERRAIN:
			subkind = &"terrain"
			state = _terrain_state()
		OperationCatalogScript.PROVIDER_WILDERNESS:
			subkind = &"hostile"
			state = {&"health": 9, &"max_health": 9, &"is_boss": false}
	return _provider_fixture(subkind, state, operation, close_behavior)


static func _target_kind_for(subkind: StringName) -> StringName:
	if subkind in [&"tree"]:
		return &"tree"
	if subkind in [&"pickup"]:
		return &"pickup"
	if subkind in [&"herd", &"livestock"]:
		return &"friendly_fauna"
	if subkind in [&"hazard", &"hostile"]:
		return &"hostile"
	if subkind in [&"resident", &"settler"]:
		return &"resident"
	if subkind in [&"deposit_biomass", &"deposit_mineral", &"deposit_salvage"]:
		return &"resource"
	return &"structure"


static func _deposit_state(phase: StringName) -> Dictionary:
	return {
		&"source_kind": "salvage",
		&"remaining_charges": 3 if phase == &"rich" else 0,
		&"capacity": 3,
		&"tier": 2,
		&"phase": str(phase),
		&"renewal_day": 14 if phase == &"renewing" else 0,
		&"reserved_by": "",
		&"reward_item_id": "item.material.scrap",
		&"reward_count": 2,
	}


static func _build_read(fixture: Dictionary) -> Dictionary:
	return ReadCatalogScript.build(
		fixture[&"menu"],
		fixture[&"option"],
		fixture[&"descriptor"],
	)


static func _input(
	action_id: StringName,
	operation: StringName,
	priority: int,
	close_behavior: StringName,
) -> Dictionary:
	return {
		&"action_id": action_id,
		&"operation": operation,
		&"arguments": {&"cell": Vector2i(4, 7)},
		&"enabled": true,
		&"label_key": StringName("%s.label" % str(action_id)),
		&"reason_key": &"",
		&"priority": priority,
		&"cost_preview": [],
		&"close_behavior": close_behavior,
	}


static func _terrain_state() -> Dictionary:
	return {
		&"biome_id": &"woodland",
		&"blocked": false,
		&"farmable": true,
		&"plot": {},
		&"surface_id": &"grass",
		&"walkable": true,
	}


static func _plot_state(watered: bool) -> Dictionary:
	var state: Dictionary = _terrain_state()
	state[&"plot"] = _plot(watered, false)
	return state


static func _crop_state(watered: bool, ready: bool) -> Dictionary:
	var state: Dictionary = _terrain_state()
	state[&"plot"] = _plot(watered, ready)
	return state


static func _plot(watered: bool, ready: bool) -> Dictionary:
	return {
		&"cell": [4, 7],
		&"crop_id": "crop.glowroot",
		&"growth_points": 3 if ready else 1,
		&"harvest_sequence": 0,
		&"last_watered_day": 9 if watered else 0,
		&"planted_day": 7,
		&"ready": ready,
		&"stage": 3 if ready else 1,
		&"tilled": true,
	}


static func _view(facts: Array[Dictionary]) -> Dictionary:
	return ExecutionResultScript.canonical_view({
		&"title_key": &"interaction.target.terrain.title",
		&"body_key": &"interaction.inspect.terrain.body",
		&"parameters": {},
		&"facts": facts,
	})


static func _fact(label_key: StringName, value_kind: StringName, value: Variant) -> Dictionary:
	return {
		&"label_key": label_key,
		&"value_kind": value_kind,
		&"value": value,
	}


static func _action(menu: Dictionary, action_id: StringName) -> Dictionary:
	for option: Dictionary in menu.get(&"options", []) as Array[Dictionary]:
		if option[&"action_id"] == action_id:
			return option
	return {}


static func _result_has_fact(result: Dictionary, label_key: StringName) -> bool:
	return _fact_value(result, label_key) != null


static func _fact_value(result: Dictionary, label_key: StringName) -> Variant:
	for fact: Dictionary in (result[&"view"] as Dictionary)[&"facts"] as Array[Dictionary]:
		if fact[&"label_key"] == label_key:
			return fact[&"value"]
	return null


static func _result_fact_count(result: Dictionary) -> int:
	return ((result[&"view"] as Dictionary)[&"facts"] as Array).size()


static func _next_action_count(result: Dictionary) -> int:
	return int(((result[&"view"] as Dictionary)[&"parameters"] as Dictionary)[
		&"next_action_count"
	])


static func _shuffled_dictionary(source: Dictionary, seed_value: int) -> Dictionary:
	var keys: Array = source.keys()
	_shuffle(keys, seed_value)
	var result: Dictionary = {}
	for key: Variant in keys:
		var value: Variant = source[key]
		if value is Dictionary:
			value = _shuffled_dictionary(value as Dictionary, seed_value * 17 + 3)
		result[key] = value
	return result


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
