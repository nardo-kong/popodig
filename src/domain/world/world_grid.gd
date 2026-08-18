class_name WorldGrid
extends RefCounted

signal cell_changed(cell_coord: Vector2i, change_flags: int)
signal chunk_dirtied(chunk_coord: Vector2i, dirty_flags: int)

const CellDataScript = preload("res://src/domain/world/cell_data.gd")
const WorldChunkScript = preload("res://src/domain/world/world_chunk.gd")

const CHANGE_TERRAIN := 1
const CHANGE_SIGNALS := 2
const CHANGE_WATER := 4
const CHANGE_STABILITY := 8
const CHANGE_PATHING := 16
const CHANGE_DIG := 32
const CHANGE_ZONE := 64

const CELL_FLAG_PROTECTED := 1
const CELL_FLAG_EXTERIOR := 2
const CELL_FLAG_LANDMARK := 4
const CELL_FLAG_SEALED := 32
const CELL_FLAG_STRATUM_SHIFT := 3
const CELL_FLAG_STRATUM_MASK := 24

var width: int
var height: int
var chunk_size: int
var metadata: Dictionary = {}

var _terrain := PackedByteArray()
var _excavated := PackedByteArray()
var _hardness := PackedFloat32Array()
var _dig_state := PackedByteArray()
var _dig_progress := PackedFloat32Array()
var _feature_ids := PackedInt32Array()
var _stability_base := PackedByteArray()
var _water_units := PackedByteArray()
var _moisture_signal := PackedByteArray()
var _root_signal := PackedByteArray()
var _zone_ids := PackedInt32Array()
var _cell_flags := PackedByteArray()
var _chunks: Dictionary = {}


func _init(grid_width: int, grid_height: int, requested_chunk_size: int = 16) -> void:
	width = maxi(1, grid_width)
	height = maxi(1, grid_height)
	chunk_size = maxi(1, requested_chunk_size)
	_initialize_storage(width * height)
	_initialize_chunks()


func is_in_bounds(cell_coord: Vector2i) -> bool:
	return cell_coord.x >= 0 and cell_coord.y >= 0 and cell_coord.x < width and cell_coord.y < height


func cell_to_index(cell_coord: Vector2i) -> int:
	if not is_in_bounds(cell_coord):
		return -1
	return cell_coord.y * width + cell_coord.x


func index_to_cell(index: int) -> Vector2i:
	if index < 0 or index >= width * height:
		return Vector2i(-1, -1)
	return Vector2i(index % width, index / width)


func cell_to_chunk(cell_coord: Vector2i) -> Vector2i:
	if not is_in_bounds(cell_coord):
		return Vector2i(-1, -1)
	return Vector2i(cell_coord.x / chunk_size, cell_coord.y / chunk_size)


func get_cell(cell_coord: Vector2i) -> CellData:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return null
	var cell := CellDataScript.new()
	cell.coord = cell_coord
	cell.terrain_material = _terrain[index]
	cell.excavated = _excavated[index] == 1
	cell.hardness = _hardness[index]
	cell.dig_state = _dig_state[index]
	cell.dig_progress = _dig_progress[index]
	cell.feature_id = _feature_ids[index]
	cell.stratum_id = (_cell_flags[index] & CELL_FLAG_STRATUM_MASK) >> CELL_FLAG_STRATUM_SHIFT
	cell.landmark = (_cell_flags[index] & CELL_FLAG_LANDMARK) != 0
	cell.stability_base = _stability_base[index]
	cell.water_units = _water_units[index]
	cell.moisture_signal = _moisture_signal[index]
	cell.root_signal = _root_signal[index]
	cell.zone_id = _zone_ids[index]
	cell.protected_cell = (_cell_flags[index] & CELL_FLAG_PROTECTED) != 0
	cell.exterior = (_cell_flags[index] & CELL_FLAG_EXTERIOR) != 0
	cell.sealed = (_cell_flags[index] & CELL_FLAG_SEALED) != 0
	return cell


func initialize_cell(
	cell_coord: Vector2i,
	material: int,
	is_excavated: bool,
	is_protected: bool = false,
	is_exterior_cell: bool = false
) -> void:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return
	_terrain[index] = material
	_excavated[index] = 1 if is_excavated else 0
	_hardness[index] = CellDataScript.default_hardness(material)
	_cell_flags[index] = (CELL_FLAG_PROTECTED if is_protected else 0) | (CELL_FLAG_EXTERIOR if is_exterior_cell else 0)


