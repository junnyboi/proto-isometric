extends RefCounted

const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")
const KIND_BROADLEAF: StringName = WoodlandClearingScript.KIND_BROADLEAF
const KIND_CONIFER: StringName = WoodlandClearingScript.KIND_CONIFER
const KIND_POND: StringName = &"woodland_pond"
const TEXTURES: Dictionary = {
	KIND_BROADLEAF: preload("res://assets/woodland/woodland_broadleaf_tree.png"),
	KIND_CONIFER: preload("res://assets/woodland/woodland_conifer_tree.png"),
	KIND_POND: preload("res://assets/woodland/woodland_pond.png"),
}
const DISPLAY_SIZES: Dictionary = {
	KIND_BROADLEAF: Vector2(126.0, 126.0),
	KIND_CONIFER: Vector2(126.0, 126.0),
	KIND_POND: Vector2(216.0, 216.0),
}
const GROUND_ANCHORS: Dictionary = {
	KIND_BROADLEAF: Vector2(0.5, 0.91),
	KIND_CONIFER: Vector2(0.5, 0.92),
	KIND_POND: Vector2(0.5, 0.63),
}


static func texture_for(kind: StringName) -> Texture2D:
	return TEXTURES.get(kind) as Texture2D


static func display_size_for(kind: StringName) -> Vector2:
	return DISPLAY_SIZES.get(kind, Vector2.ZERO) as Vector2


static func draw_offset_for(kind: StringName) -> Vector2:
	var size: Vector2 = display_size_for(kind)
	var anchor: Vector2 = GROUND_ANCHORS.get(kind, Vector2(0.5, 1.0)) as Vector2
	return -size * anchor


static func get_required_paths() -> Array[String]:
	var paths: Array[String] = [
		"res://assets/textures/terrain/woodland_grass.png",
		"res://assets/textures/terrain/farm_soil.png",
	]
	for kind: StringName in [KIND_BROADLEAF, KIND_CONIFER, KIND_POND]:
		var texture: Texture2D = texture_for(kind)
		if texture != null:
			paths.append(texture.resource_path)
	return paths
