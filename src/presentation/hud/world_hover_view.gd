extends PanelContainer

var _title: Label
var _body: Label
var _action: Label
var _icon: TextureRect
var _glyph: ClueIcon
var _signature := ""
var _hover_cell := Vector2i(-1, -1)
var _elapsed := 0.0
var _info: Dictionary = {}


func _ready() -> void:
	z_index = 180
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.border_color = Color("bfa476")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 7)
	add_child(rows)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(heading)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(38, 38)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(_icon)
	_glyph = ClueIcon.new()
	heading.add_child(_glyph)
	_title = _label(heading, 17)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_body = _label(rows, 14)
	_action = _label(rows, 14)
	_action.add_theme_color_override("font_color", Color("e1c993"))
	visible = false


func update_hover(info: Dictionary, cell: Vector2i, pointer: Vector2, delta: float, allowed: bool) -> void:
	if not allowed or info.is_empty():
		visible = false
		_elapsed = 0.0
		_hover_cell = Vector2i(-1, -1)
		return
	if cell != _hover_cell:
		_hover_cell = cell
		_elapsed = 0.0
	_elapsed += delta
	var signature := JSON.stringify(info)
	if signature != _signature:
		_signature = signature
		_info = info
		_title.text = str(info.title)
		_body.text = str(info.body)
		_action.text = str(info.action)
		_icon.texture = ResourceVisuals.texture(str(info.get("icon", "")))
		_icon.visible = _icon.texture != null
		_glyph.visible = info.has("glyph")
		if _glyph.visible:
			_glyph.kind = str(info.glyph)
			_glyph.queue_redraw()
		reset_size()
	visible = _elapsed >= 0.18
	var viewport := get_viewport_rect().size
	var target := pointer + Vector2(22, 22)
	if target.x + size.x > viewport.x - 12:
		target.x = pointer.x - size.x - 18
	if target.y + size.y > viewport.y - 156:
		target.y = pointer.y - size.y - 18
	position = Vector2(clampf(target.x, 12, maxf(12, viewport.x - size.x - 12)), clampf(target.y, 12, maxf(12, viewport.y - size.y - 12)))


func _label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 240
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
