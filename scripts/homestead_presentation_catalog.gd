extends RefCounted

const HomesteadServiceScript: GDScript = preload("res://scripts/homestead_service.gd")
const LivestockServiceScript: GDScript = preload("res://scripts/livestock_service.gd")
const OutpostVisualsScript: GDScript = preload("res://scripts/outpost_visuals.gd")
const ResidentServiceScript: GDScript = preload("res://scripts/resident_service.gd")

const HOME_TEXTURE: Texture2D = preload("res://assets/facilities/facility_home.png")
const FACILITY_TEXTURES: Dictionary = {
	HomesteadServiceScript.GREENHOUSE_ID:
	preload("res://assets/facilities/facility_greenhouse.png"),
	HomesteadServiceScript.WORKSHOP_ID:
	preload("res://assets/facilities/facility_workshop.png"),
	HomesteadServiceScript.CLINIC_ID:
	preload("res://assets/facilities/facility_clinic_kitchen.png"),
}
const RESIDENT_TEXTURES: Dictionary = {
	ResidentServiceScript.LYRA_ID: preload("res://assets/residents/resident_lyra.png"),
	ResidentServiceScript.ROOK_ID: preload("res://assets/residents/resident_rook.png"),
	ResidentServiceScript.MIRA_ID: preload("res://assets/residents/resident_mira.png"),
}
const ANIMAL_CELLS: Array[Vector2i] = [
	Vector2i(6, 6),
	Vector2i(7, 6),
	Vector2i(8, 6),
	Vector2i(9, 6),
	Vector2i(6, 7),
	Vector2i(7, 8),
	Vector2i(8, 8),
	Vector2i(9, 8),
	Vector2i(5, 7),
	Vector2i(5, 8),
	Vector2i(9, 5),
	Vector2i(10, 5),
]
const STRUCTURE_SIZE: Vector2 = Vector2(178.0, 178.0)
const STRUCTURE_OFFSET: Vector2 = Vector2(0.0, -53.0)
const PERSON_SIZE: Vector2 = Vector2(92.0, 92.0)
const PERSON_OFFSET: Vector2 = Vector2(0.0, -38.0)
const ANIMAL_SIZE: Vector2 = Vector2(96.0, 96.0)
const ANIMAL_OFFSET: Vector2 = Vector2(0.0, -40.0)


static func build_records(farm: Dictionary) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	if not homestead.has(&"home"):
		return records
	records.append(_home_record(homestead[&"home"] as Dictionary))
	for facility_id: StringName in HomesteadServiceScript.FACILITY_IDS:
		var record: Dictionary = _facility_record(farm, facility_id)
		if not record.is_empty():
			records.append(record)
	var calendar: Dictionary = farm.get(&"calendar_weather", {}) as Dictionary
	var minute: int = int(calendar.get(&"minute_of_day", 360))
	for schedule: Dictionary in ResidentServiceScript.schedule_snapshot(farm, minute):
		var resident: Dictionary = _resident_record(schedule)
		if not resident.is_empty():
			records.append(resident)
	var animals: Array = homestead.get(&"animals", []) as Array
	for index: int in animals.size():
		var animal: Dictionary = _animal_record(animals[index] as Dictionary, index)
		if not animal.is_empty():
			records.append(animal)
	return records


static func build_chunk_indexes(farm: Dictionary, chunk_size: int = 8) -> Dictionary:
	var indexes: Dictionary = {}
	if chunk_size <= 0:
		return indexes
	for record: Dictionary in build_records(farm):
		var cell: Vector2i = record[&"cell"] as Vector2i
		var chunk: Vector2i = Vector2i(
			floori(float(cell.x) / float(chunk_size)),
			floori(float(cell.y) / float(chunk_size)),
		)
		if not indexes.has(chunk):
			indexes[chunk] = []
		(indexes[chunk] as Array).append(record)
	return indexes


