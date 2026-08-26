extends RefCounted

const StateHashScript: GDScript = preload("res://scripts/persistence_state_hash.gd")


# SaveRepository validates normalized schema and cross-links after this raw hash check.
# Accepting a genuine raw hash lets additive schema-5 defaults be applied without
# weakening tamper detection or allowing malformed normalized state to load.
static func raw_hash_is_valid(envelope: Dictionary, verify_result_hash: bool) -> bool:
	return verify_result_hash and StateHashScript.result_hash_matches(envelope)
