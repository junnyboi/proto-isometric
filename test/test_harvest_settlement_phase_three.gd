extends RefCounted

const BindingScript: GDScript = preload("res://scripts/context_binding_formatter.gd")
const DirectorScript: GDScript = preload("res://scripts/context_tutorial_director.gd")
const EventScript: GDScript = preload("res://scripts/context_tutorial_event.gd")
const LocalizationScript: GDScript = preload("res://scripts/localization_service.gd")
const MenuScript: GDScript = preload("res://scripts/interaction_menu_snapshot.gd")
const ModalityScript: GDScript = preload("res://scripts/input_modality_tracker.gd")
const OptionScript: GDScript = preload("res://scripts/interaction_option.gd")
const PlayerPreferencesScript: GDScript = preload("res://scripts/player_preferences.gd")
const PresenterScript: GDScript = preload("res://scripts/context_tutorial_presenter.gd")
const SectionsScript: GDScript = preload("res://scripts/settlement_persistence_sections.gd")
const StateScript: GDScript = preload("res://scripts/context_tutorial_state.gd")

const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1024.0, 576.0),
	Vector2(844.0, 390.0),
	Vector2(720.0, 1280.0),
	Vector2(390.0, 844.0),
]
const SCALES: Array[float] = [0.85, 1.0, 1.25]


class CommitProbe:
	extends RefCounted

	var state: Dictionary = StateScript.neutral()
	var calls: int = 0
	var fail: bool = false

	func commit(candidate: Dictionary) -> Dictionary:
		calls += 1
		if fail:
			return {&"ok": false, &"reason": &"injected"}
		state = candidate.duplicate(true)
		return {&"ok": true, &"tutorial": state.duplicate(true)}


static func evaluate(runtime: Node2D = null) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_schema(cases)
	_test_semantic_events(cases)
	_test_determinism(cases)
	_test_failure_and_controls(cases)
	_test_legacy_and_budget(cases)
	_test_modality_and_localization(cases)
	_test_layout(cases)
	if runtime != null:
		_test_live_runtime(cases, runtime)
	return cases


static func _test_schema(cases: Array[Dictionary]) -> void:
	var neutral: Dictionary = StateScript.neutral()
	_add(
		cases,
		"P3 neutral tutorial state is validator-exact",
		StateScript.validate(neutral) == neutral,
	)
	var unknown: Dictionary = neutral.duplicate(true)
	unknown[&"elapsed"] = 0.0
	_add(
		cases,
		"P3 timer and unknown tutorial fields reject",
		StateScript.validate(unknown).is_empty(),
	)
	var overflow: Dictionary = neutral.duplicate(true)
	overflow[&"completion_mask"] = 1 << SectionsScript.MAX_TUTORIAL_LESSONS
	_add(cases, "P3 tutorial cap plus one rejects", StateScript.validate(overflow).is_empty())
	_add(
		cases,
		"P3 default relevance exposes move before future systems",
		StateScript.current_lesson(neutral) == StateScript.LESSON_MOVE,
	)
	_add(
		cases,
		"P3 tutorial state remains far below four KiB",
		StateScript.canonical_bytes(neutral) > 0 and StateScript.canonical_bytes(neutral) < 4096,
	)


