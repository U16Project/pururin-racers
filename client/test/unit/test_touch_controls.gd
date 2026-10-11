extends GutTest

const TouchPadInput := preload("res://scripts/input/touch_pad_input.gd")
const TouchControls := preload("res://scripts/presentation/touch_controls.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

const SCREEN := Vector2(1200.0, 700.0)


func after_each() -> void:
	# 押しっぱなしを、次のテストへ残さない。
	TouchPadInput.release_all()


func _pad() -> Control:
	var pad: Control = TouchControls.new()
	add_child_autofree(pad)
	pad.size = SCREEN
	return pad


func test_stick_vector_stays_inside_one_and_points_at_the_finger() -> void:
	var center := Vector2(200.0, 500.0)
	assert_eq(TouchPadInput.stick_vector(center, center, 100.0), Vector2.ZERO)
	# まん中から半分の所は、0.5倒したことになる。
	assert_almost_eq(TouchPadInput.stick_vector(center, center + Vector2(50.0, 0.0), 100.0).x, 0.5, 0.001)
	# 外まで動かしても、倒しきり（長さ1）で止まる。
	var far := TouchPadInput.stick_vector(center, center + Vector2(400.0, 0.0), 100.0)
	assert_almost_eq(far.length(), 1.0, 0.001)
	assert_almost_eq(far.x, 1.0, 0.001)
	assert_eq(TouchPadInput.stick_vector(center, center + Vector2(10.0, 0.0), 0.0), Vector2.ZERO)


func test_touch_state_is_remembered_and_cleared() -> void:
	assert_false(TouchPadInput.button_down(JOY_BUTTON_X))
	TouchPadInput.set_button(JOY_BUTTON_X, true)
	TouchPadInput.set_axis(JOY_AXIS_LEFT_X, 0.7)
	assert_true(TouchPadInput.button_down(JOY_BUTTON_X))
	assert_almost_eq(TouchPadInput.axis_value(JOY_AXIS_LEFT_X), 0.7, 0.001)
	TouchPadInput.release_all()
	assert_false(TouchPadInput.button_down(JOY_BUTTON_X))
	assert_almost_eq(TouchPadInput.axis_value(JOY_AXIS_LEFT_X), 0.0, 0.001)


func test_race_input_reads_the_virtual_pad_too() -> void:
	assert_false(RaceControllerInput.brake_pressed())
	TouchPadInput.set_button(JOY_BUTTON_A, true)
	assert_true(RaceControllerInput.brake_pressed())
	TouchPadInput.set_axis(JOY_AXIS_LEFT_X, -0.8)
	assert_almost_eq(RaceControllerInput.line_axis(), -0.8, 0.001)
	TouchPadInput.set_button(JOY_BUTTON_DPAD_UP, true)
	assert_almost_eq(RaceControllerInput.notch_axis(), 1.0, 0.001)


func test_the_pad_starts_shown_only_on_a_finger_screen() -> void:
	var pad := _pad()
	# 指で触る画面かどうかで、最初に出すかが決まる。
	assert_eq(pad.is_pad_shown(), TouchPadInput.shows_by_default())


func test_pad_parts_answer_only_while_the_pad_is_shown() -> void:
	var pad := _pad()
	if pad.is_pad_shown():
		pad.toggle_pad()
	assert_false(pad.is_pad_shown())
	assert_eq(pad.widget_at(pad.stick_center()), "")
	assert_eq(pad.widget_at(pad.button_center(TouchControls.ROUND_BUTTONS[0])), "")
	pad.toggle_pad()
	assert_true(pad.is_pad_shown())
	assert_eq(pad.widget_at(pad.stick_center()), "stick")
	for spec: Dictionary in TouchControls.ROUND_BUTTONS:
		assert_eq(pad.widget_at(pad.button_center(spec)), str(spec["id"]))


func test_buttons_do_not_overlap_each_other_or_the_stick() -> void:
	var pad := _pad()
	if not pad.is_pad_shown():
		pad.toggle_pad()
	var spots: Array = [[pad.stick_center(), TouchControls.STICK_RADIUS]]
	for spec: Dictionary in TouchControls.ROUND_BUTTONS:
		spots.append([pad.button_center(spec), float(spec["radius"])])
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var gap: float = (spots[i][0] as Vector2).distance_to(spots[j][0])
			assert_gt(gap, float(spots[i][1]) + float(spots[j][1]))


func test_hiding_the_pad_lets_go_of_everything() -> void:
	var pad := _pad()
	if not pad.is_pad_shown():
		pad.toggle_pad()
	TouchPadInput.set_button(JOY_BUTTON_B, true)
	TouchPadInput.set_axis(JOY_AXIS_LEFT_X, 0.9)
	pad.toggle_pad()
	assert_false(pad.is_pad_shown())
	assert_false(TouchPadInput.button_down(JOY_BUTTON_B))
	assert_almost_eq(TouchPadInput.axis_value(JOY_AXIS_LEFT_X), 0.0, 0.001)


func test_the_knob_follows_the_stick_and_stays_in_the_ring() -> void:
	var pad := _pad()
	if not pad.is_pad_shown():
		pad.toggle_pad()
	TouchPadInput.set_axis(JOY_AXIS_LEFT_X, 1.0)
	var knob: Vector2 = pad.knob_center()
	var center: Vector2 = pad.stick_center()
	assert_gt(knob.x, center.x)
	assert_almost_eq(knob.distance_to(center), TouchControls.STICK_RADIUS - TouchControls.STICK_KNOB_RADIUS, 0.001)


func test_set_pad_shown_puts_it_away_and_back() -> void:
	var pad := _pad()
	pad.set_pad_shown(true)
	assert_true(pad.is_pad_shown())
	pad.set_pad_shown(false)
	assert_false(pad.is_pad_shown())
	# 同じ値をもう一度入れても、変わらない。
	pad.set_pad_shown(false)
	assert_false(pad.is_pad_shown())


func test_the_menu_button_sits_at_the_top_right() -> void:
	var pad := _pad()
	var at: Vector2 = pad.button_center(TouchControls.button_spec("menu"))
	assert_gt(at.x, SCREEN.x * 0.75)
	assert_lt(at.y, SCREEN.y * 0.25)
