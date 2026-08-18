extends RefCounted

const RuntimeIdsScript: GDScript = preload("res://scripts/runtime_ids.gd")

const SCOPE_TRANSIENT: StringName = &"transient"
const SCOPE_WORLD: StringName = &"world"
const SCOPE_ACTIVE_RUN: StringName = &"active_run"
const SCOPE_PROFILE: StringName = &"profile"
const SCOPE_PREFERENCES: StringName = &"preferences"
const SCOPE_PRESENTATION: StringName = &"presentation"

const POLICY_AUTHORITATIVE: StringName = &"authoritative"
const POLICY_COMPOSITION_ONLY: StringName = &"composition_only"
const POLICY_READ_ONLY: StringName = &"read_only"

const MIGRATION_STABLE: StringName = &"stable"
const MIGRATION_PLANNED: StringName = &"planned"


static func contracts() -> Array[Dictionary]:
	return [
		_stable_contract(
			RuntimeIdsScript.DOMAIN_FIELD_COMPOSITION,
			RuntimeIdsScript.OWNER_FIELD_COMPOSITION,
			SCOPE_TRANSIENT,
			POLICY_COMPOSITION_ONLY,
			"res://scripts/isometric_map.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_MOVEMENT,
			RuntimeIdsScript.OWNER_FIELD_COMPOSITION,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/isometric_map.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_COMBAT_INPUT,
			RuntimeIdsScript.OWNER_FIELD_COMPOSITION,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/isometric_map.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_IMPACT_CHARGE,
			RuntimeIdsScript.OWNER_IMPACT_CHARGE,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/impact_charge.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_WORLD,
			RuntimeIdsScript.OWNER_INFINITE_WORLD,
			SCOPE_WORLD,
			POLICY_AUTHORITATIVE,
			"res://scripts/infinite_world.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_ACTIVE_RUN,
			RuntimeIdsScript.OWNER_RUN_COORDINATOR,
			SCOPE_ACTIVE_RUN,
			POLICY_AUTHORITATIVE,
			"res://scripts/run_coordinator.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_PROFILE,
			RuntimeIdsScript.OWNER_PROFILE_STATE,
			SCOPE_PROFILE,
			POLICY_AUTHORITATIVE,
			"res://scripts/profile_state.gd",
		),
		_planned_contract(
			RuntimeIdsScript.DOMAIN_PREFERENCES,
			RuntimeIdsScript.OWNER_UNASSIGNED,
			RuntimeIdsScript.OWNER_PLAYER_PREFERENCES,
			SCOPE_PREFERENCES,
			"",
			"res://scripts/player_preferences.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_RELAY_RUNTIME,
			RuntimeIdsScript.OWNER_RELAY_CONTEST,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/relay_contest.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_ENCOUNTERS,
			RuntimeIdsScript.OWNER_SANDWORMS,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/sandworms.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_HAZARDS,
			RuntimeIdsScript.OWNER_DESERT_HAZARDS,
			SCOPE_TRANSIENT,
			POLICY_AUTHORITATIVE,
			"res://scripts/desert_hazards.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_PERSISTENCE,
			RuntimeIdsScript.OWNER_WORLD_STATE_STORE,
			SCOPE_WORLD,
			POLICY_AUTHORITATIVE,
			"res://scripts/world_state_store.gd",
		),
		_stable_contract(
			RuntimeIdsScript.DOMAIN_FIELD_PRESENTATION,
			RuntimeIdsScript.OWNER_FIELD_HUD,
			SCOPE_PRESENTATION,
			POLICY_AUTHORITATIVE,
			"res://scripts/field_hud.gd",
		),
		_planned_contract(
			RuntimeIdsScript.DOMAIN_FEEDBACK,
			RuntimeIdsScript.OWNER_UNASSIGNED,
			RuntimeIdsScript.OWNER_FEEDBACK_ROUTER,
			SCOPE_PRESENTATION,
			"",
			"res://scripts/feedback_router.gd",
		),
	]


static func owner_for(domain_id: StringName) -> StringName:
	var contract: Dictionary = contract_for(domain_id)
	return contract.get(&"target_owner_id", &"") as StringName


static func current_owner_for(domain_id: StringName) -> StringName:
	var contract: Dictionary = contract_for(domain_id)
	return contract.get(&"current_owner_id", &"") as StringName


static func contract_for(domain_id: StringName) -> Dictionary:
	for contract: Dictionary in contracts():
		if contract[&"domain_id"] == domain_id:
			return contract.duplicate(true)
	return {}


static func validate() -> bool:
	if not RuntimeIdsScript.validate_catalog():
		return false
	var seen_domains: Dictionary = {}
	var valid_policies: Array[StringName] = [
		POLICY_AUTHORITATIVE,
		POLICY_COMPOSITION_ONLY,
		POLICY_READ_ONLY,
	]
	for contract: Dictionary in contracts():
		var domain_id: StringName = contract[&"domain_id"] as StringName
		var current_owner: StringName = contract[&"current_owner_id"] as StringName
		var target_owner: StringName = contract[&"target_owner_id"] as StringName
		var current_file: String = str(contract[&"current_file"])
		if (
			seen_domains.has(domain_id)
			or domain_id not in RuntimeIdsScript.domain_ids()
			or current_owner not in RuntimeIdsScript.owner_ids()
			or target_owner not in RuntimeIdsScript.owner_ids()
			or contract[&"current_policy"] not in valid_policies
			or contract[&"target_policy"] not in valid_policies
			or not str(contract[&"target_file"]).begins_with("res://")
			or (current_owner == RuntimeIdsScript.OWNER_UNASSIGNED) != current_file.is_empty()
			or (not current_file.is_empty() and not current_file.begins_with("res://"))
		):
			return false
		seen_domains[domain_id] = true
	return seen_domains.size() == RuntimeIdsScript.domain_ids().size()


static func _stable_contract(
	domain_id: StringName,
	owner_id: StringName,
	state_scope: StringName,
	policy: StringName,
	file_path: String,
) -> Dictionary:
	return {
		&"domain_id": domain_id,
		&"current_owner_id": owner_id,
		&"target_owner_id": owner_id,
		&"state_scope": state_scope,
		&"migration_state": MIGRATION_STABLE,
		&"current_policy": policy,
		&"target_policy": policy,
		&"current_file": file_path,
		&"target_file": file_path,
	}


static func _planned_contract(
	domain_id: StringName,
	current_owner_id: StringName,
	target_owner_id: StringName,
	state_scope: StringName,
	current_file: String,
	target_file: String,
) -> Dictionary:
	return {
		&"domain_id": domain_id,
		&"current_owner_id": current_owner_id,
		&"target_owner_id": target_owner_id,
		&"state_scope": state_scope,
		&"migration_state": MIGRATION_PLANNED,
		&"current_policy": POLICY_AUTHORITATIVE,
		&"target_policy": POLICY_AUTHORITATIVE,
		&"current_file": current_file,
		&"target_file": target_file,
	}
