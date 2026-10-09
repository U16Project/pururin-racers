extends GutTest
## カメラ探索モードが、レースのセッションを使わず会場と自由カメラを用意することを確かめる。

const ExplorationScene := preload("res://scenes/camera_exploration.tscn")
const ExplorationCamera := preload("res://scripts/exploration_camera.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")


func test_exploration_scene_builds_existing_venue_without_runners() -> void:
	var screen := ExplorationScene.instantiate()
	add_child(screen)
	assert_not_null(screen.get_node_or_null("TrackPath/RaceVenue"))
	assert_not_null(screen.get_node_or_null("TrackPath/StartGate"))
	assert_not_null(screen.get_node_or_null("TrackPath/GoalGate"))
	assert_not_null(screen.get_node_or_null("TrackPath/RouteLaunchStraight"))
	assert_not_null(screen.get_node_or_null("ExplorationCamera"))
	assert_null(screen.get_node_or_null("Runners"))
	assert_null(screen.get_node_or_null("UI/HudLabel"))
	var launch := screen.get_node("TrackPath/RouteLaunchStraight") as MeshInstance3D
	assert_true(launch.visible)
	assert_almost_eq((launch.mesh as BoxMesh).size.z, 160.0, 0.001)
	assert_string_contains(screen.get_node("UI/GuidePanel/GuideLabel").text, "移動速度")
	screen.free()


func test_exploration_camera_has_safe_speed_limits_and_no_roll() -> void:
	var screen := ExplorationScene.instantiate()
	add_child(screen)
	var camera: Camera3D = screen.get_node("ExplorationCamera")
	camera.call("set_move_speed", 10000.0)
	assert_eq(float(camera.get("move_speed_mps")), 300.0)
	camera.call("set_move_speed", 0.0)
	assert_eq(float(camera.get("move_speed_mps")), 5.0)
	camera.call("_apply_look", Vector2(0.2, 100.0))
	assert_almost_eq(camera.rotation.z, 0.0, 0.0001)
	assert_true(absf(camera.rotation.x) <= deg_to_rad(88.0) + 0.0001)
	screen.free()


func test_initial_camera_sees_whole_course_and_launch_straight() -> void:
	var screen := ExplorationScene.instantiate()
	add_child(screen)
	var camera := screen.get_node("ExplorationCamera") as Camera3D
	var track := screen.get_node("TrackPath") as Path3D
	var layout := M5CourseBuilder.load_layout()
	var route := M5CourseBuilder.route_for_distance(layout, 1600.0)
	# 本線全体と専用直線の両端が、初期位置から画面に収まる。
	for point: Vector3 in track.curve.get_baked_points():
		assert_true(camera.is_position_in_frustum(track.to_global(point)))
	for distance_m: float in [0.0, 160.0]:
		var pose := M5CourseBuilder.route_pose(track.curve, route, distance_m, float(layout["track_length_m"]))
		assert_true(camera.is_position_in_frustum(track.to_global(pose["position"])))
	screen.free()


func test_movement_input_and_minimum_height() -> void:
	var camera := ExplorationCamera.new()
	add_child(camera)
	camera.set_process(false)
	camera.position = Vector3(0.0, 2.0, 0.0)
	_send_key(KEY_W, true)
	assert_eq(camera.movement_input(), Vector2(0.0, 1.0))
	camera._process(0.1)
	assert_almost_eq(camera.position.z, -8.0, 0.001)
	_send_key(KEY_W, false)
	_send_key(KEY_CTRL, true)
	camera._process(1.0)
	assert_almost_eq(camera.position.y, ExplorationCamera.MIN_HEIGHT_M, 0.001)
	_send_key(KEY_CTRL, false)
	camera.free()


func test_analog_triggers_and_return_buttons() -> void:
	var camera := ExplorationCamera.new()
	add_child(camera)
	camera.set_process(false)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.4)
	assert_almost_eq(camera.vertical_input(), 0.4, 0.001)
	_send_axis(JOY_AXIS_TRIGGER_LEFT, 0.1)
	assert_almost_eq(camera.vertical_input(), 0.3, 0.001)
	_send_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	_send_axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	assert_true(ExplorationCamera._is_return_event(escape))
	escape.echo = true
	assert_false(ExplorationCamera._is_return_event(escape))
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	assert_true(ExplorationCamera._is_return_event(button))
	button.pressed = false
	assert_false(ExplorationCamera._is_return_event(button))
	camera.free()


func test_sticks_dpad_wheel_and_mouse_look() -> void:
	var camera := ExplorationCamera.new()
	add_child(camera)
	camera.set_process(false)
	_send_axis(JOY_AXIS_LEFT_X, 0.6)
	_send_axis(JOY_AXIS_LEFT_Y, -0.3)
	assert_almost_eq(camera.movement_input().x, 0.6, 0.001)
	assert_almost_eq(camera.movement_input().y, 0.3, 0.001)
	_send_axis(JOY_AXIS_LEFT_X, 0.0)
	_send_axis(JOY_AXIS_LEFT_Y, 0.0)
	var dpad := InputEventJoypadButton.new()
	dpad.device = 0
	dpad.button_index = JOY_BUTTON_DPAD_UP
	dpad.pressed = true
	Input.parse_input_event(dpad)
	Input.flush_buffered_events()
	assert_eq(camera.movement_input(), Vector2(0.0, 1.0))
	var release := InputEventJoypadButton.new()
	release.device = 0
	release.button_index = JOY_BUTTON_DPAD_UP
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	_send_axis(JOY_AXIS_RIGHT_X, 0.5)
	camera._process(0.1)
	assert_almost_eq(camera.rotation.y, -0.09, 0.001)
	_send_axis(JOY_AXIS_RIGHT_X, 0.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	camera._unhandled_input(wheel)
	assert_almost_eq(camera.move_speed_mps, 100.0, 0.001)
	# ヘッドレス環境はマウス捕捉を行えないため、マウスと共通の視点更新を確認。
	camera._apply_look(Vector2(10.0, 10.0) * ExplorationCamera.MOUSE_SENSITIVITY)
	assert_almost_eq(camera.rotation.y, -0.112, 0.001)
	assert_almost_eq(camera.rotation.x, -0.022, 0.001)
	camera.free()
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE)


func _send_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _send_axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
