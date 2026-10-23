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
		var center := (Vector2(cell) + Vector2(0.5, 0.5)) * _cell_size
		DiscoveryGlyphs.draw_mark(self, kind, center, 1.0, 0.25 + band * 0.2)


func signal_band(cell: Vector2i) -> int:
	# Only the explored fringe contributes. Hidden cavities are not light sources.
	if _fog == null or not _world.is_in_bounds(cell):
		return 0
	var distance: int = _fog.distance_to_frontier(cell)
	return maxi(0, 4 - distance) if distance >= 1 else 3
