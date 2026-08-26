class_name SignalSystem
extends RefCounted

signal field_region_updated(channel: String, region: Rect2i)
signal recognition_changed(category: String, level: int)

enum RecognitionLevel {
	UNKNOWN,
	ENCOUNTERED,
	UNDERSTOOD,
}

enum Band {
	NONE,
	WEAK,
	NOTICEABLE,
	STRONG,
}

const WorldGridScript = preload("res://src/domain/world/world_grid.gd")

const ROOT_DENSITY := "root_density"
const MOISTURE := "moisture"
const INSTABILITY := "instability"
const ROOT_CATEGORY := "root_cluster"
const WATER_CATEGORY := "water_reservoir"

var _world
var _feature_registry
var _emitters: Array[Dictionary] = []
var _config: Dictionary = {}
var _recognition: Dictionary = {
	ROOT_CATEGORY: RecognitionLevel.UNKNOWN,
	WATER_CATEGORY: RecognitionLevel.UNKNOWN,
}
var _dirty_regions: Array[Dictionary] = []
var _runtime_updates := 0
var _runtime_tracking := false


func configure(
	world_grid,
	feature_registry,
	emitters: Array,
	config: Dictionary = {},
	rebuild_fields: bool = true,
	enable_runtime_tracking: bool = true
) -> void:
	if _world != null and _world.cell_changed.is_connected(_on_world_cell_changed):
		_world.cell_changed.disconnect(_on_world_cell_changed)
	_world = world_grid
	_feature_registry = feature_registry
	_emitters.clear()
	for emitter_value: Variant in emitters:
		if emitter_value is Dictionary:
			_emitters.append((emitter_value as Dictionary).duplicate(true))
	_config = config.duplicate(true)
	_runtime_tracking = enable_runtime_tracking
	_dirty_regions.clear()
	_runtime_updates = 0
	_recognition = {
		ROOT_CATEGORY: RecognitionLevel.UNKNOWN,
		WATER_CATEGORY: RecognitionLevel.UNKNOWN,
	}
	if _world == null:
		return
	_world.metadata.signal_thresholds = _threshold_metadata()
	if rebuild_fields:
		rebuild_all()
	if _runtime_tracking:
		_world.cell_changed.connect(_on_world_cell_changed)
		_scan_existing_frontier()


func rebuild_all() -> void:
	if _world == null:
		return
	_rebuild_channel(ROOT_DENSITY)
	_rebuild_channel(MOISTURE)


func rebuild_channel(channel: String) -> void:
	if channel not in [ROOT_DENSITY, MOISTURE]:
		return
	_rebuild_channel(channel)


func get_value(channel: String, cell: Vector2i) -> int:
	if _world == null or not _world.is_in_bounds(cell):
		return 0
	match channel:
		ROOT_DENSITY:
			return _world.get_root_signal(cell)
		MOISTURE:
			return _world.get_moisture_signal(cell)
		INSTABILITY:
			return _world.get_stability_base(cell)
		_:
			return 0


func get_band(channel: String, cell: Vector2i) -> int:
	var value := get_value(channel, cell)
	var thresholds := get_thresholds(channel)
	if value < thresholds[0]:
		return Band.NONE
	if value < thresholds[1]:
		return Band.WEAK
	if value < thresholds[2]:
		return Band.NOTICEABLE
	return Band.STRONG


func get_band_name(band: int) -> String:
	match band:
		Band.WEAK:
			return "WEAK"
		Band.NOTICEABLE:
			return "NOTICEABLE"
		Band.STRONG:
			return "STRONG"
		_:
			return "NONE"


func get_thresholds(channel: String) -> Array[int]:
	var defaults: Array[int] = [1, 3, 5]
	var channel_config: Dictionary = _config.get(channel, {})
	var values: Array = channel_config.get("thresholds", defaults)
	if values.size() != 3:
		return defaults
	var result: Array[int] = [int(values[0]), int(values[1]), int(values[2])]
	if result[0] <= 0 or result[1] <= result[0] or result[2] <= result[1]:
		return defaults
	return result


