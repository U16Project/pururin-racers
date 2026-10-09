extends GutTest
const Options := preload("res://scripts/input/pad_input_options.gd")
const RaceInput := preload("res://scripts/input/race_controller_input.gd")
const Diagnostics := preload("res://scripts/pad_diagnostics.gd")
const GUID := "0300457e790000000600000000000000"
var options: Node
var profile: Dictionary

class Receiver extends Node:
	var events: Array = []
	func _unhandled_input(event: InputEvent) -> void:
		if event.has_meta("pad_corrected"):
			events.append(event)

func before_each() -> void:
	options = Options.new()
	options.profiles = JSON.parse_string(FileAccess.get_file_as_string(Options.PROFILE_PATH)).profiles
	profile = options.profiles[0]

func after_each() -> void:
	options.free()

func button(index: int, down: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = down
	return event

func axis(index: int, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = index
	event.axis_value = value
	return event

func test_saved_selection_matches_only_guid_and_platform() -> void:
	options.selections[GUID] = profile.id
	var path := "user://pad_options_gut_test.json"
	assert_eq(options.save_options(path), OK)
	options.selections.clear()
	options.load_options(path)
	assert_eq(options.profile_for(GUID).id, profile.id)
	assert_true(options.profile_for("another-device").is_empty())
	assert_true(options.profile_for(GUID, "Linux").is_empty())
	assert_eq(options.select_profile("another-device", profile.id), ERR_INVALID_PARAMETER)
	options.selections[GUID] = "standard"
	assert_true(options.profile_for(GUID).is_empty())
	DirAccess.remove_absolute(path)

func test_face_buttons_shoulders_select_and_stick_clicks() -> void:
	for pair in [[2, JOY_BUTTON_A], [3, JOY_BUTTON_B], [0, JOY_BUTTON_X], [1, JOY_BUTTON_Y], [4, JOY_BUTTON_LEFT_SHOULDER], [5, JOY_BUTTON_RIGHT_SHOULDER], [10, JOY_BUTTON_BACK], [8, JOY_BUTTON_LEFT_STICK], [9, JOY_BUTTON_RIGHT_STICK]]:
		var events: Array = options.convert_event(button(pair[0]), profile)
		assert_eq(events.size(), 1)
		assert_eq(events[0].button_index, pair[1])
		assert_true(events[0].pressed)
		assert_true(options.convert_event(button(pair[0]), profile).is_empty(), "held入力は再発火しない")
		var releases: Array = options.convert_event(button(pair[0], false), profile)
		assert_false(releases[0].pressed)

func test_digital_triggers_become_axes_for_brake_and_slot_move() -> void:
	RaceInput._trigger_down.clear()
	var left: Array = options.convert_event(button(6), profile)
	assert_eq(left[0].axis, JOY_AXIS_TRIGGER_LEFT)
	assert_eq(left[0].axis_value, 1.0)
	assert_eq(RaceInput.slot_move_direction(left[0]), -1)
	assert_true(options.convert_event(button(6), profile).is_empty())
	RaceInput.slot_move_direction(options.convert_event(button(6, false), profile)[0])
	var right: Array = options.convert_event(button(7), profile)
	assert_eq(right[0].axis, JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(RaceInput.slot_move_direction(right[0]), 1)
	RaceInput._trigger_down.clear()

func test_recorded_sticks_dpad_duplicate_axis_and_start_conflict() -> void:
	options.convert_event(axis(0, -1), profile)
	assert_true(options.buttons[JOY_BUTTON_DPAD_LEFT])
	options.convert_event(axis(1, -1), profile)
	assert_true(options.buttons[JOY_BUTTON_DPAD_UP])
	var up: Array = options.convert_event(button(11), profile)
	assert_eq(up[0].axis, JOY_AXIS_LEFT_Y)
	assert_eq(up[0].axis_value, -1.0)
	assert_false(options.buttons.get(JOY_BUTTON_START, false), "区別できないSTARTは割り当てない")
	options.convert_event(axis(2, 0.8), profile)
	assert_almost_eq(options.axes[JOY_AXIS_RIGHT_X], 0.8, 0.001)
	assert_true(options.convert_event(axis(3, 0.8), profile).is_empty(), "重複raw軸を無視")
	options.convert_event(axis(4, -0.8), profile)
	assert_almost_eq(options.axes[JOY_AXIS_RIGHT_Y], -0.8, 0.001)

func test_runtime_pipeline_delivers_canonical_event_and_polls_corrected_state() -> void:
	var receiver := Receiver.new()
	add_child_autofree(receiver)
	PadInputOptions.clear_state()
	PadInputOptions.active_device = 0
	PadInputOptions.active_profile = profile
	PadInputOptions.diagnostic_mode = false
	Input.parse_input_event(button(2))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(RaceInput.button_down(JOY_BUTTON_A))
	assert_false(RaceInput.button_down(JOY_BUTTON_X))
	assert_true(receiver.events.any(func(event): return RaceInput.is_accept_pressed(event)))
	Input.parse_input_event(axis(4, -0.9))
	await get_tree().process_frame
	assert_almost_eq(RaceInput.look_vector().y, -0.9, 0.001)
	Input.parse_input_event(button(6))
	await get_tree().process_frame
	assert_true(RaceInput.brake_pressed())
	Input.parse_input_event(button(2, false))
	Input.parse_input_event(button(6, false))
	Input.parse_input_event(axis(4, 0))
	await get_tree().process_frame
	PadInputOptions.refresh_active()
	await get_tree().process_frame
	assert_true(PadInputOptions.buttons.is_empty())
	assert_false(Input.is_joy_button_pressed(PadInputOptions.synthetic_device, JOY_BUTTON_A))

func test_diagnostics_keeps_raw_and_restores_correction_when_closed() -> void:
	PadInputOptions.active_profile = profile
	PadInputOptions.active_device = 0
	var diagnostics := Diagnostics.new()
	add_child(diagnostics)
	assert_true(PadInputOptions.diagnostic_mode)
	assert_false(PadInputOptions.correction_enabled())
	if diagnostics.record.device == 0:
		Input.parse_input_event(button(2))
		assert_true(diagnostics.record.buttons.get(2, false), "補正前の番号で記録")
		Input.parse_input_event(button(2, false))
	diagnostics.free()
	assert_false(PadInputOptions.diagnostic_mode)
	PadInputOptions.refresh_active()
