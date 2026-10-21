class_name ColonySimulation
extends RefCounted

const CollectionScript = preload("res://src/domain/progression/collection_book.gd")
const ProductionScript = preload("res://src/domain/colony/production_system.gd")
const CapabilitiesScript = preload("res://src/domain/progression/colony_capabilities.gd")
const DiscoveryScript = preload("res://src/domain/features/discovery_system.gd")
const MouseAgentScript = preload("res://src/domain/colony/mouse_agent.gd")
const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const JobSystemScript = preload("res://src/domain/jobs/job_system.gd")
const ColonyJobScript = preload("res://src/domain/jobs/colony_job.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const ZoneSystemScript = preload("res://src/domain/zones/zone_system.gd")
const SignalSystemScript = preload("res://src/domain/features/signal_system.gd")
const RootFeatureSystemScript = preload("res://src/domain/features/root_feature_system.gd")
const WaterSystemScript = preload("res://src/domain/features/water_system.gd")
const SealSystemScript = preload("res://src/domain/features/seal_system.gd")
const StabilitySystemScript = preload("res://src/domain/features/stability_system.gd")

var _discovery_system
var _production_system
var _capabilities
var _collection_book
var travel_steps := 0
var loaded_travel_steps := 0
var _world
var _path_service
var _dig_system
var _balance: Dictionary = {}
var _item_system
var _job_system
var _zone_system
var _signal_system
var _root_feature_system
var _water_system
var _seal_system
var _stability_system
var _item_damage_fraction := 0.25
var _mice: Array[MouseAgent] = []
var _storage_capacity_per_cell := 12
var _emergency_relocation_piles: Dictionary = {}
var _colony_distances := PackedInt32Array()
var _colony_distance_revision := -1


func configure(
	world_grid,
	path_service,
	dig_system,
	balance: Dictionary = {},
	feature_registry = null,
	worldgen_config: Dictionary = {}
) -> void:
	_world = world_grid
	_path_service = path_service
	_dig_system = dig_system
	_balance = balance.duplicate(true)
	_item_system = ItemSystemScript.new()
	_item_system.configure(_world, _path_service)
	_job_system = JobSystemScript.new()
	_job_system.configure(_path_service, _item_system, _balance)
	_zone_system = ZoneSystemScript.new()
	_zone_system.configure(_world, _path_service, _balance)
	_production_system = ProductionScript.new()
	_production_system.configure(_zone_system, _item_system, _job_system, _path_service)
	_collection_book = CollectionScript.new()
	_capabilities = CapabilitiesScript.new()
	_capabilities.configure(_item_system, _world)
	if bool(_balance.get("capabilities_enabled", false)):
		_dig_system.set_capability_filter(_capabilities.can_dig)

	_signal_system = null
	_root_feature_system = null
	_water_system = null
	_seal_system = SealSystemScript.new()
	if feature_registry != null:
		_signal_system = SignalSystemScript.new()
		_signal_system.configure(
			_world,
			feature_registry,
			_world.metadata.get("signal_emitters", []),
			worldgen_config.get("signal_fields", {}),
			false,
			true
		)
		_root_feature_system = RootFeatureSystemScript.new()
		_root_feature_system.configure(
			_world,
			feature_registry,
			_signal_system,
			_item_system,
			_zone_system,
			_dig_system,
			worldgen_config.get("root_feature", {})
		)
		_discovery_system = DiscoveryScript.new()
		_discovery_system.configure(_world, feature_registry, _item_system, _dig_system)
		_discovery_system.discovered.connect(_collection_book.on_discovery)
		_water_system = WaterSystemScript.new()
		_water_system.configure(_world, feature_registry, _signal_system, _dig_system, _balance)
		_water_system.reservoir_breached.connect(_on_reservoir_breached)
		_water_system.danger_cleared.connect(recover_from_danger)
	_seal_system.configure(_world, _water_system)
	var stability_balance: Dictionary = _balance.get("stability", {})
	_item_damage_fraction = clampf(float(stability_balance.get("item_damage_fraction", 0.25)), 0.0, 1.0)
	_stability_system = StabilitySystemScript.new()
	var instability_config: Dictionary = worldgen_config.get("signal_fields", {}).get("instability", {})
	_stability_system.configure(
		_world,
		feature_registry,
		_dig_system,
		_water_system,
		_balance,
		instability_config.get("thresholds", [])
	)
	_stability_system.critical_warning.connect(_on_critical_warning)
	_stability_system.region_collapsed.connect(_on_region_collapsed)
	_stability_system.danger_cleared.connect(recover_from_danger)
	_dig_system.set_hazard_filter(_stability_system.is_job_blocked)
	_job_system.set_hazard_filter(_stability_system.is_job_blocked)
	var zones_balance: Dictionary = _balance.get("zones", {})
	_storage_capacity_per_cell = maxi(1, int(zones_balance.get("storage_capacity_per_cell", 12)))
	_emergency_relocation_piles.clear()
	_colony_distances.clear()
	_colony_distance_revision = -1
	_mice.clear()
	var requested_count := maxi(1, int(_balance.get("initial_mouse_count", 3)))
	var start_value: Variant = _world.metadata.get("start_cell", Vector2i(-1, -1))
	var start_cell := Vector2i(-1, -1) if not start_value is Vector2i else start_value as Vector2i
	var spawn_cells := _find_spawn_cells(start_cell, requested_count)
	for index: int in range(requested_count):
		var spawn_cell: Vector2i = spawn_cells[index] if index < spawn_cells.size() else start_cell
		add_mouse("mouse_%d" % (index + 1), spawn_cell)


func fixed_tick(delta_seconds: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if delta_seconds <= 0.0:
		return results
	if _water_system != null:
		_water_system.fixed_tick(delta_seconds)
	if _stability_system != null:
		_stability_system.fixed_tick(delta_seconds)
	_synchronize_zone_state()
	if _discovery_system != null:
		_discovery_system.fixed_tick(delta_seconds)
	if _root_feature_system != null:
		_root_feature_system.fixed_tick(delta_seconds)
	_production_system.fixed_tick(delta_seconds)
	_job_system.advance_time(delta_seconds)
	for mouse: MouseAgent in _mice:
		results.append(mouse.fixed_tick(delta_seconds))
	_recover_mice_that_finished_water_escape()
	return results


func add_mouse(mouse_id: String, cell: Vector2i):
	if mouse_id.is_empty() or get_mouse(mouse_id) != null or not _path_service.is_walkable(cell):
		return null
	var mouse := MouseAgentScript.new(mouse_id, cell)
	mouse.configure(_world, _path_service, _dig_system, _balance)
	var start_value: Variant = _world.metadata.get("start_cell", cell)
	var home_cell := cell if not start_value is Vector2i else start_value as Vector2i
	mouse.configure_colony(_job_system, _item_system, home_cell, _balance)
	mouse.configure_zones(_zone_system, _balance)
	mouse.configure_environment(_seal_system, _stability_system)
	mouse.configure_production(_production_system)
	mouse.moved.connect(_on_mouse_moved)
	_mice.append(mouse)
	return mouse


func remove_mouse(mouse_id: String) -> bool:
	for index: int in range(_mice.size()):
		if _mice[index].mouse_id != mouse_id:
			continue
		if not _mice[index].release_current_job():
			return false
		_mice.remove_at(index)
		return true
	return false


func get_mice() -> Array[MouseAgent]:
	return _mice.duplicate()


func get_mouse(mouse_id: String):
	for mouse: MouseAgent in _mice:
		if mouse.mouse_id == mouse_id:
			return mouse
	return null


func get_job_system():
	return _job_system


func get_item_system():
	return _item_system


func get_zone_system():
	return _zone_system


func get_signal_system():
	return _signal_system


func get_root_feature_system():
	return _root_feature_system


func get_water_system():
	return _water_system


func get_seal_system():
	return _seal_system


func get_stability_system():
	return _stability_system


func request_seal(cell: Vector2i) -> Dictionary:
	return _seal_system.request_seal(cell)


func request_reinforce(cell: Vector2i) -> Dictionary:
	if _stability_system == null:
		return {"ok": false, "reason_code": "STABILITY_SYSTEM_UNAVAILABLE", "request_id": -1, "cell": cell}
	return _stability_system.request_reinforce(cell)


func add_item_pile(item_type: String, cell: Vector2i, count: int) -> int:
	return _item_system.add_pile(item_type, cell, count)


func enqueue_haul(item_type: String, source_pile_id: int, dropoff_cell: Vector2i, count: int, emergency: bool = false):
	return _job_system.enqueue_haul(item_type, source_pile_id, dropoff_cell, count, emergency)


func trigger_danger(danger_cells: Array, safe_cell: Vector2i = Vector2i(-1, -1)) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for mouse: MouseAgent in _mice:
		results.append(mouse.trigger_danger(danger_cells, safe_cell))
	return results


func recover_from_danger() -> void:
	for mouse: MouseAgent in _mice:
		mouse.recover_from_danger()


func setup_qa_demo(food_cell: Vector2i, material_cell: Vector2i, dropoff_cell: Vector2i) -> Dictionary:
	var food_pile_id := add_item_pile(ItemSystemScript.FOOD, food_cell, 8)
	var material_pile_id := add_item_pile(ItemSystemScript.GENERAL_MATERIAL, material_cell, 6)
	var haul_job = enqueue_haul(ItemSystemScript.GENERAL_MATERIAL, material_pile_id, dropoff_cell, 2)
	return {
		"ok": food_pile_id > 0 and material_pile_id > 0 and haul_job != null,
		"food_pile_id": food_pile_id,
		"material_pile_id": material_pile_id,
		"haul_job_id": -1 if haul_job == null else haul_job.job_id,
	}


func get_debug_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mouse: MouseAgent in _mice:
		result.append(mouse.get_debug_snapshot())
	return result


func _synchronize_zone_state() -> void:
	_zone_system.flush_world_changes()
	_prune_emergency_relocation_piles()
	_cancel_invalid_zone_jobs()
	_cancel_invalid_seal_jobs()
	_cancel_invalid_reinforce_jobs()
	_sync_storage_references()
	for request: Dictionary in _zone_system.consume_invalidated_storage_requests():
		_emergency_relocation_piles[int(request.pile_id)] = bool(request.emergency)
	_enqueue_zone_setup_jobs()
	_enqueue_seal_jobs()
	_enqueue_reinforce_jobs()
	_enqueue_storage_jobs()


func _cancel_invalid_seal_jobs() -> void:
	for job: ColonyJob in _job_system.get_jobs():
		if job.job_type == ColonyJobScript.Type.SEAL and not _seal_system.has_request(job.action_cell):
			_job_system.cancel(job.job_id)


func _cancel_invalid_reinforce_jobs() -> void:
	if _stability_system == null:
		return
	for job: ColonyJob in _job_system.get_jobs():
		if job.job_type == ColonyJobScript.Type.REINFORCE and not _stability_system.has_request(job.action_cell):
			_job_system.cancel(job.job_id)


func _enqueue_reinforce_jobs() -> void:
	if _stability_system == null:
		return
	for request: Dictionary in _stability_system.get_requests():
		var reinforce_cell: Vector2i = request.cell
		var already_enqueued := false
		for job: ColonyJob in _job_system.get_jobs():
			if job.job_type == ColonyJobScript.Type.REINFORCE and job.action_cell == reinforce_cell:
				already_enqueued = true
				break
		if already_enqueued:
			continue
		var candidates: Array[Dictionary] = []
		for pile: ItemPile in _item_system.get_piles():
			if pile.item_type != ItemSystemScript.GENERAL_MATERIAL or pile.available_count() < int(request.material_required):
				continue
			for work_cell: Vector2i in _world.get_cardinal_neighbors(reinforce_cell):
				if not _path_service.is_walkable(work_cell) or work_cell == reinforce_cell:
					continue
				var route: Array[Vector2i] = _path_service.find_path(pile.cell, work_cell)
				if route.is_empty():
					continue
				candidates.append({
					"pile_id": pile.pile_id,
					"work_cell": work_cell,
					"distance": route.size() - 1,
				})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.distance) != int(b.distance):
				return int(a.distance) < int(b.distance)
			if int(a.pile_id) != int(b.pile_id):
				return int(a.pile_id) < int(b.pile_id)
			return _world.cell_to_index(a.work_cell) < _world.cell_to_index(b.work_cell)
		)
		for candidate: Dictionary in candidates:
			var job = _job_system.enqueue_reinforce(
				int(candidate.pile_id),
				candidate.work_cell,
				reinforce_cell,
				int(request.material_required)
			)
			if job != null:
				break


