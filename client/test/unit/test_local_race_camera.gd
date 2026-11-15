extends GutTest

const LocalRaceCamera := preload("res://scripts/local_race_camera.gd")


func test_views_cycle_through_all_six_and_return_to_the_default() -> void:
	var view := LocalRaceCamera.View.DEFAULT
	var seen := [view]
	for _i in LocalRaceCamera.VIEW_ORDER.size() - 1:
		view = LocalRaceCamera.next_view(view)
		seen.append(view)
	assert_eq(seen, [LocalRaceCamera.View.DEFAULT, LocalRaceCamera.View.FAR, LocalRaceCamera.View.FRONT, LocalRaceCamera.View.SIDE, LocalRaceCamera.View.OVERHEAD, LocalRaceCamera.View.FIRST_PERSON])
	for expected: int in LocalRaceCamera.View.values():
		assert_true(expected in seen)
	assert_eq(LocalRaceCamera.next_view(view), LocalRaceCamera.View.DEFAULT)


func test_view_settings_match_the_intended_shapes() -> void:
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS
	# 遠距離は、デフォルトより後ろ。一人称は距離0で、まっすぐ前を見る。上空は、ほかの視点より高い。
	assert_gt(float(settings[LocalRaceCamera.View.FAR]["back"]), float(settings[LocalRaceCamera.View.DEFAULT]["back"]))
	assert_eq(float(settings[LocalRaceCamera.View.FIRST_PERSON]["back"]), 0.0)
	assert_true(bool(settings[LocalRaceCamera.View.FIRST_PERSON]["look_ahead"]))
	for view in settings:
		if view != LocalRaceCamera.View.OVERHEAD:
			assert_gt(float(settings[LocalRaceCamera.View.OVERHEAD]["height"]), float(settings[view]["height"]))


func test_look_yaw_follows_the_stick_direction_all_the_way_around() -> void:
	# スティックの上（Yがマイナス）が前。右が右。
	assert_almost_eq(LocalRaceCamera.look_yaw_from_stick(Vector2(0.0, -1.0)), 0.0, 0.0001)
	assert_almost_eq(LocalRaceCamera.look_yaw_from_stick(Vector2(1.0, 0.0)), PI * 0.5, 0.0001)
	assert_almost_eq(LocalRaceCamera.look_yaw_from_stick(Vector2(-1.0, 0.0)), -PI * 0.5, 0.0001)
	assert_almost_eq(absf(LocalRaceCamera.look_yaw_from_stick(Vector2(0.0, 1.0))), PI, 0.0001)
	assert_almost_eq(LocalRaceCamera.look_yaw_from_stick(Vector2(0.7, -0.7)), PI * 0.25, 0.0001)


func test_camera_follows_the_target_and_hides_the_body_only_in_first_person() -> void:
	var target := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	target.add_child(body)
	add_child_autofree(target)
	var camera := Camera3D.new()
	camera.set_script(LocalRaceCamera)
	camera.set("input_allowed", func() -> bool: return true)
	add_child_autofree(camera)
	camera.call("set_follow_target", target)
	var default_settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
	assert_almost_eq(camera.global_position.y, float(default_settings["height"]), 0.0001)
	assert_almost_eq(camera.global_position.z, float(default_settings["back"]), 0.0001)
	assert_true(body.visible)
	camera.call("_set_view", LocalRaceCamera.View.FIRST_PERSON)
	assert_false(body.visible)
	assert_almost_eq(camera.global_position.z, 0.0, 0.0001)
	camera.call("_set_view", LocalRaceCamera.View.OVERHEAD)
	assert_true(body.visible)


## ゴールしたかどうかを答えるだけの、仮の走者。
func _finishing_target() -> Node3D:
	var script := GDScript.new()
	script.source_code = "extends Node3D\nvar finished := false\nfunc is_finished() -> bool:\n\treturn finished\n"
	script.reload()
	var target := Node3D.new()
	target.set_script(script)
	var body := MeshInstance3D.new()
	body.name = "Body"
	target.add_child(body)
	add_child_autofree(target)
	return target


