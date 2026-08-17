class_name DeterministicRng
extends RefCounted

var _rng := RandomNumberGenerator.new()
var _seed_value: int


func _init(initial_seed: int) -> void:
	_seed_value = initial_seed
	_rng.seed = initial_seed


func get_seed() -> int:
	return _seed_value


func next_int(minimum: int, maximum: int) -> int:
	return _rng.randi_range(minimum, maximum)


func next_float() -> float:
	return _rng.randf()


func fork(stream_id: int) -> DeterministicRng:
	var mixed := hash([_seed_value, stream_id])
	return DeterministicRng.new(mixed)
