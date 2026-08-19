extends RefCounted


static func set_state(value: String) -> void:
	if not OS.has_feature("web"):
		return
	(
		JavaScriptBridge
		. eval(
			"document.body.dataset.godotScene=%s;" % JSON.stringify(value),
			true,
		)
	)
