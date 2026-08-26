extends RefCounted

const WildFloraCatalogScript: GDScript = preload("res://scripts/wild_flora_catalog.gd")

const MATURE_PATHS: Dictionary = {
	WildFloraCatalogScript.SPECIES_STARFLOWER:
		"res://assets/flora/wild_starflower_mature.png",
	WildFloraCatalogScript.SPECIES_BRAMBLEBERRY:
		"res://assets/flora/wild_brambleberry_mature.png",
	WildFloraCatalogScript.SPECIES_SUNPEAR: "res://assets/flora/wild_sunpear_mature.png",
	WildFloraCatalogScript.SPECIES_WILDWHEAT: "res://assets/flora/wild_wildwheat_mature.png",
	WildFloraCatalogScript.SPECIES_COTTON: "res://assets/flora/wild_cotton_mature.png",
}
const DRAW_SIZES: Dictionary = {
	WildFloraCatalogScript.SPECIES_STARFLOWER: Vector2(94.0, 94.0),
	WildFloraCatalogScript.SPECIES_BRAMBLEBERRY: Vector2(98.0, 98.0),
	WildFloraCatalogScript.SPECIES_SUNPEAR: Vector2(118.0, 118.0),
	WildFloraCatalogScript.SPECIES_WILDWHEAT: Vector2(100.0, 108.0),
	WildFloraCatalogScript.SPECIES_COTTON: Vector2(102.0, 106.0),
}
static var _runtime_textures: Dictionary = {}


static func texture_for(species_id: StringName) -> Texture2D:
	if _runtime_textures.has(species_id):
		return _runtime_textures[species_id] as Texture2D
	var path: String = str(MATURE_PATHS.get(species_id, ""))
	if path.is_empty():
		return null
	var source: Texture2D = load(path) as Texture2D
	if source == null:
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(source.get_image())
	_runtime_textures[species_id] = texture
	return texture


static func display_size_for(species_id: StringName) -> Vector2:
	return DRAW_SIZES.get(species_id, Vector2(96.0, 96.0)) as Vector2


static func draw_offset_for(species_id: StringName) -> Vector2:
	var size: Vector2 = display_size_for(species_id)
	return Vector2(-size.x * 0.5, 12.0 - size.y)


static func validate() -> bool:
	if not WildFloraCatalogScript.validate(true):
		return false
	for species_id: StringName in WildFloraCatalogScript.SPECIES_IDS:
		var texture: Texture2D = texture_for(species_id)
		var size: Vector2 = display_size_for(species_id)
		if texture == null or size.x <= 0.0 or size.y <= 0.0:
			return false
	return true