func _enqueue_seal_jobs() -> void:
	for request: Dictionary in _seal_system.get_requests():
		var seal_cell: Vector2i = request.cell
		var already_enqueued := false
		for job: ColonyJob in _job_system.get_jobs():
			if job.job_type == ColonyJobScript.Type.SEAL and job.action_cell == seal_cell:
				already_enqueued = true
				break
		if already_enqueued:
			continue
		var candidates: Array[Dictionary] = []
		for pile: ItemPile in _item_system.get_piles():
			if pile.item_type != ItemSystemScript.GENERAL_MATERIAL or pile.available_count() < int(request.material_required):
				continue
			for work_cell: Vector2i in _world.get_cardinal_neighbors(seal_cell):
				if not _path_service.is_walkable(work_cell):
					continue
				var route: Array[Vector2i] = _path_service.find_path(pile.cell, work_cell)
				if route.is_empty():
					continue
				candidates.append({
					"pile_id": pile.pile_id,
					"work_cell": work_cell,
					"distance": route.size() - 1,
				})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.distance) != int(b.distance):
				return int(a.distance) < int(b.distance)
			if int(a.pile_id) != int(b.pile_id):
				return int(a.pile_id) < int(b.pile_id)
			return _world.cell_to_index(a.work_cell) < _world.cell_to_index(b.work_cell)
		)
		for candidate: Dictionary in candidates:
			var job = _job_system.enqueue_seal(
				int(candidate.pile_id),
				candidate.work_cell,
				seal_cell,
				int(request.material_required)
			)
			if job != null:
				break


