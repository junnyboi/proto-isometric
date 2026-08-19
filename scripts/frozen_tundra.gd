extends RefCounted

const BIOME_FROZEN: StringName = &"frozen"
const FROZEN_ENTRY_Y: int = -8
const ICE_LONGITUDINAL_ACCELERATION: float = 155.0
const ICE_LATERAL_ACCELERATION: float = 68.0
const ICE_DRAG: float = 24.0
const PATCH_SIZE: int = 12
const PATCH_RADIUS: Vector2 = Vector2(4.8, 3.8)
const PATCH_SALT: int = 0xF20A
const TEACHING_ICE_CENTER: Vector2 = Vector2(8, -15)


static func contains(cell: Vector2i) -> bool:
	return cell.y <= FROZEN_ENTRY_Y


static func surface_for(
	cell: Vector2i, base_terrain: StringName, in_sanctuary: bool = false
) -> StringName:
	if not contains(cell) or base_terrain not in [&"sand", &"salt"]:
		return base_terrain
	if in_sanctuary or cell.y >= FROZEN_ENTRY_Y - 1:
		return &"snow"
	return &"blue_ice" if is_ice_cell(cell) else &"snow"


static func is_ice_cell(cell: Vector2i) -> bool:
	if not contains(cell) or cell.y >= FROZEN_ENTRY_Y - 1:
		return false
	if Vector2(cell).distance_to(TEACHING_ICE_CENTER) <= 4.2:
		return true
	var patch: Vector2i = Vector2i(
		floori(float(cell.x) / float(PATCH_SIZE)),
		floori(float(cell.y - FROZEN_ENTRY_Y) / float(PATCH_SIZE)),
	)
	var center: Vector2 = Vector2(
		float(patch.x * PATCH_SIZE + PATCH_SIZE / 2),
		float(FROZEN_ENTRY_Y + patch.y * PATCH_SIZE + PATCH_SIZE / 2),
	)
	var hash: int = _cell_hash(patch, PATCH_SALT)
	center += Vector2(posmod(hash, 5) - 2, posmod(hash >> 5, 5) - 2)
	var delta: Vector2 = Vector2(cell) - center
	return (
		(
			(delta.x * delta.x) / (PATCH_RADIUS.x * PATCH_RADIUS.x)
			+ (delta.y * delta.y) / (PATCH_RADIUS.y * PATCH_RADIUS.y)
		)
		<= 1.0
	)


static func _cell_hash(cell: Vector2i, salt: int) -> int:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ salt * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)