func get_material(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return CellDataScript.TerrainMaterial.EMPTY if index < 0 else _terrain[index]


func is_excavated(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return index >= 0 and _excavated[index] == 1


func is_exterior(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return index >= 0 and (_cell_flags[index] & CELL_FLAG_EXTERIOR) != 0


func is_traversable(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return (
		index >= 0
		and _excavated[index] == 1
		and (_cell_flags[index] & (CELL_FLAG_EXTERIOR | CELL_FLAG_SEALED)) == 0
	)


func is_solid(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return (
		index >= 0
		and (
			(_cell_flags[index] & CELL_FLAG_SEALED) != 0
			or (_terrain[index] != CellDataScript.TerrainMaterial.EMPTY and _excavated[index] == 0)
		)
	)


func is_sealed(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return index >= 0 and (_cell_flags[index] & CELL_FLAG_SEALED) != 0


func is_protected(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return index >= 0 and (_cell_flags[index] & CELL_FLAG_PROTECTED) != 0


func get_hardness(cell_coord: Vector2i) -> float:
	var index := cell_to_index(cell_coord)
	return 0.0 if index < 0 else _hardness[index]


func get_dig_state(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return CellDataScript.DigState.NONE if index < 0 else _dig_state[index]


func get_dig_progress(cell_coord: Vector2i) -> float:
	var index := cell_to_index(cell_coord)
	return 0.0 if index < 0 else _dig_progress[index]


func get_water_units(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return 0 if index < 0 else _water_units[index]


func get_feature_id(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return -1 if index < 0 else _feature_ids[index]


func get_stratum_id(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return -1 if index < 0 else ((_cell_flags[index] & CELL_FLAG_STRATUM_MASK) >> CELL_FLAG_STRATUM_SHIFT)


func is_landmark(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	return index >= 0 and (_cell_flags[index] & CELL_FLAG_LANDMARK) != 0


func get_stability_base(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return 0 if index < 0 else _stability_base[index]


func get_moisture_signal(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return 0 if index < 0 else _moisture_signal[index]


func get_root_signal(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return 0 if index < 0 else _root_signal[index]


func get_zone_id(cell_coord: Vector2i) -> int:
	var index := cell_to_index(cell_coord)
	return -1 if index < 0 else _zone_ids[index]


func get_cardinal_neighbors(cell_coord: Vector2i, in_bounds_only: bool = true) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		var neighbor := cell_coord + direction
		if not in_bounds_only or is_in_bounds(neighbor):
			neighbors.append(neighbor)
	return neighbors


func set_material(cell_coord: Vector2i, material: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or _terrain[index] == material:
		return false
	_terrain[index] = material
	_hardness[index] = CellDataScript.default_hardness(material)
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_PATHING)
	return true


func set_excavated(cell_coord: Vector2i, value: bool, allow_protected: bool = false) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or ((_cell_flags[index] & CELL_FLAG_PROTECTED) != 0 and not allow_protected):
		return false
	var encoded := 1 if value else 0
	if _excavated[index] == encoded:
		return false
	_excavated[index] = encoded
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_PATHING | CHANGE_STABILITY)
	return true


func set_protected(cell_coord: Vector2i, value: bool) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var current := (_cell_flags[index] & CELL_FLAG_PROTECTED) != 0
	if current == value:
		return false
	if value:
		_cell_flags[index] |= CELL_FLAG_PROTECTED
	else:
		_cell_flags[index] &= ~CELL_FLAG_PROTECTED
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN)
	return true


func set_exterior(cell_coord: Vector2i, value: bool) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var current := (_cell_flags[index] & CELL_FLAG_EXTERIOR) != 0
	if current == value:
		return false
	if value:
		_cell_flags[index] |= CELL_FLAG_EXTERIOR
	else:
		_cell_flags[index] &= ~CELL_FLAG_EXTERIOR
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_PATHING)
	return true


func set_sealed(cell_coord: Vector2i, value: bool) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or _excavated[index] == 0 or (_cell_flags[index] & CELL_FLAG_EXTERIOR) != 0:
		return false
	var current := (_cell_flags[index] & CELL_FLAG_SEALED) != 0
	if current == value:
		return false
	if value:
		_cell_flags[index] |= CELL_FLAG_SEALED
	else:
		_cell_flags[index] &= ~CELL_FLAG_SEALED
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_WATER | CHANGE_PATHING | CHANGE_STABILITY)
	return true


func set_dig_state(cell_coord: Vector2i, state: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or state < CellDataScript.DigState.NONE or state > CellDataScript.DigState.ACTIVE:
		return false
	if _dig_state[index] == state and (state != CellDataScript.DigState.NONE or is_zero_approx(_dig_progress[index])):
		return false
	_dig_state[index] = state
	if state == CellDataScript.DigState.NONE:
		_dig_progress[index] = 0.0
	_mark_cell_changed(cell_coord, CHANGE_DIG)
	return true


func set_dig_progress(cell_coord: Vector2i, progress: float) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or _dig_state[index] == CellDataScript.DigState.NONE:
		return false
	var normalized := clampf(progress, 0.0, 1.0)
	if is_equal_approx(_dig_progress[index], normalized):
		return false
	_dig_progress[index] = normalized
	_mark_cell_changed(cell_coord, CHANGE_DIG)
	return true


func clear_dig(cell_coord: Vector2i) -> bool:
	return set_dig_state(cell_coord, CellDataScript.DigState.NONE)


func set_water_units(cell_coord: Vector2i, units: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var encoded := clampi(units, 0, 255)
	if _water_units[index] == encoded:
		return false
	_water_units[index] = encoded
	_mark_cell_changed(cell_coord, CHANGE_WATER | CHANGE_PATHING)
	return true


func set_feature_id(cell_coord: Vector2i, feature_id: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or feature_id < -1 or _feature_ids[index] == feature_id:
		return false
	_feature_ids[index] = feature_id
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_SIGNALS)
	return true


func set_stratum_id(cell_coord: Vector2i, stratum_id: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or stratum_id < 0 or stratum_id > 3:
		return false
	var current := (_cell_flags[index] & CELL_FLAG_STRATUM_MASK) >> CELL_FLAG_STRATUM_SHIFT
	if current == stratum_id:
		return false
	_cell_flags[index] = (_cell_flags[index] & ~CELL_FLAG_STRATUM_MASK) | (stratum_id << CELL_FLAG_STRATUM_SHIFT)
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_SIGNALS)
	return true


func set_landmark(cell_coord: Vector2i, value: bool) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var current := (_cell_flags[index] & CELL_FLAG_LANDMARK) != 0
	if current == value:
		return false
	if value:
		_cell_flags[index] |= CELL_FLAG_LANDMARK
	else:
		_cell_flags[index] &= ~CELL_FLAG_LANDMARK
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_SIGNALS)
	return true


func set_stability_base(cell_coord: Vector2i, value: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var encoded := clampi(value, 0, 255)
	if _stability_base[index] == encoded:
		return false
	_stability_base[index] = encoded
	_mark_cell_changed(cell_coord, CHANGE_STABILITY)
	return true


func set_moisture_signal(cell_coord: Vector2i, value: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var encoded := clampi(value, 0, 255)
	if _moisture_signal[index] == encoded:
		return false
	_moisture_signal[index] = encoded
	_mark_cell_changed(cell_coord, CHANGE_SIGNALS)
	return true


func set_root_signal(cell_coord: Vector2i, value: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0:
		return false
	var encoded := clampi(value, 0, 255)
	if _root_signal[index] == encoded:
		return false
	_root_signal[index] = encoded
	_mark_cell_changed(cell_coord, CHANGE_SIGNALS)
	return true


func replace_signal_field(channel: String, values: PackedByteArray) -> bool:
	if values.size() != width * height:
		return false
	match channel:
		"root_density":
			_root_signal = values
		"moisture":
			_moisture_signal = values
		_:
			return false
	mark_all_chunks_dirty(WorldChunkScript.DIRTY_SIGNALS)
	return true


func set_zone_id(cell_coord: Vector2i, zone_id: int) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or zone_id < -1 or _zone_ids[index] == zone_id:
		return false
	_zone_ids[index] = zone_id
	_mark_cell_changed(cell_coord, CHANGE_ZONE)
	return true


func complete_excavation_atomic(cell_coord: Vector2i) -> bool:
	var index := cell_to_index(cell_coord)
	if index < 0 or (_cell_flags[index] & (CELL_FLAG_PROTECTED | CELL_FLAG_EXTERIOR)) != 0:
		return false
	if (_cell_flags[index] & CELL_FLAG_SEALED) != 0:
		if _dig_state[index] == CellDataScript.DigState.NONE:
			return false
		_cell_flags[index] &= ~CELL_FLAG_SEALED
		_dig_state[index] = CellDataScript.DigState.NONE
		_dig_progress[index] = 0.0
		_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_WATER | CHANGE_PATHING | CHANGE_STABILITY | CHANGE_DIG)
		return true
	if _excavated[index] == 1:
		return false
	if _terrain[index] == CellDataScript.TerrainMaterial.EMPTY:
		return false
	if _dig_state[index] == CellDataScript.DigState.NONE:
		return false
	_excavated[index] = 1
	_dig_state[index] = CellDataScript.DigState.NONE
	_dig_progress[index] = 0.0
	_mark_cell_changed(cell_coord, CHANGE_TERRAIN | CHANGE_PATHING | CHANGE_STABILITY | CHANGE_DIG)
	return true


func get_chunk(chunk_coord: Vector2i) -> WorldChunk:
	return _chunks.get(chunk_coord)


func get_chunks() -> Array[WorldChunk]:
	var chunks: Array[WorldChunk] = []
	for chunk: WorldChunk in _chunks.values():
		chunks.append(chunk)
	chunks.sort_custom(func(a: WorldChunk, b: WorldChunk) -> bool:
		return a.coord.y < b.coord.y or (a.coord.y == b.coord.y and a.coord.x < b.coord.x)
	)
	return chunks


func get_chunk_count() -> int:
	return _chunks.size()


func mark_all_chunks_dirty(flags: int = WorldChunkScript.DIRTY_ALL) -> void:
	for chunk: WorldChunk in _chunks.values():
		chunk.mark_dirty(flags)
		chunk_dirtied.emit(chunk.coord, flags)


func mark_region_dirty(region: Rect2i, change_flags: int) -> void:
	var start := Vector2i(maxi(0, region.position.x), maxi(0, region.position.y))
	var finish := Vector2i(mini(width, region.end.x), mini(height, region.end.y))
	if finish.x <= start.x or finish.y <= start.y:
		return
	var dirty_flags := _changes_to_dirty(change_flags)
	var first_chunk := cell_to_chunk(start)
	var last_chunk := cell_to_chunk(finish - Vector2i.ONE)
	for chunk_y: int in range(first_chunk.y, last_chunk.y + 1):
		for chunk_x: int in range(first_chunk.x, last_chunk.x + 1):
			var chunk_coord := Vector2i(chunk_x, chunk_y)
			var chunk: WorldChunk = _chunks.get(chunk_coord)
			if chunk == null:
				continue
			chunk.mark_dirty(dirty_flags)
			chunk_dirtied.emit(chunk_coord, dirty_flags)


func checksum() -> int:
	var value := 17
	for index: int in range(width * height):
		value = (value * 31 + _terrain[index]) % 2147483647
		value = (value * 31 + _excavated[index]) % 2147483647
		value = (value * 31 + _cell_flags[index]) % 2147483647
	return value


func content_checksum() -> int:
	var value := 29
	value = _checksum_mix(value, width)
	value = _checksum_mix(value, height)
	value = _checksum_mix(value, chunk_size)
	value = _checksum_mix(value, int(metadata.get("worldgen_version", 0)))
	var start_cell: Vector2i = metadata.get("start_cell", Vector2i(-1, -1))
	value = _checksum_mix(value, start_cell.x)
	value = _checksum_mix(value, start_cell.y)
	for index: int in range(width * height):
		value = _checksum_mix(value, _terrain[index])
		value = _checksum_mix(value, _excavated[index])
		value = _checksum_mix(value, roundi(_hardness[index] * 1000.0))
		value = _checksum_mix(value, _dig_state[index])
		value = _checksum_mix(value, roundi(_dig_progress[index] * 1000.0))
		value = _checksum_mix(value, _feature_ids[index])
		value = _checksum_mix(value, _stability_base[index])
		value = _checksum_mix(value, _water_units[index])
		value = _checksum_mix(value, _moisture_signal[index])
		value = _checksum_mix(value, _root_signal[index])
		value = _checksum_mix(value, _zone_ids[index])
		value = _checksum_mix(value, _cell_flags[index])
	for surface_y: int in metadata.get("surface_heights", PackedInt32Array()):
		value = _checksum_mix(value, surface_y)
	var depth_targets: Dictionary = metadata.get("depth_targets", {})
	var target_names: Array = depth_targets.keys()
	target_names.sort()
	for target_name: Variant in target_names:
		value = _checksum_mix_string(value, String(target_name))
		value = _checksum_mix(value, int(depth_targets[target_name]))
	return value


func estimate_storage_bytes() -> int:
	return (
		_terrain.size()
		+ _excavated.size()
		+ _hardness.size() * 4
		+ _dig_state.size()
		+ _dig_progress.size() * 4
		+ _feature_ids.size() * 4
		+ _stability_base.size()
		+ _water_units.size()
		+ _moisture_signal.size()
		+ _root_signal.size()
		+ _zone_ids.size() * 4
		+ _cell_flags.size()
	)


func _initialize_storage(cell_count: int) -> void:
	_terrain.resize(cell_count)
	_excavated.resize(cell_count)
	_hardness.resize(cell_count)
	_dig_state.resize(cell_count)
	_dig_progress.resize(cell_count)
	_feature_ids.resize(cell_count)
	_stability_base.resize(cell_count)
	_water_units.resize(cell_count)
	_moisture_signal.resize(cell_count)
	_root_signal.resize(cell_count)
	_zone_ids.resize(cell_count)
	_cell_flags.resize(cell_count)
	_feature_ids.fill(-1)
	_zone_ids.fill(-1)


func _checksum_mix(value: int, addition: int) -> int:
	return int((value * 65599 + addition + 2147483647) % 2147483647)


func _checksum_mix_string(value: int, text: String) -> int:
	var mixed := value
	for byte: int in text.to_utf8_buffer():
		mixed = _checksum_mix(mixed, byte)
	return mixed


func _initialize_chunks() -> void:
	var chunk_columns := ceili(float(width) / chunk_size)
	var chunk_rows := ceili(float(height) / chunk_size)
	for chunk_y: int in range(chunk_rows):
		for chunk_x: int in range(chunk_columns):
			var chunk_coord := Vector2i(chunk_x, chunk_y)
			var origin := chunk_coord * chunk_size
			var actual_size := Vector2i(mini(chunk_size, width - origin.x), mini(chunk_size, height - origin.y))
			_chunks[chunk_coord] = WorldChunkScript.new(chunk_coord, origin, actual_size)


func _mark_cell_changed(cell_coord: Vector2i, change_flags: int) -> void:
	var chunk_coord := cell_to_chunk(cell_coord)
	var chunk: WorldChunk = _chunks.get(chunk_coord)
	if chunk != null:
		var dirty_flags := _changes_to_dirty(change_flags)
		chunk.mark_dirty(dirty_flags)
		chunk_dirtied.emit(chunk_coord, dirty_flags)
	cell_changed.emit(cell_coord, change_flags)


func _changes_to_dirty(change_flags: int) -> int:
	var dirty := 0
	if change_flags & CHANGE_TERRAIN:
		dirty |= WorldChunkScript.DIRTY_TERRAIN
	if change_flags & CHANGE_SIGNALS:
		dirty |= WorldChunkScript.DIRTY_SIGNALS
	if change_flags & CHANGE_WATER:
		dirty |= WorldChunkScript.DIRTY_WATER
	if change_flags & CHANGE_STABILITY:
		dirty |= WorldChunkScript.DIRTY_STABILITY
	if change_flags & CHANGE_PATHING:
		dirty |= WorldChunkScript.DIRTY_PATHING
	if change_flags & CHANGE_DIG:
		dirty |= WorldChunkScript.DIRTY_JOBS
	if change_flags & CHANGE_ZONE:
		dirty |= WorldChunkScript.DIRTY_ZONES
	return dirty
