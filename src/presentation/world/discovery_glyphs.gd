class_name DiscoveryGlyphs
extends RefCounted

# The guide and the actual wall use the very same marks.
static func draw_mark(canvas: CanvasItem, kind: String, center: Vector2, scale_value: float = 1.0, alpha: float = 1.0) -> void:
	var colors := {"food": "b7d29b", "material": "e8c98a", "stone": "c4b3a5", "ore": "d59a6b", "collectible": "f4d88c"}
	var tint := Color(str(colors.get(kind, "e8c98a")), alpha)
	if kind == "collectible":
		canvas.draw_line(center + Vector2(0, -4) * scale_value, center + Vector2(0, 4) * scale_value, tint, 1.5 * scale_value)
		canvas.draw_line(center + Vector2(-4, 0) * scale_value, center + Vector2(4, 0) * scale_value, tint, 1.5 * scale_value)
		canvas.draw_circle(center, 1.5 * scale_value, tint)
	elif kind == "food":
		canvas.draw_line(center + Vector2(0, 3) * scale_value, center + Vector2(0, -1) * scale_value, tint, 1.5 * scale_value)
		canvas.draw_circle(center + Vector2(-2, -2) * scale_value, 2.0 * scale_value, tint)
		canvas.draw_circle(center + Vector2(2, -3) * scale_value, 2.0 * scale_value, tint)
	elif kind == "material":
		for x: int in [-3, 0, 3]:
			canvas.draw_line(center + Vector2(x, 3) * scale_value, center + Vector2(x + 1, -3) * scale_value, tint, 1.2 * scale_value)
	elif kind == "ore":
		var points := PackedVector2Array()
		for point: Vector2 in [Vector2(0, -4), Vector2(4, 0), Vector2(0, 4), Vector2(-4, 0), Vector2(0, -4)]:
			points.append(center + point * scale_value)
		canvas.draw_polyline(points, tint, 1.5 * scale_value)
	else:
		canvas.draw_arc(center, 3.5 * scale_value, 0.0, TAU, 6, tint, 1.5 * scale_value)