static func _test_semantic_events(cases: Array[Dictionary]) -> void:
	var option: Dictionary = _safe_option()
	var one_row: Dictionary = _menu([option])
	var disabled: Dictionary = option.duplicate(true)
	disabled[&"enabled"] = false
	disabled[&"reason_key"] = &"interaction.reason.test_disabled"
	var no_enabled_rows: Dictionary = _menu([disabled])
	var second: Dictionary = OptionScript.build(
		&"interaction.action.admire", &"interaction.provider.test", &"target.test",
		&"target.tree", &"tree.test", &"admire", {}, true, &"interaction.admire", &"", 20
	)
	var two_rows: Dictionary = _menu([option, second])
	var target: Dictionary = {
		&"valid": true, &"target_cell": Vector2i(1, 0), &"target_kind": &"target.terrain"
	}
	_add(
		cases,
		"P3 movement requires a committed cell change",
		bool(EventScript.movement_committed(Vector2i.ZERO, Vector2i.ONE)[&"success"])
		and not bool(EventScript.movement_committed(Vector2i.ZERO, Vector2i.ZERO)[&"success"]),
	)
	_add(
		cases,
		"P3 valid targets produce semantic proof",
		bool(EventScript.target_acquired(target)[&"success"]),
	)
	_add(
		cases,
		"P3 sealed terminal snapshots produce semantic proof",
		bool(EventScript.terminal_opened(one_row)[&"success"]),
	)
	_add(
		cases,
		"P3 navigation is not applicable for one enabled row",
		bool(EventScript.navigation_not_needed(one_row)[&"success"])
		and not bool(EventScript.navigation_not_needed(two_rows)[&"success"])
		and not bool(EventScript.navigation_not_needed(no_enabled_rows)[&"success"]),
	)
	_add(
		cases,
		"P3 navigation requires a real selection change",
		bool(
			EventScript.terminal_navigated(
				"interaction.snapshot.test", 0, 1, &"interaction.action.admire"
			)[&"success"]
		)
		and not bool(
			EventScript.terminal_navigated(
				"interaction.snapshot.test", 0, 0, &"interaction.action.inspect"
			)[&"success"]
		),
	)
	_add(
		cases,
		"P3 safe confirm rejects failed operations",
		bool(
			EventScript.safe_action_committed(
				"interaction.snapshot.test", option, {&"ok": true}
			)[&"success"]
		)
		and not bool(
			EventScript.safe_action_committed(
				"interaction.snapshot.test", option, {&"ok": false}
			)[&"success"]
		),
	)
	_add(
		cases,
		"P3 Quick requires executed mutation",
		bool(
			EventScript.quick_committed(
				{&"result_id": &"quick.executed", &"mutated": true}
			)[&"success"]
		)
		and not bool(
			EventScript.quick_committed(
				{&"result_id": &"quick.terminal_opened", &"mutated": false}
			)[&"success"]
		),
	)
	_add(
		cases,
		"P3 future lessons require committed receipts",
		bool(EventScript.build_mode_entered({&"ok": true, &"committed": true})[&"success"])
		and not bool(EventScript.build_mode_entered({&"ok": true})[&"success"])
		and bool(
			EventScript.worker_assignment_committed(
				{&"ok": true, &"committed": true, &"settler_id": &"settler.a", &"site_id": &"site.a"}
			)[&"success"]
		),
	)


static func _test_determinism(cases: Array[Dictionary]) -> void:
	var events: Array[Dictionary] = _successful_events()
	var forward: Dictionary = _run_events(events, 1)
	var reverse_events: Array[Dictionary] = events.duplicate(true)
	reverse_events.reverse()
	var reverse: Dictionary = _run_events(reverse_events, 4)
	var shuffled: Array[Dictionary] = [
		events[5], events[0], events[2], events[4], events[1], events[7], events[3],
		events[6], events[5], events[0], events[3],
	]
	var shuffled_state: Dictionary = _run_events(shuffled, 9)
	_add(
		cases,
		"P3 shuffled duplicate facts converge to the same mask",
		forward == reverse and reverse == shuffled_state
		and int(forward[&"completion_mask"]) == StateScript.ALL_LESSONS_MASK,
	)
	var cadence_states: Array[Dictionary] = []
	for cadence: int in [30, 60, 144]:
		cadence_states.append(_run_events(events, cadence))
	_add(
		cases,
		"P3 progression is identical at thirty sixty and one-forty-four FPS",
		cadence_states[0] == cadence_states[1] and cadence_states[1] == cadence_states[2],
	)
	var probe: CommitProbe = CommitProbe.new()
	var director: RefCounted = _director(probe)
	for event: Dictionary in events:
		director.call("ingest", event)
		director.call("ingest", event)
	_add(
		cases,
		"P3 duplicate delivery writes each lesson at most once",
		probe.calls == StateScript.LESSON_COUNT and director.call("get_commit_count") == 8,
	)
	_add(
		cases,
		"P3 director owns no timer or process loop",
		not director.has_method("_process") and not director.has_method("advance"),
	)