func test_goal_orbit_waits_then_swings_to_the_front_then_keeps_turning() -> void:
	var delay := LocalRaceCamera.GOAL_VIEW_DELAY_S
	var swing := LocalRaceCamera.GOAL_SWING_SECONDS
	assert_almost_eq(LocalRaceCamera.goal_orbit_angle(0.0), 0.0, 0.0001)
	assert_almost_eq(LocalRaceCamera.goal_orbit_angle(delay), 0.0, 0.0001, "少しのあいだは、後ろのまま")
	assert_almost_eq(LocalRaceCamera.goal_orbit_angle(delay + swing * 0.5), PI * 0.5, 0.0001, "回り込みの途中は、真横")
	assert_almost_eq(LocalRaceCamera.goal_orbit_angle(delay + swing), PI, 0.0001, "回り込み終わると、真正面")
	# そのあとは、同じ向きへ、決まった速さで回り続ける。
	assert_almost_eq(LocalRaceCamera.goal_orbit_angle(delay + swing + 3.0), PI + deg_to_rad(LocalRaceCamera.GOAL_ORBIT_DEG_PER_S) * 3.0, 0.0001)
	var previous := 0.0
	for step in 80:
		var angle := LocalRaceCamera.goal_orbit_angle(float(step) * 0.1)
		assert_gte(angle, previous - 0.0001)
		previous = angle


func test_after_the_goal_the_camera_moves_to_the_front_at_the_same_distance() -> void:
	var target := _finishing_target()
	var camera := Camera3D.new()
	camera.set_script(LocalRaceCamera)
	camera.set("input_allowed", func() -> bool: return true)
	add_child_autofree(camera)
	camera.call("set_follow_target", target)
	var to_front := LocalRaceCamera.GOAL_VIEW_DELAY_S + LocalRaceCamera.GOAL_SWING_SECONDS
	# ゴール前は、いくら時間がたっても、後ろのまま。
	camera.call("advance_goal_view", to_front)
	camera.call("_apply")
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
	assert_almost_eq(camera.global_position.z, float(settings["back"]), 0.0001)
	# ゴールして、回り込みが終わると、同じ距離・同じ高さで、前から走者を見る。
	target.set("finished", true)
	camera.call("advance_goal_view", to_front)
	camera.call("_apply")
	assert_almost_eq(camera.global_position.z, -float(settings["back"]), 0.0001)
	assert_almost_eq(camera.global_position.x, 0.0, 0.0001)
	assert_almost_eq(camera.global_position.y, float(settings["height"]), 0.0001)
	assert_gt((-camera.global_transform.basis.z).z, 0.0, "カメラは、走者のほう（後ろ向き）を見ている")
	# 視点を切り替えると、その視点の距離と高さで、前から見る。
	camera.call("_set_view", LocalRaceCamera.View.FAR)
	var far: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.FAR]
	assert_almost_eq(camera.global_position.z, -float(far["back"]), 0.0001)
	assert_almost_eq(camera.global_position.y, float(far["height"]), 0.0001)
	# 一人称は、回り込まない（前を見たまま。自分の体は隠す）。
	camera.call("_set_view", LocalRaceCamera.View.FIRST_PERSON)
	assert_almost_eq(camera.global_position.z, 0.0, 0.0001)
	assert_lt((-camera.global_transform.basis.z).z, 0.0)
	assert_false((target.get_node("Body") as Node3D).visible)



func _look_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func test_keyboard_look_directions_release_and_first_person() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	var camera := Camera3D.new()
	camera.set_script(LocalRaceCamera)
	camera.set("input_allowed", func() -> bool: return true)
	add_child_autofree(camera)
	camera.call("set_follow_target", target)
	var input_script = load("res://scripts/input/race_controller_input.gd")
	for keys: Array in [[KEY_A], [KEY_D], [KEY_W], [KEY_A, KEY_W], [KEY_D, KEY_W]]:
		for key: Key in keys:
			_look_key(key, true)
		var expected := Vector2(float(KEY_D in keys) - float(KEY_A in keys), float(KEY_W in keys)).normalized()
		assert_eq(input_script.look_vector(), expected)
		camera.call("_apply")
		var direction := Basis(Vector3.UP, -LocalRaceCamera.look_yaw_from_stick(expected)) * Vector3.FORWARD
		direction = Basis(direction.cross(Vector3.UP).normalized(), -deg_to_rad(LocalRaceCamera.LOOK_AROUND_PITCH_DEG)) * direction
		assert_true(camera.global_position.is_equal_approx(Vector3.UP * LocalRaceCamera.LOOK_AROUND_HEIGHT_M))
		assert_true((-camera.global_basis.z).is_equal_approx(direction))
		for key: Key in keys:
			_look_key(key, false)
	assert_eq(input_script.look_vector(), Vector2.ZERO)
	camera.call("_apply")
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
	assert_true(camera.global_position.is_equal_approx(Vector3(0.0, float(settings["height"]), float(settings["back"]))))
	camera.call("_set_view", LocalRaceCamera.View.FIRST_PERSON)
	var original_position := camera.global_position
	_look_key(KEY_W, true)
	camera.call("_apply")
	assert_true(camera.global_position.is_equal_approx(original_position))
	assert_true((-camera.global_basis.z).is_equal_approx(Vector3.BACK))
	_look_key(KEY_W, false)
	camera.call("_apply")
	assert_true((-camera.global_basis.z).is_equal_approx(Vector3.FORWARD))


