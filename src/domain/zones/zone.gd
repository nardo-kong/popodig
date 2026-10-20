class_name Zone
extends RefCounted

enum Type {
	SLEEPING,
	STORAGE,
	FOOD_FORAGE,
	PRODUCTION,
}

enum SetupState {
	PENDING,
	IN_PROGRESS,
	SET_UP,
}

var zone_id := 0
var zone_type: int = Type.SLEEPING
var cells: Array[Vector2i] = []
var identity_anchor := Vector2i(-1, -1)
var valid := false
var invalid_reasons := PackedStringArray()
var suitability_warnings := PackedStringArray()
var suitability := 0.0
var connected_to_colony := false
var occupant_refs: Dictionary = {}
var storage_refs: Dictionary = {}
var setup_state: int = SetupState.PENDING
var setup_material_required := 1
var setup_material_delivered := 0
var dressing_seed := 0
var dressing_revision := 0
var dressing_anchors: Array[Vector2i] = []


func _init(id: int = 0, type: int = Type.SLEEPING) -> void:
	zone_id = id
	zone_type = type


func get_type_name() -> String:
	match zone_type:
		Type.SLEEPING:
			return "SLEEPING"
		Type.STORAGE:
			return "STORAGE"
		Type.PRODUCTION:
			return "PRODUCTION"
		Type.FOOD_FORAGE:
			return "FOOD_FORAGE"
		_:
			return "UNKNOWN"


func get_setup_state_name() -> String:
	match setup_state:
		SetupState.PENDING:
			return "PENDING"
		SetupState.IN_PROGRESS:
			return "IN_PROGRESS"
		SetupState.SET_UP:
			return "SET_UP"
		_:
			return "UNKNOWN"


func get_dressing_family() -> String:
	match zone_type:
		Type.SLEEPING:
			return "sleeping_nest_proxy"
		Type.STORAGE:
			return "storage_pile_proxy"
		Type.PRODUCTION:
			return "workbench_proxy"
		Type.FOOD_FORAGE:
			return "food_forage_proxy"
		_:
			return "unknown_proxy"


func snapshot():
	var copy := Zone.new(zone_id, zone_type)
	copy.cells.assign(cells)
	copy.identity_anchor = identity_anchor
	copy.valid = valid
	copy.invalid_reasons = invalid_reasons.duplicate()
	copy.suitability_warnings = suitability_warnings.duplicate()
	copy.suitability = suitability
	copy.connected_to_colony = connected_to_colony
	copy.occupant_refs = occupant_refs.duplicate(true)
	copy.storage_refs = storage_refs.duplicate(true)
	copy.setup_state = setup_state
	copy.setup_material_required = setup_material_required
	copy.setup_material_delivered = setup_material_delivered
	copy.dressing_seed = dressing_seed
	copy.dressing_revision = dressing_revision
	copy.dressing_anchors.assign(dressing_anchors)
	return copy
