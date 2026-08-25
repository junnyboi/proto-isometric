extends RefCounted

const CommandsScript: GDScript = preload("res://scripts/harvest_command_intents.gd")
const DepthScript: GDScript = preload("res://scripts/diagonal_depth.gd")
const FarmRendererScript: GDScript = preload("res://scripts/farm_render_adapter.gd")
const MobileControlsScript: GDScript = preload("res://scripts/mobile_controls.gd")
const ResolverScript: GDScript = preload("res://scripts/interaction_resolver.gd")
const ReticleScript: GDScript = preload("res://scripts/target_reticle.gd")
const ToolPolicyScript: GDScript = preload("res://scripts/tool_friendly_fire_policy.gd")
const ToolPresenterScript: GDScript = preload("res://scripts/tool_action_presenter.gd")
const VisualCatalogScript: GDScript = preload("res://scripts/visual_catalog.gd")
const WorldObjectsScript: GDScript = preload("res://scripts/world_objects.gd")

const EXPECTED_TARGETS: Dictionary = {
	&"N": Vector2i(-1, -1),
	&"NE": Vector2i(0, -1),
	&"E": Vector2i(1, -1),
	&"SE": Vector2i(1, 0),
	&"S": Vector2i(1, 1),
	&"SW": Vector2i(0, 1),
	&"W": Vector2i(-1, 1),
	&"NW": Vector2i(-1, 0),
}


class Projector:
	extends RefCounted

	func project(cell: Vector2i) -> Vector2:
		return Vector2(cell * 10)


static func evaluate(runtime: Node2D) -> Array[Dictionary]:
	var cases: Array[Dictionary] = []
	_test_commands(cases)
	_test_targeting(cases)
	_test_tool_separation(cases)
	_test_reticle_and_renderer(cases)
	_test_depth(cases)
	_test_assets(cases)
	_test_touch(cases)
	_test_live_bridge(cases, runtime)
	return cases


static func _test_commands(cases: Array[Dictionary]) -> void:
	_add(cases, "PH-09 stable command defaults install", CommandsScript.install_defaults())
	var unique_ids: Dictionary = {}
	var unique_descriptors: Dictionary = {}
	var complete: bool = true
	for action: StringName in CommandsScript.action_ids():
		unique_ids[action] = true
		var descriptors: Dictionary = CommandsScript.descriptors_for(action)
		for platform: StringName in [&"keyboard", &"controller", &"touch"]:
			var values: Array = descriptors.get(platform, []) as Array
			complete = complete and not values.is_empty()
			for descriptor: Dictionary in values:
				var signature: String = _descriptor_signature(descriptor)
				complete = complete and not unique_descriptors.has(signature)
				unique_descriptors[signature] = action
	_add(
		cases,
		"PH-09 all fifteen intents have unique keyboard, controller, and touch descriptors",
		complete and unique_ids.size() == 15 and CommandsScript.validate_defaults(),
	)
	var attack: Dictionary = CommandsScript.descriptors_for(CommandsScript.COMBAT_ATTACK)
	_add(
		cases,
		"PH-09 legacy Smash remains on Space/J/K, controller X/shoulder, and touch Smash",
		(
			(attack[&"keyboard"] as Array).size() == 3
			and (attack[&"controller"] as Array).size() == 2
			and (attack[&"touch"] as Array)[0][&"control"] == &"smash_button"
		),
	)


static func _test_targeting(cases: Array[Dictionary]) -> void:
	var facings_exact: bool = true
	for facing: StringName in EXPECTED_TARGETS:
		facings_exact = facings_exact and (
			ResolverScript.adjacent_cell(Vector2i.ZERO, facing) == EXPECTED_TARGETS[facing]
		)
	_add(cases, "PH-10 all eight facings resolve exactly one adjacent cell", facings_exact)
	var priority: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO,
		&"SE",
		ResolverScript.MASK_ALL,
		{&"kinds": [&"terrain", &"crop", &"pickup"]},
	)
	_add(
		cases,
		"PH-10 deterministic priority chooses pickup over crop and terrain",
		bool(priority[&"valid"]) and priority[&"target_kind"] == &"pickup",
	)
	var invalid: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO,
		&"SE",
		ResolverScript.MASK_ALL,
		{&"kinds": [], &"blocked": true},
		ResolverScript.ACTION_TOOL,
	)
	_add(
		cases,
		"PH-10 invalid actions return one quiet sealed rejection",
		(
			ResolverScript.validate_result(invalid)
			and not bool(invalid[&"valid"])
			and invalid[&"action"] == ResolverScript.ACTION_NONE
			and invalid[&"rejection_reason"] == ResolverScript.REJECT_BLOCKED
		),
	)


