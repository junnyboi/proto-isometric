extends RefCounted

const REGISTRY_VERSION: int = 3

const DOMAIN_FIELD_COMPOSITION: StringName = &"domain.field_composition"
const DOMAIN_MOVEMENT: StringName = &"domain.movement"
const DOMAIN_COMBAT_INPUT: StringName = &"domain.combat_input"
const DOMAIN_IMPACT_CHARGE: StringName = &"domain.impact_charge"
const DOMAIN_WORLD: StringName = &"domain.world"
const DOMAIN_ACTIVE_RUN: StringName = &"domain.active_run"
const DOMAIN_PROFILE: StringName = &"domain.profile"
const DOMAIN_PREFERENCES: StringName = &"domain.preferences"
const DOMAIN_RELAY_RUNTIME: StringName = &"domain.relay_runtime"
const DOMAIN_ENCOUNTERS: StringName = &"domain.encounters"
const DOMAIN_HAZARDS: StringName = &"domain.hazards"
const DOMAIN_PERSISTENCE: StringName = &"domain.persistence"
const DOMAIN_FIELD_PRESENTATION: StringName = &"domain.field_presentation"
const DOMAIN_FEEDBACK: StringName = &"domain.feedback"

const OWNER_FIELD_COMPOSITION: StringName = &"owner.field_composition"
const OWNER_UNASSIGNED: StringName = &"owner.unassigned"
const OWNER_IMPACT_CHARGE: StringName = &"owner.impact_charge"
const OWNER_INFINITE_WORLD: StringName = &"owner.infinite_world"
const OWNER_RUN_COORDINATOR: StringName = &"owner.run_coordinator"
const OWNER_PROFILE_STATE: StringName = &"owner.profile_state"
const OWNER_PLAYER_PREFERENCES: StringName = &"owner.player_preferences"
const OWNER_RELAY_CONTEST: StringName = &"owner.relay_contest"
const OWNER_SANDWORMS: StringName = &"owner.sandworms"
const OWNER_DESERT_HAZARDS: StringName = &"owner.desert_hazards"
const OWNER_WORLD_STATE_STORE: StringName = &"owner.world_state_store"
const OWNER_SAVE_REPOSITORY: StringName = &"owner.save_repository"
const OWNER_FIELD_HUD: StringName = &"owner.field_hud"
const OWNER_FEEDBACK_ROUTER: StringName = &"owner.feedback_router"

const RUN_PHASE_BOOTSTRAP: StringName = &"run_phase.bootstrap"
const RUN_PHASE_HUNT: StringName = &"run_phase.hunt"
const RUN_PHASE_EXTRACTION_READY: StringName = &"run_phase.extraction_ready"
const RUN_PHASE_SUCCEEDED: StringName = &"run_phase.succeeded"
const RUN_PHASE_FAILED: StringName = &"run_phase.failed"

const EVENT_FIELD_READY: StringName = &"event.field.ready"
const EVENT_ATTACK_COMMITTED: StringName = &"event.attack.committed"
const EVENT_SCRAP_COLLECTED: StringName = &"event.scrap.collected"
const EVENT_CHASSIS_DAMAGED: StringName = &"event.chassis.damaged"
const EVENT_CHASSIS_SHUTDOWN: StringName = &"event.chassis.shutdown"
const EVENT_REPAIR_COMMITTED: StringName = &"event.repair.committed"
const EVENT_RELAY_LINK_STARTED: StringName = &"event.relay.link_started"
const EVENT_RELAY_COMPLETED: StringName = &"event.relay.completed"
const EVENT_WORM_DEFEATED: StringName = &"event.worm.defeated"
const EVENT_MODULE_PURCHASED: StringName = &"event.module.purchased"
const EVENT_RUN_EXTRACTED: StringName = &"event.run.extracted"
const EVENT_RUN_FAILED: StringName = &"event.run.failed"
const EVENT_MODIFIER_SELECTED: StringName = &"event.modifier.selected"

const OBJECTIVE_STARTER_RELAY: StringName = &"objective.relay.starter.v1"
const MODULE_WORN_PLATES: StringName = &"module.worn_plates"
const MODULE_RAM_PLATING: StringName = &"module.ram_plating"
const MODULE_AFTERSHOCK: StringName = &"module.aftershock"
const MODULE_STORM_SEAL: StringName = &"module.storm_seal"
const MODIFIER_NEUTRAL: StringName = &"modifier.neutral"
const MODIFIER_HOT_FRONT: StringName = &"modifier.hot_front"
const MODIFIER_BROOD_GROUND: StringName = &"modifier.brood_ground"
const MODIFIER_DEAD_GRID: StringName = &"modifier.dead_grid"


