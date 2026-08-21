extends RefCounted

const KIND_RUIN: StringName = &"ancient_ruin"
const KIND_TEMPLE: StringName = &"ancient_temple"
const KIND_ZIGGURAT: StringName = &"ancient_ziggurat"
const KIND_PALACE: StringName = &"ancient_palace"
const KIND_SAFEHOUSE: StringName = &"ancient_safehouse"

const KINDS: Array[StringName] = [
	KIND_RUIN,
	KIND_TEMPLE,
	KIND_ZIGGURAT,
	KIND_PALACE,
	KIND_SAFEHOUSE,
]
const TEXTURES: Dictionary = {
	KIND_RUIN: preload("res://assets/outposts/ancient_ruin.png"),
	KIND_TEMPLE: preload("res://assets/outposts/ancient_temple.png"),
	KIND_ZIGGURAT: preload("res://assets/outposts/ancient_ziggurat.png"),
	KIND_PALACE: preload("res://assets/outposts/ancient_palace.png"),
	KIND_SAFEHOUSE: preload("res://assets/outposts/ancient_safehouse.png"),
}
const DISPLAY_SIZES: Dictionary = {
	KIND_RUIN: Vector2(196.0, 196.0),
	KIND_TEMPLE: Vector2(184.0, 184.0),
	KIND_ZIGGURAT: Vector2(190.0, 190.0),
	KIND_PALACE: Vector2(198.0, 198.0),
	KIND_SAFEHOUSE: Vector2(178.0, 178.0),
}
const BEACON_POINTS: Dictionary = {
	KIND_RUIN: Vector2(0.47, 0.29),
	KIND_TEMPLE: Vector2(0.50, 0.18),
	KIND_ZIGGURAT: Vector2(0.50, 0.23),
	KIND_PALACE: Vector2(0.60, 0.22),
	KIND_SAFEHOUSE: Vector2(0.67, 0.34),
}
const BASE_OFFSET: Vector2 = Vector2(0.0, 16.0)


static func kind_for(cell: Vector2i) -> StringName:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ 0x0A77 * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	value = value ^ (value >> 16)
	return KINDS[posmod(value, KINDS.size())]


static func texture_for(kind: StringName) -> Texture2D:
	return TEXTURES.get(kind) as Texture2D


static func display_size_for(kind: StringName) -> Vector2:
	return DISPLAY_SIZES.get(kind, Vector2.ZERO) as Vector2


static func beacon_offset_for(kind: StringName) -> Vector2:
	var size: Vector2 = display_size_for(kind)
	var point: Vector2 = BEACON_POINTS.get(kind, Vector2(0.5, 0.25)) as Vector2
	return BASE_OFFSET - size * Vector2(0.5, 1.0) + size * point


static func get_required_paths() -> Array[String]:
	var result: Array[String] = []
	for kind: StringName in KINDS:
		var texture: Texture2D = texture_for(kind)
		if texture != null:
			result.append(texture.resource_path)
	return result