static func _test_tool_separation(cases: Array[Dictionary]) -> void:
	var denied: bool = true
	for target: Dictionary in [
		{&"kind": &"crop"},
		{&"kind": &"resident"},
		{&"kind": &"friendly_fauna"},
		{&"kind": &"structure", &"home": true},
		{&"kind": &"structure", &"machine": true},
	]:
		denied = denied and ToolPolicyScript.denies_damage(target[&"kind"], target)
		var result: Dictionary = ResolverScript.resolve(
			Vector2i.ZERO,
			&"SE",
			ResolverScript.MASK_ALL,
			{
				&"kinds": [target[&"kind"]],
				&"home": target.get(&"home", false),
				&"machine": target.get(&"machine", false),
				&"tool_damage": true,
			},
			ResolverScript.ACTION_TOOL,
		)
		denied = denied and result[&"rejection_reason"] == ResolverScript.REJECT_FRIENDLY_FIRE
	_add(cases, "PH-11 tool damage denies every friendly and home target", denied)
	var crop_preview: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO,
		&"SE",
		ResolverScript.MASK_ALL,
		{&"kinds": [&"crop"], &"tool_damage": false},
		ResolverScript.ACTION_TOOL,
	)
	var hostile_attack: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO,
		&"SE",
		ResolverScript.MASK_ALL,
		{&"kinds": [&"hostile"]},
		ResolverScript.ACTION_ATTACK,
	)
	_add(
		cases,
		"PH-11 productive previews and hostile combat remain separate valid actions",
		(
			crop_preview[&"action"] == ResolverScript.ACTION_PREVIEW
			and hostile_attack[&"action"] == ResolverScript.ACTION_ATTACK
		),
	)
	var presenter: Node2D = ToolPresenterScript.new() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(presenter)
	var contacts: Array[Dictionary] = []
	presenter.connect(
		"tool_contact_frame", func(result: Dictionary) -> void: contacts.append(result)
	)
	var started: bool = bool(presenter.call("play_tool", &"tool.hoe", crop_preview))
	presenter.call("_process", float(presenter.call("get_contact_time")) + 0.01)
	presenter.call("_process", float(presenter.call("get_duration")))
	_add(
		cases,
		"PH-11 tool lifecycle emits one contact independently from Walker impact",
		started and contacts.size() == 1 and not bool(presenter.call("is_playing")),
	)
	presenter.free()


static func _test_reticle_and_renderer(cases: Array[Dictionary]) -> void:
	var projector: RefCounted = Projector.new() as RefCounted
	var reticle: Node2D = ReticleScript.new() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(reticle)
	reticle.call("configure", Callable(projector, "project"))
	var result: Dictionary = ResolverScript.resolve(
		Vector2i.ZERO, &"SE", ResolverScript.MASK_ALL, {&"kinds": [&"terrain"]}
	)
	reticle.call("present", result)
	var redraw_once: int = int(reticle.call("get_redraw_request_count"))
	reticle.call("present", result)
	_add(
		cases,
		"PH-10 visible reticle redraws only when its target snapshot changes",
		(
			redraw_once == 1
			and int(reticle.call("get_redraw_request_count")) == redraw_once
			and (reticle.call("get_snapshot") as Dictionary)[&"cell"] == Vector2i(1, 0)
		),
	)
	reticle.free()
	var renderer: Node2D = FarmRendererScript.new() as Node2D
	(Engine.get_main_loop() as SceneTree).root.add_child(renderer)
	renderer.call("configure", Callable(projector, "project"), 8)
	var indexes: Dictionary = {
		Vector2i.ZERO: [
			{&"cell": Vector2i(1, 1), &"type": &"soil", &"stable_id": &"soil"},
			{&"cell": Vector2i(2, 1), &"type": &"crop", &"stable_id": &"crop"},
		]
	}
	var accepted: bool = bool(renderer.call("consume_indexes", indexes))
	var visible_chunks: Array[Vector2i] = [Vector2i.ZERO]
	renderer.call("set_visible_chunks", visible_chunks)
	var redraw: int = int(renderer.call("get_redraw_request_count"))
	renderer.call("consume_indexes", indexes)
	renderer.call("set_visible_chunks", visible_chunks)
	var remote_dirty: Array[Vector2i] = [Vector2i(80, 80)]
	renderer.call("invalidate_cells", remote_dirty)
	var no_visible_redraw: bool = int(renderer.call("get_redraw_request_count")) == redraw
	var visible_dirty: Array[Vector2i] = [Vector2i(1, 1)]
	renderer.call("invalidate_cells", visible_dirty)
	_add(
		cases,
		"PH-12 renderer consumes chunk indexes with no per-crop Node or idle redraw",
		(
			accepted
			and int(renderer.call("get_visible_record_count")) == 2
			and not bool(renderer.call("has_per_crop_nodes"))
			and no_visible_redraw
			and int(renderer.call("get_redraw_request_count")) == redraw + 1
		),
	)
	renderer.free()


