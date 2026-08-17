class_name ColonyDebugOverlay
extends Node2D

var colony_simulation
var cell_size := 16
var _refresh_accumulator := 0.0


func configure(simulation, logical_cell_size: int) -> void:
	colony_simulation = simulation
	cell_size = logical_cell_size
	queue_redraw()


func _process(delta: float) -> void:
	if colony_simulation == null or not visible:
		return
	_refresh_accumulator += delta
	if _refresh_accumulator >= 0.1:
		_refresh_accumulator = 0.0
		queue_redraw()


func _draw() -> void:
	if colony_simulation == null:
		return
	var colors: Array[Color] = [Color("64c2d4"), Color("d692c6"), Color("9dc879")]
	var mice: Array = colony_simulation.get_mice()
	for index: int in range(mice.size()):
		var agent = mice[index]
		var color: Color = colors[index % colors.size()]
		var snapshot: Dictionary = agent.get_debug_snapshot()
		var current_center := _cell_center(snapshot.get("current_cell", agent.current_cell))
		draw_arc(current_center, 6.5 + index, 0.0, TAU, 18, color, 1.0)
		var path: Array = snapshot.get("path", [])
		var previous := current_center
		for cell_value: Variant in path:
			if not cell_value is Vector2i:
				continue
			var next := _cell_center(cell_value)
			draw_line(previous, next, Color(color, 0.72), 1.5)
			previous = next
		var target: Vector2i = agent.get_current_job_cell()
		if target.x >= 0:
			draw_rect(Rect2(_cell_center(target) - Vector2.ONE * 4.0, Vector2.ONE * 8.0), color, false, 1.5)


func _cell_center(cell_coord: Vector2i) -> Vector2:
	return (Vector2(cell_coord) + Vector2(0.5, 0.5)) * cell_size