static func _test_failure_and_controls(cases: Array[Dictionary]) -> void:
	var probe: CommitProbe = CommitProbe.new()
	probe.fail = true
	var director: RefCounted = _director(probe)
	var result: Dictionary = director.call("ingest", _successful_events()[0]) as Dictionary
	_add(
		cases,
		"P3 persistence failure retains the committed source",
		not bool(result[&"ok"]) and director.call("get_state") == StateScript.neutral(),
	)
	probe = CommitProbe.new()
	director = _director(probe)
	director.call("ingest", _successful_events()[0])
	var moved_mask: int = int((director.call("get_state") as Dictionary)[&"completion_mask"])
	var skipped: bool = bool(director.call("suppress"))
	var suppressed: Dictionary = director.call("get_state") as Dictionary
	var resumed: bool = bool(director.call("resume"))
	var resumed_state: Dictionary = director.call("get_state") as Dictionary
	var reset: bool = bool(director.call("reset_training"))
	_add(
		cases,
		"P3 Skip Resume and Reset preserve their distinct semantics",
		skipped and bool(suppressed[&"suppressed"])
		and int(suppressed[&"completion_mask"]) == moved_mask
		and resumed and not bool(resumed_state[&"suppressed"])
		and int(resumed_state[&"completion_mask"]) == moved_mask
		and reset and director.call("get_state") == StateScript.neutral(),
	)
	probe = CommitProbe.new()
	director = _director(probe)
	for index: int in 6:
		director.call("ingest", _successful_events()[index])
	_add(
		cases,
		"P3 construction and worker lessons stay dormant before capability",
		int(director.call("get_current_lesson")) == -1,
	)
	director.call("set_lesson_relevant", StateScript.LESSON_BUILD, true)
	_add(
		cases,
		"P3 build lesson activates only when capability becomes relevant",
		int(director.call("get_current_lesson")) == StateScript.LESSON_BUILD,
	)


static func _test_legacy_and_budget(cases: Array[Dictionary]) -> void:
	var migrated: Dictionary = StateScript.migrate_legacy(StateScript.neutral(), true)
	_add(
		cases,
		"P3 legacy onboarding dismissal migrates to reversible suppression",
		bool(migrated[&"suppressed"]) and int(migrated[&"completion_mask"]) == 0,
	)
	var probe: CommitProbe = CommitProbe.new()
	var director: RefCounted = _director(probe, true)
	_add(
		cases,
		"P3 legacy migration persists exactly once",
		probe.calls == 1 and bool((director.call("get_state") as Dictionary)[&"suppressed"]),
	)
	var preferences: RefCounted = PlayerPreferencesScript.new() as RefCounted
	preferences.call("set_value", &"locale", &"zh-CN")
	preferences.call("set_value", &"ui_scale", 1.25)
	preferences.call("set_value", &"effects_quality", &"minimal")
	preferences.call("set_value", &"onboarding_seen", true)
	var bytes: int = JSON.stringify(
		preferences.call("to_dictionary"), "", true
	).to_utf8_buffer().size()
	_add(cases, "P3 maximum current preferences remain within four KiB", bytes <= 4096)


static func _test_modality_and_localization(cases: Array[Dictionary]) -> void:
	var tracker: RefCounted = ModalityScript.new() as RefCounted
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_G
	var joy: InputEventJoypadButton = InputEventJoypadButton.new()
	joy.pressed = true
	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	tracker.call("observe_event", joy)
	var controller_ok: bool = tracker.call("get_modality") == ModalityScript.CONTROLLER
	tracker.call("observe_event", touch)
	var touch_ok: bool = tracker.call("get_modality") == ModalityScript.TOUCH
	tracker.call("observe_event", key)
	_add(
		cases,
		"P3 modality tracker distinguishes controller touch and keyboard",
		controller_ok and touch_ok and tracker.call("get_modality") == ModalityScript.KEYBOARD_MOUSE,
	)
	var en_keys: Array[String] = LocalizationScript.get_catalog_keys(&"en")
	var zh_keys: Array[String] = LocalizationScript.get_catalog_keys(&"zh-CN")
	_add(cases, "P3 English and Simplified Chinese catalogs have exact parity", en_keys == zh_keys)
	var bindings_valid: bool = true
	for locale: StringName in [&"en", &"zh-CN"]:
		LocalizationScript.set_locale(locale, false)
		for lesson: int in StateScript.LESSON_COUNT:
			for modality: StringName in ModalityScript.MODALITIES:
				var text: String = BindingScript.format(lesson, modality)
				bindings_valid = bindings_valid and not text.is_empty() and not text.begins_with("⟦")
	_add(cases, "P3 every lesson has localized modality bindings", bindings_valid)
	LocalizationScript.set_locale(&"en", false)