func get_qualitative_clue(channel: String, cell: Vector2i) -> String:
	var band := get_band(channel, cell)
	if band == Band.NONE:
		return ""
	if channel == INSTABILITY:
		match band:
			Band.WEAK:
				return "clue.crumbs_drift"
			Band.NOTICEABLE:
				return "clue.cracks_creep"
			_:
				return "Critical: this ceiling could collapse!"
	if channel == MOISTURE:
		var moisture_level := get_recognition_level(WATER_CATEGORY)
		if moisture_level == RecognitionLevel.UNKNOWN:
			return "clue.damp"
		if moisture_level == RecognitionLevel.ENCOUNTERED:
			match band:
				Band.WEAK:
					return "A faint damp trace."
				Band.NOTICEABLE:
					return "clue.seep_marks"
				_:
					return "clue.saturated"
		match band:
			Band.WEAK:
				return "A faint trace points toward a finite reservoir."
			Band.NOTICEABLE:
				return "clue.seep_reservoir"
			_:
				return "A finite reservoir is very close."
	if channel != ROOT_DENSITY:
		return get_band_name(band).capitalize()
	var level := get_recognition_level(ROOT_CATEGORY)
	if level == RecognitionLevel.UNKNOWN:
		return "clue.fibers"
	if level == RecognitionLevel.ENCOUNTERED:
		match band:
			Band.WEAK:
				return "clue.root_fine"
			Band.NOTICEABLE:
				return "clue.root_dense"
			_:
				return "clue.root_thick"
	match band:
		Band.WEAK:
			return "clue.root_fine_food"
		Band.NOTICEABLE:
			return "clue.root_dense_food"
		_:
			return "A major food-bearing Root Cluster is close."


func get_recognition_level(category: String) -> int:
	return int(_recognition.get(category, RecognitionLevel.UNKNOWN))


func get_recognition_name(category: String) -> String:
	match get_recognition_level(category):
		RecognitionLevel.ENCOUNTERED:
			return "ENCOUNTERED"
		RecognitionLevel.UNDERSTOOD:
			return "UNDERSTOOD"
		_:
			return "UNKNOWN"


func set_recognition_level(category: String, level: int) -> bool:
	var normalized := clampi(level, RecognitionLevel.UNKNOWN, RecognitionLevel.UNDERSTOOD)
	var current := get_recognition_level(category)
	if normalized <= current:
		return false
	_recognition[category] = normalized
	recognition_changed.emit(category, normalized)
	return true


func mark_feature_understood(feature_type: String) -> bool:
	return set_recognition_level(feature_type, RecognitionLevel.UNDERSTOOD)


func get_dirty_regions() -> Array[Dictionary]:
	return _dirty_regions.duplicate(true)


func get_runtime_update_count() -> int:
	return _runtime_updates


func get_emitters() -> Array[Dictionary]:
	return _emitters.duplicate(true)


func _rebuild_channel(channel: String) -> void:
	var values := PackedByteArray()
	values.resize(_world.width * _world.height)
	values.fill(0)
	for emitter: Dictionary in _emitters:
		if String(emitter.get("channel", "")) != channel:
			continue
		var feature = _feature_registry.get_feature(int(emitter.get("feature_id", -1))) if _feature_registry != null else null
		if feature == null:
			continue
		var strength := clampi(int(emitter.get("strength", 0)), 0, 255)
		var falloff := maxi(1, int(emitter.get("falloff", 1)))
		var radius := strength / falloff
		var sources: Array[Vector2i] = feature.cells if not feature.cells.is_empty() else [feature.anchor]
		for source: Vector2i in sources:
			for offset_y: int in range(-radius, radius + 1):
				var horizontal := radius - absi(offset_y)
				for offset_x: int in range(-horizontal, horizontal + 1):
					var cell := source + Vector2i(offset_x, offset_y)
					var index: int = _world.cell_to_index(cell)
					if index < 0 or _world.is_exterior(cell):
						continue
					var value := maxi(0, strength - (absi(offset_x) + absi(offset_y)) * falloff)
					if value > values[index]:
						values[index] = value
	_world.replace_signal_field(channel, values)


func _rebuild_region(channel: String, region: Rect2i) -> void:
	if channel not in [ROOT_DENSITY, MOISTURE]:
		return
	var clipped := _clip_region(region)
	for y: int in range(clipped.position.y, clipped.end.y):
		for x: int in range(clipped.position.x, clipped.end.x):
			var cell := Vector2i(x, y)
			_set_world_value(channel, cell, _calculate_value(channel, cell))
	_record_dirty(channel, clipped)


