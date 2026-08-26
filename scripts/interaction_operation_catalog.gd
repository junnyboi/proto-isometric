extends RefCounted

const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")

const ROUTE_READ: StringName = &"read"
const ROUTE_FARM: StringName = &"farm"
const ROUTE_CROSS_DOMAIN: StringName = &"cross_domain"
const ROUTE_CONSTRUCTION_UI: StringName = &"construction_ui"
const ROUTE_WORLD_RUNTIME: StringName = &"world_runtime"
const ROUTES: Array[StringName] = [
	ROUTE_CONSTRUCTION_UI,
	ROUTE_CROSS_DOMAIN,
	ROUTE_FARM,
	ROUTE_READ,
	ROUTE_WORLD_RUNTIME,
]

const MUTABILITY_READ_ONLY: StringName = &"read_only"
const MUTABILITY_UI_ONLY: StringName = &"ui_only"
const MUTABILITY_MUTATING: StringName = &"mutating"
const MUTABILITIES: Array[StringName] = [
	MUTABILITY_MUTATING,
	MUTABILITY_READ_ONLY,
	MUTABILITY_UI_ONLY,
]

const RECEIPT_NONE: StringName = &"none"
const RECEIPT_REQUIRED: StringName = &"required"
const RECEIPT_POSTCONDITION_IDEMPOTENT: StringName = &"postcondition_idempotent"
const RECEIPT_POLICIES: Array[StringName] = [
	RECEIPT_NONE,
	RECEIPT_POSTCONDITION_IDEMPOTENT,
	RECEIPT_REQUIRED,
]

const STALE_SNAPSHOT_IDENTITY: StringName = &"snapshot_identity"
const STALE_SNAPSHOT_AND_REVISION: StringName = &"snapshot_and_revision"
const STALE_POLICIES: Array[StringName] = [
	STALE_SNAPSHOT_AND_REVISION,
	STALE_SNAPSHOT_IDENTITY,
]

const ADAPTER_READ_RESULT: StringName = &"read_result_catalog"
const ADAPTER_FARM_RUNTIME: StringName = &"farm_runtime"
const ADAPTER_CROSS_DOMAIN: StringName = &"cross_domain_transaction"
const ADAPTER_DEPOSIT_EXACT_ONCE: StringName = &"deposit_exact_once"
const ADAPTER_CONSTRUCTION_UI: StringName = &"construction_ui"
const ADAPTER_WORLD_RUNTIME: StringName = &"world_runtime"
const ROUTE_ADAPTERS: Dictionary = {
	ROUTE_CONSTRUCTION_UI: [ADAPTER_CONSTRUCTION_UI],
	ROUTE_CROSS_DOMAIN: [ADAPTER_CROSS_DOMAIN, ADAPTER_DEPOSIT_EXACT_ONCE],
	ROUTE_FARM: [ADAPTER_FARM_RUNTIME],
	ROUTE_READ: [ADAPTER_READ_RESULT],
	ROUTE_WORLD_RUNTIME: [ADAPTER_WORLD_RUNTIME],
}

const PROVIDER_CONSTRUCTION: StringName = &"interaction.provider.construction"
const PROVIDER_DEPOSIT: StringName = &"interaction.provider.deposit"
const PROVIDER_FACILITY: StringName = &"interaction.provider.home_facility_ruin"
const PROVIDER_LEGACY: StringName = &"interaction.provider.legacy_expedition"
const PROVIDER_LIVESTOCK: StringName = &"interaction.provider.livestock"
const PROVIDER_PICKUP: StringName = &"interaction.provider.pickup"
const PROVIDER_RESIDENT: StringName = &"interaction.provider.resident"
const PROVIDER_MACHINE: StringName = &"interaction.provider.storage_shipping_machine"
const PROVIDER_TERRAIN: StringName = &"interaction.provider.terrain_plot_crop"
const PROVIDER_RESOURCE: StringName = &"interaction.provider.tree_resource"
const PROVIDER_WILDERNESS: StringName = &"interaction.provider.wilderness"
const PROVIDER_IDS: Array[StringName] = [
	PROVIDER_CONSTRUCTION,
	PROVIDER_DEPOSIT,
	PROVIDER_FACILITY,
	PROVIDER_LEGACY,
	PROVIDER_LIVESTOCK,
	PROVIDER_PICKUP,
	PROVIDER_RESIDENT,
	PROVIDER_MACHINE,
	PROVIDER_TERRAIN,
	PROVIDER_RESOURCE,
	PROVIDER_WILDERNESS,
]