static func presentation_cells(farm: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for record: Dictionary in build_records(farm):
		var cell: Vector2i = record[&"cell"] as Vector2i
		if cell not in result:
			result.append(cell)
	result.sort_custom(
		func(first: Vector2i, second: Vector2i) -> bool:
			return first.y < second.y or (first.y == second.y and first.x < second.x)
	)
	return result


static func facility_texture_path(farm: Dictionary, facility_id: StringName) -> String:
	if facility_id == HomesteadServiceScript.HOME_ID:
		return HOME_TEXTURE.resource_path
	var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
	var state: Dictionary = HomesteadServiceScript.facility_state(farm, facility_id)
	if definition_value.is_empty() or state.is_empty():
		return ""
	if not bool(state.get(&"repaired", false)):
		var kind: StringName = definition_value[&"ruin_kind"] as StringName
		var ruin: Texture2D = OutpostVisualsScript.texture_for(kind)
		return ruin.resource_path if ruin != null else ""
	var texture: Texture2D = FACILITY_TEXTURES.get(facility_id) as Texture2D
	return texture.resource_path if texture != null else ""


static func animal_frame_index(animal_id: StringName, species_id: StringName) -> int:
	var value: int = 2_166_136_261
	for character: int in String("%s|%s" % [animal_id, species_id]).to_utf8_buffer():
		value = int((value ^ character) * 16_777_619) & 0x7fffffff
	return posmod(value, LivestockServiceScript.ATLAS_COLUMNS * LivestockServiceScript.ATLAS_ROWS)


static func animal_atlas_region(animal_id: StringName, species_id: StringName) -> Rect2:
	var frame: int = animal_frame_index(animal_id, species_id)
	var column: int = frame % LivestockServiceScript.ATLAS_COLUMNS
	var row: int = frame / LivestockServiceScript.ATLAS_COLUMNS
	return Rect2(
		column * LivestockServiceScript.FRAME_SIZE.x,
		row * LivestockServiceScript.FRAME_SIZE.y,
		LivestockServiceScript.FRAME_SIZE.x,
		LivestockServiceScript.FRAME_SIZE.y,
	)


static func _home_record(home: Dictionary) -> Dictionary:
	var raw_cell: Array = home.get(&"cell", []) as Array
	return {
		&"cell": Vector2i(int(raw_cell[0]), int(raw_cell[1])),
		&"anchor": HomesteadServiceScript.HOME_CELL,
		&"kind": &"structure",
		&"type": &"structure",
		&"stable_id": HomesteadServiceScript.HOME_ID,
		&"texture": HOME_TEXTURE,
		&"texture_path": HOME_TEXTURE.resource_path,
		&"draw_size": STRUCTURE_SIZE,
		&"draw_offset": STRUCTURE_OFFSET,
		&"repaired": bool(home.get(&"repaired", false)),
		&"powered": bool(home.get(&"powered", false)),
	}


static func _facility_record(farm: Dictionary, facility_id: StringName) -> Dictionary:
	var definition_value: Dictionary = HomesteadServiceScript.definition(facility_id)
	var state: Dictionary = HomesteadServiceScript.facility_state(farm, facility_id)
	if definition_value.is_empty() or state.is_empty():
		return {}
	var repaired: bool = bool(state.get(&"repaired", false))
	var ruin_kind: StringName = definition_value[&"ruin_kind"] as StringName
	var texture: Texture2D = (
		FACILITY_TEXTURES.get(facility_id) as Texture2D
		if repaired
		else OutpostVisualsScript.texture_for(ruin_kind)
	)
	if texture == null:
		return {}
	var cell: Vector2i = definition_value[&"cell"] as Vector2i
	return {
		&"cell": cell,
		&"anchor": cell,
		&"kind": &"structure",
		&"type": &"structure",
		&"stable_id": facility_id,
		&"texture": texture,
		&"texture_path": texture.resource_path,
		&"draw_size": STRUCTURE_SIZE,
		&"draw_offset": STRUCTURE_OFFSET,
		&"repaired": repaired,
		&"powered": bool(state.get(&"powered", false)),
		&"service_active": repaired and bool(state.get(&"powered", false)),
		&"ruin_kind": ruin_kind,
	}


static func _resident_record(schedule: Dictionary) -> Dictionary:
	var resident_id: StringName = schedule.get(&"resident_id", &"") as StringName
	var texture: Texture2D = RESIDENT_TEXTURES.get(resident_id) as Texture2D
	if texture == null:
		return {}
	var cell: Vector2i = schedule[&"cell"] as Vector2i
	return {
		&"cell": cell,
		&"anchor": cell,
		&"kind": &"resident",
		&"type": &"resident",
		&"stable_id": resident_id,
		&"texture": texture,
		&"texture_path": texture.resource_path,
		&"draw_size": PERSON_SIZE,
		&"draw_offset": PERSON_OFFSET,
	}


static func _animal_record(animal: Dictionary, index: int) -> Dictionary:
	if index < 0 or index >= ANIMAL_CELLS.size():
		return {}
	var species_id: StringName = StringName(str(animal.get(&"species_id", "")))
	var animal_id: StringName = StringName(str(animal.get(&"animal_id", "")))
	var hook: Dictionary = LivestockServiceScript.presentation_hook(species_id)
	var texture: Texture2D = hook.get(&"texture", null) as Texture2D
	if texture == null:
		return {}
	var cell: Vector2i = ANIMAL_CELLS[index]
	return {
		&"cell": cell,
		&"anchor": cell,
		&"kind": &"resident",
		&"type": &"livestock",
		&"stable_id": animal_id,
		&"species_id": species_id,
		&"texture": texture,
		&"texture_path": texture.resource_path,
		&"atlas_region": animal_atlas_region(animal_id, species_id),
		&"frame_index": animal_frame_index(animal_id, species_id),
		&"draw_size": ANIMAL_SIZE,
		&"draw_offset": ANIMAL_OFFSET,
	}