func _calculate_value(channel: String, cell: Vector2i) -> int:
	if _world.is_exterior(cell):
		return 0
	var best := 0
	for emitter: Dictionary in _emitters:
		if String(emitter.get("channel", "")) != channel:
			continue
		var feature = _feature_registry.get_feature(int(emitter.get("feature_id", -1))) if _feature_registry != null else null
		if feature == null:
			continue
		var nearest := 1 << 28
		var sources: Array[Vector2i] = feature.cells if not feature.cells.is_empty() else [feature.anchor]
		for source: Vector2i in sources:
			nearest = mini(nearest, absi(source.x - cell.x) + absi(source.y - cell.y))
		var strength := int(emitter.get("strength", 0))
		var falloff := maxi(1, int(emitter.get("falloff", 1)))
		best = maxi(best, strength - nearest * falloff)
	return clampi(best, 0, 255)


func _set_world_value(channel: String, cell: Vector2i, value: int) -> void:
	if channel == ROOT_DENSITY:
		_world.set_root_signal(cell, value)
	elif channel == MOISTURE:
		_world.set_moisture_signal(cell, value)


func _on_world_cell_changed(cell: Vector2i, change_flags: int) -> void:
	if (change_flags & WorldGridScript.CHANGE_TERRAIN) == 0:
		return
	var radius := _maximum_radius()
	var region := Rect2i(cell - Vector2i(radius, radius), Vector2i.ONE * (radius * 2 + 1))
	_rebuild_region(ROOT_DENSITY, region)
	_rebuild_region(MOISTURE, region)
	_runtime_updates += 1
	_update_frontier_recognition(cell)


func _scan_existing_frontier() -> void:
	for index: int in range(_world.width * _world.height):
		var cell: Vector2i = _world.index_to_cell(index)
		if _world.is_traversable(cell):
			_update_frontier_recognition(cell)
			if (
				get_recognition_level(ROOT_CATEGORY) >= RecognitionLevel.ENCOUNTERED
				and get_recognition_level(WATER_CATEGORY) >= RecognitionLevel.ENCOUNTERED
			):
				return


func _update_frontier_recognition(cell: Vector2i) -> void:
	var candidates: Array[Vector2i] = [cell]
	candidates.append_array(_world.get_cardinal_neighbors(cell))
	for candidate: Vector2i in candidates:
		if get_band(ROOT_DENSITY, candidate) != Band.NONE:
			set_recognition_level(ROOT_CATEGORY, RecognitionLevel.ENCOUNTERED)
		if get_band(MOISTURE, candidate) != Band.NONE:
			set_recognition_level(WATER_CATEGORY, RecognitionLevel.ENCOUNTERED)


func _maximum_radius() -> int:
	var result := 1
	for emitter: Dictionary in _emitters:
		result = maxi(result, int(emitter.get("strength", 0)) / maxi(1, int(emitter.get("falloff", 1))))
	return result


func _record_dirty(channel: String, region: Rect2i) -> void:
	if region.size.x <= 0 or region.size.y <= 0:
		return
	_dirty_regions.append({"channel": channel, "region": region, "update": _runtime_updates + 1})
	while _dirty_regions.size() > 32:
		_dirty_regions.pop_front()
	_world.mark_region_dirty(region, WorldGridScript.CHANGE_SIGNALS)
	field_region_updated.emit(channel, region)


func _clip_region(region: Rect2i) -> Rect2i:
	var start := Vector2i(maxi(0, region.position.x), maxi(0, region.position.y))
	var finish := Vector2i(mini(_world.width, region.end.x), mini(_world.height, region.end.y))
	return Rect2i(start, Vector2i(maxi(0, finish.x - start.x), maxi(0, finish.y - start.y)))


func _threshold_metadata() -> Dictionary:
	return {
		ROOT_DENSITY: get_thresholds(ROOT_DENSITY),
		MOISTURE: get_thresholds(MOISTURE),
		INSTABILITY: get_thresholds(INSTABILITY),
	}
