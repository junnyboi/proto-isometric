extends Resource

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

@export var modifier_id: StringName = RuntimeIdsScript.MODIFIER_NEUTRAL
@export var title: String = "modifier.neutral.title"
@export_multiline var description: String = "modifier.neutral.description"
@export var storm_interval_multiplier: float = 1.0
@export var relay_scrap_multiplier: int = 1
@export var worm_count_bonus: int = 0
@export var bonus_core_modulus: int = 0
@export var relay_spacing_bonus: float = 0.0
@export var repair_cost_discount: int = 0


func validate() -> bool:
	return (
		modifier_id in RuntimeIdsScript.catalog()[&"modifiers"]
		and modifier_id != RuntimeIdsScript.MODIFIER_NEUTRAL
		and not title.is_empty()
		and title.length() <= 32
		and not description.is_empty()
		and description.length() <= 160
		and storm_interval_multiplier >= 0.5
		and storm_interval_multiplier <= 1.0
		and relay_scrap_multiplier >= 1
		and relay_scrap_multiplier <= 3
		and worm_count_bonus >= 0
		and worm_count_bonus <= 1
		and bonus_core_modulus in [0, 2, 3, 4]
		and relay_spacing_bonus >= 0.0
		and relay_spacing_bonus <= 12.0
		and repair_cost_discount >= 0
		and repair_cost_discount <= 3
	)
