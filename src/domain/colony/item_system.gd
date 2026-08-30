class_name ItemSystem
extends RefCounted

signal pile_changed(pile_id: int)

const ItemPileScript = preload("res://src/domain/colony/item_pile.gd")

const FOOD := "FOOD"
const GENERAL_MATERIAL := "GENERAL_MATERIAL"

var _world
var _path_service
var _piles: Dictionary = {}
var _reservations: Dictionary = {}
var _worker_reservations: Dictionary = {}
var _dropoff_reservations: Dictionary = {}
var _cell_capacities: Dictionary = {}
var _next_pile_id := 1
var _next_reservation_id := 1
var _next_dropoff_reservation_id := 1


func configure(world_grid, path_service) -> void:
	_world = world_grid
	_path_service = path_service
	_piles.clear()
	_reservations.clear()
	_worker_reservations.clear()
	_dropoff_reservations.clear()
	_cell_capacities.clear()
	_next_pile_id = 1
	_next_reservation_id = 1
	_next_dropoff_reservation_id = 1


func add_pile(item_type: String, cell: Vector2i, count: int, excluded_dropoff_reservation_id: int = -1) -> int:
	if not _is_known_type(item_type) or count <= 0:
		return -1
	if _world == null or not _world.is_traversable(cell):
		return -1
	var capacity: int = get_cell_capacity(cell)
	if capacity > 0 and get_count_at(cell) + get_reserved_dropoff_count(cell, excluded_dropoff_reservation_id) + count > capacity:
		return -1
	for pile: ItemPile in _piles.values():
		if pile.item_type == item_type and pile.cell == cell:
			pile.count += count
			pile_changed.emit(pile.pile_id)
			return pile.pile_id
	var pile := ItemPileScript.new(_next_pile_id, item_type, cell, count)
	_next_pile_id += 1
	_piles[pile.pile_id] = pile
	pile_changed.emit(pile.pile_id)
	return pile.pile_id


func get_pile(pile_id: int):
	return _piles.get(pile_id)


func get_piles() -> Array[ItemPile]:
	var piles: Array[ItemPile] = []
	for pile: ItemPile in _piles.values():
		piles.append(pile.snapshot())
	piles.sort_custom(func(a: ItemPile, b: ItemPile) -> bool:
		return a.pile_id < b.pile_id
	)
	return piles


func get_total_count(item_type: String) -> int:
	var total := 0
	for pile: ItemPile in _piles.values():
		if pile.item_type == item_type:
			total += pile.count
	return total


func get_count_at(cell: Vector2i) -> int:
	var total := 0
	for pile: ItemPile in _piles.values():
		if pile.cell == cell:
			total += pile.count
	return total


func get_pile_ids_at(cell: Vector2i) -> Array[int]:
	var result: Array[int] = []
	for pile: ItemPile in _piles.values():
		if pile.cell == cell and pile.count > 0:
			result.append(pile.pile_id)
	result.sort()
	return result


func reserve_nearest(worker_id: String, item_type: String, count: int, origin: Vector2i) -> Dictionary:
	if _path_service == null or worker_id.is_empty() or count <= 0 or _worker_reservations.has(worker_id):
		return _result(false, "INVALID_RESERVATION")
	var candidate := find_nearest_available(item_type, count, origin)
	if not candidate.ok:
		return candidate
	return reserve_from_pile(worker_id, int(candidate.pile_id), count)


func find_nearest_available(item_type: String, count: int, origin: Vector2i) -> Dictionary:
	if _path_service == null or count <= 0:
		return _result(false, "INVALID_RESERVATION")
	var best_pile_id := -1
	var best_distance := 2147483647
	for pile: ItemPile in _piles.values():
		if pile.item_type != item_type or pile.available_count() < count:
			continue
		var path: Array[Vector2i] = _path_service.find_path(origin, pile.cell)
		if path.is_empty():
			continue
		var distance := path.size() - 1
		if distance < best_distance or (distance == best_distance and pile.pile_id < best_pile_id):
			best_pile_id = pile.pile_id
			best_distance = distance
	if best_pile_id < 0:
		return _result(false, "NO_REACHABLE_ITEM")
	var result := _result(true, "OK")
	result["pile_id"] = best_pile_id
	result["cell"] = (_piles[best_pile_id] as ItemPile).cell
	result["distance"] = best_distance
	return result


