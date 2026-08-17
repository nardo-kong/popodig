class_name WorldGenerationResult
extends RefCounted

var world
var feature_registry: FeatureRegistry
var report: Dictionary = {}
var success := false


func _init(generated_world = null, generated_features: FeatureRegistry = null, generation_report: Dictionary = {}) -> void:
	world = generated_world
	feature_registry = generated_features
	report = generation_report.duplicate(true)
	success = bool(report.get("valid", false))


func get_content_hash() -> int:
	return int(report.get("content_hash", 0))
