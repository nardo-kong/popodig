extends SceneTree

const GeneratorScript = preload("res://src/domain/world/simple_world_generator.gd")
const WorldViewScript = preload("res://src/presentation/world/world_view.gd")
const ChunkScript = preload("res://src/domain/world/world_chunk.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var world = GeneratorScript.new().generate({"world_size": [240, 260], "chunk_size": 16}, 9001)
	var host := Node2D.new()
	root.add_child(host)
	var world_view = WorldViewScript.new()
	host.add_child(world_view)
	world_view.configure(world, 16)
	await process_frame
	await process_frame
	if world_view.get_chunk_view_count() != 255:
		_fail("Expected 255 chunk views, got %d" % world_view.get_chunk_view_count())
		return
	var target_cell := Vector2i(120, 100)
	if not world.is_solid(target_cell) or world.is_protected(target_cell):
		_fail("Stress edit fixture cell is not editable")
		return
	var target_chunk: Vector2i = world.cell_to_chunk(target_cell)
	var unrelated_chunk := Vector2i.ZERO
	var target_view = world_view.get_chunk_view(target_chunk)
	var unrelated_view = world_view.get_chunk_view(unrelated_chunk)
	var target_draws_before: int = target_view.draw_count
	var target_requests_before: int = target_view.redraw_request_count
	var unrelated_draws_before: int = unrelated_view.draw_count
	var unrelated_requests_before: int = unrelated_view.redraw_request_count
	if not world.set_excavated(target_cell, true):
		_fail("Stress cell edit was rejected")
		return
	if target_view.redraw_request_count != target_requests_before + 1:
		_fail("Target chunk did not receive exactly one redraw request")
		return
	if unrelated_view.redraw_request_count != unrelated_requests_before:
		_fail("Unrelated chunk received a redraw request")
		return
	await process_frame
	await process_frame
	if target_view.draw_count <= target_draws_before:
		_fail("Target chunk did not redraw after edit")
		return
	if unrelated_view.draw_count != unrelated_draws_before:
		_fail("Unrelated chunk redrew after local edit")
		return
	if world.get_chunk(target_chunk).is_dirty(ChunkScript.DIRTY_TERRAIN):
		_fail("Terrain dirty flag was not consumed after draw")
		return
	print("PHASE1_LARGE_RENDER_PASS cells=%d chunk_views=%d nodes=%d target_redraws=%d" % [
		world.width * world.height,
		world_view.get_chunk_view_count(),
		_count_nodes(host),
		target_view.draw_count - target_draws_before,
	])
	quit(0)


func _count_nodes(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _count_nodes(child)
	return count


func _fail(message: String) -> void:
	push_error("PHASE1_LARGE_RENDER_FAIL %s" % message)
	quit(1)
