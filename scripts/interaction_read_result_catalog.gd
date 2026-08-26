extends RefCounted

const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const MAX_NEXT_STEPS: int = 2
const TERRAIN_SUBKINDS: Array[StringName] = [&"crop", &"plot", &"terrain"]


static func build(
	fresh_menu: Variant,
	current_option: Variant,
	operation_descriptor: Variant,
) -> Dictionary:
	if (
		not MenuScript.validate(fresh_menu)
		or not OptionScript.validate(current_option)
		or not OperationCatalogScript.validate(operation_descriptor)
	):
		return {}
	var menu: Dictionary = fresh_menu as Dictionary
	var option: Dictionary = current_option as Dictionary
	var descriptor: Dictionary = operation_descriptor as Dictionary
	if not _option_is_current(menu, option):
		return {}
	if (
		not bool(option[&"enabled"])
		or descriptor[&"route"] != OperationCatalogScript.ROUTE_READ
		or descriptor[&"mutability"] != OperationCatalogScript.MUTABILITY_READ_ONLY
		or not OperationCatalogScript.accepts(
			descriptor,
			option[&"provider_id"] as StringName,
			option[&"operation"] as StringName,
			option[&"close_behavior"] as StringName,
		)
	):
		return {}
	var view: Dictionary = _view_for(menu, option)
	if view.is_empty():
		return {}
	return ExecutionResultScript.build(
		true,
		&"",
		false,
		menu[&"snapshot_id"] as StringName,
		option[&"action_id"] as StringName,
		menu[&"target_id"] as StringName,
		menu[&"target_cell"] as Vector2i,
		menu[&"target_state"] as Dictionary,
		view,
		descriptor,
	)


static func _view_for(menu: Dictionary, option: Dictionary) -> Dictionary:
	var operation: StringName = option[&"operation"] as StringName
	var subkind: StringName = menu[&"target_subkind"] as StringName
	if operation == &"inspect" and subkind in TERRAIN_SUBKINDS:
		return _terrain_view(menu, subkind)
	return _fallback_view(menu, option)


static func _terrain_view(menu: Dictionary, subkind: StringName) -> Dictionary:
	var state: Dictionary = menu[&"target_state"] as Dictionary
	if not _terrain_state_is_valid(state):
		return _fallback_view(menu, _current_inspect_option(menu))
	var plot: Dictionary = state[&"plot"] as Dictionary
	if subkind == &"terrain" and not plot.is_empty():
		return _fallback_view(menu, _current_inspect_option(menu))
	if subkind in [&"plot", &"crop"] and plot.is_empty():
		return _fallback_view(menu, _current_inspect_option(menu))
	var facts: Array[Dictionary] = [
		_fact(
			&"interaction.inspect.fact.surface",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_value_key(&"surface", state[&"surface_id"]),
		),
		_fact(
			&"interaction.inspect.fact.biome",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_value_key(&"biome", state[&"biome_id"]),
		),
		_fact(
			&"interaction.inspect.fact.walkable",
			ExecutionResultScript.VALUE_BOOLEAN,
			state[&"walkable"],
		),
		_fact(
			&"interaction.inspect.fact.farmable",
			ExecutionResultScript.VALUE_BOOLEAN,
			state[&"farmable"],
		),
		_fact(
			&"interaction.inspect.fact.blocked",
			ExecutionResultScript.VALUE_BOOLEAN,
			state[&"blocked"],
		),
	]
	if subkind == &"plot":
		facts.append(_fact(
			&"interaction.inspect.fact.plot_state",
			ExecutionResultScript.VALUE_TEXT_KEY,
			&"interaction.value.plot.tilled",
		))
		facts.append(_fact(
			&"interaction.inspect.fact.water_state",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_water_value(plot),
		))
	elif subkind == &"crop":
		facts.append(_fact(
			&"interaction.inspect.fact.crop",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_crop_value(plot),
		))
		facts.append(_fact(
			&"interaction.inspect.fact.growth_stage",
			ExecutionResultScript.VALUE_INTEGER,
			int(plot.get(&"stage", 0)),
		))
		facts.append(_fact(
			&"interaction.inspect.fact.water_state",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_water_value(plot),
		))
		facts.append(_fact(
			&"interaction.inspect.fact.ready",
			ExecutionResultScript.VALUE_BOOLEAN,
			bool(plot.get(&"ready", false)),
		))
	var body_key: StringName = StringName("interaction.inspect.%s.body" % str(subkind))
	return _view(
		menu[&"target_title_key"] as StringName,
		body_key,
		_next_step_parameters(menu),
		facts,
	)


