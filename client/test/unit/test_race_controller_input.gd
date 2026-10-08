extends GutTest

const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")


func _button_event(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func test_start_and_b_buttons_have_distinct_menu_roles() -> void:
	assert_true(RaceControllerInput.is_menu_pressed(_button_event(JOY_BUTTON_START)))
	assert_false(RaceControllerInput.is_cancel_pressed(_button_event(JOY_BUTTON_START)))
	assert_true(RaceControllerInput.is_cancel_pressed(_button_event(JOY_BUTTON_B)))


func test_y_and_right_stick_events_are_identifiable_for_camera_controls() -> void:
	assert_true(RaceControllerInput.is_button_pressed(_button_event(JOY_BUTTON_Y), JOY_BUTTON_Y))
	assert_true(
		RaceControllerInput.is_button_pressed(_button_event(JOY_BUTTON_RIGHT_STICK), JOY_BUTTON_RIGHT_STICK)
	)


func test_visible_button_can_be_activated_by_controller() -> void:
	var button := Button.new()
	get_tree().root.add_child(button)
	assert_true(RaceControllerInput.activate_control(button))
	button.queue_free()


func test_activating_a_toggle_button_switches_it_and_a_grouped_one_only_turns_on() -> void:
	var toggle := Button.new()
	toggle.toggle_mode = true
	add_child_autofree(toggle)
	assert_true(RaceControllerInput.activate_control(toggle))
	assert_true(toggle.button_pressed)
	assert_true(RaceControllerInput.activate_control(toggle))
	assert_false(toggle.button_pressed)
	var grouped := Button.new()
	grouped.toggle_mode = true
	grouped.button_group = ButtonGroup.new()
	add_child_autofree(grouped)
	assert_true(RaceControllerInput.activate_control(grouped))
	assert_true(RaceControllerInput.activate_control(grouped))
	assert_true(grouped.button_pressed)


func test_slot_clear_is_x_and_slot_force_is_y() -> void:
	assert_true(RaceControllerInput.is_slot_clear_pressed(_button_event(JOY_BUTTON_X)))
	assert_false(RaceControllerInput.is_slot_clear_pressed(_button_event(JOY_BUTTON_Y)))
	assert_true(RaceControllerInput.is_slot_force_pressed(_button_event(JOY_BUTTON_Y)))
	assert_false(RaceControllerInput.is_slot_force_pressed(_button_event(JOY_BUTTON_X)))
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_X
	assert_true(RaceControllerInput.is_slot_clear_pressed(key))
	key.physical_keycode = KEY_Y
	assert_true(RaceControllerInput.is_slot_force_pressed(key))


func test_slot_lock_is_select_and_slot_move_counts_only_the_moment_a_trigger_is_pulled() -> void:
	assert_true(RaceControllerInput.is_slot_lock_pressed(_button_event(JOY_BUTTON_BACK)))
	assert_false(RaceControllerInput.is_slot_lock_pressed(_button_event(JOY_BUTTON_START)))
	var pull := InputEventJoypadMotion.new()
	pull.axis = JOY_AXIS_TRIGGER_LEFT
	pull.axis_value = 0.0
	RaceControllerInput.slot_move_direction(pull)
	pull.axis_value = 1.0
	assert_eq(RaceControllerInput.slot_move_direction(pull), -1, "L2 を引いた瞬間は、上へ")
	assert_eq(RaceControllerInput.slot_move_direction(pull), 0, "引いたままでは、数えない")
	pull.axis_value = 0.0
	assert_eq(RaceControllerInput.slot_move_direction(pull), 0)
	pull.axis = JOY_AXIS_TRIGGER_RIGHT
	pull.axis_value = 1.0
	assert_eq(RaceControllerInput.slot_move_direction(pull), 1, "R2 は、下へ")
	pull.axis_value = 0.0
	RaceControllerInput.slot_move_direction(pull)
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_PAGEUP
	assert_eq(RaceControllerInput.slot_move_direction(key), -1)
	key.physical_keycode = KEY_PAGEDOWN
	assert_eq(RaceControllerInput.slot_move_direction(key), 1)
