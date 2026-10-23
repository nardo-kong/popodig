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
	var id := String(pile.item_type)
	var icon := ResourceVisuals.texture(id)
	if icon != null:
		draw_texture_rect(icon, ResourceVisuals.fitted_rect(id, center, 18.0), false)



func _refresh_signature() -> void:
	var parts: PackedStringArray = []
	for pile in item_system.get_piles():
		parts.append("%s:%s:%s:%s" % [pile.pile_id, pile.item_type, pile.cell, pile.count])
	var signature := "|".join(parts)
	if signature == _last_signature:
		return
	_last_signature = signature
	queue_redraw()
