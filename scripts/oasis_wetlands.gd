extends RefCounted

const BIOME_DESERT: StringName = &"desert"
const BIOME_OASIS: StringName = &"oasis"
const OASIS_ENTRY_X: int = 18
const MUD_SPEED_MULTIPLIER: float = 0.62
const PATCH_SIZE: int = 12
const PATCH_RADIUS: Vector2 = Vector2(4.5, 3.4)
const PATCH_SALT: int = 0x0A515


static func biome_at(cell: Vector2i) -> StringName:
	return BIOME_OASIS if cell.x >= OASIS_ENTRY_X else BIOME_DESERT


static func surface_for(
	cell: Vector2i, base_terrain: StringName, in_sanctuary: bool = false
) -> StringName:
	if biome_at(cell) != BIOME_OASIS or base_terrain not in [&"sand", &"salt"]:
		return base_terrain
	if in_sanctuary:
		return &"wetland"
	return &"mud" if is_mud_cell(cell) else &"wetland"


static func is_mud(surface: StringName) -> bool:
	return surface == &"mud"


static func is_mud_cell(cell: Vector2i) -> bool:
	if biome_at(cell) != BIOME_OASIS:
		return false
	if Vector2(cell).distance_to(Vector2(23, 10)) <= 4.2:
		return true
	var patch: Vector2i = Vector2i(
		floori(float(cell.x - OASIS_ENTRY_X) / float(PATCH_SIZE)),
		floori(float(cell.y) / float(PATCH_SIZE)),
	)
	var center: Vector2 = Vector2(
		float(OASIS_ENTRY_X + patch.x * PATCH_SIZE + PATCH_SIZE / 2),
		float(patch.y * PATCH_SIZE + PATCH_SIZE / 2),
	)
	var hash: int = _cell_hash(patch, PATCH_SALT)
	center += Vector2(posmod(hash, 5) - 2, posmod(hash >> 5, 5) - 2)
	var delta: Vector2 = Vector2(cell) - center
	var distance: float = (
		(delta.x * delta.x) / (PATCH_RADIUS.x * PATCH_RADIUS.x)
		+ (delta.y * delta.y) / (PATCH_RADIUS.y * PATCH_RADIUS.y)
	)
	return distance <= 1.0


static func _cell_hash(cell: Vector2i, salt: int) -> int:
	var value: int = cell.x * 73856093 ^ cell.y * 19349663 ^ salt * 83492791
	value = (value ^ (value >> 13)) * 1274126177
	return value ^ (value >> 16)
