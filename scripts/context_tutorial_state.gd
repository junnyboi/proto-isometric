extends RefCounted

const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")

const LESSON_MOVE: int = 0
const LESSON_TARGET: int = 1
const LESSON_TERMINAL: int = 2
const LESSON_NAVIGATE: int = 3
const LESSON_CONFIRM: int = 4
const LESSON_QUICK: int = 5
const LESSON_BUILD: int = 6
const LESSON_WORKER: int = 7
const LESSON_COUNT: int = 8
const INITIAL_RELEVANCE_MASK: int = (1 << 6) - 1
const ALL_LESSONS_MASK: int = (1 << LESSON_COUNT) - 1

const LESSON_IDS: Array[StringName] = [
	&"move",
	&"target",
	&"terminal",
	&"navigate",
	&"confirm",
	&"quick",
	&"build",
	&"worker",
]
const EVENT_LESSONS: Dictionary = {
	&"player_moved": LESSON_MOVE,
	&"target_changed": LESSON_TARGET,
	&"terminal_opened": LESSON_TERMINAL,
	&"menu_navigated": LESSON_NAVIGATE,
	&"menu_navigation_not_needed": LESSON_NAVIGATE,
	&"safe_action_confirmed": LESSON_CONFIRM,
	&"quick_action_completed": LESSON_QUICK,
	&"build_mode_entered": LESSON_BUILD,
	&"first_worker_assigned": LESSON_WORKER,
}


static func neutral() -> Dictionary:
	return SectionsScript.neutral_tutorial()


static func validate(value: Variant) -> Dictionary:
	return SectionsScript.validate_tutorial(value)


static func lesson_id(index: int) -> StringName:
	return LESSON_IDS[index] if index >= 0 and index < LESSON_IDS.size() else &""


static func lesson_index(id: StringName) -> int:
	return LESSON_IDS.find(id)


static func is_completed(state: Dictionary, lesson: int) -> bool:
	var valid: Dictionary = validate(state)
	return (
		not valid.is_empty()
		and lesson >= 0
		and bool(int(valid[&"completion_mask"]) & (1 << lesson))
	)


static func current_lesson(state: Dictionary, relevance_mask: int = INITIAL_RELEVANCE_MASK) -> int:
	var valid: Dictionary = validate(state)
	if valid.is_empty() or bool(valid[&"suppressed"]):
		return -1
	var completion: int = int(valid[&"completion_mask"])
	for lesson: int in LESSON_COUNT:
		var bit: int = 1 << lesson
		if bool(relevance_mask & bit) and not bool(completion & bit):
			return lesson
	return -1


static func apply_event(state: Dictionary, event: StringName, payload: Dictionary) -> Dictionary:
	var source: Dictionary = validate(state)
	if source.is_empty() or event not in EVENT_LESSONS:
		return _result(false, false, source, -1, &"invalid_event")
	if not bool(payload.get(&"success", false)):
		return _result(true, false, source, int(EVENT_LESSONS[event]), &"semantic_failure")
	var lesson: int = int(EVENT_LESSONS[event])
	var bit: int = 1 << lesson
	if bool(int(source[&"completion_mask"]) & bit):
		return _result(true, false, source, lesson, &"duplicate")
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"completion_mask"] = int(candidate[&"completion_mask"]) | bit
	return _result(true, true, validate(candidate), lesson, &"")


static func set_suppressed(state: Dictionary, suppressed: bool) -> Dictionary:
	var source: Dictionary = validate(state)
	if source.is_empty() or bool(source[&"suppressed"]) == suppressed:
		return source
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"suppressed"] = suppressed
	return validate(candidate)


static func reset(state: Dictionary) -> Dictionary:
	return neutral() if not validate(state).is_empty() else {}


static func migrate_legacy(state: Dictionary, onboarding_seen: bool) -> Dictionary:
	var source: Dictionary = validate(state)
	if source.is_empty() or not onboarding_seen:
		return source
	if int(source[&"completion_mask"]) != 0 or bool(source[&"suppressed"]):
		return source
	var candidate: Dictionary = source.duplicate(true)
	candidate[&"suppressed"] = true
	return validate(candidate)


static func canonical_bytes(state: Dictionary) -> int:
	var valid: Dictionary = validate(state)
	return -1 if valid.is_empty() else JSON.stringify(valid, "", true).to_utf8_buffer().size()


static func _result(
	ok: bool,
	changed: bool,
	candidate: Dictionary,
	lesson: int,
	reason: StringName,
) -> Dictionary:
	return {
		&"ok": ok,
		&"changed": changed,
		&"candidate": candidate.duplicate(true),
		&"lesson": lesson,
		&"reason": reason,
	}
