class_name DesignateDigCommand
extends RefCounted

var _dig_system
var _cells: Array[Vector2i] = []


func _init(dig_system = null, cells: Array = []) -> void:
	_dig_system = dig_system
	for value: Variant in cells:
		if value is Vector2i:
			_cells.append(value)


func execute() -> Dictionary:
	if _dig_system == null:
		return {
			"ok": false,
			"reason_code": "SERVICE_UNAVAILABLE",
			"accepted_cells": [],
			"rejected": [],
			"cancelled_cells": [],
			"removed_downstream": [],
		}
	return _dig_system.designate_path(_cells)
