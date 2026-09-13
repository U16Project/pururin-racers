extends GutTest

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M2CourseBuilder := preload("res://scripts/m2_course_builder.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const M5CameraScript := preload("res://scripts/m5_camera.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func test_tokyo_stadium_length_near_2083() -> void:
	var expected := LocalRaceMath.expected_stadium_length_m()
	assert_almost_eq(expected, LocalRaceMath.TOKYO_LAP_M, 1.0)
	var curve := M2CourseBuilder.make_racecourse_curve(
		LocalRaceMath.TOKYO_STRAIGHT_M,
		LocalRaceMath.TOKYO_TURN_RADIUS_M,
		20,
		LocalRaceMath.BAKE_INTERVAL_M
	)
	assert_almost_eq(curve.get_baked_length(), LocalRaceMath.TOKYO_LAP_M, 8.0)


func test_start_leaves_final_straight_for_finish() -> void:
	assert_almost_eq(LocalRaceMath.GOAL_PATH_DISTANCE_M, 526.0, 0.1)
	assert_almost_eq(LocalRaceMath.START_PATH_DISTANCE_M, 609.0, 0.1)
	assert_eq(LocalRaceMath.RACE_DISTANCE_M, 2000.0)


func test_player_speeds_are_kmh() -> void:
	assert_eq(LocalRaceMath.PLAYER_INITIAL_SPEED_KMH, 58.0)
	assert_eq(LocalRaceMath.PLAYER_MAX_SPEED_KMH, 75.0)
	assert_lt(LocalRaceMath.PLAYER_INITIAL_SPEED_KMH, LocalRaceMath.PLAYER_MAX_SPEED_KMH)
	assert_eq(LocalRaceMath.HARD_SPEED_CAP_KMH, 90.0)


func test_target_speed_clamped_in_kmh() -> void:
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(80.0, 75.0), 75.0)
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(100.0, 90.0), 90.0)
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(40.0, 75.0), 48.0)
	assert_eq(LocalRaceMath.step_target_speed_kmh(58.0, 1.0, 75.0), 59.0)
	assert_eq(LocalRaceMath.step_target_speed_kmh(58.0, -1.0, 75.0), 57.0)


func test_drive_level_is_clamped_and_steps_by_one() -> void:
	assert_eq(LocalRaceMath.clamp_drive_level(-9.0), -3.0)
	assert_eq(LocalRaceMath.clamp_drive_level(9.0), 5.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, 1.0), 1.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, -1.0), -1.0)
	assert_eq(LocalRaceMath.step_drive_level(5.0, 1.0), 5.0)
	assert_eq(LocalRaceMath.step_drive_level(-3.0, -1.0), -3.0)


func test_local_runner_defaults_to_output_mode_and_can_toggle() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	assert_true(runner.call("is_drive_mode"))
	assert_eq(runner.call("get_current_speed"), LocalRaceMath.MIN_SPEED_KMH)
	assert_eq(runner.call("get_drive_level"), 0.0)
	assert_false(runner.call("toggle_drive_mode"))
	runner.call("set_drive_level", 99.0)
	assert_eq(runner.call("get_drive_level"), 5.0)
	assert_true(runner.call("toggle_drive_mode"))
	runner.free()


func test_drive_mode_toggle_preserves_current_speed() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	runner.call("set", "_current_speed_kmh", 63.0)
	runner.call("toggle_drive_mode")
	runner.call("toggle_drive_mode")
	assert_eq(runner.call("get_current_speed"), 63.0)
	runner.call("set", "_race_progress", 20.0)
	runner.call("set", "_current_speed_kmh", 71.0)
	runner.call("toggle_drive_mode")
	assert_eq(runner.call("get_current_speed"), 71.0)
	runner.free()


func test_drive_mode_zero_level_naturally_slows_but_respects_floor() -> void:
	var coasting := LocalRaceMath.advance_drive_speed_kmh(70.0, 0.0, 75.0, 1.0)
	assert_lt(coasting, 70.0)
	assert_eq(LocalRaceMath.advance_drive_speed_kmh(40.0, 0.0, 75.0, 1.0), 40.0)


