extends PanelContainer

signal speed_requested(value: int)
signal pause_requested()
signal home_requested()
signal focus_requested()

var _pause: Button
var _home: Button
var _focus: Button
var _speeds: Dictionary = {}


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -690
	offset_right = -290
	offset_top = 16
	offset_bottom = 53
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_pause = _button(row, "", func() -> void: pause_requested.emit())
	for value: int in [1, 2, 3]:
		var selected := value
		var button := _button(row, "%d×" % value, func() -> void: speed_requested.emit(selected))
		button.toggle_mode = true
		_speeds[value] = button
	_home = _button(row, "", func() -> void: home_requested.emit())
	_focus = _button(row, "", func() -> void: focus_requested.emit())
	refresh(false, 1)


func refresh(paused: bool, speed: int) -> void:
	if _pause == null:
		return
	var zh := TranslationServer.get_locale().begins_with("zh")
	_pause.text = ("繼續" if zh else "Resume") if paused else ("暫停" if zh else "Pause")
	_pause.tooltip_text = "Space"
	_home.text = "回家" if zh else "Home"
	_home.tooltip_text = "Home"
	_focus.text = "最近發現" if zh else "Latest find"
	_focus.tooltip_text = "N"
	for value: int in _speeds:
		_speeds[value].set_pressed_no_signal(value == speed)
		_speeds[value].tooltip_text = "Tab · " + ("危險出現時恢復 1×" if zh else "Returns to 1× when danger starts")


func _button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(action)
	row.add_child(button)
	return button