const DOMAIN_ACTIVE_RUN: StringName = &"active_run"
const DOMAIN_FARM: StringName = &"farm"
const DOMAIN_WORLD: StringName = &"world"
const PERSISTENCE_DOMAINS: Array[StringName] = [
	DOMAIN_ACTIVE_RUN,
	DOMAIN_FARM,
	DOMAIN_WORLD,
]

const KEYS: Array[StringName] = [
	&"operation",
	&"route",
	&"adapter_id",
	&"allowed_provider_ids",
	&"mutability",
	&"receipt_policy",
	&"persistence_domains",
	&"stale_policy",
	&"allowed_close_behaviors",
]


static func descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = _build_descriptors()
	return result if validate_catalog(result) else []


static func operations() -> Array[StringName]:
	var result: Array[StringName] = []
	for operation_descriptor: Dictionary in descriptors():
		result.append(operation_descriptor[&"operation"] as StringName)
	return result


static func descriptor_for(
	operation: StringName,
	provider_id: StringName = &"",
) -> Dictionary:
	for operation_descriptor: Dictionary in descriptors():
		if operation_descriptor[&"operation"] != operation:
			continue
		if (
			provider_id != &""
			and provider_id not in (operation_descriptor[&"allowed_provider_ids"] as Array)
		):
			return {}
		return operation_descriptor.duplicate(true)
	return {}


static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var operation_descriptor: Dictionary = value as Dictionary
	if operation_descriptor.keys() != KEYS:
		return false
	if (
		not operation_descriptor[&"operation"] is StringName
		or not operation_descriptor[&"route"] is StringName
		or not operation_descriptor[&"adapter_id"] is StringName
		or not operation_descriptor[&"allowed_provider_ids"] is Array
		or not operation_descriptor[&"mutability"] is StringName
		or not operation_descriptor[&"receipt_policy"] is StringName
		or not operation_descriptor[&"persistence_domains"] is Array
		or not operation_descriptor[&"stale_policy"] is StringName
		or not operation_descriptor[&"allowed_close_behaviors"] is Array
	):
		return false
	var operation: StringName = operation_descriptor[&"operation"] as StringName
	var route: StringName = operation_descriptor[&"route"] as StringName
	var adapter_id: StringName = operation_descriptor[&"adapter_id"] as StringName
	var mutability: StringName = operation_descriptor[&"mutability"] as StringName
	var receipt_policy: StringName = operation_descriptor[&"receipt_policy"] as StringName
	if (
		not _stable_id(operation)
		or route not in ROUTES
		or adapter_id not in (ROUTE_ADAPTERS[route] as Array)
		or mutability not in MUTABILITIES
		or receipt_policy not in RECEIPT_POLICIES
		or operation_descriptor[&"stale_policy"] not in STALE_POLICIES
	):
		return false
	if not _sorted_known_ids(
		operation_descriptor[&"allowed_provider_ids"] as Array,
		PROVIDER_IDS,
		false,
	):
		return false
	if not _sorted_known_ids(
		operation_descriptor[&"persistence_domains"] as Array,
		PERSISTENCE_DOMAINS,
		true,
	):
		return false
	if not _sorted_known_ids(
		operation_descriptor[&"allowed_close_behaviors"] as Array,
		OptionScript.CLOSE_BEHAVIORS,
		false,
	):
		return false
	var domains: Array = operation_descriptor[&"persistence_domains"] as Array
	if mutability in [MUTABILITY_READ_ONLY, MUTABILITY_UI_ONLY]:
		if not domains.is_empty() or receipt_policy != RECEIPT_NONE:
			return false
		if operation_descriptor[&"stale_policy"] != STALE_SNAPSHOT_IDENTITY:
			return false
	if mutability == MUTABILITY_MUTATING:
		if domains.is_empty() or operation_descriptor[&"stale_policy"] != STALE_SNAPSHOT_AND_REVISION:
			return false
	if route == ROUTE_READ and mutability != MUTABILITY_READ_ONLY:
		return false
	if route == ROUTE_CONSTRUCTION_UI and mutability != MUTABILITY_UI_ONLY:
		return false
	if route not in [ROUTE_READ, ROUTE_CONSTRUCTION_UI] and mutability != MUTABILITY_MUTATING:
		return false
	return true


