extends RefCounted

const WildFloraCatalogScript: GDScript = preload("res://scripts/wild_flora_catalog.gd")
const WoodlandClearingScript: GDScript = preload("res://scripts/woodland_clearing.gd")

const PRESENCE_MODULUS: int = 1000
const PRESENCE_THRESHOLD: int = 110
const PRESENCE_SALT: int = 0x464C4F52
const SPECIES_SALT: int = 0x53454544


static func candidate_species_at(cell: Vector2i, world_seed: int) -> StringName:
	if (
		not WoodlandClearingScript.contains(cell)
		or WoodlandClearingScript.is_protected_path(cell)
		or WoodlandClearingScript.is_farm_apron(cell)
	):
		return &""
	var presence: int = WoodlandClearingScript.cell_hash(cell, world_seed ^ PRESENCE_SALT)
	if posmod(presence, PRESENCE_MODULUS) >= PRESENCE_THRESHOLD:
		return &""
	var roll: int = WoodlandClearingScript.cell_hash(cell, world_seed ^ SPECIES_SALT)
	return WildFloraCatalogScript.species_for_weight_roll(roll)


static func density_for_seed(world_seed: int) -> float:
	var eligible: int = 0
	var occupied: int = 0
	for y: int in range(
		WoodlandClearingScript.CENTER.y - 13,
		WoodlandClearingScript.CENTER.y + 14,
	):
		for x: int in range(
			WoodlandClearingScript.CENTER.x - 13,
			WoodlandClearingScript.CENTER.x + 14,
		):
			var cell: Vector2i = Vector2i(x, y)
			if (
				not WoodlandClearingScript.contains(cell)
				or WoodlandClearingScript.is_protected_path(cell)
				or WoodlandClearingScript.is_farm_apron(cell)
			):
				continue
			eligible += 1
			occupied += 1 if candidate_species_at(cell, world_seed) != &"" else 0
	return 0.0 if eligible == 0 else float(occupied) / float(eligible)