func reserve_from_pile(worker_id: String, pile_id: int, count: int) -> Dictionary:
	if worker_id.is_empty() or count <= 0 or _worker_reservations.has(worker_id):
		return _result(false, "INVALID_RESERVATION")
	var pile: ItemPile = _piles.get(pile_id)
	if pile == null or pile.available_count() < count:
		return _result(false, "INSUFFICIENT_ITEM")
	var reservation_id := _next_reservation_id
	_next_reservation_id += 1
	pile.reserved_count += count
	var reservation := {
		"reservation_id": reservation_id,
		"worker_id": worker_id,
		"pile_id": pile_id,
		"item_type": pile.item_type,
		"count": count,
		"cell": pile.cell,
	}
	_reservations[reservation_id] = reservation
	_worker_reservations[worker_id] = reservation_id
	pile_changed.emit(pile_id)
	var result := _result(true, "OK")
	result.merge(reservation, true)
	return result


func pickup(reservation_id: int, worker_id: String) -> Dictionary:
	var reservation: Dictionary = _reservations.get(reservation_id, {})
	if reservation.is_empty() or String(reservation.worker_id) != worker_id:
		return _result(false, "RESERVATION_NOT_OWNED")
	var pile_id := int(reservation.pile_id)
	var pile: ItemPile = _piles.get(pile_id)
	if pile == null or pile.count < int(reservation.count):
		release_reservation(reservation_id, worker_id)
		return _result(false, "ITEM_CHANGED")
	pile.count -= int(reservation.count)
	pile.reserved_count = maxi(0, pile.reserved_count - int(reservation.count))
	_reservations.erase(reservation_id)
	_worker_reservations.erase(worker_id)
	if pile.count == 0:
		_piles.erase(pile_id)
	pile_changed.emit(pile_id)
	var result := _result(true, "OK")
	result.merge(reservation, true)
	return result


func dropoff(
	worker_id: String,
	item_type: String,
	count: int,
	cell: Vector2i,
	excluded_dropoff_reservation_id: int = -1
) -> Dictionary:
	if worker_id.is_empty() or count <= 0:
		return _result(false, "INVALID_DROPOFF")
	var pile_id := add_pile(item_type, cell, count, excluded_dropoff_reservation_id)
	if pile_id < 0:
		return _result(false, "INVALID_DROPOFF")
	var result := _result(true, "OK")
	result["pile_id"] = pile_id
	result["item_type"] = item_type
	result["count"] = count
	result["cell"] = cell
	return result


func reserve_dropoff(owner_id: String, cell: Vector2i, count: int, capacity: int) -> Dictionary:
	if owner_id.is_empty() or count <= 0 or capacity <= 0:
		return _result(false, "INVALID_DROPOFF_RESERVATION")
	if _world == null or not _world.is_traversable(cell):
		return _result(false, "INVALID_DROPOFF_CELL")
	var configured_capacity: int = get_cell_capacity(cell)
	var effective_capacity: int = mini(capacity, configured_capacity) if configured_capacity > 0 else capacity
	if get_count_at(cell) + get_reserved_dropoff_count(cell) + count > effective_capacity:
		return _result(false, "DROPOFF_CAPACITY_EXCEEDED")
	var reservation_id := _next_dropoff_reservation_id
	_next_dropoff_reservation_id += 1
	var reservation := {
		"reservation_id": reservation_id,
		"owner_id": owner_id,
		"cell": cell,
		"count": count,
		"capacity": effective_capacity,
	}
	_dropoff_reservations[reservation_id] = reservation
	var result := _result(true, "OK")
	result.merge(reservation, true)
	return result


func complete_reserved_dropoff(
	reservation_id: int,
	owner_id: String,
	worker_id: String,
	item_type: String,
	count: int
) -> Dictionary:
	var reservation: Dictionary = _dropoff_reservations.get(reservation_id, {})
	if reservation.is_empty() or String(reservation.owner_id) != owner_id:
		return _result(false, "INVALID_DROPOFF_RESERVATION")
	if int(reservation.count) != count:
		return _result(false, "DROPOFF_COUNT_MISMATCH")
	var cell: Vector2i = reservation.cell
	if get_count_at(cell) + count > int(reservation.capacity):
		return _result(false, "DROPOFF_CAPACITY_EXCEEDED")
	var result := dropoff(worker_id, item_type, count, cell, reservation_id)
	if not result.ok:
		return result
	_dropoff_reservations.erase(reservation_id)
	result["reservation_id"] = reservation_id
	return result


