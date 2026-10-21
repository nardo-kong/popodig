extends RefCounted

const SPEEDS: Array[int] = [1, 2, 3]
var speed := 1
var enabled := true
var slow_for_danger := true


func configure(balance: Dictionary) -> void:
	var settings: Dictionary = balance.get("time_controls", {})
	enabled = bool(settings.get("enabled", true))
	slow_for_danger = bool(settings.get("slow_for_danger", true))
	speed = 1


func set_speed(value: int) -> bool:
	if not SPEEDS.has(value) or (not enabled and value != 1):
		return false
	speed = value
	return true


func cycle() -> void:
	set_speed(1 if speed == 3 else speed + 1)


func simulation_delta(real_delta: float) -> float:
	return clampf(real_delta, 0.0, 0.4) * speed


func danger_started() -> bool:
	if speed == 1 or not slow_for_danger:
		return false
	speed = 1
	return true
