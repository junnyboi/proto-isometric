extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")
const RuntimeOwnershipScript: GDScript = preload("res://scripts/runtime_ownership.gd")
const IsometricMapScript: GDScript = preload("res://scripts/isometric_map.gd")
const ImpactChargeScript: GDScript = preload("res://scripts/impact_charge.gd")
const RelayContestScript: GDScript = preload("res://scripts/relay_contest.gd")
const SandwormsScript: GDScript = preload("res://scripts/sandworms.gd")
const DesertHazardsScript: GDScript = preload("res://scripts/desert_hazards.gd")
const InfiniteWorldScript: GDScript = preload("res://scripts/infinite_world.gd")
const OasisWetlandsScript: GDScript = preload("res://scripts/oasis_wetlands.gd")
const LavaFieldsScript: GDScript = preload("res://scripts/lava_fields.gd")
const SurfaceDriveScript: GDScript = preload("res://scripts/surface_drive.gd")


static func evaluate(coordinator: RefCounted) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_add_case(cases, "stable ID registry validates", RuntimeIdsScript.validate_catalog())
	_add_case(cases, "runtime ownership registry validates", RuntimeOwnershipScript.validate())
	_add_case(
		cases,
		"stable ID registry version is pinned",
		RuntimeIdsScript.LEGACY_REGISTRY_VERSION == 6 and RuntimeIdsScript.REGISTRY_VERSION == 10,
	)
	_add_case(
		cases,
		"Worn Plates starter module ID is stable",
		RuntimeIdsScript.MODULE_WORN_PLATES == &"module.worn_plates",
	)
	var unique_ids: Dictionary = {}
	for identifier: StringName in RuntimeIdsScript.all_ids():
		unique_ids[identifier] = true
	_add_case(
		cases,
		"stable IDs are globally unique",
		unique_ids.size() == RuntimeIdsScript.all_ids().size(),
	)
	_add_case(
		cases,
		"starter relay ID remains stable",
		RuntimeIdsScript.OBJECTIVE_STARTER_RELAY == &"objective.relay.starter.v1",
	)
	_add_case(
		cases,
		"run lifecycle vocabulary is stable",
		(
			RuntimeIdsScript.catalog()[&"run_phases"]
			== [
				&"run_phase.bootstrap",
				&"run_phase.hunt",
				&"run_phase.extraction_ready",
				&"run_phase.succeeded",
				&"run_phase.failed",
			]
		),
	)
	for domain_id: StringName in RuntimeIdsScript.domain_ids():
		_add_case(
			cases,
			"owner exists for %s" % domain_id,
			RuntimeOwnershipScript.owner_for(domain_id) != &"",
		)
	_add_case(
		cases,
		"field map owns composition only",
		(
			(
				RuntimeOwnershipScript
				. contract_for(RuntimeIdsScript.DOMAIN_FIELD_COMPOSITION)[&"current_policy"]
			)
			== RuntimeOwnershipScript.POLICY_COMPOSITION_ONLY
		),
	)
	_add_case(
		cases,
		"active-run authority is the coordinator",
		(
			RuntimeOwnershipScript.current_owner_for(RuntimeIdsScript.DOMAIN_ACTIVE_RUN)
			== RuntimeIdsScript.OWNER_RUN_COORDINATOR
		),
	)
	_add_case(
		cases,
		"active-run ownership is stable",
		(
			RuntimeOwnershipScript.owner_for(RuntimeIdsScript.DOMAIN_ACTIVE_RUN)
			== RuntimeIdsScript.OWNER_RUN_COORDINATOR
		),
	)
	_add_case(
		cases,
		"profile authority is ProfileState",
		(
			RuntimeOwnershipScript.current_owner_for(RuntimeIdsScript.DOMAIN_PROFILE)
			== RuntimeIdsScript.OWNER_PROFILE_STATE
		),
	)
	_add_case(
		cases,
		"schema-4 persistence authority is SaveRepository",
		(
			RuntimeOwnershipScript.current_owner_for(RuntimeIdsScript.DOMAIN_PERSISTENCE)
			== RuntimeIdsScript.OWNER_SAVE_REPOSITORY
		),
	)
	_add_case(
		cases,
		"semantic feedback presentation has stable ownership",
		(
			RuntimeOwnershipScript.current_owner_for(RuntimeIdsScript.DOMAIN_FEEDBACK)
			== RuntimeIdsScript.OWNER_FEEDBACK_ROUTER
		),
	)
	_test_harvest_ownership(cases)
	_add_case(cases, "neutral run coordinator exists", coordinator != null)
	if coordinator == null:
		return cases
	_add_case(
		cases,
		"neutral run coordinator is configured",
		bool(coordinator.call("is_configured")),
	)
	_add_case(
		cases,
		"WW-02 typed ownership remains behavior-neutral",
		bool(coordinator.call("is_behavior_neutral")),
	)
	_add_case(
		cases,
		"coordinator reports stable registry version",
		int(coordinator.call("get_registry_version")) == RuntimeIdsScript.REGISTRY_VERSION,
	)
	_add_case(
		cases,
		"coordinator exposes world authority",
		(
			coordinator.call("owner_for", RuntimeIdsScript.DOMAIN_WORLD)
			== RuntimeIdsScript.OWNER_INFINITE_WORLD
		),
	)
	_test_balance_snapshot(cases, coordinator.call("get_balance_snapshot") as Dictionary)
	_test_contract_snapshot(cases, coordinator)
	_test_telemetry(cases, coordinator)
	_test_worn_plates(cases)
	return cases


