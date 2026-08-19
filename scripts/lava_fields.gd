extends RefCounted

const BIOME_LAVA: StringName = &"lava"
const LAVA_ENTRY_X: int = -8
const LAVA_DAMAGE: int = 8
const LAVA_TICK_SECONDS: float = 1.0


static func contains(cell: Vector2i) -> bool:
	return cell.x <= LAVA_ENTRY_X


static func surface_for(
	cell: Vector2i,
	base_terrain: StringName,
	sanctuary: bool = false,
) -> StringName:
	if base_terrain in [&"rock", &"ruin"]:
		return base_terrain
	if sanctuary:
		return &"lava_basalt"
	var value: int = posmod(cell.x * 13 + cell.y * 7 + cell.x * cell.y * 3, 100)
	if value < 36:
		return &"lava"
	if value < 54:
		return &"volcanic_ash"
	return &"lava_basalt"
