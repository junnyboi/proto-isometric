extends Resource

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

@export var module_id: StringName
@export var display_name: String = ""
@export var category: StringName
@export var summary: String = ""
@export var core_cost: int = 1
@export var scrap_cost: int = 2
@export var effect_value: float = 0.0
@export var icon: Texture2D


func validate() -> bool:
	return (
		module_id in RuntimeIdsScript.catalog()[&"modules"]
		and module_id != RuntimeIdsScript.MODULE_WORN_PLATES
		and not display_name.is_empty()
		and display_name.length() <= 24
		and category in [&"drive", &"impact", &"cooling"]
		and not summary.is_empty()
		and summary.length() <= 48
		and core_cost >= 0
		and core_cost <= 9
		and scrap_cost >= 0
		and scrap_cost <= 99
		and is_finite(effect_value)
		and effect_value > 0.0
		and effect_value <= 2.0
		and icon != null
	)


func snapshot() -> Dictionary:
	if not validate():
		return {}
	return {
		&"module_id": module_id,
		&"display_name": display_name,
		&"category": category,
		&"summary": summary,
		&"core_cost": core_cost,
		&"scrap_cost": scrap_cost,
		&"effect_value": effect_value,
		&"icon": icon,
	}
