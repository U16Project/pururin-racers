extends GutTest
const Record := preload("res://scripts/input/pad_diagnostic_record.gd")
const Scene := preload("res://scenes/pad_diagnostics.tscn")

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
