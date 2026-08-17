extends Resource

@export_category("Movement")
@export var walk_speed: float = 150.0
@export var run_multiplier: float = 1.5
@export var acceleration: float = 310.0
@export var deceleration: float = 390.0
@export var camera_response: float = 4.8
@export var camera_look_ahead_seconds: float = 0.32
@export var camera_max_lead: float = 82.0

@export_category("Chassis and Outpost")
@export var max_chassis: int = 100
@export var repair_cost: int = 5
@export var repair_amount: int = 35

@export_category("Impact Charge")
@export var impact_low_band: float = 0.4
@export var impact_high_band: float = 0.8
@export var impact_speed_threshold: float = 0.55
@export var impact_walk_gain_per_second: float = 0.16
@export var impact_run_gain_per_second: float = 0.25
@export var impact_idle_decay_per_second: float = 0.045
@export var impact_high_band_stagger_seconds: float = 0.85

@export_category("Relay")
@export var relay_link_radius_cells: float = 2.5
@export var relay_link_seconds: float = 3.5
@export var relay_dormant_seconds: float = 0.45

@export_category("Sandworm")
@export var worm_max_health: int = 4
@export var worm_attack_damage: int = 10
@export var worm_detection_range: float = 8.0
@export var worm_attack_range: float = 0.72
@export var worm_move_speed: float = 1.28
@export var worm_attack_cooldown: float = 1.15
@export var worm_emerge_seconds: float = 0.8
@export var worm_disperse_seconds: float = 1.25
@export var worm_max_count: int = 4

@export_category("Hazards")
@export var tornado_formation_seconds: float = 3.0
@export var tornado_lifetime_seconds: float = 20.0
@export var tornado_damage_per_second: float = 6.0
@export var tornado_speed: float = 3.2
@export var tornado_fade_seconds: float = 2.0
@export var sandstorm_damage_per_second: float = 3.0
@export var sandstorm_speed: float = 0.62

@export_category("World Bounds")
@export var chunk_size: int = 8
@export var stream_radius: int = 2
@export var loaded_chunk_limit: int = 25
@export var active_cell_limit: int = 1600
@export var visible_cell_limit: int = 841
@export var coordinate_limit: int = 1_000_000
@export var save_schema: int = 2


func validate() -> bool:
	return (
		walk_speed > 0.0
		and run_multiplier >= 1.0
		and acceleration > 0.0
		and deceleration > 0.0
		and max_chassis > 0
		and repair_cost >= 0
		and repair_amount > 0
		and impact_low_band > 0.0
		and impact_low_band < impact_high_band
		and impact_high_band <= 1.0
		and impact_run_gain_per_second >= impact_walk_gain_per_second
		and impact_idle_decay_per_second >= 0.0
		and relay_link_radius_cells > 0.0
		and relay_link_seconds > 0.0
		and worm_max_health > 0
		and worm_attack_damage > 0
		and worm_max_count > 0
		and tornado_formation_seconds >= 0.0
		and tornado_lifetime_seconds > 0.0
		and tornado_damage_per_second > 0.0
		and sandstorm_damage_per_second > 0.0
		and chunk_size > 0
		and stream_radius >= 0
		and loaded_chunk_limit == (stream_radius * 2 + 1) ** 2
		and active_cell_limit >= loaded_chunk_limit * chunk_size * chunk_size
		and visible_cell_limit > 0
		and coordinate_limit > 0
		and save_schema > 0
	)


func baseline_snapshot() -> Dictionary:
	return {
		&"walk_speed": walk_speed,
		&"run_multiplier": run_multiplier,
		&"acceleration": acceleration,
		&"deceleration": deceleration,
		&"camera_response": camera_response,
		&"camera_look_ahead_seconds": camera_look_ahead_seconds,
		&"camera_max_lead": camera_max_lead,
		&"max_chassis": max_chassis,
		&"repair_cost": repair_cost,
		&"repair_amount": repair_amount,
		&"impact_low_band": impact_low_band,
		&"impact_high_band": impact_high_band,
		&"impact_speed_threshold": impact_speed_threshold,
		&"impact_walk_gain_per_second": impact_walk_gain_per_second,
		&"impact_run_gain_per_second": impact_run_gain_per_second,
		&"impact_idle_decay_per_second": impact_idle_decay_per_second,
		&"impact_high_band_stagger_seconds": impact_high_band_stagger_seconds,
		&"relay_link_radius_cells": relay_link_radius_cells,
		&"relay_link_seconds": relay_link_seconds,
		&"relay_dormant_seconds": relay_dormant_seconds,
		&"worm_max_health": worm_max_health,
		&"worm_attack_damage": worm_attack_damage,
		&"worm_detection_range": worm_detection_range,
		&"worm_attack_range": worm_attack_range,
		&"worm_move_speed": worm_move_speed,
		&"worm_attack_cooldown": worm_attack_cooldown,
		&"worm_emerge_seconds": worm_emerge_seconds,
		&"worm_disperse_seconds": worm_disperse_seconds,
		&"worm_max_count": worm_max_count,
		&"tornado_formation_seconds": tornado_formation_seconds,
		&"tornado_lifetime_seconds": tornado_lifetime_seconds,
		&"tornado_damage_per_second": tornado_damage_per_second,
		&"tornado_speed": tornado_speed,
		&"tornado_fade_seconds": tornado_fade_seconds,
		&"sandstorm_damage_per_second": sandstorm_damage_per_second,
		&"sandstorm_speed": sandstorm_speed,
		&"chunk_size": chunk_size,
		&"stream_radius": stream_radius,
		&"loaded_chunk_limit": loaded_chunk_limit,
		&"active_cell_limit": active_cell_limit,
		&"visible_cell_limit": visible_cell_limit,
		&"coordinate_limit": coordinate_limit,
		&"save_schema": save_schema,
	}