static func validate_catalog(value: Variant) -> bool:
	if not value is Array or (value as Array).is_empty():
		return false
	var previous_operation: String = ""
	for raw_descriptor: Variant in value as Array:
		if not validate(raw_descriptor):
			return false
		var operation_descriptor: Dictionary = raw_descriptor as Dictionary
		var operation: String = str(operation_descriptor[&"operation"])
		if not previous_operation.is_empty() and operation <= previous_operation:
			return false
		previous_operation = operation
		for provider_id: StringName in operation_descriptor[&"allowed_provider_ids"] as Array:
			if not _descriptor_reaches_provider(operation_descriptor, provider_id):
				return false
	return true


static func accepts(
	operation_descriptor: Variant,
	provider_id: StringName,
	operation: StringName,
	close_behavior: StringName,
) -> bool:
	if not validate(operation_descriptor):
		return false
	var exact: Dictionary = descriptor_for(operation, provider_id)
	if exact.is_empty() or exact != operation_descriptor:
		return false
	return close_behavior in (exact[&"allowed_close_behaviors"] as Array)


static func _build_descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_add_mutation(result, &"activate_remote_ruin", ROUTE_WORLD_RUNTIME, ADAPTER_WORLD_RUNTIME,
		[PROVIDER_FACILITY], [DOMAIN_FARM], RECEIPT_REQUIRED)
	_add_read(result, &"admire", [PROVIDER_RESOURCE])
	_add_cross_domain(result, &"animal_feed", [PROVIDER_LIVESTOCK])
	_add_cross_domain(result, &"animal_pet", [PROVIDER_LIVESTOCK])
	_add_cross_domain(result, &"animal_product", [PROVIDER_LIVESTOCK])
	_add_farm(result, &"buy_seed", [PROVIDER_FACILITY])
	_add_mutation(result, &"collect_run_pickup", ROUTE_WORLD_RUNTIME, ADAPTER_WORLD_RUNTIME,
		[PROVIDER_PICKUP], [DOMAIN_ACTIVE_RUN], RECEIPT_REQUIRED)
	_add_ui(result, &"confirm_construction_demolish", [PROVIDER_CONSTRUCTION])
	_add_ui(result, &"confirm_construction_upgrade", [PROVIDER_CONSTRUCTION])
	_add_cross_domain(result, &"craft_claim", [PROVIDER_MACHINE])
	_add_cross_domain(result, &"craft_start", [PROVIDER_MACHINE])
	_add_mutation(result, &"deposit_gather", ROUTE_CROSS_DOMAIN, ADAPTER_DEPOSIT_EXACT_ONCE,
		[PROVIDER_DEPOSIT], [DOMAIN_FARM], RECEIPT_REQUIRED)
	_add_mutation(result, &"enter_expedition_gate", ROUTE_WORLD_RUNTIME, ADAPTER_WORLD_RUNTIME,
		[PROVIDER_LEGACY], [DOMAIN_ACTIVE_RUN], RECEIPT_REQUIRED)
	_add_cross_domain(result, &"facility_power", [PROVIDER_FACILITY])
	_add_cross_domain(result, &"facility_repair", [PROVIDER_FACILITY])
	_add_cross_domain(result, &"gift", [PROVIDER_RESIDENT])
	_add_farm(result, &"harvest", [PROVIDER_TERRAIN])
	_add_cross_domain(result, &"herd_interact", [PROVIDER_WILDERNESS])
	_add_read(result, &"inspect", PROVIDER_IDS)
	_add_read(result, &"inspect_construction", [PROVIDER_CONSTRUCTION])
	_add_read(result, &"inspect_deposit", [PROVIDER_DEPOSIT])
	_add_read(result, &"observe_herd", [PROVIDER_WILDERNESS])
	_add_ui(result, &"open_construction", [PROVIDER_FACILITY, PROVIDER_MACHINE])
	_add_ui(result, &"open_construction_move", [PROVIDER_CONSTRUCTION])
	_add_ui(
		result,
		&"open_settlement",
		[
			PROVIDER_CONSTRUCTION,
			PROVIDER_FACILITY,
			PROVIDER_RESIDENT,
		],
		OptionScript.CLOSE_ALWAYS,
	)
	_add_farm(result, &"plant", [PROVIDER_TERRAIN])
	_add_ui(result, &"preview_extraction_range", [PROVIDER_CONSTRUCTION], OptionScript.CLOSE_NEVER)
	_add_read(result, &"read_herd_yield", [PROVIDER_WILDERNESS])
	_add_read(result, &"read_inventory", [PROVIDER_MACHINE])
	_add_read(result, &"read_machine_progress", [PROVIDER_MACHINE])
	_add_read(result, &"read_relationship", [PROVIDER_RESIDENT])
	_add_read(result, &"read_safehouse", [PROVIDER_FACILITY])
	_add_read(result, &"read_service", [PROVIDER_FACILITY, PROVIDER_RESIDENT])
	_add_read(result, &"read_shipping", [PROVIDER_MACHINE])
	_add_read(result, &"read_storage", [PROVIDER_FACILITY, PROVIDER_MACHINE])
	_add_cross_domain(result, &"request_complete", [PROVIDER_RESIDENT])
	_add_read(result, &"review_drops", [PROVIDER_WILDERNESS])
	_add_read(result, &"review_first_clear", [PROVIDER_WILDERNESS])
	_add_read(result, &"review_forecast", [PROVIDER_WILDERNESS])
	_add_read(result, &"review_gate_biome", [PROVIDER_LEGACY])
	_add_read(result, &"review_gate_risk", [PROVIDER_LEGACY])
	_add_read(result, &"review_habitat", [PROVIDER_WILDERNESS])
	_add_read(result, &"review_mitigation", [PROVIDER_WILDERNESS])
	_add_read(result, &"review_sanctuary", [PROVIDER_FACILITY])
	_add_read(result, &"review_threat", [PROVIDER_WILDERNESS])
	_add_farm(result, &"ship", [PROVIDER_MACHINE])
	_add_cross_domain(result, &"sleep", [PROVIDER_FACILITY])
	_add_mutation(result, &"stabilize_hazard", ROUTE_WORLD_RUNTIME, ADAPTER_WORLD_RUNTIME,
		[PROVIDER_WILDERNESS], [DOMAIN_FARM, DOMAIN_WORLD], RECEIPT_REQUIRED)
	_add_cross_domain(result, &"talk", [PROVIDER_RESIDENT])
	_add_farm(result, &"till", [PROVIDER_TERRAIN])
	_add_cross_domain(result, &"upgrade", [PROVIDER_MACHINE])
	_add_farm(result, &"water", [PROVIDER_TERRAIN])
	_add_mutation(result, &"world_clear_reward", ROUTE_CROSS_DOMAIN, ADAPTER_CROSS_DOMAIN,
		[PROVIDER_RESOURCE], [DOMAIN_FARM, DOMAIN_WORLD], RECEIPT_POSTCONDITION_IDEMPOTENT)
	_add_mutation(result, &"world_collect_reward", ROUTE_WORLD_RUNTIME, ADAPTER_WORLD_RUNTIME,
		[PROVIDER_PICKUP], [DOMAIN_WORLD], RECEIPT_REQUIRED)
	return result