func _on_reservoir_breached(_feature_id: int, _cell: Vector2i, danger_cells: Array, _released_units: int) -> void:
	trigger_danger(danger_cells)


func _on_critical_warning(cells: Array) -> void:
	for mouse: MouseAgent in _mice:
		if cells.has(mouse.current_cell):
			mouse.trigger_danger(cells)


func _on_region_collapsed(cells: Array, _absorbed_water_units: int) -> void:
	var collapsed: Dictionary = {}
	for cell_value: Variant in cells:
		if cell_value is Vector2i:
			collapsed[cell_value as Vector2i] = true
	for pile: ItemPile in _item_system.get_piles():
		if pile.count <= 0 or not collapsed.has(pile.cell):
			continue
		var stored_pile: ItemPile = _item_system.get_pile(pile.pile_id)
		if stored_pile == null:
			continue
		var survivors := maxi(0, stored_pile.count - ceili(float(stored_pile.count) * _item_damage_fraction))
		stored_pile.reserved_count = mini(stored_pile.reserved_count, survivors)
		stored_pile.count = survivors
		if survivors <= 0:
			continue
		var relocated := Vector2i(-1, -1)
		for neighbor: Vector2i in _world.get_cardinal_neighbors(pile.cell):
			if collapsed.has(neighbor) or not _item_system.can_accept_unreserved_dropoff(neighbor, survivors):
				continue
			relocated = neighbor
			break
		if relocated.x < 0:
			relocated = _nearest_walkable_cell(pile.cell)
		if relocated.x >= 0:
			stored_pile.cell = relocated
	for mouse: MouseAgent in _mice:
		if not collapsed.has(mouse.current_cell):
			continue
		var safe_cell := _nearest_walkable_cell(mouse.current_cell)
		if safe_cell.x < 0:
			continue
		mouse.current_cell = safe_cell
	for mouse: MouseAgent in _mice:
		if collapsed.has(mouse.current_cell):
			mouse.trigger_danger(cells)


