class_name GeneratedFeature
extends RefCounted

var id := -1
var type_id := ""
var role := "feature"
var anchor := Vector2i.ZERO
var cells: Array[Vector2i] = []
var required := false
var hidden := true
var metadata: Dictionary = {}


func _init(
	feature_type: String = "",
	feature_anchor: Vector2i = Vector2i.ZERO,
	feature_cells: Array[Vector2i] = [],
	feature_required: bool = false,
	feature_role: String = "feature"
) -> void:
	type_id = feature_type
	anchor = feature_anchor
	cells = feature_cells.duplicate()
	required = feature_required
	role = feature_role


func contains(cell: Vector2i) -> bool:
	return cells.has(cell)


func get_bounds() -> Rect2i:
	if cells.is_empty():
		return Rect2i(anchor, Vector2i.ONE)
	var minimum := cells[0]
	var maximum := cells[0]
	for cell: Vector2i in cells:
		minimum.x = mini(minimum.x, cell.x)
		minimum.y = mini(minimum.y, cell.y)
		maximum.x = maxi(maximum.x, cell.x)
		maximum.y = maxi(maximum.y, cell.y)
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func get_approach_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var source: Variant = metadata.get("approach_cells", [])
	if source is Array:
		for value: Variant in source:
			if value is Vector2i and not result.has(value):
				result.append(value)
	if result.is_empty():
		result.append(anchor)
	return result


func stable_summary() -> Dictionary:
	var sorted_cells := cells.duplicate()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x)
	)
	return {
		"id": id,
		"type_id": type_id,
		"role": role,
		"anchor": [anchor.x, anchor.y],
		"required": required,
		"hidden": hidden,
		"cells": sorted_cells.map(func(cell: Vector2i) -> Array[int]: return [cell.x, cell.y]),
	}
