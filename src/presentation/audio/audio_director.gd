class_name AudioDirector
extends Node

# Phase 11 audio pass (docs/art/13_AUDIO_VFX_SPEC.md): playback director over
# the synthesized production bank. Owns the SFX/Ambience buses, a small
# one-shot player pool, the ambient room-tone loop, and a water-drip layer
# that fades in near active water. Volumes come from config/app.json
# "audio"; per-slider UI controls are deferred to the settings menu pass.
#
# Headless/test safety: creating buses and players is harmless without an
# audio device; playback simply no-ops.

const STREAMS: Dictionary = {
	"dig_soil": preload("res://assets/audio/production/dig_soil_01.wav"),
	"dig_clay": preload("res://assets/audio/production/dig_clay_01.wav"),
	"dig_loose": preload("res://assets/audio/production/dig_loose_01.wav"),
	"dig_stone": preload("res://assets/audio/production/dig_stone_01.wav"),
	"dig_root": preload("res://assets/audio/production/dig_root_01.wav"),
	"ui_paint": preload("res://assets/audio/production/ui_paint.wav"),
	"ui_cancel": preload("res://assets/audio/production/ui_cancel.wav"),
	"ui_tool": preload("res://assets/audio/production/ui_tool.wav"),
	"zone_assign": preload("res://assets/audio/production/zone_assign.wav"),
	"stinger": preload("res://assets/audio/production/stinger_discovery.wav"),
	"breach": preload("res://assets/audio/production/cue_breach.wav"),
	"collapse": preload("res://assets/audio/production/cue_collapse.wav"),
	"critical": preload("res://assets/audio/production/cue_critical.wav"),
	"drip_1": preload("res://assets/audio/production/drip_01.wav"),
	"drip_2": preload("res://assets/audio/production/drip_02.wav"),
	"drip_3": preload("res://assets/audio/production/drip_03.wav"),
}

const AMBIENCE_STREAM: AudioStream = preload("res://assets/audio/production/amb_underground.wav")
const MUSIC_STREAM: AudioStream = preload("res://assets/audio/production/music_settle.wav")
# Loop points live in the .import params (edit/loop_mode=1 forward), so no
# runtime stream mutation is needed here.
const SFX_POOL_SIZE := 6
# CellData.TerrainMaterial -> dig impact stream key.
const MATERIAL_DIG_KEYS: Dictionary = {
	1: "dig_soil",
	2: "dig_clay",
	3: "dig_loose",
	4: "dig_stone",
	5: "dig_stone",
	6: "dig_root",
}

static var audio_enabled := true
static var _sfx_bus_index := -1
static var _ambience_bus_index := -1
static var _music_bus_index := -1

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _ambience_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _drip_timer := 0.0
var _water_proximity := false
var _muted := false


func _ready() -> void:
	_ensure_buses()
	_muted = not audio_enabled or DisplayServer.get_name() == "headless"
	for index: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(_sfx_bus_index)
		add_child(player)
		_sfx_pool.append(player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = AudioServer.get_bus_name(_ambience_bus_index)
	_ambience_player.stream = AMBIENCE_STREAM
	add_child(_ambience_player)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = AudioServer.get_bus_name(_ensure_music_bus())
	_music_player.stream = MUSIC_STREAM
	add_child(_music_player)
	if not _muted:
		_ambience_player.play()
		_music_player.play()


func apply_volumes(config: Dictionary) -> void:
	_set_bus_volume("Master", float(config.get("master_volume", 0.8)))
	_set_bus_volume(AudioServer.get_bus_name(_sfx_bus_index), float(config.get("sfx_volume", 0.9)))
	_set_bus_volume(AudioServer.get_bus_name(_ambience_bus_index), float(config.get("ambience_volume", 0.7)))
	_set_bus_volume(AudioServer.get_bus_name(_music_bus_index), float(config.get("music_volume", 0.5)))


static func _ensure_music_bus() -> int:
	_music_bus_index = AudioServer.get_bus_index("Music")
	if _music_bus_index < 0:
		_music_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_music_bus_index)
		AudioServer.set_bus_name(_music_bus_index, "Music")
		AudioServer.set_bus_send(_music_bus_index, "Master")
	return _music_bus_index


func _ensure_buses() -> void:
	_sfx_bus_index = AudioServer.get_bus_index("SFX")
	if _sfx_bus_index < 0:
		_sfx_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_sfx_bus_index)
		AudioServer.set_bus_name(_sfx_bus_index, "SFX")
		AudioServer.set_bus_send(_sfx_bus_index, "Master")
	_ambience_bus_index = AudioServer.get_bus_index("Ambience")
	if _ambience_bus_index < 0:
		_ambience_bus_index = AudioServer.bus_count
		AudioServer.add_bus(_ambience_bus_index)
		AudioServer.set_bus_name(_ambience_bus_index, "Ambience")
		AudioServer.set_bus_send(_ambience_bus_index, "Master")
	_ensure_music_bus()


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var bus := AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	var clamped := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(clamped, 0.0001)))
	AudioServer.set_bus_mute(bus, clamped <= 0.001)


func _play(stream_key: String, volume_db: float = 0.0) -> void:
	if _muted:
		return
	var stream: AudioStream = STREAMS.get(stream_key)
	if stream == null:
		return
	var player := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


## Material-specific dig impact for a completed excavation.
func play_material_dig(material: int) -> void:
	_play(String(MATERIAL_DIG_KEYS.get(material, "dig_soil")), -4.0)


func play_paint() -> void:
	_play("ui_paint", -8.0)


func play_cancel() -> void:
	_play("ui_cancel", -10.0)


func play_tool_select() -> void:
	_play("ui_tool", -10.0)


func play_zone_assign() -> void:
	_play("zone_assign", -6.0)


## Restrained discovery stinger for first reveal of a major feature.
func play_discovery_stinger() -> void:
	_play("stinger", -3.0)


func play_breach() -> void:
	_play("breach", 0.0)


func play_collapse() -> void:
	_play("collapse", 0.0)


func play_critical() -> void:
	_play("critical", -2.0)


## Water proximity drives the occasional drip layer near active water.
func set_water_proximity(near_water: bool) -> void:
	_water_proximity = near_water


func _process(delta: float) -> void:
	if _muted or not _water_proximity:
		return
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(1.6, 4.2)
		_play("drip_%d" % (randi() % 3 + 1), -6.0)


func _exit_tree() -> void:
	# Release looping playback before the audio server shuts down.
	for player: AudioStreamPlayer in _sfx_pool:
		player.stop()
		player.stream = null
	if is_instance_valid(_ambience_player):
		_ambience_player.stop()
		_ambience_player.stream = null
	if is_instance_valid(_music_player):
		_music_player.stop()
		_music_player.stream = null
