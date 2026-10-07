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
