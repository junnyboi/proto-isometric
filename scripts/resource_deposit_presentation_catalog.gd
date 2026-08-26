extends RefCounted

const CatalogScript: GDScript = preload("res://scripts/resource_deposit_catalog.gd")

const SALVAGE_ATLAS: Texture2D = preload(
	"res://assets/settlement/deposits/deposit_salvage_cluster_states.png"
)
const MINERAL_ATLAS: Texture2D = preload(
	"res://assets/settlement/deposits/deposit_mineral_seam_states.png"
)
const BIOMASS_ATLAS: Texture2D = preload(
	"res://assets/settlement/deposits/deposit_biomass_patch_states.png"
)
const REGION_SIZE: Vector2 = Vector2(256.0, 256.0)


static func record(source: Dictionary, state: Dictionary) -> Dictionary:
	if not CatalogScript.validate_source(source) or state.is_empty():
		return {}
	var kind: StringName = source[&"source_kind"] as StringName
	var texture: Texture2D = _texture(kind)
	if texture == null:
		return {}
	return {
		&"cell": source[&"cell"], &"type": &"deposit", &"stable_id": source[&"source_id"],
		&"texture": texture,
		&"atlas_region": Rect2(Vector2(_frame(state) * 256.0, 0.0), REGION_SIZE),
		&"draw_size": _draw_size(kind), &"draw_offset": Vector2(0.0, -38.0),
	}


static func validate() -> bool:
	for kind: StringName in CatalogScript.SOURCE_KINDS:
		var texture: Texture2D = _texture(kind)
		if texture == null or texture.get_size() != Vector2(768.0, 256.0):
			return false
	return true


static func _frame(state: Dictionary) -> int:
	var phase: StringName = StringName(str(state.get(&"phase", "")))
	if phase == &"rich":
		return 0
	if phase == &"depleted":
		return 1
	return 2


static func _texture(source_kind: StringName) -> Texture2D:
	match source_kind:
		CatalogScript.SALVAGE:
			return SALVAGE_ATLAS
		CatalogScript.MINERAL:
			return MINERAL_ATLAS
		CatalogScript.BIOMASS:
			return BIOMASS_ATLAS
	return null


static func _draw_size(source_kind: StringName) -> Vector2:
	match source_kind:
		CatalogScript.SALVAGE:
			return Vector2(152.0, 152.0)
		CatalogScript.MINERAL:
			return Vector2(142.0, 142.0)
	return Vector2(132.0, 132.0)
