extends RefCounted


func run(harness: Object) -> void:
	harness.call("expect_done")
	await harness.call("frames", 4)
	var scene: Node = harness.get("current_scene") as Node
	harness.call("check", "main_scene_present", scene != null, "scene=%s" % str(scene))
	if scene == null:
		return
	var title_label: Label = scene.get_node("UILayer/UIRoot/TitlePanel/TitleLabel") as Label
	var begin_button: Button = scene.get_node("UILayer/UIRoot/TitlePanel/BeginButton") as Button
	var staging_panel: Control = scene.get_node("UILayer/UIRoot/StagingPanel") as Control
	harness.call(
		"check",
		"title_text",
		title_label.text == "PROTO\nISOMETRIC",
		"text=%s" % title_label.text.replace("\n", "|")
	)
	harness.call(
		"check",
		"title_visible",
		bool(scene.call("is_title_visible")),
		"visible=%s" % str(scene.call("is_title_visible"))
	)
	harness.call(
		"check",
		"title_font_floor",
		title_label.get_theme_font_size("font_size") >= 64,
		"pixels=%d" % title_label.get_theme_font_size("font_size")
	)
	harness.call(
		"check",
		"button_font_floor",
		begin_button.get_theme_font_size("font_size") >= 32,
		"pixels=%d" % begin_button.get_theme_font_size("font_size")
	)
	harness.call(
		"check",
		"button_ascii_label",
		begin_button.text == "BEGIN  >",
		"text=%s" % begin_button.text
	)
	harness.call(
		"check",
		"button_focusable",
		begin_button.focus_mode == Control.FOCUS_ALL,
		"focus_mode=%d" % int(begin_button.focus_mode)
	)
	harness.call(
		"check",
		"audio_stream_ready",
		bool(scene.call("is_audio_ready")),
		"ready=%s" % str(scene.call("is_audio_ready"))
	)
	harness.call(
		"check",
		"audio_trigger_born_zero",
		int(scene.call("get_audio_trigger_count")) == 0,
		"count=%d" % int(scene.call("get_audio_trigger_count"))
	)
	harness.call(
		"check",
		"staging_born_hidden",
		not staging_panel.visible,
		"visible=%s" % str(staging_panel.visible)
	)
	await harness.call("shot", "title_launch")
	await harness.call("click_view", begin_button)
	harness.call(
		"check",
		"begin_hides_title",
		not bool(scene.call("is_title_visible")),
		"title_visible=%s" % str(scene.call("is_title_visible"))
	)
	harness.call(
		"check",
		"begin_opens_staging",
		bool(scene.call("is_staging_visible")),
		"staging_visible=%s" % str(scene.call("is_staging_visible"))
	)
	harness.call(
		"check",
		"begin_triggers_audio_once",
		int(scene.call("get_audio_trigger_count")) == 1,
		"count=%d" % int(scene.call("get_audio_trigger_count"))
	)
	await harness.call("shot", "staging_field")
	harness.call("done")
