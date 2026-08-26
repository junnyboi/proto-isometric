extends RefCounted

const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const StateScript: GDScript = preload("res://scripts/context_tutorial_state.gd")
const ModalityScript: GDScript = preload("res://scripts/input_modality_tracker.gd")


static func format(lesson: int, modality: StringName) -> String:
	var lesson_id: StringName = StateScript.lesson_id(lesson)
	if lesson_id == &"":
		return ""
	var suffix: String = "desktop"
	if modality == ModalityScript.CONTROLLER:
		suffix = "controller"
	elif modality == ModalityScript.TOUCH:
		suffix = "touch"
	return LocalizationScript.t("tutorial.binding.%s.%s" % [lesson_id, suffix])
