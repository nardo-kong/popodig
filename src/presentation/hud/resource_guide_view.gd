extends PanelContainer

signal close_requested()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -365
	offset_right = 365
	offset_top = -310
	offset_bottom = 310
	z_index = 115
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.set_content_margin_all(20)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	visible = false
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var zh := Localization.current().begins_with("zh")
	var locale := Localization.current()
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	add_child(rows)
	var title := _label(rows, "認識物資與土壁線索" if zh else "Supplies, roots and clues", 23)
	title.name = "GuideTitle"
	_label(rows, "地上的物資已經能使用；土壁圖案只是線索，需要挖近才會找到東西。" if zh else "Supplies on the floor are usable. Marks in a wall are clues: dig closer to find what they hide.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 410
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_label(body, "物資與食物來源" if zh else "Resources and food sources", 18)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	body.add_child(grid)
	for id: String in ["FOOD", "GENERAL_MATERIAL", "STONE", "ORE", "METAL", "ROOT"]:
		var card := HBoxContainer.new()
		card.custom_minimum_size.x = 325
		grid.add_child(card)
		var image := TextureRect.new()
		image.texture = ResourceVisuals.texture(id)
		image.custom_minimum_size = Vector2(54, 54)
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card.add_child(image)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(words)
		_label(words, ResourceVisuals.title(id, locale), 17)
		_label(words, ("停留檢查食物；可採集的根系旁，按 4 劃覓食區。" if zh else "Hover to check for food; use 4 to mark forage ground beside edible roots.") if id == "ROOT" else ResourceVisuals.purpose(id, locale), 14)
	_label(body, "土壁上的線索（不是地上的物資）" if zh else "Marks in the wall (not supply piles)", 18)
	var clues := GridContainer.new()
	clues.columns = 2
	clues.add_theme_constant_override("h_separation", 16)
	body.add_child(clues)
	var names := [["food", "小芽 → 可能有食物", "Sprout → possible food"], ["material", "細纖維 → 可能有建材", "Fibres → possible materials"], ["stone", "灰色石紋 → 石材線索", "Grey stone → stone clue"], ["ore", "銅色微光 → 礦石線索", "Copper glint → ore clue"], ["collectible", "星光 → 收藏線索", "Glimmer → keepsake clue"]]
	for entry: Array in names:
		var row := HBoxContainer.new()
		row.custom_minimum_size.x = 325
		clues.add_child(row)
		var icon := ClueIcon.new()
		icon.kind = str(entry[0])
		row.add_child(icon)
		_label(row, str(entry[1 if zh else 2]), 14)
	_label(body, "把鼠標停在世界物件上，可查看名稱、用途與操作。" if zh else "Hold the pointer over an object to see its name, use and next action.", 14)
	var close := Button.new()
	close.text = "回到家園（I / Esc）" if zh else "Back to our home (I / Esc)"
	close.pressed.connect(func() -> void: close_requested.emit())
	rows.add_child(close)


func _label(parent: Node, text: String, font_size: int = 15) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