static func _add_read(
	result: Array[Dictionary],
	operation: StringName,
	providers: Array[StringName],
) -> void:
	result.append(_descriptor(
		operation,
		ROUTE_READ,
		ADAPTER_READ_RESULT,
		providers,
		MUTABILITY_READ_ONLY,
		RECEIPT_NONE,
		[],
		STALE_SNAPSHOT_IDENTITY,
		[OptionScript.CLOSE_NEVER],
	))


static func _add_farm(
	result: Array[Dictionary],
	operation: StringName,
	providers: Array[StringName],
) -> void:
	_add_mutation(result, operation, ROUTE_FARM, ADAPTER_FARM_RUNTIME,
		providers, [DOMAIN_FARM], RECEIPT_NONE)


static func _add_cross_domain(
	result: Array[Dictionary],
	operation: StringName,
	providers: Array[StringName],
) -> void:
	_add_mutation(result, operation, ROUTE_CROSS_DOMAIN, ADAPTER_CROSS_DOMAIN,
		providers, [DOMAIN_FARM], RECEIPT_NONE)


static func _add_ui(
	result: Array[Dictionary],
	operation: StringName,
	providers: Array[StringName],
	close_behavior: StringName = OptionScript.CLOSE_ON_SUCCESS,
) -> void:
	result.append(_descriptor(
		operation,
		ROUTE_CONSTRUCTION_UI,
		ADAPTER_CONSTRUCTION_UI,
		providers,
		MUTABILITY_UI_ONLY,
		RECEIPT_NONE,
		[],
		STALE_SNAPSHOT_IDENTITY,
		[close_behavior],
	))


