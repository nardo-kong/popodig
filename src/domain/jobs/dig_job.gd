class_name DigJob
extends RefCounted

enum State {
	QUEUED,
	RESERVED,
	COMPLETED,
	CANCELLED,
}

var job_id := 0
var cell := Vector2i(-1, -1)
var work_cell := Vector2i(-1, -1)
var state: int = State.QUEUED
var worker_id := ""
var required_work := 1.0
var completed_work := 0.0
var priority := 0


func _init(id: int = 0, target_cell: Vector2i = Vector2i(-1, -1)) -> void:
	job_id = id
	cell = target_cell


func normalized_progress() -> float:
	if required_work <= 0.0:
		return 1.0
	return clampf(completed_work / required_work, 0.0, 1.0)


func is_reserved() -> bool:
	return state == State.RESERVED


func snapshot():
	var copy := DigJob.new(job_id, cell)
	copy.work_cell = work_cell
	copy.state = state
	copy.worker_id = worker_id
	copy.required_work = required_work
	copy.completed_work = completed_work
	copy.priority = priority
	return copy
