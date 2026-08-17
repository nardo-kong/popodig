class_name EraseZoneCommand
extends RefCounted

var _zone_system
var _cells: Array[Vector2i] = []


func _init(zone_system = null, cells: Array = []) -> void:
	_zone_system = zone_system
	for value: Variant in cells:
		if value is Vector2i:
			_cells.append(value)


func execute() -> Dictionary:
	if _zone_system == null:
		return {"ok": false, "reason_code": "SERVICE_UNAVAILABLE", "changed_cells": [], "rejected": []}
	return _zone_system.erase_cells(_cells)