static func _add_mutation(
	result: Array[Dictionary],
	operation: StringName,
	route: StringName,
	adapter_id: StringName,
	providers: Array[StringName],
	domains: Array[StringName],
	receipt_policy: StringName,
) -> void:
	result.append(_descriptor(
		operation,
		route,
		adapter_id,
		providers,
		MUTABILITY_MUTATING,
		receipt_policy,
		domains,
		STALE_SNAPSHOT_AND_REVISION,
		[OptionScript.CLOSE_ON_SUCCESS],
	))


static func _descriptor(
	operation: StringName,
	route: StringName,
	adapter_id: StringName,
	providers: Array[StringName],
	mutability: StringName,
	receipt_policy: StringName,
	domains: Array[StringName],
	stale_policy: StringName,
	close_behaviors: Array[StringName],
) -> Dictionary:
	var sorted_providers: Array[StringName] = providers.duplicate()
	sorted_providers.sort_custom(_id_less)
	var sorted_domains: Array[StringName] = domains.duplicate()
	sorted_domains.sort_custom(_id_less)
	var sorted_close_behaviors: Array[StringName] = close_behaviors.duplicate()
	sorted_close_behaviors.sort_custom(_id_less)
	return {
		&"operation": operation,
		&"route": route,
		&"adapter_id": adapter_id,
		&"allowed_provider_ids": sorted_providers,
		&"mutability": mutability,
		&"receipt_policy": receipt_policy,
		&"persistence_domains": sorted_domains,
		&"stale_policy": stale_policy,
		&"allowed_close_behaviors": sorted_close_behaviors,
	}


static func _descriptor_reaches_provider(
	operation_descriptor: Dictionary,
	provider_id: StringName,
) -> bool:
	return (
		provider_id in PROVIDER_IDS
		and provider_id in (operation_descriptor[&"allowed_provider_ids"] as Array)
		and not str(operation_descriptor[&"operation"]).is_empty()
	)


static func _sorted_known_ids(
	values: Array,
	known: Array[StringName],
	allow_empty: bool,
) -> bool:
	if values.is_empty():
		return allow_empty
	var previous: String = ""
	for raw_value: Variant in values:
		if not raw_value is StringName or raw_value not in known:
			return false
		var current: String = str(raw_value)
		if not previous.is_empty() and current <= previous:
			return false
		previous = current
	return true


static func _stable_id(value: StringName) -> bool:
	var identifier: String = str(value)
	return not identifier.is_empty() and identifier.length() <= 128


static func _id_less(first: StringName, second: StringName) -> bool:
	return str(first) < str(second)
