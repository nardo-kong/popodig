class_name CollectionView
extends PanelContainer

signal close_requested()
var book
var _rows: VBoxContainer


func configure(collection_book) -> void:
	book = collection_book
	z_index = 100
	var background := StyleBoxFlat.new()
	background.bg_color = Color("211c18")
	background.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", background)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	offset_left = -290
	offset_right = 290
	offset_top = -225
	offset_bottom = 225
	custom_minimum_size = Vector2(580, 450)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	_rows = VBoxContainer.new()
	margin.add_child(_rows)
	book.changed.connect(refresh)
	visible = false
	refresh()


func refresh() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	var zh := TranslationServer.get_locale().begins_with("zh")
	var header := HBoxContainer.new()
	_rows.add_child(header)
	var title := Label.new()
	title.text = ("地下小珍藏" if zh else "Treasures of our burrow") + "  %d / 18" % book.unique_count()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "關閉 (C / Esc)" if zh else "Close (C / Esc)"
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	var intro := Label.new()
	intro.text = "有些東西只要找到，就足以讓鼠鼠開心。" if zh else "Some finds simply make the mice happy."
	_rows.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 360
	_rows.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 7)
	scroll.add_child(list)
	for entry: Dictionary in book.entries():
		var row := Label.new()
		if int(entry.count) > 0:
			row.text = str(entry.get("zh" if zh else "en", entry.id)) + "  ×%d" % int(entry.count)
		else:
			row.text = "??? — " + str(entry.get("hint_zh" if zh else "hint_en", ""))
		row.add_theme_font_size_override("font_size", 15)
		list.add_child(row)