static func _test_harvest_ownership(cases: Array[Dictionary]) -> void:
	var contracts: Array[Dictionary] = [
		{
			&"domain": RuntimeIdsScript.DOMAIN_FARM,
			&"owner": RuntimeIdsScript.OWNER_FARM_STATE,
			&"scope": RuntimeOwnershipScript.SCOPE_FARM,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_CALENDAR_WEATHER,
			&"owner": RuntimeIdsScript.OWNER_CALENDAR_WEATHER,
			&"scope": RuntimeOwnershipScript.SCOPE_CALENDAR_WEATHER,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_INVENTORY_ECONOMY,
			&"owner": RuntimeIdsScript.OWNER_INVENTORY_ECONOMY,
			&"scope": RuntimeOwnershipScript.SCOPE_INVENTORY_ECONOMY,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_HOMESTEAD_SETTLEMENT,
			&"owner": RuntimeIdsScript.OWNER_HOMESTEAD_SETTLEMENT,
			&"scope": RuntimeOwnershipScript.SCOPE_HOMESTEAD_SETTLEMENT,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_TOOLS_INTERACTIONS,
			&"owner": RuntimeIdsScript.OWNER_TOOL_INTERACTION,
			&"scope": RuntimeOwnershipScript.SCOPE_TOOLS_INTERACTIONS,
		},
		{
			&"domain": RuntimeIdsScript.DOMAIN_ECOLOGY,
			&"owner": RuntimeIdsScript.OWNER_ECOLOGY,
			&"scope": RuntimeOwnershipScript.SCOPE_ECOLOGY,
		},
	]
	for expected: Dictionary in contracts:
		var domain_id: StringName = expected[&"domain"] as StringName
		var owner_id: StringName = expected[&"owner"] as StringName
		var contract: Dictionary = RuntimeOwnershipScript.contract_for(domain_id)
		var is_stable: bool = domain_id in [
			RuntimeIdsScript.DOMAIN_HOMESTEAD_SETTLEMENT,
			RuntimeIdsScript.DOMAIN_ECOLOGY,
		]
		_add_case(
			cases,
			"Harvest owner and scope are explicit for %s" % domain_id,
			(
				RuntimeOwnershipScript.owner_for(domain_id) == owner_id
				and contract[&"state_scope"] == expected[&"scope"]
				and contract[&"migration_state"]
				== (
					RuntimeOwnershipScript.MIGRATION_STABLE
					if is_stable
					else RuntimeOwnershipScript.MIGRATION_PLANNED
				)
			),
		)
		_add_case(
			cases,
			"Harvest domain rejects cross-domain mutation for %s" % domain_id,
			(
				RuntimeOwnershipScript.can_target_mutation(domain_id, owner_id)
				and not RuntimeOwnershipScript.can_target_mutation(
					domain_id, RuntimeIdsScript.OWNER_SAVE_REPOSITORY
				)
				and RuntimeOwnershipScript.can_mutate(domain_id, owner_id) == is_stable
			),
		)


