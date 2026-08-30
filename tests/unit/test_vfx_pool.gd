extends RefCounted

# Phase 11 unit tests: the pooled VFX view caps particles, decays them by
# lifetime, and respects the reduced-particles accessibility mode
# (docs/art/13_AUDIO_VFX_SPEC.md §9/§10).

const VfxViewScript = preload("res://src/presentation/fx/vfx_view.gd")

var results: Array[Dictionary] = []


func run() -> Array[Dictionary]:
	results = []
	_test_bursts_stay_under_the_cap()
	_test_particles_expire()
	_test_reduced_mode_shrinks_bursts()
	_test_camera_shake_honors_reduced_flag()
	return results


func _make_view() -> VfxView:
	var view: VfxView = VfxViewScript.new()
	return view


func _test_bursts_stay_under_the_cap() -> void:
	var view := _make_view()
	for index: int in range(60):
		view.burst_dig(Vector2(8, 8), 1)
	_assert(view.get_active_count() <= 220, "Dig bursts stay under the particle cap (%d active)" % view.get_active_count())
	view.free()


func _test_particles_expire() -> void:
	var view := _make_view()
	view.burst_dig(Vector2(8, 8), 1)
	var initial := view.get_active_count()
	_assert(initial > 0, "A dig burst spawns particles")
	# Step well past the longest particle life (0.8s).
	for _step: int in range(20):
		view._process(0.1)
	_assert(view.get_active_count() == 0, "All particles expire within their lifetime")
	_assert(not view.visible, "The view hides itself once the pool drains")
	view.free()


func _test_reduced_mode_shrinks_bursts() -> void:
	var view := _make_view()
	view.burst_water(Vector2(8, 8), 40)
	var full_count := view.get_active_count()
	view.free()
	var reduced := _make_view()
	reduced.set_reduced_particles(true)
	reduced.burst_water(Vector2(8, 8), 40)
	_assert(reduced.get_active_count() < full_count, "Reduced-particles mode spawns fewer droplets (%d < %d)" % [reduced.get_active_count(), full_count])
	_assert(reduced.get_active_count() <= 5, "Reduced mode caps droplets at the documented minimum")
	reduced.free()


func _test_camera_shake_honors_reduced_flag() -> void:
	var camera_script: Script = load("res://src/presentation/world/world_camera.gd")
	var camera: Camera2D = camera_script.new()
	camera.reduced_shake = true
	camera.apply_shake(5.0)
	_assert(camera._shake_amplitude == 0.0, "Reduced-shake mode blocks camera shake entirely")
	camera.reduced_shake = false
	camera.apply_shake(5.0)
	_assert(camera._shake_amplitude > 0.0, "Normal mode applies the shake impulse")
	camera.free()


func _assert(condition: bool, description: String) -> void:
	results.append({
		"passed": condition,
		"description": description,
		"details": "" if condition else "Expected true",
	})
