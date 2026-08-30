extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/app/game_app.tscn") as PackedScene
	if packed == null:
		_fail("Main scene could not be loaded")
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var world_view = scene.get_node("WorldView")
	if world_view.get_chunk_view_count() != 30:
		_fail("Expected 30 chunk views, got %d" % world_view.get_chunk_view_count())
		return
	var node_count := _count_nodes(scene)
	var cell_count: int = scene.world_grid.width * scene.world_grid.height
	var chunk_view_count: int = world_view.get_chunk_view_count()
	# The guardrail targets per-cell presentation (~6900 nodes for 96x72).
	# The current budget: 30 chunk views + 30 dig overlays + mice views plus
	# the Phase 9 UI panels (HUD, tutorial, notifications, inspector) sits at
	# ~103 nodes, so the threshold keeps generous headroom above that.
	if node_count >= 160:
		_fail("Scene node count indicates per-cell presentation: %d" % node_count)
		return
	if scene.world_grid.width != 96 or scene.world_grid.height != 72:
		_fail("Unexpected world size")
		return
	var expected_debug := _get_expected_debug_visibility()
	for debug_control_name: String in ["TopBar", "Footer"]:
		var debug_control: CanvasItem = scene.get_node("%%%s" % debug_control_name)
		if debug_control.visible != expected_debug:
			_fail("Debug visibility mismatch for %s" % debug_control_name)
			return
	# Since Phase 9 the inspector is dual-mode: the qualitative player panel
	# stays visible in every profile, so it is exempt from the debug gate.
	var inspector: CanvasItem = scene.get_node("%Inspector")
	if not inspector.visible:
		_fail("Dual-mode inspector must stay visible in every profile")
		return
	if expected_debug:
		if not _validate_layout(scene, Vector2i(1280, 720)):
			return
		if not _validate_camera_bounds(scene):
			return
		root.remove_child(scene)
		scene.free()
		root.size = Vector2i(1920, 1080)
		var wide_scene := packed.instantiate()
		root.add_child(wide_scene)
		await process_frame
		await process_frame
		if not _validate_layout(wide_scene, Vector2i(1920, 1080)):
			return
	print("PHASE1_SCENE_SMOKE_PASS profile_debug=%s nodes=%d cells=%d chunk_views=%d" % [
		expected_debug,
		node_count,
		cell_count,
		chunk_view_count,
	])
	quit(0)


func _validate_layout(scene: Node, viewport_size: Vector2i) -> bool:
	var top_bar: Control = scene.get_node("%TopBar")
	var inspector: Control = scene.get_node("%Inspector")
	var footer: Control = scene.get_node("%Footer")
	var ui_root: Control = scene.get_node("UI/Root")
	if top_bar.get_global_rect().intersects(inspector.get_global_rect()):
		_fail("Top bar overlaps inspector at %s" % viewport_size)
		return false
	if footer.get_global_rect().intersects(top_bar.get_global_rect()) or footer.get_global_rect().intersects(inspector.get_global_rect()):
		_fail("Footer overlaps top UI at %s" % viewport_size)
		return false
	if footer.get_global_rect().end.y > ui_root.size.y + 0.5 or footer.get_global_rect().position.y < ui_root.size.y - 90.0:
		_fail("Footer is not anchored to logical viewport bottom at %s: root=%s footer=%s" % [viewport_size, ui_root.size, footer.get_global_rect()])
		return false
	return true


func _validate_camera_bounds(scene: Node) -> bool:
	var camera = scene.get_node("WorldCamera")
	var world_rect: Rect2 = scene.get_node("WorldView").get_world_rect()
	camera.zoom = Vector2.ONE * camera.max_zoom
	camera.position = Vector2(-10000.0, -10000.0)
	camera.force_clamp_to_world()
	var half_view: Vector2 = Vector2(root.size) * 0.5 / camera.zoom
	if camera.position.x < world_rect.position.x + half_view.x - 0.5 or camera.position.y < world_rect.position.y + half_view.y - 0.5:
		_fail("Camera clamp exposes space before the world")
		return false
	camera.zoom = Vector2.ONE * camera.min_zoom
	camera.position = Vector2(10000.0, 10000.0)
	camera.force_clamp_to_world()
	if not camera.position.is_equal_approx(world_rect.get_center()):
		_fail("Camera does not center a world smaller than the viewport at minimum zoom")
		return false
	return true


func _get_expected_debug_visibility() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--expect-debug="):
			return argument.trim_prefix("--expect-debug=") == "true"
	return true


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _fail(message: String) -> void:
	push_error("PHASE1_SCENE_SMOKE_FAIL %s" % message)
	quit(1)