func test_drive_mode_maximum_output_accelerates_to_cap() -> void:
	var accelerated := LocalRaceMath.advance_drive_speed_kmh(50.0, 5.0, 75.0, 1.0)
	assert_almost_eq(accelerated, 51.25, 0.001)
	assert_lte(LocalRaceMath.advance_drive_speed_kmh(74.0, 5.0, 75.0, 1.0), 75.0)


func test_drive_mode_braking_slows_but_does_not_stop() -> void:
	var braked := LocalRaceMath.advance_drive_speed_kmh(70.0, -3.0, 75.0, 1.0)
	assert_almost_eq(braked, 55.77, 0.001)
	assert_eq(LocalRaceMath.advance_drive_speed_kmh(40.0, -3.0, 75.0, 1.0), 40.0)


func test_drive_coefficients_are_moderate_for_one_second_step() -> void:
	assert_eq(LocalRaceMath.DRIVE_FORCE_BY_LEVEL_KMH_PER_S, [0.0, 1.8, 1.9, 2.2, 2.6, 3.0])
	assert_almost_eq(LocalRaceMath.BRAKE_DECELERATION_PER_LEVEL, 4.0, 0.001)
	assert_lt(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 5.0, 75.0, 1.0) - 50.0,
		5.0
	)


func test_drive_notches_use_force_minus_resistance_without_speed_bands() -> void:
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 1.0, 75.0, 1.0),
		50.05,
		0.001
	)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 5.0, 75.0, 1.0),
		51.25,
		0.001
	)


func test_drive_notch_one_is_a_small_low_speed_acceleration() -> void:
	var from_floor := LocalRaceMath.advance_drive_speed_kmh(40.0, 1.0, 75.0, 1.0)
	var at_high_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 1.0, 75.0, 1.0)
	assert_gt(from_floor, 40.0)
	assert_lt(at_high_speed, 75.0)


func test_drive_notch_three_and_zero_have_different_deceleration() -> void:
	var notch_three := LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0)
	var notch_zero := LocalRaceMath.advance_drive_speed_kmh(75.0, 0.0, 75.0, 1.0)
	assert_lt(notch_three, 75.0)
	# ノッチ3は駆動力が残るため、惰性（ノッチ0）より減速が弱い。
	assert_lt(notch_zero, notch_three)


func test_drive_notch_five_reaches_personal_cap_without_speed_band() -> void:
	var speed := 40.0
	for _i in range(60):
		speed = LocalRaceMath.advance_drive_speed_kmh(speed, 5.0, 75.0, 1.0)
	assert_almost_eq(speed, 75.0, 0.001)


func test_drafting_can_exceed_personal_max_but_respects_hard_cap() -> void:
	assert_almost_eq(LocalRaceMath.draft_speed_bonus_kmh(0.0), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.draft_speed_bonus_kmh(0.55), 4.0, 0.001)
	assert_almost_eq(LocalRaceMath.draft_speed_bonus_kmh(1.0), 4.0, 0.001)
	var drafted_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 5.0, 75.0, 1.0, 0.55)
	assert_almost_eq(drafted_speed, 76.64, 0.001)
	var open_speed := 75.0
	open_speed = LocalRaceMath.advance_drive_speed_kmh(open_speed, 5.0, 75.0, 1.0, 0.0)
	assert_almost_eq(open_speed, 75.0, 0.001)


func test_zero_notch_keeps_stamina_unchanged() -> void:
	assert_eq(LocalRaceMath.stamina_delta_per_s(0.0), 0.0)
	assert_gt(LocalRaceMath.stamina_delta_per_s(-1.0), 0.0)
	assert_lt(LocalRaceMath.stamina_delta_per_s(1.0), 1.0)


