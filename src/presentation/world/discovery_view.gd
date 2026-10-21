class_name DiscoveryView
extends Node2D

const Discovery = preload("res://src/domain/features/discovery_system.gd")
var _world
var _registry
var _fog
var _cell_size := 16
var _clock := 0.0


func configure(world, registry, fog, cell_size: int) -> void:
	_world = world
	_registry = registry
	_fog = fog
	_cell_size = cell_size


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= 0.2:
		_clock = 0.0
		queue_redraw()


func _draw() -> void:
	if _registry == null:
		return
	for feature in _registry.get_features("discovery"):
		if bool(feature.metadata.get("claimed", false)):
			continue
		var cell: Vector2i = feature.anchor
		var band := signal_band(cell)
		if band == 0:
			continue
		var definition: Dictionary = Discovery.definition_for(str(feature.metadata.get("definition_id", "")))
		var kind: String = str(definition.get("kind", "material"))
		var tint := Color("e8c98a")
		if kind == "food":
			tint = Color("b7d29b")
		elif kind in ["stone", "ore"]:
			tint = Color("c4b3a5") if kind == "stone" else Color("d59a6b")
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size
		# Local category silhouettes remain visible without revealing object geometry.
		tint.a = 0.25 + band * 0.2
		if kind == "collectible":
			draw_line(center + Vector2(0, -4), center + Vector2(0, 4), tint, 1.5)
			draw_line(center + Vector2(-4, 0), center + Vector2(4, 0), tint, 1.5)
			draw_circle(center, 1.5, tint)
		elif kind == "food":
			draw_line(center + Vector2(0, 3), center + Vector2(0, -1), tint, 1.5)
			draw_circle(center + Vector2(-2, -2), 2.0, tint)
			draw_circle(center + Vector2(2, -3), 2.0, tint)
		elif kind == "material":
			for x: int in [-3, 0, 3]:
				draw_line(center + Vector2(x, 3), center + Vector2(x + 1, -3), tint, 1.2)
		elif kind == "ore":
			draw_polyline(PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0), center + Vector2(0, -4)]), tint, 1.5)
		else:
			draw_arc(center, 3.5, 0.0, TAU, 6, tint, 1.5)


func signal_band(cell: Vector2i) -> int:
	# Only the explored fringe contributes. Hidden cavities are not light sources.
	if _fog == null or not _world.is_in_bounds(cell):
		return 0
	var distance: int = _fog.distance_to_frontier(cell)
	return maxi(0, 4 - distance) if distance >= 1 else 3
