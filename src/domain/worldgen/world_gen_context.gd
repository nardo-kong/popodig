class_name WorldGenContext
extends RefCounted

const DeterministicRngScript = preload("res://src/domain/common/deterministic_rng.gd")
const FeatureRegistryScript = preload("res://src/domain/worldgen/feature_registry.gd")

var config: Dictionary
var seed_value: int
var attempt: int
var width := 0
var height := 0
var chunk_size := 16
var world
var surface_heights := PackedInt32Array()
var stratum_boundaries: Dictionary = {}
var depth_targets: Dictionary = {}
var feature_registry: FeatureRegistry
var decision_knots: Array[Vector2i] = []
var signal_emitters: Array[Dictionary] = []
var stage_timings_ms: Dictionary = {}
var stage_notes: Dictionary = {}
var stage_trace := PackedStringArray()
var repairs: Array[Dictionary] = []
var validation_report: Dictionary = {}


func _init(generation_config: Dictionary, generation_seed: int, generation_attempt: int = 0) -> void:
	config = generation_config.duplicate(true)
	seed_value = generation_seed
	attempt = generation_attempt
	feature_registry = FeatureRegistryScript.new()


func stage_rng(stage_name: String) -> DeterministicRng:
	var stream_id := _stable_text_hash(stage_name)
	stream_id = int((stream_id + attempt * 104729) % 2147483647)
	return DeterministicRngScript.new(_mixed_seed(seed_value, stream_id))


func record_stage(stage_name: String, elapsed_ms: float, notes: Dictionary = {}) -> void:
	stage_trace.append(stage_name)
	stage_timings_ms[stage_name] = elapsed_ms
	if not notes.is_empty():
		stage_notes[stage_name] = notes.duplicate(true)


func total_generation_ms() -> float:
	var total := 0.0
	for value: Variant in stage_timings_ms.values():
		total += float(value)
	return total


func _stable_text_hash(text: String) -> int:
	var value := 216613626
	for byte: int in text.to_utf8_buffer():
		value = int((value * 16777619 + byte) % 2147483647)
	return value


func _mixed_seed(base_seed: int, stream_id: int) -> int:
	var value := int(base_seed % 2147483647)
	if value < 0:
		value += 2147483647
	value = int((value + 1) % 2147483647)
	value = int((value * 48271 + stream_id + 1) % 2147483647)
	return value if value != 0 else 1