func test_shift_suppresses_keyboard_look_and_keeps_adjustment() -> void:
	var camera := Camera3D.new()
	camera.set_script(LocalRaceCamera)
	camera.set("input_allowed", func() -> bool: return true)
	add_child_autofree(camera)
	var input_script = load("res://scripts/input/race_controller_input.gd")
	_look_key(KEY_SHIFT, true)
	_look_key(KEY_W, true)
	_look_key(KEY_A, true)
	assert_eq(input_script.look_vector(), Vector2.ZERO)
	camera.call("_process_keyboard_adjustment", 0.1)
	assert_almost_eq(float(camera.get("_back_offset")), -camera.get("chase_adjust_speed") * 0.1, 0.0001)
	assert_almost_eq(float(camera.get("_lateral_offset")), -camera.get("chase_adjust_speed") * 0.1, 0.0001)
	_look_key(KEY_A, false)
	_look_key(KEY_W, false)
	_look_key(KEY_SHIFT, false)


func _camera_for(target: Node3D) -> Camera3D:
	var camera := Camera3D.new()
	camera.set_script(LocalRaceCamera)
	camera.set("input_allowed", func() -> bool: return true)
	add_child_autofree(camera)
	camera.set_process(false)
	camera.call("set_follow_target", target)
	return camera


func test_front_side_and_overhead_positions_use_the_view_settings() -> void:
	var target := _finishing_target()
	target.position = Vector3(4.0, 1.0, 8.0)
	var camera := _camera_for(target)
	for view: int in [LocalRaceCamera.View.FRONT, LocalRaceCamera.View.SIDE, LocalRaceCamera.View.OVERHEAD]:
		camera.call("_set_view", view)
		var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[view]
		var forward := Basis(Vector3.UP, float(settings.get("angle", 0.0))) * Vector3.FORWARD
		var expected := target.position - forward * float(settings["back"]) + Vector3.UP * float(settings["height"])
		assert_true(camera.position.is_equal_approx(expected))
		var direction := (target.position + Vector3.UP * LocalRaceCamera.LOOK_TARGET_HEIGHT_M - expected).normalized()
		assert_true((-camera.basis.z).is_equal_approx(direction))


func test_follow_chord_waits_cancels_and_accepts_both_orders() -> void:
	var camera := _camera_for(_finishing_target())
	var steps: Array[int] = []
	var returns: Array[bool] = []
	camera.connect("follow_step_requested", func(step: int) -> void: steps.append(step))
	camera.connect("return_player_requested", func() -> void: returns.append(true))
	var window := LocalRaceCamera.FOLLOW_CHORD_SECONDS
	for first: int in [-1, 1]:
		camera.call("queue_follow_step", first, 0.0)
		camera.call("advance_follow_selection", window * 0.5)
		assert_true(steps.is_empty())
		camera.call("queue_follow_step", -first, window)
		camera.call("advance_follow_selection", window * 2.0)
		assert_true(steps.is_empty(), "同時押しでは、先の片方も切り替えない")
	assert_eq(returns.size(), 2)
	camera.call("queue_follow_step", -1, 0.0)
	camera.call("queue_follow_step", 1, window * 1.1)
	assert_eq(steps, [-1])
	camera.call("advance_follow_selection", window * 2.2)
	assert_eq(steps, [-1, 1], "時間を超えた2回は、それぞれ切り替える")
	camera.call("queue_follow_step", -1, 1.0)
	camera.call("clear_pending_follow")
	camera.call("advance_follow_selection", 1.0 + window * 2.0)
	assert_eq(steps, [-1, 1])