func _nearest_walkable_cell(from_cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_distance := 2147483647
	for index: int in range(_world.width * _world.height):
		var candidate: Vector2i = _world.index_to_cell(index)
		if not _path_service.is_walkable(candidate):
			continue
		var distance := absi(candidate.x - from_cell.x) + absi(candidate.y - from_cell.y)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _recover_mice_that_finished_water_escape() -> void:
	var water_active: bool = _water_system != null and _water_system.is_danger_active()
	var stability_active: bool = _stability_system != null and _stability_system.is_danger_active()
	if not water_active and not stability_active:
		return
	for mouse: MouseAgent in _mice:
		if not mouse.danger_state:
			continue
		if mouse.get_state_name() != "FLEEING":
			continue
		if water_active and _water_system.is_cell_in_danger_region(mouse.current_cell):
			continue
		if stability_active and _stability_system.is_cell_in_danger_region(mouse.current_cell):
			continue
		mouse.recover_from_danger()


func _cancel_invalid_zone_jobs() -> void:
	for job: ColonyJob in _job_system.get_jobs():
		if job.zone_id < 0:
			continue
		var zone: Zone = _zone_system.get_zone(job.zone_id)
		var valid_target := (
			zone != null
			and zone.valid
			and zone.cells.has(job.target_cell)
		)
		if job.job_type != ColonyJobScript.Type.ZONE_SETUP:
			valid_target = (
				valid_target
				and zone.zone_type == (ZoneScript.Type.PRODUCTION if job.job_type == ColonyJobScript.Type.PRODUCE else ZoneScript.Type.STORAGE)
				and zone.setup_state == ZoneScript.SetupState.SET_UP
			)
		if valid_target and (job.worker_id.is_empty() or job.item_reservation_id >= 0):
			var source_pile: ItemPile = _item_system.get_pile(job.source_pile_id)
			valid_target = (
				source_pile != null
				and source_pile.count >= job.item_count
				and _is_reachable_from_colony(source_pile.cell)
			)
		if not valid_target:
			_job_system.cancel(job.job_id)


func _sync_storage_references() -> void:
	var capacities: Dictionary = {}
	for zone: Zone in _zone_system.get_zones_by_type(ZoneScript.Type.STORAGE):
		for cell: Vector2i in zone.cells:
			capacities[cell] = _storage_capacity_per_cell
	for zone: Zone in _zone_system.get_zones_by_type(ZoneScript.Type.PRODUCTION, true):
		capacities[zone.identity_anchor] = _storage_capacity_per_cell
	_item_system.replace_cell_capacities(capacities)
	for zone: Zone in _zone_system.get_zones_by_type(ZoneScript.Type.STORAGE):
		for pile_id_value: Variant in zone.storage_refs.keys():
			var pile_id := int(pile_id_value)
			var pile: ItemPile = _item_system.get_pile(pile_id)
			var current_zone: Zone = null if pile == null else _zone_system.get_zone_at(pile.cell)
			if pile == null or current_zone == null or current_zone.zone_id != zone.zone_id:
				_zone_system.unregister_storage_pile(zone.zone_id, pile_id)
	for pile: ItemPile in _item_system.get_piles():
		if pile.count <= 0:
			continue
		var zone: Zone = _zone_system.get_zone_at(pile.cell)
		if zone != null and zone.zone_type == ZoneScript.Type.STORAGE:
			_zone_system.register_storage_pile(zone.zone_id, pile.pile_id, pile.cell)


func _enqueue_zone_setup_jobs() -> void:
	for request: Dictionary in _zone_system.get_setup_requests():
		var zone_id := int(request.zone_id)
		if not _job_system.get_zone_jobs(zone_id, ColonyJobScript.Type.ZONE_SETUP).is_empty():
			continue
		var remaining := int(request.material_remaining)
		if remaining <= 0:
			continue
		var candidates: Array[Dictionary] = []
		for pile: ItemPile in _item_system.get_piles():
			if pile.item_type != ItemSystemScript.GENERAL_MATERIAL or pile.available_count() < remaining:
				continue
			var route: Array[Vector2i] = _path_service.find_path(pile.cell, request.anchor)
			if route.is_empty():
				continue
			candidates.append({"pile_id": pile.pile_id, "distance": route.size() - 1})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a.distance) < int(b.distance) or (int(a.distance) == int(b.distance) and int(a.pile_id) < int(b.pile_id))
		)
		for candidate: Dictionary in candidates:
			var job = _job_system.enqueue_zone_setup(int(candidate.pile_id), request.anchor, remaining, zone_id)
			if job == null:
				continue
			_zone_system.begin_setup(zone_id)
			break


