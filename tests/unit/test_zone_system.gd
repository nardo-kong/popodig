extends RefCounted

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const GridScript = preload("res://src/domain/world/world_grid.gd")
const PathServiceScript = preload("res://src/application/services/grid_path_service.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const ZoneSystemScript = preload("res://src/domain/zones/zone_system.gd")

const BALANCE := {
	"zones": {"setup_material_per_zone": 2},
	"pathfinding": {"max_walkable_water_units": 1},
}

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	_test_paint_validation_and_grid_membership()
	_test_deterministic_split_merge_and_reassignment()
	_test_setup_and_dressing_contract()
	_test_suitability_reacts_to_water()
	_test_reference_preservation_and_storage_invalidation()
	return results


func _test_paint_validation_and_grid_membership() -> void:
	var context := _context()
	var world = context.world
	var zones = context.zones
	_assert_equal(zones.inspect_cell(ZoneScript.Type.SLEEPING, Vector2i(9, 1)).reason_code, ZoneSystemScript.REASON_NOT_EXCAVATED, "Zone paint rejects solid cells")
	world.initialize_cell(Vector2i(10, 6), CellDataScript.TerrainMaterial.SOFT_SOIL, true)
	_assert_equal(zones.inspect_cell(ZoneScript.Type.STORAGE, Vector2i(10, 6)).reason_code, ZoneSystemScript.REASON_NOT_CONNECTED, "Zone paint rejects disconnected natural cavities")
	world.set_water_units(Vector2i(3, 3), 2)
	_assert_equal(zones.inspect_cell(ZoneScript.Type.FOOD_FORAGE, Vector2i(3, 3)).reason_code, ZoneSystemScript.REASON_FLOODED, "Zone paint rejects full water")
	world.set_water_units(Vector2i(3, 3), 0)
	var painted: Dictionary = zones.paint_zone(ZoneScript.Type.SLEEPING, [Vector2i(2, 3), Vector2i(3, 3)])
	_assert_true(painted.ok, "Connected excavated cells can be painted as Sleeping")
	_assert_equal(painted.changed_cells, [Vector2i(2, 3), Vector2i(3, 3)], "Paint result returns deterministic changed cells")
	var zone: Zone = zones.get_zone_at(Vector2i(2, 3))
	_assert_true(zone != null and zone.zone_type == ZoneScript.Type.SLEEPING, "Paint creates deterministic zone ownership")
	_assert_equal(world.get_zone_id(Vector2i(2, 3)), zone.zone_id, "ZoneSystem synchronizes compact WorldGrid membership")
	var repeated: Dictionary = zones.paint_zone(ZoneScript.Type.SLEEPING, [Vector2i(2, 3), Vector2i(2, 3)])
	_assert_equal(repeated.reason_code, ZoneSystemScript.REASON_ALREADY_ASSIGNED, "Duplicate paint input is idempotent rather than malformed")
	var atomic_failure: Dictionary = zones.paint_zone(ZoneScript.Type.STORAGE, [Vector2i(4, 3), Vector2i(9, 1)])
	_assert_true(not atomic_failure.ok, "Mixed valid/invalid paint is rejected atomically")
	_assert_true(zones.get_zone_at(Vector2i(4, 3)) == null, "Atomic rejection does not partially reassign cells")


func _test_deterministic_split_merge_and_reassignment() -> void:
	var context := _context()
	var zones = context.zones
	var line: Array[Vector2i] = []
	for x: int in range(2, 7):
		line.append(Vector2i(x, 3))
	zones.paint_zone(ZoneScript.Type.SLEEPING, line)
	var original: Zone = zones.get_zone_at(Vector2i(2, 3))
	var original_id := original.zone_id
	var original_seed := original.dressing_seed
	zones.begin_setup(original_id)
	zones.apply_setup_material(original_id, 2)
	var reassigned: Dictionary = zones.reassign_cells(ZoneScript.Type.STORAGE, [Vector2i(4, 3)])
	_assert_true(reassigned.ok, "A painted cell can be reassigned to another zone type")
	_assert_equal(zones.get_zones_by_type(ZoneScript.Type.SLEEPING).size(), 2, "Removing a bridge deterministically splits a zone")
	_assert_equal(zones.get_zone_at(Vector2i(2, 3)).zone_id, original_id, "Component containing the identity anchor preserves zone ID")
	_assert_equal(zones.get_zone_at(Vector2i(2, 3)).dressing_seed, original_seed, "Identity-preserving resize keeps dressing seed")
	_assert_equal(zones.get_zone_at(Vector2i(2, 3)).setup_state, ZoneScript.SetupState.SET_UP, "Identity-preserving component keeps setup state")
	_assert_equal(zones.get_zone_at(Vector2i(5, 3)).setup_state, ZoneScript.SetupState.PENDING, "New split component requires its own automatic setup")
	zones.reassign_cells(ZoneScript.Type.SLEEPING, [Vector2i(4, 3)])
	_assert_equal(zones.get_zones_by_type(ZoneScript.Type.SLEEPING).size(), 1, "Repainting the bridge merges same-type components")
	_assert_equal(zones.get_zone_at(Vector2i(6, 3)).zone_id, original_id, "Merged zone deterministically keeps the lowest anchored identity")
	_assert_equal(zones.get_zone_at(Vector2i(6, 3)).dressing_seed, original_seed, "Merge avoids unnecessary dressing reseeding")
	_assert_equal(context.world.get_zone_id(Vector2i(4, 3)), original_id, "Grid membership follows reassignment and merge")


func _test_setup_and_dressing_contract() -> void:
	var context := _context()
	var zones = context.zones
	zones.paint_zone(ZoneScript.Type.SLEEPING, [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)])
	var zone: Zone = zones.get_zone_at(Vector2i(2, 2))
	var requests: Array[Dictionary] = zones.get_setup_requests()
	_assert_equal(requests.size(), 1, "Valid unfinished zone emits one automatic setup request")
	for field: String in ["request_id", "zone_id", "zone_type", "zone_type_name", "anchor", "material_type", "material_required", "material_delivered", "material_remaining", "dressing_seed"]:
		_assert_true(requests[0].has(field), "Setup request exposes stable field %s" % field)
	_assert_equal(requests[0].request_id, "zone_setup:%d" % zone.zone_id, "Setup request ID is stable for a zone")
	_assert_equal(requests[0].material_type, "GENERAL_MATERIAL", "Zone setup consumes only General Material")
	_assert_equal(requests[0].material_required, 2, "Setup cost reads balance.zones setup_material_per_zone")
	_assert_equal(zones.find_best_usable_cell(ZoneScript.Type.SLEEPING, Vector2i(8, 3)), Vector2i(-1, -1), "Unfinished Sleeping zone is not a usable rest target")
	_assert_equal(zones.find_best_usable_cell(ZoneScript.Type.SLEEPING, Vector2i(8, 3), false), Vector2i(4, 2), "Preview query chooses nearest valid cell before setup")
	_assert_true(zones.begin_setup(zone.zone_id).ok, "Valid zone setup can begin")
	var partial: Dictionary = zones.apply_setup_material(zone.zone_id, 1)
	_assert_true(partial.ok and not partial.completed and partial.material_remaining == 1, "Partial setup tracks delivered material")
	var completed: Dictionary = zones.apply_setup_material(zone.zone_id, 1)
	_assert_true(completed.ok and completed.completed, "Required material completes automatic setup")
	_assert_equal(zones.get_setup_requests().size(), 0, "Completed zone leaves setup request queue")
	var contract: Dictionary = zones.get_dressing_contract(zone.zone_id)
	_assert_true(contract.ready, "Valid SET_UP zone exposes ready dressing contract")
	_assert_true(contract.engineering_placeholder, "Dressing contract is explicitly an engineering placeholder")
	_assert_equal(contract.family, "sleeping_nest_proxy", "Sleeping dressing uses its deterministic proxy family")
	_assert_true(not contract.anchors.is_empty(), "Dressing contract supplies deterministic cell anchors")
	_assert_equal(zones.find_best_usable_cell(ZoneScript.Type.SLEEPING, Vector2i(8, 3)), Vector2i(4, 2), "Usable-cell query chooses shortest path then stable coordinate")
	var first_bed: Dictionary = zones.reserve_best_usable_cell(ZoneScript.Type.SLEEPING, "mouse_a", Vector2i(8, 3), 1)
	var second_bed: Dictionary = zones.reserve_best_usable_cell(ZoneScript.Type.SLEEPING, "mouse_b", Vector2i(8, 3), 1)
	_assert_true(first_bed.ok and second_bed.ok and first_bed.cell != second_bed.cell, "Sleeping occupancy prevents two mice reserving one single-capacity cell")
	_assert_true(zones.release_occupant("mouse_a"), "Sleeping occupancy can be released")
	var reused_bed: Dictionary = zones.reserve_best_usable_cell(ZoneScript.Type.SLEEPING, "mouse_c", Vector2i(8, 3), 1)
	_assert_equal(reused_bed.cell, first_bed.cell, "Released sleeping capacity becomes deterministically available")


