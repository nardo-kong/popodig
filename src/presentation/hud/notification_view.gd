class_name NotificationView
extends VBoxContainer

# Renders the NotificationModel's active entries as small toast rows.
# Positioned top-center below the HUD; mouse-transparent so the world keeps
# full input priority.

const ROW_STYLE := Color(0.086, 0.07, 0.055, 0.88)
const TEXT_COLOR := Color(0.93, 0.88, 0.78)

var _model: NotificationModel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)


func bind(model: NotificationModel) -> void:
	_model = model


func refresh(now: float) -> void:
	if _model == null:
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for entry: Dictionary in _model.active(now):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = ROW_STYLE
		style.set_corner_radius_all(4)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		panel.add_theme_stylebox_override("panel", style)
		var label := Label.new()
		label.text = String(entry.text)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_color", TEXT_COLOR)
		panel.add_child(label)
		add_child(panel)