static func _test_layout(cases: Array[Dictionary]) -> void:
	var valid: bool = true
	for viewport: Vector2 in VIEWPORTS:
		for scale: float in SCALES:
			for left_handed: bool in [false, true]:
				var layout: Dictionary = PresenterScript.layout_for(viewport, scale, left_handed)
				var safe: Rect2 = layout[&"safe"] as Rect2
				var card: Rect2 = layout[&"card"] as Rect2
				var help: Rect2 = layout[&"help"] as Rect2
				valid = valid and safe.encloses(card) and safe.encloses(help)
	_add(cases, "P3 presenter stays safe across five viewports scales and handedness", valid)


static func _test_live_runtime(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var hud: CanvasLayer = runtime.get_node_or_null("FieldHUD") as CanvasLayer
	var director: RefCounted = (
		bridge.call("get_context_tutorial_director") as RefCounted if bridge != null else null
	)
	var presenter: CanvasLayer = (
		hud.call("_get_context_tutorial_presenter") as CanvasLayer if hud != null else null
	)
	_add(
		cases,
		"P3 live field owns one director and one pooled native presenter",
		bridge != null and director != null and presenter != null
		and hud.get_node_or_null("OnboardingOverlay") == null,
	)
	if director == null or presenter == null:
		return
	director.call("reset_training")
	var radar: Control = hud.get_node("ExpeditionRadar") as Control
	hud.call("_process", 0.0)
	var radar_yielded: bool = not radar.visible
	director.call("suppress")
	hud.call("_process", 0.0)
	var radar_restored: bool = radar.visible
	director.call("resume")
	_add(
		cases,
		"P3 radar yields only for the compact prompt and restores after suppression",
		radar_yielded and radar_restored,
	)
	var before: Dictionary = director.call("get_state") as Dictionary
	runtime.call("update_drive", Vector2.ZERO, 10.0, false)
	_add(
		cases,
		"P3 idle time and blocked zero movement do not advance live training",
		director.call("get_state") == before,
	)
	for _step: int in 60:
		runtime.call("update_drive", Vector2(0.0, -1.0), 0.05, false)
	var controller: Node2D = bridge.call("get_interaction_controller") as Node2D
	controller.call("_sync_target")
	var after_target: Dictionary = director.call("get_state") as Dictionary
	var move_target_mask: int = (1 << StateScript.LESSON_MOVE) | (1 << StateScript.LESSON_TARGET)
	_add(
		cases,
		"P3 live committed movement and target acquisition advance semantic bits",
		(int(after_target[&"completion_mask"]) & move_target_mask) == move_target_mask,
	)
	var opened: bool = bool(controller.call("open_menu"))
	var terminal_state: Dictionary = director.call("get_state") as Dictionary
	var terminal_mask: int = (
		move_target_mask | (1 << StateScript.LESSON_TERMINAL)
		| (1 << StateScript.LESSON_NAVIGATE)
	)
	_add(
		cases,
		"P3 live terminal opening completes terminal and not-applicable navigation",
		opened and (int(terminal_state[&"completion_mask"]) & terminal_mask) == terminal_mask,
	)
	var menu: Dictionary = controller.call("get_menu_snapshot") as Dictionary
	var disabled_index: int = _first_disabled_index(menu)
	var before_disabled: Dictionary = director.call("get_state") as Dictionary
	if disabled_index >= 0:
		controller.call("select_menu_index", disabled_index)
		controller.call("confirm_menu")
	_add(
		cases,
		"P3 disabled live terminal rows never advance confirmation",
		director.call("get_state") == before_disabled,
	)
	controller.call("select_menu_index", _first_enabled_index(menu))
	var confirmed: bool = bool(controller.call("confirm_menu"))
	var confirmed_state: Dictionary = director.call("get_state") as Dictionary
	_add(
		cases,
		"P3 successful live safe confirmation advances exactly its lesson",
		confirmed and StateScript.is_completed(confirmed_state, StateScript.LESSON_CONFIRM),
	)
	controller.call("close_menu")
	var persisted: Dictionary = _read_json(str(runtime.get("save_path")))
	var persisted_tutorial: Dictionary = (
		StateScript.validate((persisted.get(&"farm", {}) as Dictionary).get(&"tutorial"))
	)
	_add(
		cases,
		"P3 live tutorial mask persists inside the validated farm envelope",
		not persisted.is_empty()
		and persisted_tutorial == confirmed_state,
	)
	presenter.call("_open_help")
	var mobile: CanvasLayer = runtime.get("_mobile_controls") as CanvasLayer
	_add(
		cases,
		"P3 More Help owns modal input without a second terminal",
		bool(presenter.call("is_help_modal_open"))
		and bool(bridge.call("is_interaction_menu_open"))
		and bool(mobile.call("is_modal_input_suppressed")),
	)
	presenter.call("_close_help")
	_add(
		cases,
		"P3 closing More Help restores field input",
		not bool(bridge.call("is_interaction_menu_open"))
		and not bool(mobile.call("is_modal_input_suppressed")),
	)


static func evaluate_reloaded(runtime: Node2D, expected: Dictionary) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	var bridge: Node = runtime.get_node_or_null("HarvestPhaseTwo")
	var director: RefCounted = (
		bridge.call("get_context_tutorial_director") as RefCounted if bridge != null else null
	)
	_add(
		cases,
		"P3 cold reload restores the exact committed tutorial mask",
		director != null and director.call("get_state") == expected,
	)
	return cases


static func _first_disabled_index(menu: Dictionary) -> int:
	for index: int in (menu[&"options"] as Array).size():
		if not bool((menu[&"options"] as Array)[index][&"enabled"]):
			return index
	return -1


static func _first_enabled_index(menu: Dictionary) -> int:
	for index: int in (menu[&"options"] as Array).size():
		if bool((menu[&"options"] as Array)[index][&"enabled"]):
			return index
	return -1


static func _read_json(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


static func _successful_events() -> Array[Dictionary]:
	var option: Dictionary = _safe_option()
	var menu: Dictionary = _menu([option])
	return [
		EventScript.movement_committed(Vector2i.ZERO, Vector2i.ONE),
		EventScript.target_acquired(
			{&"valid": true, &"target_cell": Vector2i.ONE, &"target_kind": &"target.terrain"}
		),
		EventScript.terminal_opened(menu),
		EventScript.navigation_not_needed(menu),
		EventScript.safe_action_committed("interaction.snapshot.test", option, {&"ok": true}),
		EventScript.quick_committed({&"result_id": &"quick.executed", &"mutated": true}),
		EventScript.build_mode_entered({&"ok": true, &"committed": true}),
		EventScript.worker_assignment_committed(
			{
				&"ok": true, &"committed": true, &"settler_id": &"settler.a",
				&"site_id": &"site.a",
			}
		),
	]


static func _run_events(events: Array[Dictionary], idle_ticks: int) -> Dictionary:
	var probe: CommitProbe = CommitProbe.new()
	var director: RefCounted = _director(probe)
	for event: Dictionary in events:
		for _tick: int in idle_ticks:
			pass
		director.call("ingest", event)
	return director.call("get_state") as Dictionary


static func _director(probe: CommitProbe, legacy_seen: bool = false) -> RefCounted:
	var director: RefCounted = DirectorScript.new() as RefCounted
	director.call("configure", probe.state, Callable(probe, "commit"), legacy_seen)
	return director


static func _safe_option() -> Dictionary:
	var affected: Array[Vector2i] = [Vector2i.ZERO]
	var costs: Array[Dictionary] = []
	return OptionScript.build(
		&"interaction.action.inspect", &"interaction.provider.test", &"target.test",
		&"target.terrain", &"terrain.test", &"inspect", {}, true,
		&"interaction.inspect", &"", 10, affected, costs, OptionScript.CLOSE_NEVER
	)


static func _menu(options: Array[Dictionary]) -> Dictionary:
	return MenuScript.build(
		Vector2i.ZERO, &"target.test", &"target.terrain", &"terrain.test",
		&"interaction.target.terrain", {}, options
	)


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