func test_live_place_keeps_finished_order_fixed() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player := Node3D.new()
	var first := Node3D.new()
	var later := Node3D.new()
	for runner in [player, first, later]:
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 0, 75.0, runner == player, "テスト")
	player.set("_race_progress", LocalRaceMath.RACE_DISTANCE_M)
	player.call("mark_finished", 2, 10.0)
	first.set("_race_progress", LocalRaceMath.RACE_DISTANCE_M)
	first.call("mark_finished", 1, 9.0)
	later.set("_race_progress", LocalRaceMath.RACE_DISTANCE_M)
	later.call("mark_finished", 3, 11.0)
	var racers: Array[Node3D] = [player, first, later]
	race.set("_runners", racers)
	assert_eq(race.call("_live_place", player), 2)
	# 後続のゴール後も、プレイヤーの確定順位は変わらない。
	assert_eq(race.call("_live_place", player), 2)
	player.free()
	first.free()
	later.free()
	race.free()


func test_local_hud_shows_drafting_status_and_bonus() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player := Node3D.new()
	player.set_script(RunnerScript)
	add_child(player)
	player.call("setup_for_race", null, 0, 75.0, true, "あなた")
	player.set("_drafting", true)
	player.set("_draft_bonus_kmh", 4.0)
	race.set("_player", player)
	race.call("_update_hud")
	var hud: Label = race.get_node("UI/HudLabel")
	assert_true(hud.text.contains("ドラフト中 +4.0km/h"))
	player.set("_drafting", false)
	race.call("_update_hud")
	assert_true(hud.text.contains("単独走"))
	player.free()
	race.free()


func test_local_race_uses_m5_camera_with_chase_controls() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var camera: Camera3D = race.get_node("Camera3D")
	assert_eq(camera.get_script(), M5CameraScript)
	assert_eq(camera.get("mode"), 0)
	assert_eq(camera.get("follow_distance"), 12.0)
	var target := Node3D.new()
	add_child(target)
	target.global_position = Vector3(3.0, 0.0, 4.0)
	camera.call("set_follow_target", target)
	camera.call("_process", 0.0)
	var initial_position := camera.global_position
	camera.set("_follow_yaw", PI * 0.5)
	camera.call("_process", 0.0)
	assert_almost_eq(camera.global_position.x, initial_position.x, 0.001)
	assert_almost_eq(camera.global_position.z, initial_position.z, 0.001)
	camera.set("follow_distance", 30.0)
	camera.set("_follow_lateral", 8.0)
	camera.call("_reset_chase_adjustment")
	assert_eq(camera.get("follow_distance"), 12.0)
	assert_eq(camera.get("_follow_lateral"), 0.0)
	target.free()
	race.free()


func test_local_goal_display_matches_m5_layout() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var goal_marker: MeshInstance3D = race.get_node("GoalMarker")
	assert_true(goal_marker.mesh is BoxMesh)
	assert_almost_eq((goal_marker.mesh as BoxMesh).size.z, 0.12, 0.001)
	assert_almost_eq(goal_marker.position.y, 0.14, 0.001)
	var goal_sign: Label3D = race.get_node("TrackPath/GoalSign")
	assert_eq(goal_sign.text, "GOAL")
	assert_eq(goal_sign.font_size, 720)
	assert_eq(goal_sign.billboard, BaseMaterial3D.BILLBOARD_DISABLED)
	assert_almost_eq(goal_sign.global_position.y, 8.4, 0.001)
	var goal_panel: MeshInstance3D = race.get_node("TrackPath/GoalPanel")
	assert_true(goal_panel.mesh is BoxMesh)
	assert_almost_eq((goal_panel.mesh as BoxMesh).size.x, 19.0, 0.001)
	assert_almost_eq((goal_panel.mesh as BoxMesh).size.y, 4.0, 0.001)
	assert_almost_eq(goal_panel.global_position.y, 2.0, 0.001)
	assert_true(goal_sign.global_basis.is_equal_approx(goal_panel.global_basis))
	var panel_material := goal_panel.material_override as StandardMaterial3D
	assert_eq(panel_material.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA)
	assert_almost_eq(panel_material.albedo_color.a, 0.055, 0.001)
	assert_true(panel_material.emission_enabled)
	var goal_glow: MeshInstance3D = race.get_node("TrackPath/GoalGlowLine")
	assert_true(goal_glow.mesh is BoxMesh)
	assert_almost_eq((goal_glow.mesh as BoxMesh).size.z, 0.7, 0.001)
	assert_eq(race.get_node("TrackPath/GoalPanelFrame").get_child_count(), 4)
	race.free()