static func _fallback_view(menu: Dictionary, option: Dictionary) -> Dictionary:
	if option.is_empty():
		return {}
	var parameters: Dictionary = _next_step_parameters(
		menu,
		option[&"action_id"] as StringName,
	)
	var facts: Array[Dictionary] = [
		_fact(
			&"interaction.inspect.fact.target_kind",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_value_key(&"target_kind", menu[&"target_kind"]),
		),
		_fact(
			&"interaction.inspect.fact.target_subkind",
			ExecutionResultScript.VALUE_TEXT_KEY,
			_value_key(&"target_subkind", menu[&"target_subkind"]),
		),
	]
	return _view(
		menu[&"target_title_key"] as StringName,
		&"interaction.inspect.generic.body",
		parameters,
		facts,
	)


static func _view(
	title_key: StringName,
	body_key: StringName,
	parameters: Dictionary,
	facts: Array[Dictionary],
) -> Dictionary:
	return ExecutionResultScript.canonical_view({
		&"title_key": title_key,
		&"body_key": body_key,
		&"parameters": parameters,
		&"facts": facts,
	})


static func _fact(
	label_key: StringName,
	value_kind: StringName,
	value: Variant,
) -> Dictionary:
	return {
		&"label_key": label_key,
		&"value_kind": value_kind,
		&"value": value,
	}


static func _next_step_parameters(
	menu: Dictionary,
	excluded_action_id: StringName = &"",
) -> Dictionary:
	var parameters: Dictionary = {
		&"next_action_count": 0,
		&"next_action_key": &"interaction.inspect.next.none",
		&"next_action_secondary_key": &"interaction.inspect.next.none",
	}
	var keys: Array[StringName] = []
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if (
			not bool(option[&"enabled"])
			or option[&"operation"] == &"inspect"
			or option[&"action_id"] == excluded_action_id
		):
			continue
		keys.append(option[&"label_key"] as StringName)
		if keys.size() == MAX_NEXT_STEPS:
			break
	parameters[&"next_action_count"] = keys.size()
	if not keys.is_empty():
		parameters[&"next_action_key"] = keys[0]
	if keys.size() > 1:
		parameters[&"next_action_secondary_key"] = keys[1]
	return parameters


static func _terrain_state_is_valid(state: Dictionary) -> bool:
	return (
		state.keys() == [&"biome_id", &"blocked", &"farmable", &"plot", &"surface_id", &"walkable"]
		and state[&"biome_id"] is StringName
		and state[&"blocked"] is bool
		and state[&"farmable"] is bool
		and state[&"plot"] is Dictionary
		and state[&"surface_id"] is StringName
		and state[&"walkable"] is bool
		and not str(state[&"biome_id"]).is_empty()
		and not str(state[&"surface_id"]).is_empty()
	)


static func _option_is_current(menu: Dictionary, option: Dictionary) -> bool:
	for candidate: Dictionary in menu[&"options"] as Array[Dictionary]:
		if candidate[&"action_id"] == option[&"action_id"]:
			return candidate == option
	return false


static func _current_inspect_option(menu: Dictionary) -> Dictionary:
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"operation"] == &"inspect":
			return option
	return (menu[&"options"] as Array[Dictionary])[0]


static func _value_key(category: StringName, value: Variant) -> StringName:
	var identifier: String = _safe_suffix(str(value))
	return StringName("interaction.value.%s.%s" % [str(category), identifier])


static func _crop_value(plot: Dictionary) -> StringName:
	var crop_id: String = str(plot.get(&"crop_id", "")).trim_prefix("crop.")
	return StringName("interaction.value.crop.%s" % _safe_suffix(crop_id))


static func _water_value(plot: Dictionary) -> StringName:
	return (
		&"interaction.value.water.watered"
		if int(plot.get(&"last_watered_day", 0)) > 0
		else &"interaction.value.water.dry"
	)


static func _safe_suffix(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	var result: String = ""
	for character: String in normalized:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_-.":
			result += character
		else:
			result += "_"
	result = result.strip_edges().trim_prefix(".").trim_suffix(".")
	return result if not result.is_empty() else "unknown"
