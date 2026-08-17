class_name ItemPile
extends RefCounted

var pile_id := 0
var item_type := ""
var cell := Vector2i(-1, -1)
var count := 0
var reserved_count := 0


func _init(id: int = 0, type: String = "", pile_cell: Vector2i = Vector2i(-1, -1), amount: int = 0) -> void:
	pile_id = id
	item_type = type
	cell = pile_cell
	count = maxi(0, amount)


func available_count() -> int:
	return maxi(0, count - reserved_count)


func snapshot():
	var copy := ItemPile.new(pile_id, item_type, cell, count)
	copy.reserved_count = reserved_count
	return copy
