extends GutTest
const Record := preload("res://scripts/input/pad_diagnostic_record.gd")
const Scene := preload("res://scenes/pad_diagnostics.tscn")

class DiagnosticProbe extends "res://scripts/pad_diagnostics.gd":
	var back_requests := 0
	func _back() -> void:
		back_requests += 1

func test_b_returns_only_when_pressed_and_not_armed() -> void:
	var screen := DiagnosticProbe.new()
	add_child_autofree(screen)
	screen.record.select_device(3)
	var event := button(3, false)
	event.button_index = JOY_BUTTON_B
	screen._input(event)
	assert_eq(screen.back_requests, 0, "Bを離しただけでは戻らない")
	event.pressed = true
	screen._input(event)
	assert_eq(screen.back_requests, 1, "採取待ちでなければBで戻る")

func test_armed_b_is_recorded_without_returning() -> void:
	var screen := DiagnosticProbe.new()
	add_child_autofree(screen)
	screen.record.select_device(3)
	assert_true(screen.record.start_guide())
	assert_true(screen.record.arm())
	var event := button(3, true)
	event.button_index = JOY_BUTTON_B
	screen._input(event)
	assert_eq(screen.back_requests, 0)
	assert_eq(screen.record.candidate.index, JOY_BUTTON_B)
	assert_true(screen.record.buttons[JOY_BUTTON_B])
	assert_false(screen.record.armed)
	event.pressed = false
	screen._input(event)
	assert_eq(screen.back_requests, 0, "採取直後のBリリースでも戻らない")

func button(device: int, pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event

func motion(value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event

func test_guide_requires_explicit_arm_and_confirmation() -> void:
	var record := Record.new()
	record.select_device(3)
	assert_true(record.start_guide())
	record.record(button(3, true))
	assert_true(record.candidate.is_empty())
	assert_false(record.arm())
	record.record(button(3, false))
	assert_true(record.arm())
	record.record(button(3, true))
	assert_eq(record.candidate.index, JOY_BUTTON_A)
	assert_eq(record.step, 0)
	assert_true(record.confirm())
	assert_eq(record.samples[0].physical_control, Record.STEPS[0])
	assert_false(record.arm())
	record.record(button(3, false))
	assert_true(record.arm())

func test_other_device_and_disconnect_cannot_record() -> void:
	var record := Record.new()
	record.select_device(3)
	record.start_guide()
	record.arm()
	record.record(button(4, true))
	assert_true(record.events.is_empty())
	record.disconnect_device(4)
	assert_true(record.connected)
	record.disconnect_device(3)
	record.record(button(3, true))
	assert_true(record.events.is_empty())
	assert_false(record.arm())
	assert_false(record.confirm())

func test_axis_return_and_noise_do_not_capture_next_step() -> void:
	var record := Record.new()
	record.select_device(3)
	record.axes[JOY_AXIS_LEFT_X] = 0.0
	record.start_guide()
	record.arm()
	record.record(motion(0.1))
	assert_true(record.candidate.is_empty())
	record.record(motion(-0.9))
	assert_false(record.candidate.is_empty())
	record.confirm()
	assert_false(record.arm())
	record.record(motion(0.0))
	assert_true(record.candidate.is_empty())
	assert_true(record.arm())
	record.record(motion(0.9))
	assert_almost_eq(float(record.candidate.value), 0.9, 0.0001)

func test_device_selection_resets_diagnostic_and_skip_is_explicit() -> void:
	var record := Record.new()
	record.select_device(3)
	record.start_guide()
	record.skip()
	assert_true(record.samples[0].skipped)
	record.select_device(4)
	assert_eq(record.step, -1)
	assert_true(record.samples.is_empty())
	assert_true(record.axes.is_empty())

func test_scene_builds_without_gamepad() -> void:
	var screen := Scene.instantiate()
	add_child_autofree(screen)
	assert_not_null(screen.get("_device_picker"))