static func _test_balance_snapshot(cases: Array[Dictionary], balance: Dictionary) -> void:
	var expected: Dictionary = {
		&"walk_speed": IsometricMapScript.WALK_SPEED,
		&"run_multiplier": IsometricMapScript.RUN_MULTIPLIER,
		&"acceleration": IsometricMapScript.ACCELERATION,
		&"deceleration": IsometricMapScript.DECELERATION,
		&"camera_response": IsometricMapScript.CAMERA_RESPONSE,
		&"camera_look_ahead_seconds": IsometricMapScript.CAMERA_LOOK_AHEAD_SECONDS,
		&"camera_max_lead": IsometricMapScript.CAMERA_MAX_LEAD,
		&"mud_speed_multiplier": OasisWetlandsScript.MUD_SPEED_MULTIPLIER,
		&"ice_longitudinal_acceleration": SurfaceDriveScript.ICE_LONGITUDINAL_ACCELERATION,
		&"ice_lateral_acceleration": SurfaceDriveScript.ICE_LATERAL_ACCELERATION,
		&"ice_drag": SurfaceDriveScript.ICE_DRAG,
		&"max_chassis": IsometricMapScript.MAX_CHASSIS,
		&"repair_cost": IsometricMapScript.REPAIR_COST,
		&"repair_amount": IsometricMapScript.REPAIR_AMOUNT,
		&"impact_low_band": ImpactChargeScript.LOW_BAND_MAX,
		&"impact_high_band": ImpactChargeScript.MID_BAND_MAX,
		&"impact_speed_threshold": ImpactChargeScript.CHARGE_SPEED_THRESHOLD,
		&"impact_walk_gain_per_second": ImpactChargeScript.WALK_GAIN_PER_SECOND,
		&"impact_run_gain_per_second": ImpactChargeScript.RUN_GAIN_PER_SECOND,
		&"impact_idle_decay_per_second": ImpactChargeScript.IDLE_DECAY_PER_SECOND,
		&"relay_link_radius_cells": RelayContestScript.LINK_RADIUS_CELLS,
		&"relay_link_seconds": RelayContestScript.LINK_SECONDS,
		&"relay_dormant_seconds": RelayContestScript.DORMANT_SECONDS,
		&"worm_max_health": SandwormsScript.MAX_HEALTH,
		&"worm_attack_damage": SandwormsScript.ATTACK_DAMAGE,
		&"worm_detection_range": SandwormsScript.DETECTION_RANGE,
		&"worm_attack_range": SandwormsScript.ATTACK_RANGE,
		&"worm_move_speed": SandwormsScript.MOVE_SPEED,
		&"worm_attack_cooldown": SandwormsScript.ATTACK_COOLDOWN,
		&"worm_emerge_seconds": SandwormsScript.EMERGE_SECONDS,
		&"worm_disperse_seconds": SandwormsScript.DISPERSE_SECONDS,
		&"worm_max_count": SandwormsScript.MAX_WORMS,
		&"tornado_formation_seconds": DesertHazardsScript.TORNADO_FORMATION_SECONDS,
		&"tornado_lifetime_seconds": DesertHazardsScript.TORNADO_LIFETIME_SECONDS,
		&"tornado_damage_per_second": DesertHazardsScript.TORNADO_DAMAGE_PER_SECOND,
		&"tornado_speed": DesertHazardsScript.TORNADO_SPEED,
		&"tornado_fade_seconds": DesertHazardsScript.TORNADO_FADE_SECONDS,
		&"sandstorm_damage_per_second": DesertHazardsScript.SANDSTORM_DAMAGE_PER_SECOND,
		&"sandstorm_speed": DesertHazardsScript.SANDSTORM_SPEED,
		&"lava_damage_per_tick": LavaFieldsScript.LAVA_DAMAGE,
		&"lava_tick_seconds": LavaFieldsScript.LAVA_TICK_SECONDS,
		&"chunk_size": InfiniteWorldScript.CHUNK_SIZE,
		&"stream_radius": InfiniteWorldScript.STREAM_RADIUS,
		&"coordinate_limit": InfiniteWorldScript.COORDINATE_LIMIT,
		&"playable_half_extent": InfiniteWorldScript.PLAYABLE_HALF_EXTENT,
		&"save_schema": IsometricMapScript.SAVE_SCHEMA,
	}
	_add_case(cases, "default balance snapshot is populated", balance.size() >= expected.size())
	for key: StringName in expected:
		_add_case(
			cases,
			"default balance preserves %s" % key,
			_values_match(balance.get(key), expected[key]),
		)
	_add_case(cases, "loaded chunk contract remains 25", int(balance[&"loaded_chunk_limit"]) == 25)
	_add_case(
		cases, "active cell contract remains 1600", int(balance[&"active_cell_limit"]) == 1600
	)
	_add_case(
		cases, "visible cell contract remains 841", int(balance[&"visible_cell_limit"]) == 841
	)


