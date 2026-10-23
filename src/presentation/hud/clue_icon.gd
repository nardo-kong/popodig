class_name ClueIcon
extends Control

var kind := "food"


func _ready() -> void:
	custom_minimum_size = Vector2(32, 32)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	DiscoveryGlyphs.draw_mark(self, kind, size * 0.5, 2.2)