func test_drive_mode_has_no_curve_or_line_speed_penalty() -> void:
	var straight := LocalRaceMath.advance_drive_speed_kmh(60.0, 2.0, 75.0, 1.0)
	var draftless := LocalRaceMath.advance_drive_speed_kmh(60.0, 2.0, 75.0, 1.0, 0.0)
	assert_eq(straight, draftless)


func test_drafting_reduces_air_resistance_only() -> void:
	var open := LocalRaceMath.drive_resistance_kmh_per_s(70.0, 0.0)
	var drafted := LocalRaceMath.drive_resistance_kmh_per_s(70.0, 1.0)
	assert_lt(drafted, open)


func test_follow_speed_approaches_target() -> void:
	var s := LocalRaceMath.follow_speed_kmh(50.0, 58.0, 0.2)
	assert_gt(s, 50.0)
	assert_lt(s, 58.0)
	assert_eq(LocalRaceMath.follow_speed_kmh(57.5, 58.0, 1.0), 58.0)


func test_block_caps_speed_when_ahead() -> void:
	var others := [
		{"distance": 5.0, "offset": 0.0, "speed": 54.0},
	]
	var blocker := LocalRaceMath.blocking_speed_kmh(4.0, 0.0, others, 2083.0)
	assert_eq(blocker, 54.0)
	assert_almost_eq(LocalRaceMath.apply_block_cap_kmh(75.0, blocker), 54.0, 0.001)


func test_no_block_when_laterally_clear() -> void:
	var others := [
		{"distance": 5.0, "offset": 3.0, "speed": 54.0},
	]
	var blocker := LocalRaceMath.blocking_speed_kmh(4.0, 0.0, others, 2083.0)
	assert_eq(blocker, -1.0)


func test_contact_overlap_is_detected() -> void:
	assert_true(LocalRaceMath.contact_overlaps(10.0, 0.0, 10.5, 0.8))
	assert_false(LocalRaceMath.contact_overlaps(10.0, 0.0, 12.0, 0.8))
	assert_false(LocalRaceMath.contact_overlaps(10.0, 0.0, 10.5, 2.0))


func test_race_progress_finishes_at_2000() -> void:
	var p := 0.0
	p = LocalRaceMath.add_race_progress(p, 1999.0)
	assert_false(LocalRaceMath.has_finished(p))
	p = LocalRaceMath.add_race_progress(p, 2.0)
	assert_true(LocalRaceMath.has_finished(p))


func test_kmh_advance_matches_divide_by_36() -> void:
	# 36 km/h で 1 秒 → 10 m（曲率0・倍率1）。
	var d := LocalRaceMath.centerline_delta_from_kmh(36.0, 1.0, 0.0, 0.0)
	assert_almost_eq(d, 10.0, 0.001)


func test_race_time_uses_competition_style_minutes() -> void:
	assert_eq(LocalRaceMath.format_race_time(58.44), "58.4")
	assert_eq(LocalRaceMath.format_race_time(83.44), "1:23.4")
	assert_eq(LocalRaceMath.format_race_time(125.0), "2:05.0")


func test_innermost_gate_is_most_negative_offset() -> void:
	var gate0 := LocalRaceMath.starting_offset_for_gate(0)
	var gate7 := LocalRaceMath.starting_offset_for_gate(7)
	assert_lt(gate0, gate7)
	assert_lt(gate0, 0.0)
