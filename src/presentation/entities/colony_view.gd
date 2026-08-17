class_name ColonyView
extends Node2D

const MouseViewScript = preload("res://src/presentation/entities/mouse_view.gd")

var colony_simulation
var cell_size := 16
var _mouse_views: Dictionary = {}


func configure(simulation, logical_cell_size: int) -> void:
	colony_simulation = simulation
	cell_size = logical_cell_size
	_sync_mice()


func get_mouse_view_count() -> int:
	return _mouse_views.size()


func _process(_delta: float) -> void:
	if colony_simulation == null:
		visible = false
		return
	visible = true
	_sync_mice()


func _sync_mice() -> void:
	if colony_simulation == null:
		return
	var live_ids: Dictionary = {}
	var mice: Array = colony_simulation.get_mice()
	for index: int in range(mice.size()):
		var agent = mice[index]
		var mouse_id := String(agent.mouse_id)
		live_ids[mouse_id] = true
		if _mouse_views.has(mouse_id):
			continue
		var view := MouseViewScript.new()
		view.name = "Mouse_%s" % mouse_id.validate_node_name()
		add_child(view)
		view.configure(agent, cell_size, index)
		_mouse_views[mouse_id] = view
	for mouse_id: String in _mouse_views.keys():
		if live_ids.has(mouse_id):
			continue
		var stale_view: Node = _mouse_views[mouse_id]
		_mouse_views.erase(mouse_id)
		stale_view.queue_free()
