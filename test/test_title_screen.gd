extends GutTest


func test_project_launches_title_scene() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	assert_eq(main_scene, "res://scenes/title_screen.tscn")


func test_title_scene_builds_launch_controls() -> void:
	var packed_scene: PackedScene = load("res://scenes/title_screen.tscn") as PackedScene
	assert_not_null(packed_scene)
	var scene: Node = packed_scene.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var title_label: Label = scene.get_node("UILayer/UIRoot/TitlePanel/TitleLabel") as Label
	var begin_button: Button = scene.get_node("UILayer/UIRoot/TitlePanel/BeginButton") as Button
	assert_eq(title_label.text, "PROTO\nISOMETRIC")
	assert_true(title_label.visible)
	assert_gte(title_label.get_theme_font_size("font_size"), 64)
	assert_eq(begin_button.text, "BEGIN  >")
	assert_gte(begin_button.get_theme_font_size("font_size"), 32)
	assert_false(bool(scene.call("is_staging_visible")))
