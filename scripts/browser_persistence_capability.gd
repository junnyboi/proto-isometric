extends RefCounted

const STATE_VERSION: int = 1
const STATUS_AVAILABLE: StringName = &"available"
const STATUS_BLOCKED: StringName = &"blocked"
const STATUS_VOLATILE: StringName = &"volatile"


static func from_signals(
	is_web: bool, storage_writable: bool, persistence_granted: bool
) -> Dictionary:
	if not is_web:
		return _state(STATUS_AVAILABLE, &"filesystem", &"native_storage", true)
	if not storage_writable:
		return _state(STATUS_BLOCKED, &"browser", &"storage_blocked", false)
	if not persistence_granted:
		return _state(STATUS_VOLATILE, &"browser", &"persistence_not_guaranteed", false)
	return _state(STATUS_AVAILABLE, &"browser", &"persistent_storage_granted", true)


static func probe(overrides: Dictionary = {}) -> Dictionary:
	var is_web: bool = bool(overrides.get(&"is_web", OS.has_feature("web")))
	if overrides.has(&"storage_writable"):
		return from_signals(
			is_web,
			bool(overrides[&"storage_writable"]),
			bool(overrides.get(&"persistence_granted", false)),
		)
	if not is_web:
		return from_signals(false, true, true)
	var writable: bool = _browser_storage_is_writable()
	# A synchronous probe cannot prove navigator.storage.persisted(); report volatile honestly.
	return from_signals(true, writable, false)


static func validate(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var state: Dictionary = value as Dictionary
	var keys: Array[StringName] = [
		&"state_version", &"status", &"backend", &"reason", &"persistent_guaranteed"
	]
	if state.size() != keys.size():
		return {}
	for key: StringName in keys:
		if not state.has(key):
			return {}
	var status: StringName = StringName(str(state[&"status"]))
	if (
		state[&"state_version"] != STATE_VERSION
		or status not in [STATUS_AVAILABLE, STATUS_BLOCKED, STATUS_VOLATILE]
		or not state[&"persistent_guaranteed"] is bool
		or not state[&"backend"] is String
		or not state[&"reason"] is String
	):
		return {}
	var normalized: Dictionary = _state(
		status,
		StringName(state[&"backend"]),
		StringName(state[&"reason"]),
		bool(state[&"persistent_guaranteed"]),
	)
	return normalized if normalized in _allowed_states() else {}


static func _browser_storage_is_writable() -> bool:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return false
	if OS.has_method("is_userfs_persistent") and not bool(OS.call("is_userfs_persistent")):
		return false
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var result: Variant = bridge.call(
		"eval",
		"(()=>{try{const k='__protos_persistence_probe__';"
		+ "localStorage.setItem(k,'1');localStorage.removeItem(k);return true;}"
		+ "catch(_error){return false;}})()",
		true,
	)
	return bool(result)


static func _state(
	status: StringName, backend: StringName, reason: StringName, guaranteed: bool
) -> Dictionary:
	return {
		&"state_version": STATE_VERSION,
		&"status": String(status),
		&"backend": String(backend),
		&"reason": String(reason),
		&"persistent_guaranteed": guaranteed,
	}


static func _allowed_states() -> Array[Dictionary]:
	return [
		_state(STATUS_AVAILABLE, &"filesystem", &"native_storage", true),
		_state(STATUS_BLOCKED, &"browser", &"storage_blocked", false),
		_state(STATUS_VOLATILE, &"browser", &"persistence_not_guaranteed", false),
		_state(STATUS_AVAILABLE, &"browser", &"persistent_storage_granted", true),
	]