static func _test_depth(cases: Array[Dictionary]) -> void:
	_add(
		cases,
		"PH-13 trees, crops, residents, and Walker own one-cell foot anchors",
		(
			DepthScript.footprint_for(&"tree", Vector2i(2, 3)) == [Vector2i(2, 3)]
			and DepthScript.footprint_for(&"crop", Vector2i(2, 3)) == [Vector2i(2, 3)]
			and DepthScript.footprint_for(&"resident", Vector2i(2, 3)) == [Vector2i(2, 3)]
			and DepthScript.footprint_for(&"walker", Vector2i(2, 3)) == [Vector2i(2, 3)]
		),
	)
	var records: Array[Dictionary] = []
	for facing: StringName in EXPECTED_TARGETS:
		records.append(
			{
				&"anchor": EXPECTED_TARGETS[facing],
				&"kind": &"tree",
				&"stable_id": facing,
			}
		)
	var first: Array[Dictionary] = DepthScript.stable_sort(records)
	var second: Array[Dictionary] = DepthScript.stable_sort(records)
	var monotonic: bool = first == second
	for index: int in range(1, first.size()):
		var previous_bucket: int = int(DepthScript.depth_key(first[index - 1])[0])
		var current_bucket: int = int(DepthScript.depth_key(first[index])[0])
		monotonic = monotonic and previous_bucket <= current_bucket
	_add(cases, "PH-13 all approach directions sort deterministically by diagonal depth", monotonic)
	var objects: Node2D = WorldObjectsScript.new() as Node2D
	var approach_cells: Array[Vector2i] = []
	for value: Variant in EXPECTED_TARGETS.values():
		approach_cells.append(value as Vector2i)
	objects.call("set_visible_cells", approach_cells)
	var ordered: Array = objects.get("_visible_cells") as Array
	var ordered_buckets: bool = true
	for index: int in range(1, ordered.size()):
		ordered_buckets = ordered_buckets and (
			DepthScript.bucket_for(ordered[index - 1]) <= DepthScript.bucket_for(ordered[index])
		)
	_add(cases, "PH-13 existing batched world objects use diagonal cell order", ordered_buckets)
	objects.free()


static func _test_assets(cases: Array[Dictionary]) -> void:
	var hoe: Texture2D = load("res://assets/tools/protos_hoe_spritesheet.png") as Texture2D
	var water: Texture2D = load("res://assets/tools/protos_water_spritesheet.png") as Texture2D
	var assets_valid: bool = hoe.get_size() == Vector2(1024, 512)
	assets_valid = assets_valid and water.get_size() == Vector2(1024, 512)
	for name: String in ["hoe", "watering_tool", "axe", "pick", "seed_pouch"]:
		var icon: Texture2D = load("res://assets/ui/tools/icon_%s.png" % name) as Texture2D
		assets_valid = assets_valid and icon != null and icon.get_size() == Vector2(256, 256)
	var catalog: Resource = VisualCatalogScript.new() as Resource
	var required: Array[String] = catalog.call("get_required_paths") as Array[String]
	_add(
		cases,
		"PH-11 GPT Image 2/video-carrier tool assets validate and register",
		(
			assets_valid
			and "res://assets/tools/protos_hoe_spritesheet.png" in required
			and "res://assets/ui/tools/icon_seed_pouch.png" in required
			and bool(catalog.call("validate_required"))
		),
	)


