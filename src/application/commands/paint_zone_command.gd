class_name PaintZoneCommand
extends RefCounted

var _zone_system
var _zone_type := -1
var _cells: Array[Vector2i] = []


func _init(zone_system = null, zone_type: int = -1, cells: Array = []) -> void:
	_zone_system = zone_system
	_zone_type = zone_type
	for value: Variant in cells:
		if value is Vector2i:
			_cells.append(value)


func execute() -> Dictionary:
	if _zone_system == null:
		return {"ok": false, "reason_code": "SERVICE_UNAVAILABLE", "changed_cells": [], "rejected": []}
	return _zone_system.paint_zone(_zone_type, _cells)