func _enqueue_storage_jobs() -> void:
	var usable_zones: Array[Zone] = []
	for zone: Zone in _zone_system.get_zones_by_type(ZoneScript.Type.STORAGE, true):
		if zone.setup_state == ZoneScript.SetupState.SET_UP:
			usable_zones.append(zone)
	if usable_zones.is_empty():
		return
	for pile: ItemPile in _item_system.get_piles():
		if pile.count <= 0:
			_emergency_relocation_piles.erase(pile.pile_id)
			continue
		if _is_pile_in_usable_storage(pile):
			_emergency_relocation_piles.erase(pile.pile_id)
			continue
		if _has_source_job(pile.pile_id):
			continue
		if not _is_reachable_from_colony(pile.cell):
			continue
		var source_zone: Zone = _zone_system.get_zone_at(pile.cell)
		var environmental_emergency := (
			source_zone != null
			and source_zone.zone_type == ZoneScript.Type.STORAGE
			and not source_zone.valid
			and (source_zone.invalid_reasons.has(ZoneSystemScript.REASON_WET) or source_zone.invalid_reasons.has(ZoneSystemScript.REASON_FLOODED))
		)
		var candidates: Array[Dictionary] = []
		for zone: Zone in usable_zones:
			for cell: Vector2i in zone.cells:
				var remaining_capacity: int = (
					_storage_capacity_per_cell
					- _item_system.get_count_at(cell)
					- _item_system.get_reserved_dropoff_count(cell)
				)
				if remaining_capacity <= 0 or cell == pile.cell:
					continue
				var route: Array[Vector2i] = _path_service.find_path(pile.cell, cell)
				if route.is_empty():
					continue
				candidates.append({
					"zone_id": zone.zone_id,
					"cell": cell,
					"capacity": remaining_capacity,
					"distance": route.size() - 1,
				})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if int(a.distance) != int(b.distance):
				return int(a.distance) < int(b.distance)
			if int(a.zone_id) != int(b.zone_id):
				return int(a.zone_id) < int(b.zone_id)
			var a_cell: Vector2i = a.cell
			var b_cell: Vector2i = b.cell
			return a_cell.y < b_cell.y or (a_cell.y == b_cell.y and a_cell.x < b_cell.x)
		)
		for candidate: Dictionary in candidates:
			var count: int = mini(pile.available_count(), int(candidate.capacity))
			if count <= 0:
				continue
			var job = _job_system.enqueue_haul(
				pile.item_type,
				pile.pile_id,
				candidate.cell,
				count,
				bool(_emergency_relocation_piles.get(pile.pile_id, false)) or environmental_emergency,
				int(candidate.zone_id),
				_storage_capacity_per_cell
			)
			if job != null:
				break


