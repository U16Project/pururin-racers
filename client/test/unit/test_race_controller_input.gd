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
