extends GutTest

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M2CourseBuilder := preload("res://scripts/m2_course_builder.gd")


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


func test_target_speed_clamped_to_tier() -> void:
	assert_eq(LocalRaceMath.clamp_target_speed(20.0, 15.0), 15.0)
	assert_eq(LocalRaceMath.clamp_target_speed(30.0, LocalRaceMath.PLAYER_MAX_SPEED), 25.0)
	assert_eq(LocalRaceMath.clamp_target_speed(5.0, 15.0), 8.0)
	assert_eq(LocalRaceMath.step_target_speed(14.0, 1.0, 15.0), 15.0)
	assert_eq(LocalRaceMath.step_target_speed(14.0, -1.0, 15.0), 13.0)


func test_follow_speed_approaches_target() -> void:
	var s := LocalRaceMath.follow_speed(10.0, 15.0, 0.5)
	assert_gt(s, 10.0)
	assert_lt(s, 15.0)
	assert_eq(LocalRaceMath.follow_speed(14.9, 15.0, 1.0), 15.0)


func test_block_caps_speed_when_ahead() -> void:
	var others := [
		{"distance": 5.0, "offset": 0.0, "speed": 12.0},
	]
	var blocker := LocalRaceMath.blocking_speed(4.0, 0.0, others, 2083.0)
	assert_eq(blocker, 12.0)
	assert_almost_eq(LocalRaceMath.apply_block_cap(15.0, blocker), 12.0, 0.001)


func test_no_block_when_laterally_clear() -> void:
	var others := [
		{"distance": 5.0, "offset": 3.0, "speed": 12.0},
	]
	var blocker := LocalRaceMath.blocking_speed(4.0, 0.0, others, 2083.0)
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


func test_race_time_uses_competition_style_minutes() -> void:
	assert_eq(LocalRaceMath.format_race_time(58.44), "58.4")
	assert_eq(LocalRaceMath.format_race_time(83.44), "1:23.4")
	assert_eq(LocalRaceMath.format_race_time(125.0), "2:05.0")


func test_innermost_gate_is_most_negative_offset() -> void:
	var gate0 := LocalRaceMath.starting_offset_for_gate(0)
	var gate7 := LocalRaceMath.starting_offset_for_gate(7)
	assert_lt(gate0, gate7)
	assert_lt(gate0, 0.0)