func _is_pile_in_usable_storage(pile: ItemPile) -> bool:
	var zone: Zone = _zone_system.get_zone_at(pile.cell)
	return (
		zone != null
		and zone.zone_type == ZoneScript.Type.STORAGE
		and zone.valid
		and zone.setup_state == ZoneScript.SetupState.SET_UP
		and _item_system.get_count_at(pile.cell) <= _storage_capacity_per_cell
	)


func _has_source_job(pile_id: int) -> bool:
	for job: ColonyJob in _job_system.get_jobs():
		if job.source_pile_id == pile_id:
			return true
	return false


func _is_reachable_from_colony(cell: Vector2i) -> bool:
	var topology_revision: int = _path_service.get_topology_revision()
	if _colony_distance_revision != topology_revision:
		var start_value: Variant = _world.metadata.get("start_cell", Vector2i(-1, -1))
		var start_cell := Vector2i(-1, -1) if not start_value is Vector2i else start_value as Vector2i
		_colony_distances = _path_service.build_distance_field(start_cell)
		_colony_distance_revision = topology_revision
	var index: int = _world.cell_to_index(cell)
	return index >= 0 and index < _colony_distances.size() and _colony_distances[index] >= 0


func _prune_emergency_relocation_piles() -> void:
	for pile_id_value: Variant in _emergency_relocation_piles.keys():
		if _item_system.get_pile(int(pile_id_value)) == null:
			_emergency_relocation_piles.erase(pile_id_value)


## Public spawn-cell query for milestone population growth (spec 10 §14).
func find_spawn_cells_near(anchor: Vector2i, count: int) -> Array[Vector2i]:
	return _find_spawn_cells(anchor, count)


func _find_spawn_cells(start_cell: Vector2i, count: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var distances: PackedInt32Array = _path_service.build_distance_field(start_cell)
	var candidates: Array[Dictionary] = []
	for index: int in range(distances.size()):
		if distances[index] < 0:
			continue
		candidates.append({"cell": _world.index_to_cell(index), "distance": distances[index]})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.distance) != int(b.distance):
			return int(a.distance) < int(b.distance)
		var a_cell: Vector2i = a.cell
		var b_cell: Vector2i = b.cell
		return a_cell.y < b_cell.y or (a_cell.y == b_cell.y and a_cell.x < b_cell.x)
	)
	for candidate: Dictionary in candidates:
		result.append(candidate.cell)
		if result.size() >= count:
			break
	return result


