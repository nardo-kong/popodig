extends Control

signal new_requested()
signal continue_requested(slot: String)
signal help_requested()
signal language_requested()
signal quit_requested()

var latest_slot := ""
var message := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 80
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var zh := TranslationServer.get_locale().begins_with("zh")
	var dim := ColorRect.new()
	dim.color = Color(0.055, 0.043, 0.032, 1.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 460
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.set_content_margin_all(28)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 14)
	panel.add_child(rows)
	var icon := TextureRect.new()
	icon.texture = preload("res://assets/app_icon.svg")
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rows.add_child(icon)
	var title := Label.new()
	title.text = "地下鼠鼠" if zh else "Dig Down"
	title.add_theme_font_size_override("font_size", 36)
	rows.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "一個小小洞穴，慢慢成為家。" if zh else "A little burrow. A place to call home."
	subtitle.add_theme_color_override("font_color", Color("d5b98d"))
	rows.add_child(subtitle)
	var description := Label.new()
	description.text = "跟著線索發現驚喜，帶領鼠群建好地下家園。" if zh else "Follow small clues. Find little treasures. Build a home together."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(description)
	var resume := _button(rows, "繼續上次的家園" if zh else "Continue our home", func() -> void: continue_requested.emit(latest_slot), not latest_slot.is_empty())
	resume.disabled = latest_slot.is_empty()
	_button(rows, "開始新的家園" if zh else "Start a new home", func() -> void: new_requested.emit(), latest_slot.is_empty())
	if not latest_slot.is_empty():
		var note := Label.new()
		note.text = "開始新家園前，舊的保存會先封存保留。" if zh else "Starting anew keeps an archived copy of your previous saves."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 13)
		rows.add_child(note)
	_button(rows, "怎樣開始？" if zh else "How do I begin?", func() -> void: help_requested.emit())
	_button(rows, "中文 / English", func() -> void: language_requested.emit())
	_button(rows, "離開" if zh else "Quit", func() -> void: quit_requested.emit())
	if not message.is_empty():
		var error := Label.new()
		error.text = message
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(error)


func _button(rows: VBoxContainer, text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("745935") if primary else Color("30291f")
		if state == "hover":
			style.bg_color = style.bg_color.lightened(0.15)
		elif state == "pressed":
			style.bg_color = style.bg_color.darkened(0.15)
		elif state == "disabled":
			style.bg_color = Color("25221d")
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("f0dfbf"))
	button.add_theme_color_override("font_disabled_color", Color("807665"))
	button.pressed.connect(action)
	rows.add_child(button)
	return button