static func _test_touch(cases: Array[Dictionary]) -> void:
	var mobile: CanvasLayer = MobileControlsScript.new() as CanvasLayer
	(Engine.get_main_loop() as SceneTree).root.add_child(mobile)
	mobile.call("force_mobile", true)
	mobile.call("apply_layout", Vector2(720.0, 1280.0))
	var commands: Array[StringName] = []
	var smashes: Array[bool] = []
	mobile.connect(
		"command_pressed", func(action: StringName) -> void: commands.append(action)
	)
	mobile.connect("smash_pressed", func() -> void: smashes.append(true))
	mobile.call("trigger_command", CommandsScript.CONTEXT)
	mobile.call("trigger_smash")
	var buttons: Dictionary = mobile.get("_command_buttons") as Dictionary
	var dock: Control = mobile.get("_command_dock") as Control
	var smash: Button = mobile.call("get_smash_button") as Button
	var dock_rect: Rect2 = Rect2(dock.position, dock.size)
	var smash_rect: Rect2 = Rect2(smash.position, smash.size)
	_add(
		cases,
		"PH-09 portrait touch dock exposes seven commands without covering Smash",
		(
			buttons.size() == 7
			and commands == [CommandsScript.CONTEXT]
			and smashes.size() == 1
			and dock.visible
			and not dock_rect.intersects(smash_rect)
			and Rect2(Vector2.ZERO, Vector2(720.0, 1280.0)).encloses(dock_rect)
		),
	)
	mobile.free()


static func _test_live_bridge(cases: Array[Dictionary], runtime: Node2D) -> void:
	var bridge: Node = runtime.get_node("HarvestPhaseTwo")
	var controller: Node2D = bridge.call("get_interaction_controller") as Node2D
	var renderer: Node2D = bridge.call("get_farm_renderer") as Node2D
	_add(
		cases,
		"PH-09 live field composes command, reticle, tool, and farm render seams",
		(
			bool(bridge.call("is_ready_for_commands"))
			and controller != null
			and renderer != null
			and controller.call("get_reticle") != null
			and controller.call("get_tool_presenter") != null
		),
	)
	var target: Dictionary = controller.call("get_last_target") as Dictionary
	var expected: Vector2i = ResolverScript.adjacent_cell(
		runtime.call("get_robot_grid"), runtime.call("get_facing")
	)
	_add(
		cases,
		"PH-10 live reticle follows the authoritative adjacent facing cell",
		ResolverScript.validate_result(target) and target[&"target_cell"] == expected,
	)
	var world: RefCounted = runtime.get("_world") as RefCounted
	var coordinator: RefCounted = runtime.get("_run_coordinator") as RefCounted
	var world_before: Dictionary = world.call("make_snapshot") as Dictionary
	var run_before: Dictionary = coordinator.call("get_run_snapshot") as Dictionary
	var avatar: Node2D = runtime.call("get_avatar") as Node2D
	var accepted: bool = bool(controller.call("handle_touch_command", CommandsScript.TOOL_ACTION))
	var presenter: Node2D = controller.call("get_tool_presenter") as Node2D
	var hidden_during_tool: bool = not avatar.visible and bool(presenter.call("is_playing"))
	presenter.call("_process", float(presenter.call("get_duration")) + 0.01)
	_add(
		cases,
		"PH-11 live tool preview costs nothing, mutates nothing, and restores the Walker",
		(
			accepted
			and hidden_during_tool
			and avatar.visible
			and world_before == world.call("make_snapshot")
			and run_before == coordinator.call("get_run_snapshot")
		),
	)


static func _descriptor_signature(descriptor: Dictionary) -> String:
	if descriptor[&"type"] == &"touch":
		return "touch:%s:%s" % [descriptor[&"control"], descriptor[&"direction"]]
	return "%s:%s:%s" % [
		descriptor[&"type"],
		descriptor.get(&"code", -1),
		signf(float(descriptor.get(&"value", 0.0))),
	]


static func _add(cases: Array[Dictionary], label: String, passed: bool) -> void:
	cases.append({&"label": label, &"passed": passed})