func release_dropoff(reservation_id: int, owner_id: String = "") -> bool:
	var reservation: Dictionary = _dropoff_reservations.get(reservation_id, {})
	if reservation.is_empty() or (not owner_id.is_empty() and String(reservation.owner_id) != owner_id):
		return false
	_dropoff_reservations.erase(reservation_id)
	return true


func get_reserved_dropoff_count(cell: Vector2i, excluded_reservation_id: int = -1) -> int:
	var total := 0
	for reservation_id: int in _dropoff_reservations:
		var reservation: Dictionary = _dropoff_reservations[reservation_id]
		if reservation_id != excluded_reservation_id and reservation.cell == cell:
			total += int(reservation.count)
	return total


func get_debug_dropoff_reservations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reservation: Dictionary in _dropoff_reservations.values():
		result.append(reservation.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.reservation_id) < int(b.reservation_id)
	)
	return result


func replace_cell_capacities(capacities: Dictionary) -> void:
	_cell_capacities.clear()
	for cell: Variant in capacities:
		if cell is Vector2i and int(capacities[cell]) > 0:
			_cell_capacities[cell] = int(capacities[cell])


func get_cell_capacity(cell: Vector2i) -> int:
	return int(_cell_capacities.get(cell, -1))


func can_accept_unreserved_dropoff(cell: Vector2i, count: int) -> bool:
	if count <= 0 or _world == null or not _world.is_traversable(cell):
		return false
	var capacity: int = get_cell_capacity(cell)
	return capacity <= 0 or get_count_at(cell) + get_reserved_dropoff_count(cell) + count <= capacity


func release_worker(worker_id: String) -> bool:
	if not _worker_reservations.has(worker_id):
		return false
	return release_reservation(int(_worker_reservations[worker_id]), worker_id)


func release_reservation(reservation_id: int, worker_id: String) -> bool:
	var reservation: Dictionary = _reservations.get(reservation_id, {})
	if reservation.is_empty() or String(reservation.worker_id) != worker_id:
		return false
	var pile: ItemPile = _piles.get(int(reservation.pile_id))
	if pile != null:
		pile.reserved_count = maxi(0, pile.reserved_count - int(reservation.count))
		pile_changed.emit(pile.pile_id)
	_reservations.erase(reservation_id)
	_worker_reservations.erase(worker_id)
	return true


func get_worker_reservation(worker_id: String) -> Dictionary:
	if not _worker_reservations.has(worker_id):
		return {}
	return _reservations.get(int(_worker_reservations[worker_id]), {}).duplicate(true)


func get_debug_reservations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for reservation: Dictionary in _reservations.values():
		result.append(reservation.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.reservation_id) < int(b.reservation_id)
	)
	return result


func _is_known_type(item_type: String) -> bool:
	return item_type == FOOD or item_type == GENERAL_MATERIAL


func _result(ok: bool, reason_code: String) -> Dictionary:
	return {"ok": ok, "reason_code": reason_code}


## Phase 10 persistence (docs/tech/15 §6): logical piles only. Reservations are
## runtime state and are rebuilt from world state on load; Storage cell
## capacities are re-derived from restored zones by the colony tick sync.
func to_save_data() -> Dictionary:
	var piles: Array = []
	for pile: ItemPile in _piles.values():
		piles.append({
			"id": pile.pile_id,
			"item_type": pile.item_type,
			"cell": [pile.cell.x, pile.cell.y],
			"count": pile.count,
		})
	return {"piles": piles, "next_pile_id": _next_pile_id}


func apply_save_data(data: Dictionary) -> Dictionary:
	_piles.clear()
	_reservations.clear()
	_worker_reservations.clear()
	_dropoff_reservations.clear()
	_next_pile_id = maxi(1, int(data.get("next_pile_id", 1)))
	for entry: Variant in data.get("piles", []):
		if entry is not Dictionary:
			return {"ok": false, "error": "malformed item pile entry"}
		var cell_entry: Array = entry.cell
		if cell_entry.size() != 2:
			return {"ok": false, "error": "malformed item pile cell"}
		var pile := ItemPileScript.new(
			int(entry.id),
			String(entry.item_type),
			Vector2i(int(cell_entry[0]), int(cell_entry[1])),
			int(entry.count)
		)
		_next_pile_id = maxi(_next_pile_id, pile.pile_id + 1)
		_piles[pile.pile_id] = pile
		pile_changed.emit(pile.pile_id)
	return {"ok": true, "error": ""}