## Phase 10 persistence (docs/tech/15 §5-§9): mice, piles, and zones. Job
## reservations, paths, and occupancy are runtime state — rebuilt from world
## state on load per the spec's recommendation.
func to_save_data() -> Dictionary:
	var mice: Array = []
	for mouse: MouseAgent in _mice:
		mice.append({
			"id": mouse.mouse_id,
			"cell": [mouse.current_cell.x, mouse.current_cell.y],
			"hunger": snappedf(mouse.hunger, 0.001),
			"rest": snappedf(mouse.rest, 0.001),
			"carried_item_type": mouse.carried_item_type,
			"carried_item_count": mouse.carried_item_count,
		})
	return {
		"mice": mice,
		"items": _item_system.to_save_data(),
		"zones": _zone_system.to_save_data(),
		"production": _production_system.to_save_data(),
		"collection_book": _collection_book.to_save_data(),
		"capabilities": _capabilities.to_save_data(),
		"travel": {"steps": travel_steps, "loaded_steps": loaded_travel_steps},
	}


func apply_save_data(data: Dictionary) -> Dictionary:
	for old_mouse: MouseAgent in _mice.duplicate():
		remove_mouse(old_mouse.mouse_id)
	_job_system.configure(_path_service, _item_system, _balance)
	var item_result: Dictionary = _item_system.apply_save_data(data.get("items", {}))
	if not bool(item_result.ok):
		return item_result
	var zone_result: Dictionary = _zone_system.apply_save_data(data.get("zones", {}))
	if not bool(zone_result.ok):
		return zone_result
	var book_result: Dictionary = _collection_book.apply_save_data(data.get("collection_book", {}))
	if not book_result.ok:
		return book_result
	if _discovery_system != null:
		_collection_book.reconcile(_discovery_system._registry)
	var production_result: Dictionary = _production_system.apply_save_data(data.get("production", {}))
	if not production_result.ok:
		return production_result
	var ability_result: Dictionary = _capabilities.apply_save_data(data.get("capabilities", {}))
	if not ability_result.ok:
		return ability_result
	travel_steps = maxi(0, int(data.get("travel", {}).get("steps", 0)))
	loaded_travel_steps = maxi(0, int(data.get("travel", {}).get("loaded_steps", 0)))
	for entry: Variant in data.get("mice", []):
		if entry is not Dictionary:
			return {"ok": false, "error": "malformed mouse entry"}
		var cell_entry: Array = entry.cell
		if cell_entry.size() != 2:
			return {"ok": false, "error": "malformed mouse cell"}
		var cell := Vector2i(int(cell_entry[0]), int(cell_entry[1]))
		var mouse = add_mouse(String(entry.id), cell)
		if mouse == null:
			# Spec §5 safe fallback: a saved cell can be unwalkable when the
			# save's surroundings changed; recover the mouse at the nearest
			# walkable colony cell instead of failing the whole colony load.
			var anchor: Vector2i = _world.metadata.get("start_cell", cell)
			var fallback := _find_spawn_cells(anchor, 1)
			var fallback_cell: Vector2i = fallback[0] if not fallback.is_empty() else cell
			mouse = add_mouse(String(entry.id), fallback_cell)
			if mouse == null:
				return {"ok": false, "error": "no walkable cell to recover mouse: %s" % String(entry.id)}
		mouse.hunger = float(entry.hunger)
		mouse.rest = float(entry.rest)
		mouse.carried_item_type = String(entry.carried_item_type)
		mouse.carried_item_count = int(entry.carried_item_count)
	return {"ok": true, "error": ""}


func get_discovery_system():
	return _discovery_system


func get_production_system():
	return _production_system


func get_capabilities():
	return _capabilities


func _on_mouse_moved(mouse_id: String, _from: Vector2i, _to: Vector2i) -> void:
	travel_steps += 1
	var mouse = get_mouse(mouse_id)
	if mouse != null and mouse.carried_item_count > 0:
		loaded_travel_steps += 1


func route_between(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	return _path_service.find_path(from_cell, to_cell)


func get_collection_book():
	return _collection_book
