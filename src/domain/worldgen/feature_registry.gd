class_name FeatureRegistry
extends RefCounted

const GeneratedFeatureScript = preload("res://src/domain/worldgen/generated_feature.gd")

var _features_by_id: Dictionary = {}
var _ids_by_type: Dictionary = {}
var _next_id := 1


func add_feature(feature: GeneratedFeature) -> int:
	if feature == null or feature.type_id.is_empty():
		return -1
	if feature.id < 0:
		feature.id = _next_id
	if _features_by_id.has(feature.id):
		return -1
	_next_id = maxi(_next_id, feature.id + 1)
	_features_by_id[feature.id] = feature
	var type_ids: Array = _ids_by_type.get(feature.type_id, [])
	type_ids.append(feature.id)
	_ids_by_type[feature.type_id] = type_ids
	return feature.id


func remove_feature(feature_id: int) -> bool:
	var feature: GeneratedFeature = _features_by_id.get(feature_id)
	if feature == null:
		return false
	_features_by_id.erase(feature_id)
	var type_ids: Array = _ids_by_type.get(feature.type_id, [])
	type_ids.erase(feature_id)
	if type_ids.is_empty():
		_ids_by_type.erase(feature.type_id)
	else:
		_ids_by_type[feature.type_id] = type_ids
	return true


func get_feature(feature_id: int) -> GeneratedFeature:
	return _features_by_id.get(feature_id)


func get_features(type_id: String = "") -> Array[GeneratedFeature]:
	var result: Array[GeneratedFeature] = []
	var ids: Array = _features_by_id.keys() if type_id.is_empty() else _ids_by_type.get(type_id, [])
	ids.sort()
	for feature_id: int in ids:
		var feature: GeneratedFeature = _features_by_id.get(feature_id)
		if feature != null:
			result.append(feature)
	return result


func get_features_by_role(role: String) -> Array[GeneratedFeature]:
	var result: Array[GeneratedFeature] = []
	for feature: GeneratedFeature in get_features():
		if feature.role == role:
			result.append(feature)
	return result


func count(type_id: String = "") -> int:
	return get_features(type_id).size()


func clear() -> void:
	_features_by_id.clear()
	_ids_by_type.clear()
	_next_id = 1


func stable_summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for feature: GeneratedFeature in get_features():
		result.append(feature.stable_summary())
	return result


func checksum() -> int:
	var value := 23
	for feature: GeneratedFeature in get_features():
		value = _mix(value, feature.id)
		value = _mix_string(value, feature.type_id)
		value = _mix_string(value, feature.role)
		value = _mix(value, feature.anchor.x)
		value = _mix(value, feature.anchor.y)
		value = _mix(value, 1 if feature.required else 0)
		value = _mix(value, 1 if feature.hidden else 0)
		var sorted_cells := feature.cells.duplicate()
		sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x)
		)
		for cell: Vector2i in sorted_cells:
			value = _mix(value, cell.x)
			value = _mix(value, cell.y)
		value = _mix_variant(value, feature.metadata)
	return value


func _mix(value: int, addition: int) -> int:
	return int((value * 65599 + addition + 2147483647) % 2147483647)


func _mix_string(value: int, text: String) -> int:
	var mixed := value
	for byte: int in text.to_utf8_buffer():
		mixed = _mix(mixed, byte)
	return mixed


func _mix_variant(value: int, variant: Variant) -> int:
	var mixed := value
	if variant == null:
		return _mix(mixed, 0)
	if variant is bool:
		return _mix(mixed, 1 if variant else 2)
	if variant is int:
		return _mix(mixed, int(variant))
	if variant is float:
		return _mix(mixed, roundi(float(variant) * 10000.0))
	if variant is String or variant is StringName:
		return _mix_string(mixed, String(variant))
	if variant is Vector2i:
		mixed = _mix(mixed, variant.x)
		return _mix(mixed, variant.y)
	if variant is Array:
		mixed = _mix(mixed, variant.size())
		for item: Variant in variant:
			mixed = _mix_variant(mixed, item)
		return mixed
	if variant is Dictionary:
		var keys: Array = variant.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
		for key: Variant in keys:
			mixed = _mix_string(mixed, String(key))
			mixed = _mix_variant(mixed, variant[key])
		return mixed
	return _mix_string(mixed, str(variant))
