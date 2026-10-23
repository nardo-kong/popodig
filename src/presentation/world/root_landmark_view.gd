extends Node2D

var registry
var fog
var cell_size := 16
var _elapsed := 0.0


func configure(features, visibility, logical_cell_size: int) -> void:
	registry = features
	fog = visibility
	cell_size = logical_cell_size


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		queue_redraw()


func _draw() -> void:
	if registry == null:
		return
	for feature in registry.get_features("root_cluster"):
		if feature.hidden:
			continue
		for cell: Vector2i in feature.cells:
			if fog.distance_to_frontier(cell) <= 1:
				var center := (Vector2(cell) + Vector2.ONE * 0.5) * cell_size
				draw_texture_rect(ResourceVisuals.texture("ROOT"), ResourceVisuals.fitted_rect("ROOT", center, 22.0), false)
				break
