class_name RootFeatureSystem
extends RefCounted

signal feature_revealed(feature_id: int, feature_type: String, exposure_cell: Vector2i)
signal feature_reacted(feature_id: int, reaction: Dictionary)
signal feature_state_changed(feature_id: int, state: String)
signal food_produced(feature_id: int, cell: Vector2i, count: int)

const ItemSystemScript = preload("res://src/domain/colony/item_system.gd")
const ZoneScript = preload("res://src/domain/zones/zone.gd")
const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

const STATE_SIGNAL := "SIGNAL"
const STATE_REACTION := "REACTION"
const STATE_ADAPTATION := "ADAPTATION"
const STATE_STABLE := "STABLE_STATE"

var _world
var _feature_registry
var _signal_system
var _item_system
var _zone_system
var _dig_system
var _config: Dictionary = {}
var _forage_accumulators: Dictionary = {}


func configure(
	world_grid,
	feature_registry,
	signal_system,
	item_system,
	zone_system,
	dig_system,
	config: Dictionary = {}
) -> void:
	if _dig_system != null and _dig_system.cell_excavated.is_connected(_on_cell_excavated):
		_dig_system.cell_excavated.disconnect(_on_cell_excavated)
	_world = world_grid
	_feature_registry = feature_registry
	_signal_system = signal_system
	_item_system = item_system
	_zone_system = zone_system
	_dig_system = dig_system
	_config = config.duplicate(true)
	_forage_accumulators.clear()
	_initialize_feature_contracts()
	if _dig_system != null:
		_dig_system.cell_excavated.connect(_on_cell_excavated)


func fixed_tick(delta_seconds: float) -> void:
	if delta_seconds <= 0.0 or _feature_registry == null:
		return
	for feature in _feature_registry.get_features("root_cluster"):
		if feature.hidden or not bool(feature.metadata.get("food_opportunity", false)):
			continue
		var forage_cell := _find_forage_cell(feature)
		if forage_cell.x < 0:
			continue
		if String(feature.metadata.get("lifecycle_state", STATE_SIGNAL)) != STATE_STABLE:
			_set_state(feature, STATE_STABLE)
		var reserve := int(feature.metadata.get("food_reserve_units", 0))
		if reserve <= 0:
			feature.metadata.food_depleted = true
			continue
		var elapsed := float(_forage_accumulators.get(feature.id, 0.0)) + delta_seconds
		var interval := maxf(0.1, float(feature.metadata.get("forage_interval_seconds", _config.get("forage_interval_seconds", 8.0))))
		while elapsed + 0.00001 >= interval and int(feature.metadata.get("food_reserve_units", 0)) > 0:
			if not _produce_food(feature, forage_cell, 1):
				break
			elapsed -= interval
		_forage_accumulators[feature.id] = minf(elapsed, interval)


func reveal_feature(feature_id: int, exposure_cell: Vector2i) -> Dictionary:
	var feature = _feature_registry.get_feature(feature_id) if _feature_registry != null else null
	if feature == null or feature.type_id != "root_cluster":
		return _result(false, "FEATURE_NOT_FOUND", feature_id, exposure_cell)
	if not _is_valid_exposure(feature, exposure_cell):
		return _result(false, "INVALID_EXPOSURE", feature_id, exposure_cell)
	if not feature.hidden:
		return _result(false, "ALREADY_REVEALED", feature_id, exposure_cell)
	feature.hidden = false
	feature.metadata.reveal_count = int(feature.metadata.get("reveal_count", 0)) + 1
	feature.metadata.revealed_at = exposure_cell
	_set_state(feature, STATE_REACTION)
	var initial_yield := mini(
		int(feature.metadata.get("food_reserve_units", 0)),
		maxi(0, int(feature.metadata.get("initial_food_yield", _config.get("initial_food_yield", 4))))
	)
	var produced := 0
	if initial_yield > 0 and _produce_food(feature, exposure_cell, initial_yield):
		produced = initial_yield
	var reaction := {
		"type": "ROOT_EXPOSED",
		"feature_id": feature.id,
		"cell": exposure_cell,
		"food_produced": produced,
		"persistent_obstruction": true,
	}
	feature.metadata.reaction_fired = true
	feature.metadata.last_reaction = reaction.duplicate(true)
	feature_revealed.emit(feature.id, feature.type_id, exposure_cell)
	feature_reacted.emit(feature.id, reaction)
	if _signal_system != null:
		_signal_system.mark_feature_understood("root_cluster")
	_world.mark_region_dirty(
		feature.get_bounds().grow(1),
		WorldGridScript.CHANGE_TERRAIN | WorldGridScript.CHANGE_SIGNALS
	)
	_set_state(feature, STATE_ADAPTATION)
	var result := _result(true, "OK", feature.id, exposure_cell)
	result.food_produced = produced
	result.state = String(feature.metadata.lifecycle_state)
	return result


func get_feature_state(feature_id: int) -> String:
	var feature = _feature_registry.get_feature(feature_id) if _feature_registry != null else null
	return "" if feature == null else String(feature.metadata.get("lifecycle_state", STATE_SIGNAL))


