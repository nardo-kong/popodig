extends SceneTree

# Phase 9 Slice UX smoke: player HUD, contextual tutorial, notifications, and
# the qualitative inspector. Development run exercises tutorial advancement and
# notification delivery; Release run verifies debug chrome stays hidden while
# player-facing UX stays visible with qualitative-only inspector text.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await create_timer(1.2).timeout

	var expect_debug := _expected_debug()
	var top_bar: Control = scene.get_node("%TopBar")
	var footer: Control = scene.get_node("%Footer")
	var gameplay_hud: Control = scene.get_node("%GameplayHud")
	var tutorial_panel: Control = scene.get_node("%TutorialPanel")
	var tutorial_label: Label = scene.get_node("%TutorialLabel")
	var notifications: Control = scene.get_node("%Notifications")
	var inspector_label: Label = scene.get_node("%InspectorLabel")

	if top_bar.visible != expect_debug:
		_fail("Top bar visibility does not match the profile contract")
		return
	if footer.visible != expect_debug:
		_fail("Footer visibility does not match the profile contract")
		return
	if not gameplay_hud.visible or not tutorial_panel.visible:
		_fail("Player HUD and tutorial must stay visible in every profile")
		return
	if tutorial_label.text.is_empty():
		_fail("Contextual tutorial has no prompt text")
		return

	if expect_debug:
		var flags: Dictionary = scene._tutorial_flags
		flags["designated"] = true
		flags["open_space"] = true
		scene._slow_poll()
		if String(scene._tutorial.current_id()) != "sleep":
			_fail("Tutorial did not advance to the sleeping step after flags were set")
			return
		if tutorial_label.text.is_empty() or tutorial_label.text == "这里有点挤，挖一点空间吧——按住左键在附近泥土上拖动，指定要挖的格子。":
			_fail("Tutorial label did not refresh after advancement")
			return
		scene._push_notification("qa_smoke", "冒烟测试通知：发现事件推送正常。", Vector2i(10, 12))
		scene.notifications_view.refresh(scene._now_seconds)
		if notifications.get_child_count() == 0:
			_fail("Notification view rendered no rows after a real push")
			return
	else:
		if notifications.get_child_count() > 0:
			var row_text: String = ""
			for child: Node in notifications.get_children():
				row_text += child.get_child(0).text + " | "
			_fail("Release showed notification rows without any event: %s" % row_text)
			return

	var inspector_text := inspector_label.text
	if not expect_debug and inspector_text.contains("hardness"):
		_fail("Release inspector leaked debug numeric field names")
		return
	if inspector_text.is_empty():
		_fail("Inspector produced no text at all")
		return

	for mouse in scene.colony_simulation.get_mice():
		if not scene.path_service.is_walkable(mouse.current_cell):
			_fail("Mouse stranded inside solid terrain during UX smoke")
			return

	print("PHASE9_UX_SMOKE_PASS profile_debug=%s tutorial_step=%s notifications=%d inspector_chars=%d" % [
		expect_debug,
		String(scene._tutorial.current_id()),
		notifications.get_child_count(),
		inspector_text.length(),
	])
	quit(0)


func _expected_debug() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=").to_lower() == "true"
	return false


func _fail(message: String) -> void:
	push_error("PHASE9_UX_SMOKE_FAIL %s" % message)
	quit(1)
