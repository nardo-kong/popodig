extends "res://tests/test_case.gd"
const Clock = preload("res://src/domain/progression/time_control.gd")


func run() -> Array[Dictionary]:
	var clock := Clock.new()
	clock.configure({})
	assert_equal(clock.speed, 1, "Every new session starts at comfortable normal speed")
	assert_true(clock.set_speed(3), "Three-times speed is an explicit player choice")
	assert_true(is_equal_approx(clock.simulation_delta(0.1), 0.3), "Speed multiplies elapsed simulation time")
	assert_true(is_equal_approx(clock.simulation_delta(3.0), 1.2), "Frame backlog remains bounded")
	assert_equal(clock.simulation_delta(-1.0), 0.0, "Negative real delta cannot reverse simulation")
	assert_true(clock.danger_started(), "New danger requests a visible return to normal speed")
	assert_equal(clock.speed, 1, "Danger returns speed to one")
	assert_true(not clock.danger_started(), "Normal-speed danger does not spam slow notifications")
	clock.cycle()
	assert_equal(clock.speed, 2, "Cycle reaches two-times speed")
	clock.cycle()
	clock.cycle()
	assert_equal(clock.speed, 1, "Cycle wraps rather than increasing without limit")
	assert_true(not clock.set_speed(100), "Unknown speeds are rejected")
	clock.configure({"time_controls": {"enabled": false}})
	assert_true(not clock.set_speed(2), "Time-control variant can be disabled by configuration")
	return results