func get_revealed_features() -> Array:
	var result: Array = []
	if _feature_registry == null:
		return result
	for feature in _feature_registry.get_features("root_cluster"):
		if not feature.hidden:
			result.append(feature)
	return result


func _on_cell_excavated(cell: Vector2i) -> void:
	var candidate_ids: Dictionary = {}
	var owner_id: int = int(_world.get_feature_id(cell))
	if owner_id >= 0:
		candidate_ids[owner_id] = true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(cell):
		var neighbor_id: int = int(_world.get_feature_id(neighbor))
		if neighbor_id >= 0:
			candidate_ids[neighbor_id] = true
	var ids: Array = candidate_ids.keys()
	ids.sort()
	for feature_id: int in ids:
		var feature = _feature_registry.get_feature(feature_id)
		if feature != null and feature.type_id == "root_cluster" and feature.hidden:
			reveal_feature(feature_id, cell)


func _initialize_feature_contracts() -> void:
	if _feature_registry == null:
		return
	for feature in _feature_registry.get_features("root_cluster"):
		if not feature.metadata.has("lifecycle_state"):
			feature.metadata.lifecycle_state = STATE_SIGNAL if feature.hidden else STATE_ADAPTATION
		if not feature.metadata.has("reaction_fired"):
			feature.metadata.reaction_fired = not feature.hidden
		if not feature.metadata.has("reveal_count"):
			feature.metadata.reveal_count = 0 if feature.hidden else 1
		if not feature.metadata.has("food_reserve_units"):
			var default_reserve := int(_config.get("required_food_reserve", 12) if feature.required else _config.get("optional_food_reserve", 8))
			feature.metadata.food_reserve_units = default_reserve if bool(feature.metadata.get("food_opportunity", false)) else 0
		if not feature.metadata.has("initial_food_yield"):
			feature.metadata.initial_food_yield = int(_config.get("initial_food_yield", 4))
		if not feature.metadata.has("forage_interval_seconds"):
			feature.metadata.forage_interval_seconds = float(_config.get("forage_interval_seconds", 8.0))
		feature.metadata.food_produced_total = int(feature.metadata.get("food_produced_total", 0))
		feature.metadata.food_depleted = int(feature.metadata.food_reserve_units) <= 0


func _find_forage_cell(feature) -> Vector2i:
	if _zone_system == null:
		return Vector2i(-1, -1)
	var radius := maxi(1, int(_config.get("forage_radius", 2)))
	var candidates: Array[Vector2i] = []
	for zone in _zone_system.get_zones_by_type(ZoneScript.Type.FOOD_FORAGE, true):
		if zone.setup_state != ZoneScript.SetupState.SET_UP:
			continue
		for zone_cell: Vector2i in zone.cells:
			if _distance_to_feature(feature, zone_cell) <= radius:
				candidates.append(zone_cell)
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var a_distance := _distance_to_feature(feature, a)
		var b_distance := _distance_to_feature(feature, b)
		return a_distance < b_distance or (a_distance == b_distance and _world.cell_to_index(a) < _world.cell_to_index(b))
	)
	return Vector2i(-1, -1) if candidates.is_empty() else candidates[0]


func _distance_to_feature(feature, cell: Vector2i) -> int:
	var nearest := 1 << 28
	for feature_cell: Vector2i in feature.cells:
		nearest = mini(nearest, absi(feature_cell.x - cell.x) + absi(feature_cell.y - cell.y))
	return nearest


func _produce_food(feature, cell: Vector2i, requested_count: int) -> bool:
	var reserve := int(feature.metadata.get("food_reserve_units", 0))
	var count := mini(reserve, requested_count)
	if count <= 0 or _item_system == null:
		return false
	var pile_id: int = int(_item_system.add_pile(ItemSystemScript.FOOD, cell, count))
	if pile_id < 0:
		return false
	feature.metadata.food_reserve_units = reserve - count
	feature.metadata.food_produced_total = int(feature.metadata.get("food_produced_total", 0)) + count
	feature.metadata.food_depleted = int(feature.metadata.food_reserve_units) <= 0
	food_produced.emit(feature.id, cell, count)
	return true


func _is_valid_exposure(feature, exposure_cell: Vector2i) -> bool:
	if not _world.is_traversable(exposure_cell):
		return false
	if feature.cells.has(exposure_cell):
		return true
	for neighbor: Vector2i in _world.get_cardinal_neighbors(exposure_cell):
		if feature.cells.has(neighbor):
			return true
	return false


func _set_state(feature, state: String) -> void:
	if String(feature.metadata.get("lifecycle_state", "")) == state:
		return
	feature.metadata.lifecycle_state = state
	feature_state_changed.emit(feature.id, state)


func _result(ok: bool, reason_code: String, feature_id: int, cell: Vector2i) -> Dictionary:
	return {
		"ok": ok,
		"reason_code": reason_code,
		"feature_id": feature_id,
		"cell": cell,
	}
