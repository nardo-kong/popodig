class_name ColonyItemsView
extends Node2D

var item_system
var cell_size := 16
var _refresh_accumulator := 0.0
var _last_signature := ""


func configure(system, logical_cell_size: int) -> void:
	item_system = system
	cell_size = logical_cell_size
	_last_signature = ""
	_refresh_signature()


func _process(delta: float) -> void:
	if item_system == null:
		visible = false
		return
	visible = true
	_refresh_accumulator += delta
	if _refresh_accumulator < 0.1:
		return
	_refresh_accumulator = 0.0
	_refresh_signature()


func _draw() -> void:
	if item_system == null:
		return
	for pile in item_system.get_piles():
		if int(pile.count) <= 0:
			continue
		_draw_pile(pile)


func _draw_pile(pile) -> void:
	var center := (Vector2(pile.cell) + Vector2(0.5, 0.5)) * cell_size
	var is_food := String(pile.item_type) == "FOOD"
	var primary := Color("d76d52") if is_food else Color("d1b26f")
	if pile.item_type == "STONE":
		primary = Color("aaa49d")
	elif pile.item_type == "ORE":
		primary = Color("c18b66")
	elif pile.item_type == "METAL":
		primary = Color("c4d0d2")
	var outline := Color("4a352b")
	var visible_count: int = mini(3, int(pile.count))
	for index: int in range(visible_count):
		var offset := Vector2((index - 1) * 4.0, -1.0 - (index % 2) * 3.0)
		if is_food:
			draw_circle(center + offset, 2.8, outline)
			draw_circle(center + offset, 2.0, primary)
		else:
			var rect := Rect2(center + offset - Vector2(2.5, 2.0), Vector2(5.0, 4.0))
			draw_rect(rect, primary, true)
			draw_rect(rect, outline, false, 1.0)


func _refresh_signature() -> void:
	var parts: PackedStringArray = []
	for pile in item_system.get_piles():
		parts.append("%s:%s:%s:%s" % [pile.pile_id, pile.item_type, pile.cell, pile.count])
	var signature := "|".join(parts)
	if signature == _last_signature:
		return
	_last_signature = signature
	queue_redraw()
