extends GutTest

const LocalRaceCamera := preload("res://scripts/local_race_camera.gd")


func test_views_cycle_through_all_four_and_return_to_the_default() -> void:
	var view := LocalRaceCamera.View.DEFAULT
	var seen := [view]
	for _i in LocalRaceCamera.VIEW_ORDER.size() - 1:
		view = LocalRaceCamera.next_view(view)
		seen.append(view)
	assert_eq(seen.size(), 4)
	for expected: int in LocalRaceCamera.View.values():
		assert_true(expected in seen)
	assert_eq(LocalRaceCamera.next_view(view), LocalRaceCamera.View.DEFAULT)


func test_view_settings_match_the_intended_shapes() -> void:
	var settings: Dictionary = LocalRaceCamera.VIEW_SETTINGS
	# 遠距離は、デフォルトより後ろ。一人称は距離0で、まっすぐ前を見る。上空は、後ろより上が大きい。
	assert_gt(float(settings[LocalRaceCamera.View.FAR]["back"]), float(settings[LocalRaceCamera.View.DEFAULT]["back"]))
	assert_eq(float(settings[LocalRaceCamera.View.FIRST_PERSON]["back"]), 0.0)
	assert_true(bool(settings[LocalRaceCamera.View.FIRST_PERSON]["look_ahead"]))
	assert_gt(float(settings[LocalRaceCamera.View.OVERHEAD]["height"]), float(settings[LocalRaceCamera.View.OVERHEAD]["back"]))


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

