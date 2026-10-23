extends "res://tests/phase22_readability_smoke.gd"

# Reuse the real viewport pointer/key and fog-boundary checks. Only presentation
# captures differ; no economy/worldgen fixtures are added by this revision.
class ArtBoard:
	extends Control
	const MouseTexture := preload("res://assets/art/production/entities/mouse_master_idle_01.png")
	const SoilTexture := preload("res://assets/art/production/terrain/terrain_soil_soft_center_01.png")

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(Vector2.ZERO, size), Color("24252a"))
		draw_string(font, Vector2(35, 42), "Soft Pixel resource revision 02 - original mouse comparison", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e8dbbc"))
		draw_string(font, Vector2(35, 70), "Presentation sampler only; not a gameplay discovery or progression capture", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("baaf9c"))
		var ids := ["FOOD", "GENERAL_MATERIAL", "STONE", "ORE", "METAL", "ROOT"]
		var titles := ["Original mouse", "Food", "Building", "Stone", "Ore", "Metal", "Roots"]
		for column: int in range(7):
			draw_string(font, Vector2(50 + column * 174, 107), titles[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e8dbbc"))
		for row: int in range(4):
			var y := 158.0 + row * 145.0
			var extent: float = [54.0, 18.0, 39.6, 128.0][row]
			draw_string(font, Vector2(35, y - 20), ["Guide 54px", "World 1x", "World 2.2x", "Detail 128px"][row], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("baaf9c"))
			for column: int in range(7):
				var center := Vector2(100 + column * 174, y + 42)
				if row == 1 or row == 2:
					for tile: int in range(5):
						draw_texture_rect(SoilTexture, Rect2(center + Vector2(-40 + tile * 16, extent * 0.5), Vector2(16, 16)), false)
				if column == 0:
					draw_texture_rect(MouseTexture, Rect2(center - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), false)
				else:
					var id: String = ids[column - 1]
					var actual_extent := extent * 22.0 / 18.0 if id == "ROOT" and (row == 1 or row == 2) else extent
					draw_texture_rect(ResourceVisuals.texture(id), ResourceVisuals.fitted_rect(id, center, actual_extent), false)


func _capture(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await _save_art_capture(name)
	if name == "food":
		var initial_zoom: Vector2 = scene.world_camera.zoom
		var initial_position: Vector2 = scene.world_camera.position
		var food_cell: Vector2i = scene._selected_cell
		for zoom_value: float in [0.55, 2.2]:
			scene.world_camera._set_zoom(zoom_value)
			scene.world_camera.focus_cell(food_cell, 16)
			scene.world_camera.reset_smoothing()
			scene.world_camera.force_update_scroll()
			await process_frame
			await _hover(food_cell)
			if not _expect_tip("resource", "FOOD"):
				_fail("Zoom capture does not keep the actual food pile under its hover")
				return
			await _save_art_capture("world_zoom_%s" % str(zoom_value).replace(".", "_"))
		scene.world_camera.zoom = initial_zoom
		scene.world_camera.position = initial_position
		scene.world_camera.reset_smoothing()
		await process_frame
		await _hover(food_cell)
	if name == "guide":
		var layer := CanvasLayer.new()
		layer.layer = 100
		root.add_child(layer)
		var board := ArtBoard.new()
		board.size = Vector2(1280, 720)
		board.scale = Vector2(root.size) / board.size
		layer.add_child(board)
		await process_frame
		await _save_art_capture("scale_sampler")
		layer.queue_free()
		await process_frame


func _save_art_capture(name: String) -> void:
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_png("res://art/qa/screenshots/phase23_%s_%s_%d.png" % [name, locale, root.size.x])
