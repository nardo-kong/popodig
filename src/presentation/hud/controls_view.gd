extends PanelContainer

signal close_requested()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -300
	offset_right = 300
	offset_top = -225
	offset_bottom = 225
	z_index = 110
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.set_content_margin_all(20)
	add_theme_stylebox_override("panel", style)
	visible = false
	refresh()


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var zh := TranslationServer.get_locale().begins_with("zh")
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	add_child(rows)
	var title := Label.new()
	title.text = "把小洞穴變成地下家園" if zh else "Make a little burrow into a home"
	title.add_theme_font_size_override("font_size", 21)
	rows.add_child(title)
	var body := Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.text = ("追尋土壁線索 → 挖掘發現 → 搬運加工 → 升級鼠群 → 深入建家。\n\n左鍵拖曳：指定；右鍵：清除。鼠鼠會自己執行。\n1 挖掘 · 2 睡眠 · 3 倉儲 · 4 覓食 · 5 封堵 · 6 加固 · 7 工坊\n\n小芽提示食物，細纖維提示建材；灰色石紋和銅光提示原料，星光提示珍藏。線索只透露附近的機會。\n\n空格：暫停 · Tab：1× / 2× / 3× · 滾輪：縮放 · WASD／方向鍵／中鍵拖曳：移動\nHome：回家 · N：最近發現 · C：收藏 · L：語言\nCtrl/Cmd+S：快速保存 · F9：讀檔 · Esc：設定\n\n倉儲靠近工作前沿能減少往返；寬洞穴和潮濕地帶要留意風險。" if zh else "Follow clues → dig up discoveries → haul and craft → improve colony tools → build deeper.\n\nDrag left mouse to assign; right mouse to erase. Mice do the work.\n1 Dig · 2 Sleep · 3 Store · 4 Forage · 5 Seal · 6 Reinforce · 7 Workshop\n\nSprouts suggest food, fibres suggest building materials; grey stone and copper glints suggest raw materials, stars suggest keepsakes. Clues only show nearby opportunities.\n\nSpace: pause · Tab: 1× / 2× / 3× · Wheel: zoom · WASD/arrows/middle drag: pan\nHome: home · N: latest find · C: collection · L: language\nCtrl/Cmd+S: quick save · F9: load · Esc: settings\n\nStores near work reduce travel. Watch for danger in wide or damp passages.")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 280
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	scroll.add_child(body)
	var button := Button.new()
	button.text = "繼續探索（H / Esc）" if zh else "Keep exploring (H / Esc)"
	button.pressed.connect(func() -> void: close_requested.emit())
	rows.add_child(button)
