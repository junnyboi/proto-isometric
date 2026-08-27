extends RefCounted

const CodecScript: GDScript = preload("res://scripts/interaction_contract_codec.gd")
const ExecutionResultScript: GDScript = preload("res://scripts/interaction_execution_result.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const OperationCatalogScript: GDScript = preload("res://scripts/interaction_operation_catalog.gd")

const TERRAIN_SUBKINDS: Array[StringName] = [&"crop", &"plot", &"terrain", &"water"]
const OBJECT_SUBKINDS: Array[StringName] = [
	&"construction",
	&"deposit_biomass",
	&"deposit_mineral",
	&"deposit_salvage",
	&"expedition_gate",
	&"facility",
	&"functional_prop",
	&"hazard",
	&"herd",
	&"home",
	&"hostile",
	&"livestock",
	&"machine",
	&"pickup",
	&"resource",
	&"resident",
	&"ruin",
	&"safe_exit",
	&"shipping",
	&"storage",
	&"tree",
]
const RESULT_FACT_LABELS: Array[StringName] = [
	&"interaction.inspect.fact.activated",
	&"interaction.inspect.fact.active",
	&"interaction.inspect.fact.age",
	&"interaction.inspect.fact.available",
	&"interaction.inspect.fact.available_actions",
	&"interaction.inspect.fact.bed",
	&"interaction.inspect.fact.biome",
	&"interaction.inspect.fact.blocked",
	&"interaction.inspect.fact.bond",
	&"interaction.inspect.fact.boss",
	&"interaction.inspect.fact.capacity",
	&"interaction.inspect.fact.complete_day",
	&"interaction.inspect.fact.credit_value",
	&"interaction.inspect.fact.crop",
	&"interaction.inspect.fact.destination",
	&"interaction.inspect.fact.farmable",
	&"interaction.inspect.fact.growth_stage",
	&"interaction.inspect.fact.health",
	&"interaction.inspect.fact.irrigation_relevant",
	&"interaction.inspect.fact.item_count",
	&"interaction.inspect.fact.last_talk_day",
	&"interaction.inspect.fact.level",
	&"interaction.inspect.fact.max_health",
	&"interaction.inspect.fact.occupied_slots",
	&"interaction.inspect.fact.orientation",
	&"interaction.inspect.fact.plot_state",
	&"interaction.inspect.fact.population",
	&"interaction.inspect.fact.powered",
	&"interaction.inspect.fact.prepared",
	&"interaction.inspect.fact.purpose",
	&"interaction.inspect.fact.ready",
	&"interaction.inspect.fact.relationship",
	&"interaction.inspect.fact.remaining",
	&"interaction.inspect.fact.renewal_day",
	&"interaction.inspect.fact.repaired",
	&"interaction.inspect.fact.risk",
	&"interaction.inspect.fact.robot_item_count",
	&"interaction.inspect.fact.safehouse",
	&"interaction.inspect.fact.state",
	&"interaction.inspect.fact.storage",
	&"interaction.inspect.fact.storage_slots",
	&"interaction.inspect.fact.surface",
	&"interaction.inspect.fact.target_kind",
	&"interaction.inspect.fact.target_subkind",
	&"interaction.inspect.fact.tier",
	&"interaction.inspect.fact.trust",
	&"interaction.inspect.fact.unbanked_scrap",
	&"interaction.inspect.fact.walkable",
	&"interaction.inspect.fact.water_class",
	&"interaction.inspect.fact.water_state",
	&"interaction.inspect.fact.worm_cores",
	&"interaction.inspect.fact.yield",
]
const PROJECTION_KEYS: Array[StringName] = [
	&"source_snapshot_id",
	&"target_id",
	&"target_cell",
	&"profile",
	&"portrait_id",
	&"title_key",
	&"subtitle_key",
	&"summary_sections",
	&"chips",
	&"action_ids",
]
const ROW_KEYS: Array[StringName] = [
	&"row_id",
	&"label_key",
	&"value_kind",
	&"value",
	&"tone",
]


static func project(fresh_menu: Variant, latest_result: Variant = {}) -> Dictionary:
	if not MenuScript.validate(fresh_menu):
		return {}
	var menu: Dictionary = fresh_menu as Dictionary
	var sections: Array[Dictionary] = [_coordinate_section(menu[&"target_cell"] as Vector2i)]
	var chips: Array[Dictionary] = []
	var target_section: Dictionary = _target_section(menu, chips)
	if not target_section.is_empty():
		sections.append(target_section)
	_append_result_section(sections, menu, latest_result)
	var action_ids: Array[StringName] = []
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		action_ids.append(option[&"action_id"] as StringName)
	var subkind: StringName = menu[&"target_subkind"] as StringName
	var projection: Dictionary = {
		&"source_snapshot_id": menu[&"snapshot_id"],
		&"target_id": menu[&"target_id"],
		&"target_cell": menu[&"target_cell"],
		&"profile": _profile_for(subkind),
		&"portrait_id": _portrait_for(subkind),
		&"title_key": menu[&"target_title_key"],
		&"subtitle_key": _subtitle_for(subkind),
		&"summary_sections": sections,
		&"chips": chips,
		&"action_ids": action_ids,
	}
	return projection if validate(projection) else {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var projection: Dictionary = value as Dictionary
	if projection.keys() != PROJECTION_KEYS:
		return false
	if (
		not projection[&"source_snapshot_id"] is StringName
		or not str(projection[&"source_snapshot_id"]).begins_with("interaction.snapshot.")
		or not projection[&"target_id"] is StringName
		or str(projection[&"target_id"]).is_empty()
		or not projection[&"target_cell"] is Vector2i
		or projection[&"profile"] not in [&"generic", &"object", &"terrain"]
		or not projection[&"portrait_id"] is StringName
		or not projection[&"title_key"] is StringName
		or str(projection[&"title_key"]).is_empty()
		or not projection[&"subtitle_key"] is StringName
		or not projection[&"summary_sections"] is Array
		or not projection[&"chips"] is Array
		or not projection[&"action_ids"] is Array
	):
		return false
	var sections: Array = projection[&"summary_sections"] as Array
	var chips: Array = projection[&"chips"] as Array
	var actions: Array = projection[&"action_ids"] as Array
	return (
		not sections.is_empty()
		and sections.size() <= 4
		and chips.size() <= 4
		and not actions.is_empty()
		and actions.size() <= 32
	)


static func canonical_copy(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if validate(value) else {}


static func _coordinate_section(cell: Vector2i) -> Dictionary:
	return _section(
		&"interaction.dossier.section.location",
		&"interaction.dossier.section.location.title",
		&"interaction.icon.procedural.location",
		[
			_row(
				&"interaction.dossier.row.cell_x",
				&"interaction.dossier.fact.cell_x",
				ExecutionResultScript.VALUE_INTEGER,
				cell.x,
			),
			_row(
				&"interaction.dossier.row.cell_y",
				&"interaction.dossier.fact.cell_y",
				ExecutionResultScript.VALUE_INTEGER,
				cell.y,
			),
		],
	)


static func _target_section(menu: Dictionary, chips: Array[Dictionary]) -> Dictionary:
	var subkind: StringName = menu[&"target_subkind"] as StringName
	var state: Dictionary = menu[&"target_state"] as Dictionary
	if subkind in [&"terrain", &"plot", &"crop"]:
		return _terrain_section(subkind, state, chips)
	if subkind == &"water":
		return _water_section(state, chips)
	return _object_section(subkind, state)


static func _terrain_section(
	subkind: StringName,
	state: Dictionary,
	chips: Array[Dictionary],
) -> Dictionary:
	var rows: Array[Dictionary] = []
	_append_text_enum(rows, state, &"surface_id", &"surface", &"surface")
	_append_text_enum(rows, state, &"biome_id", &"biome", &"biome")
	_append_chip(chips, state, &"walkable", &"walkable")
	_append_chip(chips, state, &"farmable", &"farmable")
	_append_chip(chips, state, &"blocked", &"blocked")
	var plot: Variant = state.get(&"plot")
	if plot is Dictionary and subkind in [&"plot", &"crop"]:
		_append_plot_rows(rows, subkind, plot as Dictionary)
	return _section(
		&"interaction.dossier.section.surface",
		&"interaction.dossier.section.surface.title",
		&"interaction.icon.procedural.surface",
		rows,
	)


static func _water_section(state: Dictionary, chips: Array[Dictionary]) -> Dictionary:
	var rows: Array[Dictionary] = []
	var water_class: Variant = state.get(&"water_class")
	if water_class is StringName and water_class == &"freshwater_pond":
		rows.append(_row(
			&"interaction.dossier.row.water_class",
			&"interaction.inspect.fact.water_class",
			ExecutionResultScript.VALUE_TEXT_KEY,
			&"interaction.value.water.freshwater_pond",
		))
	_append_chip(chips, state, &"walkable", &"walkable")
	_append_chip(chips, state, &"irrigation_relevant", &"irrigation_relevant")
	return _section(
		&"interaction.dossier.section.water",
		&"interaction.dossier.section.water.title",
		&"interaction.icon.procedural.water",
		rows,
	)


static func _object_section(subkind: StringName, state: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	match subkind:
		&"facility":
			_append_boolean_row(rows, state, &"repaired", &"repaired")
			_append_boolean_row(rows, state, &"powered", &"powered")
		&"home":
			_append_boolean_row(rows, state, &"bed", &"bed")
			_append_boolean_row(rows, state, &"storage", &"storage")
			_append_boolean_row(rows, state, &"safehouse", &"safehouse")
		&"storage":
			_append_boolean_row(rows, state, &"available", &"available")
			_append_integer_row(rows, state, &"item_count", &"item_count")
			_append_integer_row(rows, state, &"occupied_slots", &"occupied_slots")
			_append_integer_row(rows, state, &"capacity_slots", &"storage_slots")
		&"shipping":
			_append_integer_row(rows, state, &"item_count", &"item_count")
			_append_integer_row(rows, state, &"money", &"credit_value")
		&"machine":
			_append_known_enum(
				rows,
				state,
				&"state",
				&"state",
				&"machine",
				[&"complete", &"idle", &"running"],
			)
			_append_integer_row(rows, state, &"complete_day", &"complete_day")
		&"resident":
			_append_integer_row(rows, state, &"points", &"relationship")
			_append_integer_row(rows, state, &"last_talk_day", &"last_talk_day")
		&"livestock":
			_append_integer_row(rows, state, &"bond", &"bond")
		&"pickup":
			_append_integer_row(rows, state, &"count", &"item_count")
		&"herd":
			_append_integer_row(rows, state, &"population", &"population")
			_append_integer_row(rows, state, &"trust", &"trust")
			_append_boolean_row(rows, state, &"active", &"active")
		&"hostile":
			_append_integer_row(rows, state, &"health", &"health")
			_append_integer_row(rows, state, &"max_health", &"max_health")
			_append_boolean_row(rows, state, &"is_boss", &"boss")
		&"hazard":
			_append_decimal_row(rows, state, &"age", &"age")
			_append_boolean_row(rows, state, &"prepared", &"prepared")
		&"functional_prop":
			_append_known_enum(
				rows,
				state,
				&"purpose",
				&"purpose",
				&"purpose",
				[&"irrigation", &"water_access"],
			)
			_append_boolean_row(rows, state, &"active", &"active")
		&"ruin":
			_append_boolean_row(rows, state, &"activated", &"activated")
		&"construction":
			_append_known_enum(
				rows,
				state,
				&"state",
				&"state",
				&"construction",
				[&"complete", &"constructing"],
			)
			_append_integer_row(rows, state, &"level", &"level")
			_append_integer_row(rows, state, &"orientation", &"orientation")
		_:
			pass
	if rows.is_empty():
		return {}
	return _section(
		&"interaction.dossier.section.systems",
		&"interaction.dossier.section.systems.title",
		&"interaction.icon.procedural.systems",
		rows,
	)


static func _append_plot_rows(
	rows: Array[Dictionary],
	subkind: StringName,
	plot: Dictionary,
) -> void:
	if plot.get(&"tilled") is bool:
		rows.append(_row(
			&"interaction.dossier.row.plot_state",
			&"interaction.inspect.fact.plot_state",
			ExecutionResultScript.VALUE_BOOLEAN,
			plot[&"tilled"],
		))
	if plot.get(&"last_watered_day") is int:
		var water_value: StringName = (
			&"interaction.value.water.watered"
			if int(plot[&"last_watered_day"]) > 0
			else &"interaction.value.water.dry"
		)
		rows.append(_row(
			&"interaction.dossier.row.water_state",
			&"interaction.inspect.fact.water_state",
			ExecutionResultScript.VALUE_TEXT_KEY,
			water_value,
		))
	if subkind != &"crop":
		return
	_append_integer_row(rows, plot, &"stage", &"growth_stage")
	_append_boolean_row(rows, plot, &"ready", &"ready")


static func _append_result_section(
	sections: Array[Dictionary],
	menu: Dictionary,
	latest_result: Variant,
) -> void:
	var result: Dictionary = _current_result(menu, latest_result)
	if result.is_empty():
		return
	var used_rows: int = 0
	for section: Dictionary in sections:
		used_rows += (section[&"rows"] as Array).size()
	var available: int = 12 - used_rows
	if available <= 0:
		return
	var facts: Array[Dictionary] = []
	var subkind: StringName = menu[&"target_subkind"] as StringName
	for fact: Dictionary in (result[&"view"] as Dictionary)[&"facts"] as Array[Dictionary]:
		if _result_label_is_allowed(subkind, fact[&"label_key"] as StringName):
			facts.append(fact.duplicate(true))
	facts.sort_custom(_fact_less)
	var rows: Array[Dictionary] = []
	for index: int in mini(available, facts.size()):
		var fact: Dictionary = facts[index]
		rows.append({
			&"row_id": StringName("interaction.dossier.row.result.%02d" % index),
			&"label_key": fact[&"label_key"],
			&"value_kind": fact[&"value_kind"],
			&"value": fact[&"value"],
			&"tone": &"information",
		})
	if not rows.is_empty():
		sections.append(_section(
			&"interaction.dossier.section.inspection",
			&"interaction.dossier.section.inspection.title",
			&"interaction.icon.procedural.inspect",
			rows,
		))


static func _current_result(menu: Dictionary, value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var result: Dictionary = value as Dictionary
	var descriptor: Dictionary = {}
	for option: Dictionary in menu[&"options"] as Array[Dictionary]:
		if option[&"action_id"] == result.get(&"action_id"):
			descriptor = OperationCatalogScript.descriptor_for(
				option[&"operation"] as StringName,
				option[&"provider_id"] as StringName,
			)
			break
	if descriptor.is_empty() or not ExecutionResultScript.validate(result, descriptor):
		return {}
	if (
		result[&"source_snapshot_id"] != menu[&"snapshot_id"]
		or result[&"target_id"] != menu[&"target_id"]
		or result[&"target_cell"] != menu[&"target_cell"]
	):
		return {}
	return result.duplicate(true)


static func _append_text_enum(
	rows: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	row_name: StringName,
	category: StringName,
) -> void:
	var raw: Variant = state.get(key)
	if raw is StringName and not str(raw).is_empty():
		rows.append(_row(
			StringName("interaction.dossier.row.%s" % str(row_name)),
			StringName("interaction.inspect.fact.%s" % str(row_name)),
			ExecutionResultScript.VALUE_TEXT_KEY,
			StringName("interaction.value.%s.%s" % [str(category), _safe_suffix(str(raw))]),
		))


static func _append_known_enum(
	rows: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	row_name: StringName,
	category: StringName,
	allowed: Array[StringName],
) -> void:
	var normalized: StringName = StringName(str(state.get(key, "")).trim_prefix("machine."))
	if normalized not in allowed:
		return
	rows.append(_row(
		StringName("interaction.dossier.row.%s" % str(row_name)),
		StringName("interaction.inspect.fact.%s" % str(row_name)),
		ExecutionResultScript.VALUE_TEXT_KEY,
		StringName("interaction.value.%s.%s" % [str(category), str(normalized)]),
	))


static func _append_boolean_row(
	rows: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	row_name: StringName,
) -> void:
	if state.get(key) is bool:
		rows.append(_row(
			StringName("interaction.dossier.row.%s" % str(row_name)),
			StringName("interaction.inspect.fact.%s" % str(row_name)),
			ExecutionResultScript.VALUE_BOOLEAN,
			state[key],
		))


static func _append_integer_row(
	rows: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	row_name: StringName,
) -> void:
	if state.get(key) is int:
		rows.append(_row(
			StringName("interaction.dossier.row.%s" % str(row_name)),
			StringName("interaction.inspect.fact.%s" % str(row_name)),
			ExecutionResultScript.VALUE_INTEGER,
			state[key],
		))


static func _append_decimal_row(
	rows: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	row_name: StringName,
) -> void:
	if state.get(key) is float and is_finite(state[key] as float):
		rows.append(_row(
			StringName("interaction.dossier.row.%s" % str(row_name)),
			StringName("interaction.inspect.fact.%s" % str(row_name)),
			ExecutionResultScript.VALUE_DECIMAL,
			state[key],
		))


static func _append_chip(
	chips: Array[Dictionary],
	state: Dictionary,
	key: StringName,
	name: StringName,
) -> void:
	if not state.get(key) is bool or chips.size() >= 4:
		return
	chips.append({
		&"chip_id": StringName("interaction.dossier.chip.%s" % str(name)),
		&"label_key": StringName("interaction.inspect.fact.%s" % str(name)),
		&"value_kind": ExecutionResultScript.VALUE_BOOLEAN,
		&"value": state[key],
		&"tone": &"positive" if bool(state[key]) else &"neutral",
	})


static func _section(
	section_id: StringName,
	title_key: StringName,
	icon_id: StringName,
	rows: Array[Dictionary],
) -> Dictionary:
	return {} if rows.is_empty() else {
		&"section_id": section_id,
		&"title_key": title_key,
		&"icon_id": icon_id,
		&"rows": rows,
	}


static func _row(
	row_id: StringName,
	label_key: StringName,
	value_kind: StringName,
	value: Variant,
) -> Dictionary:
	return {
		&"row_id": row_id,
		&"label_key": label_key,
		&"value_kind": value_kind,
		&"value": value,
		&"tone": &"neutral",
	}


static func _profile_for(subkind: StringName) -> StringName:
	if subkind in TERRAIN_SUBKINDS:
		return &"terrain"
	return &"object" if subkind in OBJECT_SUBKINDS else &"generic"


static func _portrait_for(subkind: StringName) -> StringName:
	return (
		StringName("interaction.portrait.%s" % str(subkind))
		if subkind in OBJECT_SUBKINDS
		else &""
	)


static func _subtitle_for(subkind: StringName) -> StringName:
	return (
		StringName("interaction.subkind.%s" % str(subkind))
		if subkind in TERRAIN_SUBKINDS or subkind in OBJECT_SUBKINDS
		else &""
	)


static func _result_label_is_allowed(
	subkind: StringName,
	label_key: StringName,
) -> bool:
	var common: Array[StringName] = [
		&"interaction.inspect.fact.available_actions",
		&"interaction.inspect.fact.target_kind",
		&"interaction.inspect.fact.target_subkind",
	]
	if label_key in common:
		return true
	var suffixes: Dictionary = {
		&"terrain": [&"biome", &"blocked", &"farmable", &"surface", &"walkable"],
		&"plot": [
			&"biome", &"blocked", &"farmable", &"plot_state", &"surface",
			&"walkable", &"water_state",
		],
		&"crop": [
			&"biome", &"blocked", &"crop", &"farmable", &"growth_stage",
			&"ready", &"surface", &"walkable", &"water_state",
		],
		&"water": [&"irrigation_relevant", &"walkable", &"water_class"],
		&"facility": [&"powered", &"repaired"],
		&"home": [
			&"bed", &"capacity", &"item_count", &"occupied_slots", &"safehouse",
			&"storage", &"storage_slots",
		],
		&"storage": [
			&"available", &"item_count", &"occupied_slots", &"robot_item_count",
			&"storage_slots",
		],
		&"shipping": [&"credit_value", &"item_count"],
		&"machine": [&"complete_day", &"state"],
		&"resident": [&"last_talk_day", &"relationship"],
		&"livestock": [&"bond"],
		&"tree": [&"yield"],
		&"resource": [&"yield"],
		&"pickup": [&"item_count"],
		&"herd": [&"active", &"population", &"trust"],
		&"hostile": [&"boss", &"health", &"max_health"],
		&"hazard": [&"age", &"prepared"],
		&"safe_exit": [&"destination", &"ready", &"risk"],
		&"functional_prop": [&"active", &"purpose"],
		&"ruin": [&"activated"],
		&"expedition_gate": [&"unbanked_scrap", &"worm_cores"],
		&"construction": [&"level", &"orientation", &"state"],
		&"deposit_biomass": [&"capacity", &"remaining", &"renewal_day", &"state", &"tier", &"yield"],
		&"deposit_mineral": [&"capacity", &"remaining", &"renewal_day", &"state", &"tier", &"yield"],
		&"deposit_salvage": [&"capacity", &"remaining", &"renewal_day", &"state", &"tier", &"yield"],
	}
	var label_suffix: StringName = StringName(str(label_key).trim_prefix("interaction.inspect.fact."))
	return label_key in RESULT_FACT_LABELS and label_suffix in suffixes.get(subkind, [])


static func _fact_less(first: Dictionary, second: Dictionary) -> bool:
	return CodecScript.text(first) < CodecScript.text(second)


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