static func _test_contract_snapshot(cases: Array[Dictionary], coordinator: RefCounted) -> void:
	var contracts: Array[Dictionary] = (
		coordinator.call("get_contract_snapshot") as Array[Dictionary]
	)
	_add_case(
		cases,
		"coordinator exposes one contract per domain",
		contracts.size() == RuntimeIdsScript.domain_ids().size(),
	)
	contracts[0][&"target_owner_id"] = &"owner.mutated_test_copy"
	var fresh_contracts: Array[Dictionary] = (
		coordinator.call("get_contract_snapshot") as Array[Dictionary]
	)
	_add_case(
		cases,
		"ownership snapshots are detached",
		fresh_contracts[0][&"target_owner_id"] != &"owner.mutated_test_copy",
	)


static func _test_worn_plates(cases: Array[Dictionary]) -> void:
	var starter: Node2D = ImpactChargeScript.new() as Node2D
	starter.call("advance_drive", 1.0, false, 1.0)
	_add_case(
		cases,
		"Worn Plates raises only Impact Charge gain by fifteen percent",
		is_equal_approx(
			float(starter.call("get_charge")),
			(
				ImpactChargeScript.WALK_GAIN_PER_SECOND
				* ImpactChargeScript.WORN_PLATES_GAIN_MULTIPLIER
			),
		),
	)
	var baseline: Node2D = ImpactChargeScript.new() as Node2D
	baseline.call("set_gain_multiplier", 1.0)
	baseline.call("advance_drive", 1.0, false, 1.0)
	_add_case(
		cases,
		"Worn Plates does not alter Impact footprint geometry",
		(
			starter.call("footprint", Vector2i.ZERO, Vector2i.RIGHT, 2)
			== baseline.call("footprint", Vector2i.ZERO, Vector2i.RIGHT, 2)
		),
	)
	starter.call("set_charge", 0.5)
	starter.call("advance_drive", 0.0, false, 1.0)
	_add_case(
		cases,
		"Worn Plates does not alter idle charge decay",
		is_equal_approx(
			float(starter.call("get_charge")), 0.5 - ImpactChargeScript.IDLE_DECAY_PER_SECOND
		),
	)
	_add_case(
		cases,
		"Impact gain multipliers reject unsafe values",
		(
			not bool(starter.call("set_gain_multiplier", 0.99))
			and not bool(starter.call("set_gain_multiplier", INF))
		),
	)
	starter.free()
	baseline.free()


static func _test_telemetry(cases: Array[Dictionary], coordinator: RefCounted) -> void:
	var initial_summary: Dictionary = coordinator.call("get_telemetry_summary") as Dictionary
	_add_case(cases, "telemetry is explicitly local-only", bool(initial_summary[&"local_only"]))
	_add_case(
		cases, "field-ready telemetry records once", int(initial_summary[&"event_count"]) == 1
	)
	_add_case(
		cases,
		"unknown telemetry events are rejected",
		not bool(coordinator.call("record_event", &"event.unknown")),
	)
	var payload: Dictionary = {&"message": "x".repeat(96)}
	for index: int in range(12):
		payload["field_%02d" % index] = index
	for index: int in range(70):
		coordinator.call("record_event", RuntimeIdsScript.EVENT_ATTACK_COMMITTED, payload)
	var events: Array[Dictionary] = coordinator.call("get_telemetry_events") as Array[Dictionary]
	_add_case(cases, "telemetry ring buffer remains bounded", events.size() == 64)
	var last_payload: Dictionary = events[-1][&"payload"] as Dictionary
	_add_case(cases, "telemetry payload fields are bounded", last_payload.size() == 8)
	_add_case(
		cases,
		"telemetry text is bounded",
		str(last_payload["message"]).length() == 64,
	)
	var detached: Array[Dictionary] = coordinator.call("get_telemetry_events") as Array[Dictionary]
	detached.clear()
	_add_case(
		cases,
		"telemetry snapshots are detached",
		(coordinator.call("get_telemetry_events") as Array[Dictionary]).size() == 64,
	)


static func _values_match(left: Variant, right: Variant) -> bool:
	if left is float or right is float:
		return is_equal_approx(float(left), float(right))
	return left == right


static func _add_case(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
