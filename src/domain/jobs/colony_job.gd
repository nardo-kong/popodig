class_name ColonyJob
extends RefCounted

enum Type {
	HAUL_FOOD,
	HAUL_MATERIAL,
	EMERGENCY_HAUL,
	ZONE_SETUP,
	REINFORCE,
	SEAL,
}

enum State {
	PENDING,
	RESERVED,
	COMPLETED,
	CANCELLED,
}

var job_id := 0
var job_type: int = Type.HAUL_MATERIAL
var state: int = State.PENDING
var priority := 20.0
var source_pile_id := -1
var target_cell := Vector2i(-1, -1)
var item_type := ""
var item_count := 0
var zone_id := -1
var worker_id := ""
var item_reservation_id := -1
var dropoff_reservation_id := -1


func snapshot():
	var copy := ColonyJob.new()
	copy.job_id = job_id
	copy.job_type = job_type
	copy.state = state
	copy.priority = priority
	copy.source_pile_id = source_pile_id
	copy.target_cell = target_cell
	copy.item_type = item_type
	copy.item_count = item_count
	copy.zone_id = zone_id
	copy.worker_id = worker_id
	copy.item_reservation_id = item_reservation_id
	copy.dropoff_reservation_id = dropoff_reservation_id
	return copy


func get_type_name() -> String:
	match job_type:
		Type.HAUL_FOOD:
			return "HAUL_FOOD"
		Type.HAUL_MATERIAL:
			return "HAUL_MATERIAL"
		Type.EMERGENCY_HAUL:
			return "EMERGENCY_HAUL"
		Type.ZONE_SETUP:
			return "ZONE_SETUP"
		Type.REINFORCE:
			return "REINFORCE"
		Type.SEAL:
			return "SEAL"
		_:
			return "UNKNOWN"
