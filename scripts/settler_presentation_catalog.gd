extends RefCounted

const HousingScript: GDScript = preload("res://scripts/housing_protection_service.gd")
const SettlerDayScript: GDScript = preload("res://scripts/settler_day_service.gd")
const SettlerCatalogScript: GDScript = preload("res://scripts/settler_catalog.gd")

const TEXTURES: Dictionary = {
	SettlerCatalogScript.AMARA_VOSS:
	preload("res://assets/settlement/settlers/sprites/settler_amara_voss.png"),
	SettlerCatalogScript.TOMAS_REED:
	preload("res://assets/settlement/settlers/sprites/settler_tomas_reed.png"),
	SettlerCatalogScript.KEIKO_TAN:
	preload("res://assets/settlement/settlers/sprites/settler_keiko_tan.png"),
	SettlerCatalogScript.MALIK_OKAFOR:
	preload("res://assets/settlement/settlers/sprites/settler_malik_okafor.png"),
	SettlerCatalogScript.ELENA_MOROZ:
	preload("res://assets/settlement/settlers/sprites/settler_elena_moroz.png"),
	SettlerCatalogScript.NOOR_HADDAD:
	preload("res://assets/settlement/settlers/sprites/settler_noor_haddad.png"),
	SettlerCatalogScript.ISHAN_PATEL:
	preload("res://assets/settlement/settlers/sprites/settler_ishan_patel.png"),
	SettlerCatalogScript.MAEVE_QUINN:
	preload("res://assets/settlement/settlers/sprites/settler_maeve_quinn.png"),
}
const BED_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2), Vector2i(2, 1),
]
const DRAW_SIZE: Vector2 = Vector2(104.0, 156.0)
const DRAW_OFFSET: Vector2 = Vector2(0.0, -66.0)


static func build_records(farm: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var homestead: Dictionary = farm.get(&"homestead", {}) as Dictionary
	var workforce: Dictionary = homestead.get(&"workforce", {}) as Dictionary
	for settler: Dictionary in workforce.get(&"settlers", []) as Array[Dictionary]:
		var settler_id: StringName = StringName(str(settler[&"settler_id"]))
		var texture: Texture2D = TEXTURES.get(settler_id) as Texture2D
		var housing: Dictionary = _housing(workforce, settler_id)
		var bed: Dictionary = HousingScript.bed(farm, str(housing.get(&"bed_id", "")))
		if texture == null or bed.is_empty():
			continue
		var slot: int = int(bed[&"slot"])
		var base_cell: Vector2i = bed[&"cell"] as Vector2i
		var cell: Vector2i = base_cell + BED_OFFSETS[slot % BED_OFFSETS.size()]
		var work_status: StringName = SettlerDayScript.presentation_status(farm, settler_id)
		if work_status in [SettlerDayScript.WORKING, SettlerDayScript.CARRYING]:
			var work_cell: Vector2i = SettlerDayScript.work_cell(farm, settler_id)
			if absi(work_cell.x) < 1_000_000 and absi(work_cell.y) < 1_000_000:
				cell = work_cell
		result.append(
			{
				&"cell": cell,
				&"anchor": cell,
				&"kind": &"settler",
				&"type": &"resident",
				&"stable_id": settler_id,
				&"texture": texture,
				&"texture_path": texture.resource_path,
				&"draw_size": DRAW_SIZE,
				&"draw_offset": DRAW_OFFSET,
					&"status": work_status,
					&"settler_state": StringName(str(settler[&"status"])),
				&"bed_id": str(bed[&"bed_id"]),
			}
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a[&"stable_id"]) < str(b[&"stable_id"])
	)
	return result


static func build_chunk_indexes(farm: Dictionary, chunk_size: int = 8) -> Dictionary:
	var result: Dictionary = {}
	if chunk_size <= 0:
		return result
	for record: Dictionary in build_records(farm):
		var cell: Vector2i = record[&"cell"] as Vector2i
		var chunk: Vector2i = Vector2i(
			floori(float(cell.x) / float(chunk_size)),
			floori(float(cell.y) / float(chunk_size)),
		)
		if not result.has(chunk):
			result[chunk] = []
		(result[chunk] as Array).append(record)
	return result


static func presentation_cells(farm: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for record: Dictionary in build_records(farm):
		result.append(record[&"cell"] as Vector2i)
	return result


static func validate() -> bool:
	if TEXTURES.size() != SettlerCatalogScript.IDS.size():
		return false
	for settler_id: StringName in SettlerCatalogScript.IDS:
		var texture: Texture2D = TEXTURES.get(settler_id) as Texture2D
		if texture == null or texture.get_size() != Vector2(256, 384):
			return false
	return true


static func _housing(workforce: Dictionary, settler_id: StringName) -> Dictionary:
	for assignment: Dictionary in workforce.get(&"housing_assignments", []) as Array[Dictionary]:
		if str(assignment[&"settler_id"]) == str(settler_id):
			return assignment.duplicate(true)
	return {}
