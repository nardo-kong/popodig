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
var _next_pile_id := 1
var _next_reservation_id := 1


func configure(world_grid, path_service) -> void:
	_world = world_grid
	_path_service = path_service
	_piles.clear()
	_reservations.clear()
	_worker_reservations.clear()
	_next_pile_id = 1
	_next_reservation_id = 1


func add_pile(item_type: String, cell: Vector2i, count: int) -> int:
	if not _is_known_type(item_type) or count <= 0:
		return -1
	if _world == null or not _world.is_in_bounds(cell) or not _world.is_excavated(cell):
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


func dropoff(worker_id: String, item_type: String, count: int, cell: Vector2i) -> Dictionary:
	if worker_id.is_empty() or count <= 0:
		return _result(false, "INVALID_DROPOFF")
	var pile_id := add_pile(item_type, cell, count)
	if pile_id < 0:
		return _result(false, "INVALID_DROPOFF")
	var result := _result(true, "OK")
	result["pile_id"] = pile_id
	result["item_type"] = item_type
	result["count"] = count
	result["cell"] = cell
	return result


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
