class_name CollectionBook
extends RefCounted

signal changed()
const Discovery = preload("res://src/domain/features/discovery_system.gd")
var _collected: Dictionary = {}


func on_discovery(event: Dictionary) -> void:
	var id: String = str(event.get("definition_id", ""))
	if not Discovery.COLLECTIBLES.has(id):
		return
	_collected[id] = int(_collected.get(id, 0)) + 1
	changed.emit()


func unique_count() -> int:
	return _collected.size()


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in Discovery.COLLECTIBLES:
		var definition: Dictionary = Discovery.definition_for(id).duplicate(true)
		definition["id"] = id
		definition["count"] = int(_collected.get(id, 0))
		definition["tier"] = mini(3, Discovery.COLLECTIBLES.find(id) / 5)
		result.append(definition)
	return result


func reconcile(registry) -> void:
	# Older v3 saves already contain claimed discovery facts but no separate book.
	if registry == null:
		return
	var claimed: Dictionary = {}
	for feature in registry.get_features("discovery"):
		var id: String = str(feature.metadata.get("definition_id", ""))
		if Discovery.COLLECTIBLES.has(id) and bool(feature.metadata.get("claimed", false)):
			claimed[id] = int(claimed.get(id, 0)) + 1
	for id: String in claimed:
		_collected[id] = maxi(int(claimed[id]), int(_collected.get(id, 0)))
	changed.emit()


func to_save_data() -> Dictionary:
	return {"collected": _collected.duplicate()}


func apply_save_data(data: Dictionary) -> Dictionary:
	var restored: Dictionary = {}
	var source: Variant = data.get("collected", {})
	if not source is Dictionary:
		return {"ok": false, "error": "invalid collection book"}
	for id: String in source:
		if not Discovery.COLLECTIBLES.has(id) or int(source[id]) < 1:
			return {"ok": false, "error": "unknown collection entry"}
		restored[id] = int(source[id])
	_collected = restored
	changed.emit()
	return {"ok": true, "error": ""}