func test_follow_neighbors_wrap_and_use_the_current_order() -> void:
	var a := _finishing_target()
	var b := _finishing_target()
	var c := _finishing_target()
	var order := [a, b, c]
	for index in order.size():
		for step: int in [-1, 1]:
			assert_eq(LocalRaceCamera.adjacent_target(order, order[index], step), order[posmod(index + step, order.size())])
	var camera := _camera_for(b)
	order = [c, a, b]
	assert_eq(camera.get("_target"), b, "順位が変わっても、選んだ子を追う")
	assert_eq(LocalRaceCamera.adjacent_target(order, b, -1), a)
	assert_eq(LocalRaceCamera.adjacent_target(order, b, 1), c)
	assert_eq(LocalRaceCamera.adjacent_target([b], b, 1), b)
	assert_eq(LocalRaceCamera.adjacent_target([], b, 1), b)


func test_follow_switch_restores_body_and_applies_the_new_goal_time_immediately() -> void:
	var a := _finishing_target()
	var b := _finishing_target()
	var camera := _camera_for(a)
	camera.call("_set_view", LocalRaceCamera.View.FIRST_PERSON)
	assert_false((a.get_node("Body") as Node3D).visible)
	camera.call("set_follow_target", b)
	assert_true((a.get_node("Body") as Node3D).visible)
	assert_false((b.get_node("Body") as Node3D).visible)
	b.set("finished", true)
	var elapsed := LocalRaceCamera.GOAL_VIEW_DELAY_S + LocalRaceCamera.GOAL_SWING_SECONDS
	camera.call("set_follow_target", b, elapsed)
	camera.call("_set_view", LocalRaceCamera.View.DEFAULT)
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
	var expected := b.position - (Basis(Vector3.UP, LocalRaceCamera.goal_orbit_angle(elapsed)) * Vector3.FORWARD) * float(settings["back"]) + Vector3.UP * float(settings["height"])
	assert_true(camera.position.is_equal_approx(expected))
	camera.call("set_follow_target", a)
	assert_eq(camera.get("_goal_seconds"), 0.0)
	assert_true(camera.position.is_equal_approx(a.position + Vector3(0.0, float(settings["height"]), float(settings["back"]))))


func test_turn_orbits_the_target_and_first_person_turns_only_the_head() -> void:
	var target := _finishing_target()
	var camera := _camera_for(target)
	var delta := 0.5
	for turn: Vector2 in [Vector2(1.0, 0.0), Vector2(0.0, 0.6)]:
		camera.call("reset_view")
		camera.call("apply_turn", turn, delta)
		camera.call("_apply")
		var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
		var angle := (turn.x - turn.y) * float(camera.get("chase_turn_speed")) * delta
		var expected := -(Basis(Vector3.UP, angle) * Vector3.FORWARD) * float(settings["back"]) + Vector3.UP * float(settings["height"])
		assert_true(camera.position.is_equal_approx(expected))
	camera.call("_set_view", LocalRaceCamera.View.FIRST_PERSON)
	var head_position := camera.position
	camera.call("apply_turn", Vector2(1.0, 0.0), delta)
	camera.call("_apply")
	assert_true(camera.position.is_equal_approx(head_position))
	camera.call("apply_turn", Vector2.ONE, delta)
	camera.call("_apply")
	assert_eq(camera.get("view"), LocalRaceCamera.View.FIRST_PERSON)
	assert_true((-camera.basis.z).is_equal_approx(Vector3.FORWARD))


