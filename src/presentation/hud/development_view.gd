class_name DevelopmentView
extends PanelContainer

signal collection_requested()
signal guide_requested()
signal focus_requested(cell: Vector2i)

const ZoneScript = preload("res://src/domain/zones/zone.gd")
const Capabilities = preload("res://src/domain/progression/colony_capabilities.gd")
const Resources = preload("res://src/domain/colony/resource_catalog.gd")
var colony
var home
var _rows: VBoxContainer
var _signature := ""
var _elapsed := 0.0
var _feedback: Label
var _routes: Label
var _statuses: Dictionary = {}
var _progress_bars: Dictionary = {}
var _focus_buttons: Dictionary = {}
var _scroll: ScrollContainer
var _upgrade: Button
var _upgrade_hint: Label
var _show_workshops := false
var roots_known := false


func configure(simulation, progress = null) -> void:
	colony = simulation
	home = progress
	position = Vector2(14, 105)
	custom_minimum_size.x = 300
	var style := StyleBoxFlat.new()
	style.bg_color = Color("211c18")
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(280, mini(340, get_viewport_rect().size.y - 340))
	margin.add_child(_scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows)
	_rebuild()
	_signature = _content_signature()


func _process(delta: float) -> void:
	if colony == null:
		return
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var production = colony.get_production_system()
	var signature := _content_signature()
	if signature != _signature:
		_signature = signature
		_rebuild()
	for zone_id: int in _statuses:
		var status: Dictionary = production.status(zone_id)
		_statuses[zone_id].text = _status_text(status)
		_progress_bars[zone_id].value = float(status.fraction) * 100.0
		_progress_bars[zone_id].visible = float(status.fraction) > 0.0
	_refresh_upgrade()
	var longest := 0
	for job in colony.get_job_system().get_jobs():
		var pile = colony.get_item_system().get_pile(job.source_pile_id)
		if pile == null:
			continue
		var path: Array[Vector2i] = colony.route_between(pile.cell, job.target_cell)
		longest = maxi(longest, path.size() - 1)
	_routes.visible = _show_workshops
	_routes.text = _text("供應路線較遠，可試建近處倉儲", "Long supply route — try a nearer store") if longest > 24 else _text("就近倉儲讓鼠鼠多些時間工作", "Nearby stores leave more time for work")


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_statuses.clear()
	_progress_bars.clear()
	_focus_buttons.clear()
	_upgrade = null
	_upgrade_hint = null
	_label(_text("一起建好地下家園", "Growing our home"))
	var capability = colony.get_capabilities()
	_show_workshops = _crafting_visible()
	if _show_workshops:
		_label(_text("鼠群能力：", "Colony tools: ") + (["基礎", "加固", "深掘"][capability.level] if TranslationServer.get_locale().begins_with("zh") else Capabilities.NAMES[capability.level]))
		if capability.level < 2:
			_label(_text("新本領需要：", "Tools need: ") + _cost_text(Capabilities.COSTS[capability.level]))
			_upgrade = _button(_text("升級鼠群工具", "Upgrade colony tools"), func() -> void:
				var result: Dictionary = capability.upgrade()
				_feedback.text = _text("鼠群學會了新能力！", "The whole colony has new tools!") if result.ok else _text("還需要可運到家的材料", "More reachable materials are needed")
			)
			_upgrade_hint = _label("")
	else:
		_primer_row("FOOD", _text("食物｜鼠鼠會自己取食", "Food · mice take it when hungry"))
		_primer_row("GENERAL_MATERIAL", _text("建材｜用於佈置與建造", "Building material · sets up our home"))
		_label(_text("土壁的小芽、細纖維只是線索；選 1，左鍵拖曳挖近看看。", "Sprouts and fibres in a wall are clues. Select 1 and drag soil to dig closer."))
	if roots_known:
		_primer_row("ROOT", _text("樹根｜停留檢查可否採食物（4）", "Roots · hover to check for food (4)"))
	_button(_text("I 看懂物資與線索", "I Learn the icons and clues"), func() -> void: guide_requested.emit())
	if home != null and not home.unlocked.is_empty():
		_label(_text("家園回憶 ", "Home memories ") + "%d / 6" % home.unlocked.size())
	if colony.get_collection_book().unique_count() > 0 or capability.level > 0:
		_button(_text("C 收藏圖鑑", "C Collection book"), func() -> void: collection_requested.emit())
	if _show_workshops:
		_label(_text("7 生產區 · 自主供料與加工", "7 Workshop · mice supply and craft"))
	var production = colony.get_production_system()
	var zones: Array = colony.get_zone_system().get_zones_by_type(ZoneScript.Type.PRODUCTION)
	for zone in zones:
		var zone_id: int = zone.zone_id
		var status: Dictionary = production.status(zone_id)
		var anchor: Vector2i = zone.identity_anchor
		_focus_buttons[zone_id] = _button(_text("前往工坊 ", "Find workshop ") + str(zone_id), func() -> void: focus_requested.emit(anchor))
		_statuses[zone_id] = _label(_status_text(status))
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 8
		bar.show_percentage = false
		bar.value = float(status.fraction) * 100.0
		bar.visible = float(status.fraction) > 0.0
		_rows.add_child(bar)
		_progress_bars[zone_id] = bar
		var buttons := HBoxContainer.new()
		_rows.add_child(buttons)
		for recipe_id: String in ["building", "metal"]:
			var id := recipe_id
			var button := Button.new()
			button.text = _text("石材 → 建材", "Stone → materials") if id == "building" else _text("礦石 → 金屬", "Ore → metal")
			var recipe: Dictionary = production.RECIPES[id]
			button.tooltip_text = "%d %s → %d %s · %ds" % [int(recipe.count), Resources.display_name(str(recipe.input), TranslationServer.get_locale()), int(recipe.yield), Resources.display_name(str(recipe.output), TranslationServer.get_locale()), int(recipe.seconds)]
			button.pressed.connect(func() -> void:
				var result: Dictionary = production.set_recipe(zone_id, id)
				_feedback.text = _text("已選擇配方", "Recipe selected") if result.ok else _text("鼠鼠正加工，完成後再切換", "A mouse is crafting — switch after this batch")
			)
			buttons.add_child(button)
		_button(_text("繼續", "Resume") if not bool(status.enabled) else _text("暫停供料", "Pause supply"), func() -> void:
			production.set_enabled(zone_id, not bool(production.status(zone_id).enabled))
		)
	_feedback = _label("")
	_routes = _label(_text("就近倉儲讓鼠鼠多些時間工作", "Nearby stores leave more time for work"))
	_routes.visible = _show_workshops
	_refresh_upgrade()
	_resize_panel.call_deferred()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	_rows.add_child(label)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_rows.add_child(button)
	return button


