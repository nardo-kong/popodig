class_name DevelopmentView
extends PanelContainer

const ZoneScript = preload("res://src/domain/zones/zone.gd")
const Capabilities = preload("res://src/domain/progression/colony_capabilities.gd")
const Resources = preload("res://src/domain/colony/resource_catalog.gd")
var colony
var _rows: VBoxContainer
var _signature := ""
var _elapsed := 0.0
var _feedback: Label
var _routes: Label
var _statuses: Dictionary = {}


func configure(simulation) -> void:
	colony = simulation
	position = Vector2(14, 105)
	custom_minimum_size.x = 280
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	margin.add_child(_rows)
	_rebuild()


func _process(delta: float) -> void:
	if colony == null:
		return
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var production = colony.get_production_system()
	var signature := str(colony.get_capabilities().level) + TranslationServer.get_locale()
	for zone in colony.get_zone_system().get_zones_by_type(ZoneScript.Type.PRODUCTION):
		var status: Dictionary = production.status(zone.zone_id)
		signature += "%d:%s:%s;" % [zone.zone_id, status.recipe, status.enabled]
	if signature != _signature:
		_signature = signature
		_rebuild()
	for zone_id: int in _statuses:
		var status: Dictionary = production.status(zone_id)
		_statuses[zone_id].text = _status_text(str(status.reason))
	var longest := 0
	for job in colony.get_job_system().get_jobs():
		var pile = colony.get_item_system().get_pile(job.source_pile_id)
		if pile == null:
			continue
		var path: Array[Vector2i] = colony.route_between(pile.cell, job.target_cell)
		longest = maxi(longest, path.size() - 1)
	_routes.text = _text("供應路線較遠，可試建近處倉儲", "Long supply route — try a nearer store") if longest > 24 else _text("就近倉儲讓鼠鼠多些時間工作", "Nearby stores leave more time for work")


func _rebuild() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_statuses.clear()
	_label(_text("一起建好地下家園", "Growing our home"))
	var capability = colony.get_capabilities()
	_label(_text("鼠群能力：", "Colony tools: ") + Capabilities.NAMES[capability.level])
	if capability.level < 2:
		var parts: PackedStringArray = []
		for item_id: String in Capabilities.COSTS[capability.level]:
			parts.append("%d %s" % [int(Capabilities.COSTS[capability.level][item_id]), Resources.display_name(item_id, TranslationServer.get_locale())])
		_button(_text("升級：", "Upgrade: ") + " + ".join(parts), func() -> void:
			var result: Dictionary = capability.upgrade()
			_feedback.text = _text("鼠群學會了新能力！", "The whole colony has new tools!") if result.ok else _text("還需要可運到家的材料", "More reachable materials are needed")
		)
	_label(_text("7 生產區 · 自主供料與加工", "7 Workshop · mice supply and craft"))
	var production = colony.get_production_system()
	var zones: Array = colony.get_zone_system().get_zones_by_type(ZoneScript.Type.PRODUCTION)
	for zone in zones:
		var zone_id: int = zone.zone_id
		var status: Dictionary = production.status(zone_id)
		_label(_text("工坊 ", "Workshop ") + str(zone_id))
		_statuses[zone_id] = _label(_status_text(str(status.reason)))
		var buttons := HBoxContainer.new()
		_rows.add_child(buttons)
		for recipe_id: String in ["building", "metal"]:
			var id := recipe_id
			var button := Button.new()
			button.text = _text("石材 → 建材", "Stone → materials") if id == "building" else _text("礦石 → 金屬", "Ore → metal")
			button.tooltip_text = _text("每批需 2 單位原料", "Each batch needs 2 raw units")
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


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	_rows.add_child(label)
	return label


func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	_rows.add_child(button)


func _status_text(reason: String) -> String:
	match reason:
		"WORKING": return _text("鼠鼠正在加工", "A mouse is crafting")
		"SETTING_UP": return _text("等待建材佈置工坊", "Waiting for setup materials")
		"PAUSED": return _text("已暫停供料", "Supply paused")
		"UNAVAILABLE": return _text("工坊不可用，請查看連通與積水", "Check access and water")
	return _text("等候原料或搬運中的鼠鼠", "Waiting for inputs or a carrier")


func _text(zh: String, en: String) -> String:
	return zh if TranslationServer.get_locale().begins_with("zh") else en