func _test_suitability_reacts_to_water() -> void:
	var context := _context()
	var world = context.world
	var zones = context.zones
	zones.paint_zone(ZoneScript.Type.SLEEPING, [Vector2i(2, 4), Vector2i(3, 4)])
	var sleeping_id: int = zones.get_zone_at(Vector2i(2, 4)).zone_id
	world.set_water_units(Vector2i(2, 4), 1)
	zones.flush_world_changes()
	var sleeping: Zone = zones.get_zone(sleeping_id)
	_assert_true(sleeping.valid, "Shallow water lowers Sleeping quality without inventing disease invalidation")
	_assert_true(sleeping.suitability < 1.0 and sleeping.suitability_warnings.has("DAMP_SLEEPING"), "Sleeping suitability reports damp penalty")
	var damp_sleeping_suitability: float = sleeping.suitability
	zones.paint_zone(ZoneScript.Type.SLEEPING, [Vector2i(7, 4)])
	var dry_sleeping: Zone = zones.get_zone_at(Vector2i(7, 4))
	zones.begin_setup(sleeping_id)
	zones.apply_setup_material(sleeping_id, 2)
	zones.begin_setup(dry_sleeping.zone_id)
	zones.apply_setup_material(dry_sleeping.zone_id, 2)
	_assert_equal(zones.find_best_usable_cell(ZoneScript.Type.SLEEPING, Vector2i(1, 4)), Vector2i(7, 4), "Sleeping selection consumes suitability before travel-distance tie breaking")
	world.set_water_units(Vector2i(2, 4), 2)
	zones.flush_world_changes()
	sleeping = zones.get_zone(sleeping_id)
	_assert_true(not sleeping.valid and sleeping.invalid_reasons.has(ZoneSystemScript.REASON_FLOODED), "Full water invalidates Sleeping zone")
	world.set_water_units(Vector2i(2, 4), 0)
	zones.flush_world_changes()
	_assert_true(zones.get_zone(sleeping_id).valid, "Drying a zone revalidates it through world events")
	zones.paint_zone(ZoneScript.Type.FOOD_FORAGE, [Vector2i(5, 4), Vector2i(6, 4)])
	var food_id: int = zones.get_zone_at(Vector2i(5, 4)).zone_id
	world.set_water_units(Vector2i(5, 4), 1)
	zones.flush_world_changes()
	var food: Zone = zones.get_zone(food_id)
	_assert_true(food.valid and food.suitability > damp_sleeping_suitability, "Food/Forage keeps a milder provisional damp penalty than Sleeping")