func _status_text(status: Dictionary) -> String:
	match str(status.reason):
		"WORKING": return _text("加工進度 ", "Crafting ") + "%d%%" % int(float(status.fraction) * 100)
		"SUPPLYING": return _text("鼠鼠正把原料運到工坊", "A mouse is bringing the inputs")
		"WAITING_WORKER": return _text("原料已預備，等鼠鼠有空", "Inputs ready; waiting for a free mouse")
		"OUTPUT_BLOCKED": return _text("產物放不下了，請在旁邊增設倉儲", "Output is full; add a store nearby")
		"INPUT_UNREACHABLE": return _text("原料通路未接通，請檢查路線", "Inputs cannot reach here; check the route")
		"CONSOLIDATE_INPUT": return _text("把散落原料集中到附近倉儲", "Gather loose inputs in a nearby store")
		"SETTING_UP": return _text("等待建材佈置工坊", "Waiting for setup materials")
		"PAUSED": return _text("已暫停供料", "Supply paused")
		"UNAVAILABLE": return _text("工坊不可用，請查看連通與積水", "Check access and water")
	return _text("還需要 ", "Still need ") + "%d %s" % [int(status.missing), Resources.display_name(str(status.input), TranslationServer.get_locale())]


func _crafting_visible() -> bool:
	var items = colony.get_item_system()
	return colony.get_capabilities().level > 0 or colony.get_production_system().completed_batches > 0 or items.get_total_count("STONE") > 0 or items.get_total_count("ORE") > 0 or not colony.get_zone_system().get_zones_by_type(ZoneScript.Type.PRODUCTION).is_empty()


func _content_signature() -> String:
	var value := str(roots_known) + str(colony.get_capabilities().level) + TranslationServer.get_locale() + str(_crafting_visible()) + str(colony.get_collection_book().unique_count() > 0)
	if home != null:
		value += str(home.unlocked.size())
	for zone in colony.get_zone_system().get_zones_by_type(ZoneScript.Type.PRODUCTION):
		var status: Dictionary = colony.get_production_system().status(zone.zone_id)
		value += "%d:%s:%s;" % [zone.zone_id, status.recipe, status.enabled]
	return value


func _cost_text(costs: Dictionary) -> String:
	var parts: PackedStringArray = []
	for item: String in costs:
		parts.append("%d %s" % [int(costs[item]), Resources.display_name(item, TranslationServer.get_locale())])
	return " + ".join(parts)


func _resize_panel() -> void:
	_scroll.custom_minimum_size.y = clampf(_rows.get_combined_minimum_size().y, 70.0, maxf(100.0, minf(340.0, get_viewport_rect().size.y - 340.0)))


func _text(zh: String, en: String) -> String:
	return zh if TranslationServer.get_locale().begins_with("zh") else en


func _refresh_upgrade() -> void:
	if is_instance_valid(_upgrade):
		var requirements: Dictionary = colony.get_capabilities().requirements()
		_upgrade.disabled = not bool(requirements.ready)
		_upgrade_hint.text = _text("材料已備好，鼠群可以學新本領！", "Ready for the whole colony to learn new tools!") if requirements.ready else _text("還需要：", "Still need: ") + _cost_text(requirements.missing)


func _primer_row(id: String, text: String) -> void:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var image := TextureRect.new()
	image.texture = ResourceVisuals.texture(id)
	image.custom_minimum_size = Vector2(32, 32)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.add_theme_font_size_override("font_size", 14)
	row.add_child(label)