func test_keyboard_and_shoulders_share_follow_selection_and_turn_controls() -> void:
	var input_script = load("res://scripts/input/race_controller_input.gd")
	for pair: Array in [[JOY_BUTTON_LEFT_SHOULDER, KEY_COMMA, -1], [JOY_BUTTON_RIGHT_SHOULDER, KEY_PERIOD, 1]]:
		var button := InputEventJoypadButton.new()
		button.button_index = pair[0]
		button.pressed = true
		assert_eq(input_script.camera_follow_step(button), pair[2])
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		key.pressed = true
		assert_eq(input_script.camera_follow_step(key), pair[2])
		key.echo = true
		assert_eq(input_script.camera_follow_step(key), 0)
	_look_key(KEY_Q, true)
	assert_eq(input_script.camera_turn(), Vector2(1.0, 0.0))
	_look_key(KEY_E, true)
	assert_eq(input_script.camera_turn(), Vector2.ONE)
	_look_key(KEY_Q, false)
	assert_eq(input_script.camera_turn(), Vector2(0.0, 1.0))
	_look_key(KEY_E, false)


func test_disabled_input_blocks_view_switches_adjustment_and_pending_follow() -> void:
	var camera := _camera_for(_finishing_target())
	camera.set("input_allowed", func() -> bool: return false)
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_Y
	camera.call("_unhandled_input", event)
	assert_eq(camera.get("view"), LocalRaceCamera.View.DEFAULT)
	camera.call("queue_follow_step", -1, 0.0)
	_look_key(KEY_Q, true)
	camera.call("_process", LocalRaceCamera.FOLLOW_CHORD_SECONDS * 2.0)
	_look_key(KEY_Q, false)
	assert_eq(camera.get("_yaw_offset"), 0.0)
	assert_eq(camera.get("_pending_follow_step"), 0)


func test_reset_returns_default_even_after_the_goal_orbit() -> void:
	var target := _finishing_target()
	var camera := _camera_for(target)
	target.set("finished", true)
	camera.call("advance_goal_view", LocalRaceCamera.GOAL_VIEW_DELAY_S + LocalRaceCamera.GOAL_SWING_SECONDS)
	camera.call("_set_view", LocalRaceCamera.View.SIDE)
	camera.call("apply_turn", Vector2(1.0, 0.0), 0.5)
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_RIGHT_STICK
	camera.call("_unhandled_input", event)
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS[LocalRaceCamera.View.DEFAULT]
	assert_eq(camera.get("view"), LocalRaceCamera.View.DEFAULT)
	assert_true(camera.position.is_equal_approx(target.position + Vector3(0.0, float(settings["height"]), float(settings["back"])) ))


func test_race_state_allows_camera_input_from_start_through_results() -> void:
	# 場面には入れず、進行側の判定だけを確かめる。
	var controller := Node3D.new()
	controller.set_script(load("res://scripts/local_race_controller.gd"))
	assert_false(bool(controller.call("_camera_input_allowed")), "走者がまだいない")
	var runner := Node3D.new()
	(controller.get("_runners") as Array).append(runner)
	# 見せ方が終わったカウントダウンの間（スタート前）から選べる。
	assert_true(bool(controller.call("_camera_input_allowed")), "カウントダウンの間")
	# 着順の結果が出たあとも選べる。
	controller.set("_race_over", true)
	assert_true(bool(controller.call("_camera_input_allowed")), "結果のあと")
	controller.set("_race_over", false)
	# オンラインのレースでも、同じように選べる。
	controller.set("_online_view", true)
	assert_true(bool(controller.call("_camera_input_allowed")), "オンライン")
	controller.set("_online_view", false)
	controller.set("_paused", true)
	assert_false(bool(controller.call("_camera_input_allowed")), "一時停止")
	controller.set("_paused", false)
	var overlay := Control.new()
	controller.set("_paddock_overlay", overlay)
	assert_false(bool(controller.call("_camera_input_allowed")), "出走表")
	controller.set("_paddock_overlay", null)
	controller.set("_control_guide", overlay)
	assert_false(bool(controller.call("_camera_input_allowed")), "操作ガイド")
	controller.set("_control_guide", null)
	overlay.free()
	var show := Node.new()
	var script := GDScript.new()
	script.source_code = "extends Node\nfunc is_running() -> bool:\n\treturn true\n"
	script.reload()
	show.set_script(script)
	controller.set("_pre_race_show", show)
	assert_false(bool(controller.call("_camera_input_allowed")), "ゲートイン・スタート前の見せ方")
	controller.set("_pre_race_show", null)
	runner.free()
	show.free()
	# 場面の終了処理は呼ばず、判定用のノードを解放する。
	controller.set_script(null)
	controller.free()
