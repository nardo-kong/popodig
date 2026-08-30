class_name SettingsView
extends Control

# Phase 12 settings overlay (player-facing; works in release). Contains the
# deferred quick-load entry with explicit confirmation (user decision from the
# Phase 10 acceptance), the spec §10 accessibility volume controls, language
# toggle, and reduced-particles/shake flags. Options persist through
# SettingsStore. The game pauses while the overlay is open (game_app owns
# the pause flag); Esc or Resume closes.

signal resume_requested
signal quick_load_confirmed
signal settings_changed(audio_accessibility: Dictionary)

var store: SettingsStore

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _load_button: Button
var _confirm_box: VBoxContainer
var _confirm_label: Label
var _language_button: Button
var _volume_sliders: Dictionary = {}
var _volume_rows: Dictionary = {}
var _particles_check: CheckBox
var _shake_check: CheckBox
var _resume_button: Button


func _ready() -> void:
	store = SettingsStore.new()
	store.load_settings()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	refresh_localization()


func open() -> void:
	store.load_settings()
	_sync_controls_from_store()
	_confirm_box.visible = false
	_load_button.visible = true
	visible = true
	refresh_localization()


func close() -> void:
	visible = false


func is_open() -> bool:
	return visible


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(380.0, 0.0)
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for margin_side: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(margin_side, 18)
	_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)

	_title = Label.new()
	rows.add_child(_title)

	_load_button = Button.new()
	_load_button.pressed.connect(_show_confirm)
	rows.add_child(_load_button)

	_confirm_box = VBoxContainer.new()
	_confirm_box.visible = false
	rows.add_child(_confirm_box)
	_confirm_label = Label.new()
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_box.add_child(_confirm_label)
	var confirm_row := HBoxContainer.new()
	confirm_row.name = "ConfirmRow"
	_confirm_box.add_child(confirm_row)
	var confirm_yes := Button.new()
	confirm_yes.name = "ConfirmYes"
	confirm_yes.pressed.connect(func() -> void:
		_confirm_box.visible = false
		_load_button.visible = false
		quick_load_confirmed.emit()
	)
	confirm_row.add_child(confirm_yes)
	var confirm_no := Button.new()
	confirm_no.name = "ConfirmNo"
	confirm_no.pressed.connect(func() -> void: _confirm_box.visible = false)
	confirm_row.add_child(confirm_no)

	_language_button = Button.new()
	_language_button.pressed.connect(_on_language_pressed)
	rows.add_child(_language_button)

	for key: String in ["master", "sfx", "ambience", "music"]:
		var label := Label.new()
		rows.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value_changed.connect(_on_volume_changed.bind(key))
		rows.add_child(slider)
		_volume_sliders[key] = slider
		_volume_rows[key] = label

	_particles_check = CheckBox.new()
	_particles_check.toggled.connect(_on_particles_toggled)
	rows.add_child(_particles_check)
	_shake_check = CheckBox.new()
	_shake_check.toggled.connect(_on_shake_toggled)
	rows.add_child(_shake_check)
	rows.add_child(HSeparator.new())

	_resume_button = Button.new()
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	rows.add_child(_resume_button)


func _sync_controls_from_store() -> void:
	(_volume_sliders["master"] as HSlider).value = float(store.get_value("audio/master_volume"))
	(_volume_sliders["sfx"] as HSlider).value = float(store.get_value("audio/sfx_volume"))
	(_volume_sliders["ambience"] as HSlider).value = float(store.get_value("audio/ambience_volume"))
	(_volume_sliders["music"] as HSlider).value = float(store.get_value("audio/music_volume"))
	_particles_check.button_pressed = bool(store.get_value("accessibility/reduced_particles"))
	_shake_check.button_pressed = bool(store.get_value("accessibility/reduced_shake"))


func _on_volume_changed(value: float, key: String) -> void:
	store.set_value("audio/%s_volume" % key, value)
	_store_and_notify()


func _on_particles_toggled(pressed: bool) -> void:
	store.set_value("accessibility/reduced_particles", pressed)
	_store_and_notify()


func _on_shake_toggled(pressed: bool) -> void:
	store.set_value("accessibility/reduced_shake", pressed)
	_store_and_notify()


func _store_and_notify() -> void:
	store.save_settings()
	settings_changed.emit(store.as_audio_accessibility())


func _on_language_pressed() -> void:
	Localization.cycle()
	refresh_localization()


func _show_confirm() -> void:
	_confirm_box.visible = true


func refresh_localization() -> void:
	_title.text = Localization.text("settings.title")
	_load_button.text = Localization.text("settings.quick_load")
	_confirm_label.text = Localization.text("settings.quick_load_confirm")
	var confirm_yes := _confirm_box.get_node("ConfirmRow/ConfirmYes") as Button
	var confirm_no := _confirm_box.get_node("ConfirmRow/ConfirmNo") as Button
	confirm_yes.text = Localization.text("settings.confirm")
	confirm_no.text = Localization.text("settings.cancel")
	_language_button.text = Localization.text("settings.language") % Localization.current().to_upper()
	(_volume_rows["master"] as Label).text = Localization.text("settings.master_volume")
	(_volume_rows["sfx"] as Label).text = Localization.text("settings.sfx_volume")
	(_volume_rows["ambience"] as Label).text = Localization.text("settings.ambience_volume")
	(_volume_rows["music"] as Label).text = Localization.text("settings.music_volume")
	_particles_check.text = Localization.text("settings.reduced_particles")
	_shake_check.text = Localization.text("settings.reduced_shake")
	_resume_button.text = Localization.text("settings.resume")