static func catalog() -> Dictionary:
	return {
		&"domains":
		[
			DOMAIN_FIELD_COMPOSITION,
			DOMAIN_MOVEMENT,
			DOMAIN_COMBAT_INPUT,
			DOMAIN_IMPACT_CHARGE,
			DOMAIN_WORLD,
			DOMAIN_ACTIVE_RUN,
			DOMAIN_PROFILE,
			DOMAIN_PREFERENCES,
			DOMAIN_RELAY_RUNTIME,
			DOMAIN_ENCOUNTERS,
			DOMAIN_HAZARDS,
			DOMAIN_PERSISTENCE,
			DOMAIN_FIELD_PRESENTATION,
			DOMAIN_FEEDBACK,
		],
		&"owners":
		[
			OWNER_FIELD_COMPOSITION,
			OWNER_UNASSIGNED,
			OWNER_IMPACT_CHARGE,
			OWNER_INFINITE_WORLD,
			OWNER_RUN_COORDINATOR,
			OWNER_PROFILE_STATE,
			OWNER_PLAYER_PREFERENCES,
			OWNER_RELAY_CONTEST,
			OWNER_SANDWORMS,
			OWNER_DESERT_HAZARDS,
			OWNER_WORLD_STATE_STORE,
			OWNER_SAVE_REPOSITORY,
			OWNER_FIELD_HUD,
			OWNER_FEEDBACK_ROUTER,
		],
		&"run_phases":
		[
			RUN_PHASE_BOOTSTRAP,
			RUN_PHASE_HUNT,
			RUN_PHASE_EXTRACTION_READY,
			RUN_PHASE_SUCCEEDED,
			RUN_PHASE_FAILED,
		],
		&"events":
		[
			EVENT_FIELD_READY,
			EVENT_ATTACK_COMMITTED,
			EVENT_SCRAP_COLLECTED,
			EVENT_CHASSIS_DAMAGED,
			EVENT_CHASSIS_SHUTDOWN,
			EVENT_REPAIR_COMMITTED,
			EVENT_RELAY_LINK_STARTED,
			EVENT_RELAY_COMPLETED,
			EVENT_WORM_DEFEATED,
			EVENT_MODULE_PURCHASED,
			EVENT_RUN_EXTRACTED,
			EVENT_RUN_FAILED,
			EVENT_MODIFIER_SELECTED,
		],
		&"objectives": [OBJECTIVE_STARTER_RELAY],
		&"modules": [MODULE_WORN_PLATES, MODULE_RAM_PLATING, MODULE_AFTERSHOCK, MODULE_STORM_SEAL],
		&"modifiers":
		[
			MODIFIER_NEUTRAL,
			MODIFIER_HOT_FRONT,
			MODIFIER_BROOD_GROUND,
			MODIFIER_DEAD_GRID,
		],
	}


static func all_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for group: Variant in catalog().values():
		for identifier: StringName in group as Array:
			result.append(identifier)
	return result


static func event_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for identifier: StringName in catalog()[&"events"] as Array:
		result.append(identifier)
	return result


static func owner_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for identifier: StringName in catalog()[&"owners"] as Array:
		result.append(identifier)
	return result


static func domain_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for identifier: StringName in catalog()[&"domains"] as Array:
		result.append(identifier)
	return result


static func is_event_id(identifier: StringName) -> bool:
	return identifier in event_ids()


static func validate_catalog() -> bool:
	var seen: Dictionary = {}
	for identifier: StringName in all_ids():
		if seen.has(identifier) or not _is_stable_identifier(identifier):
			return false
		seen[identifier] = true
	return not seen.is_empty()


static func _is_stable_identifier(identifier: StringName) -> bool:
	var value: String = String(identifier)
	if value.is_empty() or value.begins_with(".") or value.ends_with(".") or ".." in value:
		return false
	for index: int in range(value.length()):
		var code: int = value.unicode_at(index)
		var is_lower: bool = code >= 97 and code <= 122
		var is_digit: bool = code >= 48 and code <= 57
		if not is_lower and not is_digit and code not in [45, 46, 95]:
			return false
	return true