func _test_reference_preservation_and_storage_invalidation() -> void:
	var context := _context()
	var world = context.world
	var zones = context.zones
	zones.paint_zone(ZoneScript.Type.STORAGE, [Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3)])
	var original: Zone = zones.get_zone_at(Vector2i(3, 3))
	_assert_true(zones.register_storage_pile(original.zone_id, 42, Vector2i(5, 3)), "Storage zone records logical pile reference")
	_assert_true(zones.register_occupant(original.zone_id, "mouse_a", Vector2i(3, 3)), "Zone records occupancy reference")
	zones.erase_cells([Vector2i(4, 3)])
	var right: Zone = zones.get_zone_at(Vector2i(5, 3))
	var left: Zone = zones.get_zone_at(Vector2i(3, 3))
	_assert_true(right.storage_refs.has(42), "Zone split preserves pile with the component containing its cell")
	_assert_true(left.occupant_refs.has("mouse_a"), "Zone split preserves occupant with the component containing its cell")
	_assert_equal(zones.consume_invalidated_storage_requests().size(), 0, "Preserved storage does not create spurious relocation")
	world.set_water_units(Vector2i(5, 3), 1)
	zones.flush_world_changes()
	_assert_true(not zones.get_zone(right.zone_id).valid and zones.get_zone(right.zone_id).invalid_reasons.has(ZoneSystemScript.REASON_WET), "Threatened Storage invalidates while shallow water remains walkable")
	var requests: Array = zones.consume_invalidated_storage_requests()
	_assert_equal(requests.size(), 1, "Wet Storage emits one early relocation request")
	for field: String in ["request_id", "pile_id", "from_zone_id", "cell", "reason_code", "emergency"]:
		_assert_true(requests[0].has(field), "Storage invalidation request exposes stable field %s" % field)
	_assert_equal(requests[0].request_id, "storage_relocate:42", "Storage relocation request ID is stable per pile")
	_assert_true(requests[0].emergency, "Environmental Storage invalidation marks emergency hauling")
	world.set_water_units(Vector2i(5, 3), 0)
	zones.flush_world_changes()
	zones.reassign_cells(ZoneScript.Type.SLEEPING, [Vector2i(5, 3)])
	requests = zones.consume_invalidated_storage_requests()
	_assert_equal(requests.size(), 1, "Reassigning a pile cell emits relocation instead of deleting item state")
	_assert_equal(requests[0].reason_code, "ZONE_REMOVED_OR_REASSIGNED", "Resize relocation distinguishes non-emergency spatial edit")
	_assert_true(not requests[0].emergency, "Player zone edit does not masquerade as an emergency")


func _context() -> Dictionary:
	var world := GridScript.new(12, 8, 4)
	for y: int in range(world.height):
		for x: int in range(world.width):
			var excavated := x >= 1 and x <= 8 and y >= 2 and y <= 5
			world.initialize_cell(Vector2i(x, y), CellDataScript.TerrainMaterial.SOFT_SOIL, excavated)
	world.metadata = {"start_cell": Vector2i(1, 3), "seed": 4242}
	var path_service := PathServiceScript.new()
	path_service.configure(world, BALANCE)
	var zones := ZoneSystemScript.new()
	zones.configure(world, path_service, BALANCE)
	return {"world": world, "path_service": path_service, "zones": zones}


func _assert_true(condition: bool, description: String) -> void:
	results.append({"passed": condition, "description": description, "details": "" if condition else "Expected true"})


func _assert_equal(actual: Variant, expected: Variant, description: String) -> void:
	var passed: bool = actual == expected
	results.append({"passed": passed, "description": description, "details": "" if passed else "Expected %s, got %s" % [expected, actual]})
