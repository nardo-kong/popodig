class_name WorldChunk
extends RefCounted

const DIRTY_TERRAIN := 1
const DIRTY_SIGNALS := 2
const DIRTY_WATER := 4
const DIRTY_STABILITY := 8
const DIRTY_PATHING := 16
const DIRTY_ALL := DIRTY_TERRAIN | DIRTY_SIGNALS | DIRTY_WATER | DIRTY_STABILITY | DIRTY_PATHING

var coord := Vector2i.ZERO
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var dirty_flags := DIRTY_ALL


func _init(chunk_coord: Vector2i, chunk_origin: Vector2i, chunk_size: Vector2i) -> void:
	coord = chunk_coord
	origin = chunk_origin
	size = chunk_size


func get_rect() -> Rect2i:
	return Rect2i(origin, size)


func mark_dirty(flags: int) -> bool:
	var previous := dirty_flags
	dirty_flags |= flags
	return previous != dirty_flags


func consume_dirty(flags: int = DIRTY_ALL) -> int:
	var consumed := dirty_flags & flags
	dirty_flags &= ~flags
	return consumed


func is_dirty(flags: int = DIRTY_ALL) -> bool:
	return (dirty_flags & flags) != 0
