extends GutTest

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M2CourseBuilder := preload("res://scripts/m2_course_builder.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const M5CameraScript := preload("res://scripts/m5_camera.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func test_local_course_uses_shared_m5_layout() -> void:
	var expected := LocalRaceMath.expected_stadium_length_m()
	assert_almost_eq(expected, LocalRaceMath.lap_length_m(), 0.2)
	assert_almost_eq(LocalRaceMath.straight_length_m(), 680.0, 0.001)
	assert_almost_eq(LocalRaceMath.turn_radius_m(), 115.085, 0.001)
	var curve := M2CourseBuilder.make_racecourse_curve(
		LocalRaceMath.straight_length_m(),
		LocalRaceMath.turn_radius_m(),
		20,
		LocalRaceMath.BAKE_INTERVAL_M
	)
	assert_almost_eq(curve.get_baked_length(), LocalRaceMath.lap_length_m(), 8.0)


func test_start_leaves_straight_before_the_first_turn_and_after_the_goal() -> void:
	var straight := LocalRaceMath.straight_length_m()
	var goal := LocalRaceMath.goal_path_m()
	var start := LocalRaceMath.start_path_m()
	assert_eq(LocalRaceMath.RACE_DISTANCE_M, 2000.0)
	assert_almost_eq(goal, 400.0, 0.1)
	assert_almost_eq(start, 483.1, 0.1)
	assert_lt(start, straight)
	assert_gt(straight - start, 150.0)
	assert_gt(straight - goal, 200.0)
	assert_almost_eq(
		fposmod(start + LocalRaceMath.RACE_DISTANCE_M, LocalRaceMath.lap_length_m()),
		goal,
		0.1
	)


func test_local_race_scene_applies_shared_course_before_the_field_starts() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var track: Path3D = race.get_node("TrackPath")
	assert_almost_eq(track.call("get_straight_len"), 680.0, 0.001)
	assert_almost_eq(track.call("get_turn_radius"), 115.085, 0.001)
	assert_almost_eq(track.curve.get_baked_length(), LocalRaceMath.lap_length_m(), 8.0)
	var player: Node = race.get_node("Runners/Runner1")
	assert_almost_eq(player.call("get_distance"), LocalRaceMath.start_path_m(), 0.1)
	assert_false(player.call("is_race_active"))
	assert_eq(player.call("get_drive_level"), 4.0)
	var goal: MeshInstance3D = race.get_node("GoalMarker")
	var expected_goal := track.curve.sample_baked(LocalRaceMath.goal_path_m())
	assert_almost_eq(goal.global_position.x, expected_goal.x, 0.5)
	assert_almost_eq(goal.global_position.z, expected_goal.z, 0.5)
	race.free()


func test_start_countdown_config_uses_default_notch_four_and_faster_cpu_launch() -> void:
	var config := LocalRaceMath.Config.values()
	assert_eq(config["start_countdown_seconds"], 3.0)
	assert_eq(config["player_start_drive_level"], 4.0)
	assert_eq(config["cpu_start_drive_level"], 5.0)
	assert_eq(config["cpu_start_drive_duration_seconds"], 1.0)
	assert_true(LocalRaceMath.Config.validate(config).is_empty())


func test_countdown_keeps_runners_still_then_starts_everyone_together() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	var cpu: Node = race.get_node("Runners/Runner2")
	var start_distance: float = player.call("get_distance")
	race.call("_update_start_countdown", 2.9)
	assert_false(player.call("is_race_active"))
	assert_false(cpu.call("is_race_active"))
	assert_almost_eq(player.call("get_distance"), start_distance, 0.001)
	race.call("_update_start_countdown", 0.2)
	assert_true(player.call("is_race_active"))
	assert_true(cpu.call("is_race_active"))
	assert_eq(player.call("get_drive_level"), 4.0)
	race.free()


func test_player_speeds_are_kmh() -> void:
	assert_eq(LocalRaceMath.PLAYER_INITIAL_SPEED_KMH, 58.0)
	assert_eq(LocalRaceMath.PLAYER_MAX_SPEED_KMH, 75.0)
	assert_lt(LocalRaceMath.PLAYER_INITIAL_SPEED_KMH, LocalRaceMath.PLAYER_MAX_SPEED_KMH)
	assert_eq(LocalRaceMath.HARD_SPEED_CAP_KMH, 90.0)


func test_top_speed_maps_one_to_fifteen_directly_without_per_runner_tiers() -> void:
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(1), 61.0)
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(5), 65.0)
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(8), 68.0)
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(15), 75.0)
	assert_almost_eq(LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(5), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(8), 0.36, 0.001)
	assert_almost_eq(_natural_speed_after_sixty_seconds(1, 5), 61.0, 0.05)
	assert_almost_eq(_natural_speed_after_sixty_seconds(15, 5), 75.0, 0.05)


func test_local_player_uses_roster_effective_top_speed_and_acceleration() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	var stats: Dictionary = player.call("get_effective_stats")
	assert_eq(stats["top_speed"], 8)
	assert_eq(stats["acceleration"], 5)
	assert_almost_eq(player.call("get_natural_top_speed"), 68.0, 0.001)
	assert_almost_eq(player.call("get_max_speed"), LocalRaceMath.HARD_SPEED_CAP_KMH, 0.001)
	assert_almost_eq(player.call("get_acceleration_force_bonus"), 0.0, 0.001)
	race.free()


func test_cpu_runner_uses_its_roster_trainer_profile_instead_of_gate_cycle() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	# モモ（gate 5）は旧ゲート循環なら front になるが、roster 指定は balanced。
	var momo: Dictionary = PururinRosterConfig.pururin_by_id("cpu-5")
	runner.call("setup_for_race", null, 5, 75.0, false, str(momo["display_name"]), momo)
	var profile: Dictionary = runner.get("_cpu_trainer_profile")
	assert_eq(profile["id"], "balanced")
	runner.free()


func test_cpu_telemetry_uses_trainer_drive_level_for_drive_diagnostics() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	var momo: Dictionary = PururinRosterConfig.pururin_by_id("cpu-5")
	runner.call("setup_for_race", null, 5, 75.0, false, str(momo["display_name"]), momo)
	runner.set("_current_speed_kmh", 60.0)
	runner.set("_cpu_trainer_drive_level", 4.0)
	var telemetry: Dictionary = runner.call("get_telemetry_snapshot")
	var diagnostics: Dictionary = telemetry["drive_diagnostics"]
	var effective_stats: Dictionary = runner.call("get_effective_stats")
	var expected: Dictionary = LocalRaceMath.drive_diagnostics_kmh_per_s(
		60.0,
		4.0,
		0.0,
		runner.call("get_acceleration_force_bonus"),
		LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(
			60.0, 4.0, int(effective_stats["top_speed"])
		),
		1.0
	)
	assert_eq(telemetry["drive_level"], 4.0)
	assert_almost_eq(
		float(diagnostics["drive_contribution_kmh_per_s"]),
		float(expected["drive_contribution_kmh_per_s"]),
		0.001
	)
	runner.free()


func _natural_speed_after_sixty_seconds(top_speed: int, acceleration: int) -> float:
	var speed := LocalRaceMath.MIN_SPEED_KMH
	for _index in 6000:
		var top_speed_adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(speed, 6.0, top_speed)
		speed = LocalRaceMath.advance_drive_speed_kmh(
			speed,
			6.0,
			LocalRaceMath.HARD_SPEED_CAP_KMH,
			0.01,
			0.0,
			LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(acceleration),
			top_speed_adjustment
		)
	return speed


func test_target_speed_clamped_in_kmh() -> void:
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(80.0, 75.0), 75.0)
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(100.0, 90.0), 90.0)
	assert_eq(LocalRaceMath.clamp_target_speed_kmh(40.0, 75.0), 48.0)
	assert_eq(LocalRaceMath.step_target_speed_kmh(58.0, 1.0, 75.0), 59.0)
	assert_eq(LocalRaceMath.step_target_speed_kmh(58.0, -1.0, 75.0), 57.0)


func test_drive_level_is_clamped_and_steps_by_one() -> void:
	assert_eq(LocalRaceMath.clamp_drive_level(-9.0), -3.0)
	assert_eq(LocalRaceMath.clamp_drive_level(9.0), 6.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, 1.0), 1.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, -1.0), -1.0)
	assert_eq(LocalRaceMath.step_drive_level(5.0, 1.0), 6.0)
	assert_eq(LocalRaceMath.step_drive_level(6.0, 1.0), 6.0)
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
	assert_eq(runner.call("get_drive_level"), 6.0)
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
	var accelerated := LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0)
	assert_almost_eq(accelerated, 53.65, 0.001)
	assert_lte(LocalRaceMath.advance_drive_speed_kmh(74.0, 6.0, 75.0, 1.0), 75.0)


func test_drive_mode_braking_slows_but_does_not_stop() -> void:
	var braked := LocalRaceMath.advance_drive_speed_kmh(70.0, -3.0, 75.0, 1.0)
	assert_almost_eq(braked, 51.57, 0.001)
	assert_eq(LocalRaceMath.advance_drive_speed_kmh(40.0, -3.0, 75.0, 1.0), 40.0)


func test_drive_coefficients_are_moderate_for_one_second_step() -> void:
	assert_eq(LocalRaceMath.DRIVE_FORCE_BY_LEVEL_KMH_PER_S, [0.0, 3.0, 3.5, 4.3, 5.0, 5.8, 7.2])
	assert_almost_eq(LocalRaceMath.BRAKE_DECELERATION_PER_LEVEL, 4.0, 0.001)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0) - 50.0,
		3.65,
		0.001
	)


func test_drive_notches_use_force_minus_resistance_without_speed_bands() -> void:
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 1.0, 75.0, 1.0),
		49.45,
		0.001
	)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0),
		53.65,
		0.001
	)


func test_drive_notch_one_holds_minimum_speed_when_resistance_exceeds_force() -> void:
	var from_floor := LocalRaceMath.advance_drive_speed_kmh(40.0, 1.0, 75.0, 1.0)
	var at_high_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 1.0, 75.0, 1.0)
	# 40km/h時の抵抗は0.55 + 0.00120×40² = 2.47で、ノッチ1の3.0は少し上回る。
	var diagnostics := LocalRaceMath.drive_diagnostics_kmh_per_s(40.0, 1.0)
	assert_almost_eq(float(diagnostics["air_resistance_kmh_per_s"]), 1.92, 0.001)
	assert_almost_eq(float(diagnostics["total_acceleration_kmh_per_s"]), 0.53, 0.001)
	assert_gt(from_floor, 40.0)
	assert_lt(at_high_speed, 75.0)


func test_drive_notches_one_to_three_accelerate_from_floor_and_slow_at_high_speed() -> void:
	var previous_from_floor := LocalRaceMath.MIN_SPEED_KMH
	for level in [1.0, 2.0, 3.0]:
		var from_floor := LocalRaceMath.advance_drive_speed_kmh(
			LocalRaceMath.MIN_SPEED_KMH, level, 75.0, 1.0
		)
		assert_gt(from_floor, previous_from_floor)
		assert_lt(LocalRaceMath.advance_drive_speed_kmh(75.0, level, 75.0, 1.0), 75.0)
		previous_from_floor = from_floor


func test_drive_notch_three_and_zero_have_different_deceleration() -> void:
	var notch_three := LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0)
	var notch_zero := LocalRaceMath.advance_drive_speed_kmh(75.0, 0.0, 75.0, 1.0)
	assert_lt(notch_three, 75.0)
	# ノッチ3は駆動力が残るため、惰性（ノッチ0）より減速が弱い。
	assert_lt(notch_zero, notch_three)


func test_drive_notch_six_respects_personal_cap_without_speed_band() -> void:
	var speed := LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0)
	assert_almost_eq(speed, 53.65, 0.001)
	assert_lt(LocalRaceMath.advance_drive_speed_kmh(75.0, 6.0, 75.0, 1.0), 75.0)


func test_drive_notch_three_naturally_slows_near_personal_cap() -> void:
	var next_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0)
	assert_lt(next_speed, 75.0)
	assert_gt(next_speed, LocalRaceMath.advance_drive_speed_kmh(75.0, 0.0, 75.0, 1.0))


func test_drive_diagnostics_explain_force_resistance_and_draft_reduction() -> void:
	var open := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.0)
	assert_almost_eq(float(open["drive_contribution_kmh_per_s"]), 7.2, 0.001)
	assert_almost_eq(float(open["rolling_resistance_kmh_per_s"]), 0.55, 0.001)
	assert_almost_eq(float(open["air_resistance_kmh_per_s"]), 3.0, 0.001)
	assert_almost_eq(float(open["draft_air_reduction_kmh_per_s"]), 0.0, 0.001)
	assert_almost_eq(float(open["total_acceleration_kmh_per_s"]), 3.65, 0.001)
	var drafted := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.55)
	assert_almost_eq(float(drafted["draft_air_reduction_kmh_per_s"]), 1.65, 0.001)
	assert_almost_eq(float(drafted["total_acceleration_kmh_per_s"]), 5.3, 0.001)


func test_draft_response_curve_caps_local_effective_ratio() -> void:
	var half_received := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.5
	var three_quarters_received := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.75
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(0.0), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(half_received), 0.15, 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(three_quarters_received), 0.60 * pow(0.75, 2.0), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(LocalRaceMath.DRAFT_MAX_RECEIVED_P), 0.60, 0.001)
	assert_almost_eq(LocalRaceMath.draft_air_resistance_factor(half_received), 0.55 * 0.15, 0.001)
	assert_almost_eq(LocalRaceMath.draft_air_resistance_factor(three_quarters_received), 0.55 * 0.60 * pow(0.75, 2.0), 0.001)
	assert_almost_eq(LocalRaceMath.draft_air_resistance_factor(LocalRaceMath.DRAFT_MAX_RECEIVED_P), 0.55 * 0.60, 0.001)
	assert_almost_eq(LocalRaceMath.draft_assist_speed_kmh(half_received), 4.0 * 0.15, 0.001)
	assert_almost_eq(LocalRaceMath.draft_assist_speed_kmh(three_quarters_received), 4.0 * 0.60 * pow(0.75, 2.0), 0.001)
	assert_almost_eq(LocalRaceMath.draft_assist_speed_kmh(LocalRaceMath.DRAFT_MAX_RECEIVED_P), 2.4, 0.001)


func test_draft_aggregation_uses_same_general_formula_for_one_two_and_three_sources() -> void:
	var contribution := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.48
	var one := LocalRaceMath.draft_aggregate_contributions_p([contribution]) / LocalRaceMath.DRAFT_MAX_RECEIVED_P
	var two := LocalRaceMath.draft_aggregate_contributions_p([contribution, contribution]) / LocalRaceMath.DRAFT_MAX_RECEIVED_P
	var three := LocalRaceMath.draft_aggregate_contributions_p([contribution, contribution, contribution]) / LocalRaceMath.DRAFT_MAX_RECEIVED_P
	assert_almost_eq(LocalRaceMath.DRAFT_EFFECTIVE_MAX_RATIO * pow(one, LocalRaceMath.DRAFT_RESPONSE_EXPONENT), 0.138, 0.002)
	assert_almost_eq(LocalRaceMath.DRAFT_EFFECTIVE_MAX_RATIO * pow(two, LocalRaceMath.DRAFT_RESPONSE_EXPONENT), 0.253, 0.002)
	assert_almost_eq(LocalRaceMath.DRAFT_EFFECTIVE_MAX_RATIO * pow(three, LocalRaceMath.DRAFT_RESPONSE_EXPONENT), 0.360, 0.002)
	assert_eq(LocalRaceMath.draft_aggregate_contributions_p([]), 0.0)
	assert_almost_eq(LocalRaceMath.draft_aggregate_contributions_p([contribution * 10.0]), LocalRaceMath.DRAFT_MAX_RECEIVED_P, 0.001)
	assert_almost_eq(LocalRaceMath.draft_assist_speed_kmh(LocalRaceMath.DRAFT_MAX_RECEIVED_P), 2.4, 0.001)


func test_draft_response_curve_reduces_air_resistance_with_local_cap() -> void:
	var half_received := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.5
	var three_quarters_received := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.75
	var open := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, 0.0)
	var half := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(half_received))
	var three_quarters := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(three_quarters_received))
	var maximum := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(LocalRaceMath.DRAFT_MAX_RECEIVED_P))
	assert_almost_eq(float(open["draft_air_reduction_kmh_per_s"]), 0.0, 0.001)
	assert_almost_eq(float(half["draft_air_reduction_kmh_per_s"]), 3.0 * 0.55 * 0.15, 0.001)
	assert_almost_eq(float(three_quarters["draft_air_reduction_kmh_per_s"]), 3.0 * 0.55 * 0.60 * pow(0.75, 2.0), 0.001)
	assert_almost_eq(float(maximum["draft_air_reduction_kmh_per_s"]), 0.99, 0.001)


func test_quadratic_air_resistance_grows_with_speed_and_draft_keeps_rolling_resistance() -> void:
	var low := LocalRaceMath.drive_diagnostics_kmh_per_s(40.0, 0.0, 0.0)
	var high := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 0.0, 0.0)
	var drafted := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 0.0, 1.0)
	assert_lt(float(low["air_resistance_kmh_per_s"]), float(high["air_resistance_kmh_per_s"]))
	assert_almost_eq(float(low["air_resistance_kmh_per_s"]), 1.92, 0.001)
	assert_almost_eq(float(high["air_resistance_kmh_per_s"]), 6.75, 0.001)
	assert_almost_eq(float(drafted["rolling_resistance_kmh_per_s"]), float(high["rolling_resistance_kmh_per_s"]), 0.001)
	assert_lt(float(drafted["air_resistance_kmh_per_s"]) - float(drafted["draft_air_reduction_kmh_per_s"]), float(high["air_resistance_kmh_per_s"]))


func test_high_speed_notches_change_by_force_curve_without_special_band() -> void:
	var level_three := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 3.0)
	var level_four := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 4.0)
	var level_five := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 5.0)
	var level_six := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 6.0)
	assert_lt(float(level_three["total_acceleration_kmh_per_s"]), 0.0)
	assert_lt(float(level_four["total_acceleration_kmh_per_s"]), 0.0)
	assert_gt(float(level_five["total_acceleration_kmh_per_s"]), float(level_four["total_acceleration_kmh_per_s"]))
	assert_gt(float(level_six["total_acceleration_kmh_per_s"]), float(level_five["total_acceleration_kmh_per_s"]))
	assert_lt(float(level_five["total_acceleration_kmh_per_s"]), 0.0)
	assert_lt(float(level_six["total_acceleration_kmh_per_s"]), 0.0)


func test_cpu_lane_changes_stay_inside_configured_ranges() -> void:
	assert_almost_eq(LocalRaceMath.cpu_steer_reselect_interval_s(0.0), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.cpu_steer_reselect_interval_s(1.0), 2.0, 0.001)
	var current_offset := 0.5
	var inward := LocalRaceMath.cpu_next_target_offset_m(current_offset, 0.0)
	var biased := LocalRaceMath.cpu_next_target_offset_m(current_offset, 1.0)
	assert_lte(absf(inward - current_offset), 1.2)
	assert_lte(absf(biased - current_offset), 1.2)
	assert_lt(inward, current_offset)
	assert_lt(biased, current_offset)


func test_cpu_follow_selection_uses_one_score_and_falls_back_when_no_runner_is_ahead() -> void:
	var selected := LocalRaceMath.cpu_follow_candidate(100.0, 0.0, [
		{"id": "far-line", "race_progress": 104.0, "offset": 3.5},
		{"id": "near-gap", "race_progress": 103.5, "offset": 0.5},
		{"id": "behind", "race_progress": 99.0, "offset": 0.0},
	])
	assert_true(selected["found"])
	assert_eq(selected["id"], "near-gap")
	assert_almost_eq(float(selected["forward_gap_m"]), 3.5, 0.001)
	var none := LocalRaceMath.cpu_follow_candidate(100.0, 0.0, [
		{"id": "behind", "race_progress": 99.0, "offset": 0.0},
		{"id": "wide", "race_progress": 104.0, "offset": 4.1},
	])
	assert_false(none["found"])
	assert_almost_eq(LocalRaceMath.cpu_next_target_offset_m(0.5, 1.0), -0.415, 0.001)


func test_cpu_open_line_target_keeps_current_line_when_nearby_space_is_open() -> void:
	var selected := LocalRaceMath.cpu_open_line_target_offset_m(100.0, 2.0, [
		{"id": "behind", "race_progress": 98.0, "offset": -4.1},
	], 0.8)
	assert_true(selected["found"])
	assert_eq(str(selected["name"]), "open_line")
	assert_almost_eq(float(selected["offset"]), 2.0, 0.001)


func test_cpu_line_distance_advantage_is_zero_on_straight_and_favors_inner_on_curve() -> void:
	assert_almost_eq(LocalRaceMath.cpu_line_distance_advantage_score(-2.0, 0.0), 0.0, 0.001)
	assert_lt(
		LocalRaceMath.cpu_line_distance_advantage_score(-2.0, 0.05),
		LocalRaceMath.cpu_line_distance_advantage_score(2.0, 0.05)
	)


func test_cpu_open_line_target_uses_an_open_side_when_current_line_is_dense() -> void:
	var selected := LocalRaceMath.cpu_open_line_target_offset_m(100.0, 0.0, [
		{"id": "left", "race_progress": 100.0, "offset": -0.2},
		{"id": "right", "race_progress": 100.0, "offset": 0.2},
	], 0.5)
	assert_true(selected["found"])
	assert_ne(float(selected["offset"]), 0.0)


func test_cpu_follow_offset_is_bounded() -> void:
	assert_almost_eq(LocalRaceMath.cpu_follow_target_offset_m(-2.0, 2.0), 0.6, 0.001)
	assert_almost_eq(
		LocalRaceMath.cpu_follow_target_offset_m(M2TrackMath.MAX_ABS_OFFSET_M, 99.0),
		M2TrackMath.MAX_ABS_OFFSET_M,
		0.001
	)


func test_cpu_follow_slots_choose_open_diagonal_and_prefer_inner_on_a_tie() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var crowded_center := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [
		leader,
		{"id": "center-occupant", "race_progress": 100.0, "offset": 0.0},
	])
	assert_true(crowded_center["found"])
	assert_eq(crowded_center["name"], "inner")
	assert_almost_eq(float(crowded_center["offset"]), -1.2, 0.001)
	var open_slots := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [leader])
	assert_eq(open_slots["name"], "inner")
	var inner_crowded := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [
		leader,
		{"id": "inner-occupant", "race_progress": 100.0, "offset": -1.2},
	])
	assert_eq(inner_crowded["name"], "outer")


func test_cpu_follow_slot_is_bounded_and_no_candidate_keeps_fallback_path() -> void:
	var no_candidate := LocalRaceMath.cpu_follow_slot(100.0, 0.0, {"found": false}, [])
	assert_false(no_candidate["found"])
	var edge_slot := LocalRaceMath.cpu_follow_slot(100.0, 0.0, {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": M2TrackMath.MAX_ABS_OFFSET_M,
	}, [])
	assert_true(edge_slot["found"])
	assert_lte(absf(float(edge_slot["offset"])), M2TrackMath.MAX_ABS_OFFSET_M)
	assert_almost_eq(LocalRaceMath.cpu_next_target_offset_m(0.5, 1.0), -0.415, 0.001)


func test_cpu_follow_slot_positive_bias_uses_clear_forward_diagonal() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var selected := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [leader], 1.0)
	assert_true(selected["found"])
	assert_true(str(selected["name"]).begins_with("overtake_"))
	assert_gt(float(selected["progress"]), float(leader["race_progress"]))


func test_cpu_follow_slot_probes_open_forward_lane_when_local_field_is_dense() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var selected := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [
		leader,
		{"id": "near-left", "race_progress": 100.0, "offset": -1.0},
		{"id": "near-right", "race_progress": 100.0, "offset": 1.0},
	], 0.0)
	assert_true(selected["found"])
	assert_true(str(selected["name"]).begins_with("overtake_"))
	assert_gt(float(selected["progress"]), float(leader["race_progress"]))


func test_cpu_follow_slot_field_density_penalizes_occupied_slot() -> void:
	var density := LocalRaceMath._cpu_follow_slot_field_density(100.0, 0.0, "leader", [
		{"id": "leader", "race_progress": 104.0, "offset": 0.0},
		{"id": "occupant", "race_progress": 100.0, "offset": 0.0},
	])
	assert_gt(density, 0.0)


func test_cpu_follow_slot_prefers_inner_line_when_slots_are_similarly_open() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var selected := LocalRaceMath.cpu_follow_slot(100.0, 6.0, leader, [leader])
	assert_true(selected["found"])
	assert_eq(str(selected["name"]), "inner")
	assert_lt(float(selected["offset"]), 0.0)


func test_cpu_follow_slot_zero_or_negative_bias_keeps_rear_slots() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var default_slot := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [leader])
	var patient_slot := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [leader], -1.0)
	assert_false(str(default_slot["name"]).begins_with("overtake_"))
	assert_false(str(patient_slot["name"]).begins_with("overtake_"))
	assert_lt(float(default_slot["progress"]), float(leader["race_progress"]))
	assert_lt(float(patient_slot["progress"]), float(leader["race_progress"]))


func test_cpu_follow_slot_forward_choice_stays_bounded_at_track_edge() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": M2TrackMath.MAX_ABS_OFFSET_M,
	}
	var selected := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [leader], 1.0)
	assert_true(selected["found"])
	assert_lte(absf(float(selected["offset"])), M2TrackMath.MAX_ABS_OFFSET_M)


func test_cpu_follow_slot_holds_current_line_when_forward_slots_are_blocked() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var inner_blocker := {"id": "inner", "race_progress": 106.0, "offset": -2.0}
	var outer_blocker := {"id": "outer", "race_progress": 106.0, "offset": 2.0}
	var escape_blocker := {"id": "escape", "race_progress": 106.0, "offset": 4.5}
	var selected := LocalRaceMath.cpu_follow_slot(
		100.0, 0.5, leader, [leader, inner_blocker, outer_blocker, escape_blocker], 1.0
	)
	assert_true(selected["found"])
	assert_true(selected["hold_current"])
	assert_eq(str(selected["name"]), "hold_current")
	assert_almost_eq(float(selected["offset"]), 0.5, 0.001)


func test_cpu_follow_slot_uses_outer_escape_when_normal_forward_slots_are_crowded() -> void:
	var leader := {
		"found": true, "id": "leader", "race_progress": 104.0,
		"forward_gap_m": 4.0, "offset": 0.0,
	}
	var selected := LocalRaceMath.cpu_follow_slot(100.0, 0.0, leader, [
		leader,
		{"id": "inner", "race_progress": 106.0, "offset": -2.0},
		{"id": "outer", "race_progress": 106.0, "offset": 2.0},
	], 1.0)
	assert_true(selected["found"])
	assert_eq(str(selected["name"]), "overtake_escape_outer")
	assert_true(bool(selected["escape"]))
	assert_gt(float(selected["offset"]), 4.0)


func test_cpu_line_move_speed_only_increases_for_escape_slots() -> void:
	assert_almost_eq(
		LocalRaceMath.cpu_line_move_speed_m_per_s({"escape": false}),
		LocalRaceMath.Config.number("cpu_steer_speed_m_per_s"),
		0.001
	)
	assert_almost_eq(
		LocalRaceMath.cpu_line_move_speed_m_per_s({"escape": true}, 0.5),
		LocalRaceMath.Config.number("cpu_steer_speed_m_per_s")
			* LocalRaceMath.Config.number("cpu_overtake_escape_steer_speed_multiplier") * 0.5,
		0.001
	)


func test_drafting_reduces_resistance_without_overriding_the_safety_cap() -> void:
	var open_speed := LocalRaceMath.advance_drive_speed_kmh(
		75.0, 5.0, LocalRaceMath.HARD_SPEED_CAP_KMH, 1.0, 0.0
	)
	var drafted_speed := LocalRaceMath.advance_drive_speed_kmh(
		75.0, 5.0, LocalRaceMath.HARD_SPEED_CAP_KMH, 1.0, 0.55
	)
	assert_gt(drafted_speed, open_speed)
	assert_lte(drafted_speed, LocalRaceMath.HARD_SPEED_CAP_KMH)
	assert_eq(
		LocalRaceMath.advance_drive_speed_kmh(90.0, 6.0, LocalRaceMath.HARD_SPEED_CAP_KMH, 1.0, 1.0),
		LocalRaceMath.HARD_SPEED_CAP_KMH
	)


func test_heart_rate_uses_continuous_rise_rates_and_cardio_modifiers() -> void:
	assert_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(0.0), 0.0)
	assert_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(-3.0), 0.0)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(1.0), 1.8, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(2.0), 2.2, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(3.0), 2.5, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(4.0), 3.7, 0.001)
	assert_lt(LocalRaceMath.heart_rate_rise_rate_for_drive_level(4.0), LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.0))
	assert_lt(LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.0), LocalRaceMath.heart_rate_rise_rate_for_drive_level(6.0))
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.5), 8.2, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5), 11.0, 0.001)
	assert_gt(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 1), LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5))
	assert_lt(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 15), LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5))
	assert_gt(
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 6.0, 5),
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(200.0, 6.0, 5)
	)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 4.0, 5), 0.0)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 5.0, 5), LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 4.0, 5))
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(180.0, 2.0, 5), 0.0)
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(180.0, 3.0, 5), 0.0)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(170.0, 4.0, 5), 0.0)
	var settled: Dictionary = {}
	for drive_level in [4.0, 5.0, 6.0]:
		var heart_rate := 100.0
		for _step in 1200:
			heart_rate = clampf(
				heart_rate + LocalRaceMath.heart_rate_net_rate_bpm_per_s(heart_rate, drive_level, 5) * 0.1,
				100.0,
				230.0
			)
		settled[drive_level] = heart_rate
	assert_lte(settled[4.0], 185.0)
	assert_gt(settled[5.0], 200.0)
	assert_lte(settled[5.0], 215.0)
	assert_gt(settled[6.0], settled[5.0])
	assert_gt(settled[4.0], 175.0)
	assert_gt(settled[6.0], 225.0)
	assert_lte(settled[6.0], 230.0)
	var cardio10_notch6 := 100.0
	for _step in 1200:
		cardio10_notch6 = clampf(
			cardio10_notch6 + LocalRaceMath.heart_rate_net_rate_bpm_per_s(cardio10_notch6, 6.0, 10) * 0.1,
			100.0,
			230.0
		)
	# 約2000m相当の120秒ノッチ6で、心肺10でも200を超えて自然収束する。
	assert_gte(cardio10_notch6, 210.0)
	assert_lte(cardio10_notch6, 230.0)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(1), 11.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(5), 15.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(10), 20.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(15), 25.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_recovery_time_s(1), 29.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_recovery_time_s(15), 17.0, 0.001)
	assert_almost_eq(LocalRaceMath.Config.number("heart_rate_recovery_exponent"), 1.2, 0.001)
	assert_almost_eq(LocalRaceMath.Config.number("heart_rate_recovery_rate_scale"), 2.75, 0.001)
	assert_gt(
		LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(200.0, 5),
		(100.0 / LocalRaceMath.heart_rate_recovery_time_s(5)) * pow((200.0 - 100.0) / 130.0, 1.5)
	)
	assert_almost_eq(
		LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(230.0, 5),
		100.0 / LocalRaceMath.heart_rate_recovery_time_s(5),
		0.001
	)
	assert_gt(
		LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(230.0, 5),
		LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(120.0, 5)
	)
	assert_gt(LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(120.0, 5), 0.0)
	assert_eq(LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(100.0, 5), 0.0)
	var recovering_heart_rate := 200.0
	for _step in 600:
		recovering_heart_rate += LocalRaceMath.heart_rate_net_rate_bpm_per_s(recovering_heart_rate, 0.0, 5) * 0.1
	assert_gt(recovering_heart_rate, 100.0)
	assert_lt(recovering_heart_rate, 125.0)
	var recovery_after_sixty_seconds := recovering_heart_rate
	assert_lt(recovery_after_sixty_seconds, 130.0)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(200.0, 0.0, 5), -10.0)
	assert_eq(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 0.0, 5), 0.0)


func test_stamina_consumption_uses_heart_and_stamina_stat_without_neutral_recovery() -> void:
	assert_eq(LocalRaceMath.stamina_delta_per_s(0.0, 200.0, 1), 0.0)
	assert_eq(LocalRaceMath.stamina_delta_per_s(-1.0, 200.0, 1), 0.0)
	assert_lt(LocalRaceMath.stamina_delta_per_s(6.0, 200.0, 1), 0.0)
	assert_lt(
		LocalRaceMath.stamina_consumption_per_s(6.0, 200.0, 15),
		LocalRaceMath.stamina_consumption_per_s(6.0, 200.0, 1)
	)
	assert_gt(
		LocalRaceMath.stamina_consumption_per_s(6.0, 200.0, 5),
		LocalRaceMath.stamina_consumption_per_s(6.0, 100.0, 5)
	)


func test_overheat_exposure_continuously_reduces_propulsion_and_recovers_below_normal() -> void:
	assert_almost_eq(LocalRaceMath.overheat_ratio(200.0), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.overheat_ratio(230.0), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.overheat_stamina_multiplier(230.0), 1.5, 0.001)
	assert_almost_eq(LocalRaceMath.overheat_exposure_propulsion_efficiency(0.0), 1.0, 0.001)
	var exposure := 0.0
	for _step in 600:
		exposure = LocalRaceMath.update_overheat_exposure(exposure, 220.0, 0.05)
	assert_almost_eq(exposure, 20.0, 0.02)
	assert_almost_eq(LocalRaceMath.overheat_exposure_propulsion_efficiency(exposure), 0.66, 0.002)
	var sustained_230 := exposure
	for _step in 200:
		sustained_230 = LocalRaceMath.update_overheat_exposure(sustained_230, 230.0, 0.05)
	assert_gt(sustained_230, exposure)
	assert_lt(
		LocalRaceMath.overheat_exposure_propulsion_efficiency(sustained_230),
		LocalRaceMath.overheat_exposure_propulsion_efficiency(exposure)
	)
	var recovered := sustained_230
	for _step in 100:
		recovered = LocalRaceMath.update_overheat_exposure(recovered, 180.0, 0.05)
	assert_lt(recovered, sustained_230)
	assert_almost_eq(LocalRaceMath.stamina_debt_efficiency(0.0, 1), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.stamina_debt_efficiency(-100.0, 1), 0.40, 0.001)
	assert_gt(LocalRaceMath.stamina_debt_efficiency(-100.0, 15), 0.40)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0, 0.0, 0.0, 0.0, 0.75),
		51.85,
		0.001
	)


func test_220_bpm_thirty_seconds_lowers_single_runner_to_about_59_kmh() -> void:
	var speed := 69.0
	var exposure := 0.0
	for _step in 600:
		exposure = LocalRaceMath.update_overheat_exposure(exposure, 220.0, 0.05)
		var top_speed_adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(speed, 6.0, 9)
		speed = LocalRaceMath.advance_drive_speed_kmh(
			speed,
			6.0,
			LocalRaceMath.HARD_SPEED_CAP_KMH,
			0.05,
			0.0,
			0.0,
			top_speed_adjustment,
			LocalRaceMath.overheat_exposure_propulsion_efficiency(exposure)
		)
	assert_almost_eq(speed, 59.0, 1.5)


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


func test_local_hud_shows_drafting_status_and_resistance_diagnostics() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player := Node3D.new()
	player.set_script(RunnerScript)
	add_child(player)
	player.call("setup_for_race", null, 0, 75.0, true, "あなた")
	player.set("_drafting", true)
	player.set("_received_draft_p", LocalRaceMath.DRAFT_MAX_RECEIVED_P)
	player.set("_direct_draft_p", LocalRaceMath.DRAFT_MAX_RECEIVED_P)
	player.set("_direct_source_ids", ["CPU2"])
	player.set("_direct_source_details", [{"id": "CPU2", "gap": 4.0, "line": 1.0}])
	race.set("_player", player)
	race.set("_race_started", true)
	race.call("_update_hud")
	var hud: Label = race.get_node("UI/HudLabel")
	var lines := hud.text.split("\n")
	assert_eq(hud.anchor_left, 0.0)
	assert_eq(hud.anchor_right, 0.0)
	assert_eq(hud.offset_left, 16.0)
	assert_eq(hud.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
	assert_eq(hud.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_true(lines.has("直接 100%"))
	assert_true(lines.has("連鎖 0%"))
	assert_true(lines.has("総合 100%"))
	assert_true(lines.has("実効 60%"))
	assert_false(hud.text.contains("上限補正"))
	assert_true(lines.has("対象1 CPU2 前4.0m 横1.0m"))
	assert_true(lines.has("推進力 +0.00km/h/s"))
	assert_true(lines.has("転がり抵抗 -0.55km/h/s"))
	assert_true(lines.has("空気抵抗（二乗） -1.92km/h/s"))
	assert_true(lines.has("ドラフト軽減 +0.63km/h/s"))
	assert_true(lines.has("計算加速度 -1.84km/h/s"))
	for line in lines:
		if line.begins_with("推進力") or line.begins_with("転がり抵抗") \
				or line.begins_with("空気抵抗（二乗）") or line.begins_with("ドラフト軽減") \
				or line.begins_with("計算加速度"):
			# 18px・固定544pxのHUDで診断5行を切らずに表示する。
			assert_lte(line.length(), 30)
	var brake_lines: PackedStringArray = race.call("_drive_diagnostic_hud_lines", {
		"drive_contribution_kmh_per_s": -4.0,
		"rolling_resistance_kmh_per_s": 0.55,
		"air_resistance_kmh_per_s": 0.96,
		"draft_air_reduction_kmh_per_s": 0.0,
		"total_acceleration_kmh_per_s": -5.51,
	})
	assert_true(brake_lines.has("制動 -4.00km/h/s"))
	assert_true(brake_lines.has("計算加速度 -5.51km/h/s"))
	player.set("_direct_source_details", [
		{"id": "CPU1", "gap": 2.0, "line": 0.4},
		{"id": "CPU2", "gap": 4.0, "line": 1.0},
		{"id": "CPU3", "gap": 7.5, "line": 1.7},
	])
	race.call("_update_hud")
	for line in hud.text.split("\n"):
		if line.begins_with("対象"):
			# 18px・固定544pxのHUDで、対象3件も1行ずつ表示する。
			assert_lte(line.length(), 30)
	assert_true(hud.text.contains("対象1 CPU1 前2.0m 横0.4m"))
	assert_true(hud.text.contains("対象2 CPU2 前4.0m 横1.0m"))
	assert_true(hud.text.contains("対象3 CPU3 前7.5m 横1.7m"))
	player.set("_drafting", false)
	player.set("_received_draft_p", 0.0)
	player.set("_direct_draft_p", 0.0)
	player.set("_direct_source_ids", [])
	player.set("_direct_source_details", [])
	race.call("_update_hud")
	var solo_lines := hud.text.split("\n")
	assert_true(solo_lines.has("直接 0%"))
	assert_true(solo_lines.has("連鎖 0%"))
	assert_true(solo_lines.has("総合 0%"))
	assert_true(solo_lines.has("実効 0%"))
	assert_false(hud.text.contains("上限補正"))
	assert_true(solo_lines.has("対象 なし"))
	player.free()
	race.free()


func test_local_hud_shows_effective_draft_ratio_and_air_reduction() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player := Node3D.new()
	player.set_script(RunnerScript)
	add_child(player)
	player.call("setup_for_race", null, 0, 75.0, true, "あなた")
	player.set("_current_speed_kmh", 57.0)
	player.call("set_drive_level", 3.0)
	# 生の44%表示へ丸まる43.5%は、実効約11%となり HUD/診断の共通値で確認できる。
	var received := LocalRaceMath.DRAFT_MAX_RECEIVED_P * 0.435
	player.call("apply_draft_details", {
		"direct_draft_p": received,
		"chain_draft_p": 0.0,
		"received_draft_p": received,
		"direct_source_ids": ["cpu-7"],
		"direct_source_details": [{"id": "cpu-7", "gap": 1.5, "line": 0.2}],
	})
	runner_snapshot_for_hud(race, player)
	var hud: Label = race.get_node("UI/HudLabel")
	var lines := hud.text.split("\n")
	assert_true(lines.has("直接 44%"))
	assert_true(lines.has("連鎖 0%"))
	assert_true(lines.has("総合 44%"))
	assert_true(lines.has("実効 11%"))
	assert_true(lines.has("空気抵抗（二乗） -3.90km/h/s"))
	assert_true(lines.has("ドラフト軽減 +0.24km/h/s"))
	assert_true(hud.text.contains("計算加速度"))
	player.free()
	race.free()


func runner_snapshot_for_hud(race: Node3D, player: Node3D) -> void:
	race.set("_player", player)
	race.set("_race_started", true)
	race.call("_update_hud")


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


func test_local_draft_uses_multiple_front_sources_and_progress_not_wrapped_distance() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "distance": 2050.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-1", "race_progress": 104.0, "distance": 4.0, "offset": 0.5, "speed": 60.0},
		{"id": "cpu-2", "race_progress": 107.0, "distance": 7.0, "offset": -0.5, "speed": 60.0},
	], 0)
	assert_eq(details["direct_source_ids"], ["cpu-1", "cpu-2"])
	assert_gt(float(details["direct_draft_p"]), 0.0)
	assert_eq(details["chain_source_ids"], [])


func test_local_draft_receives_both_wide_front_sources_with_gentle_lateral_curve() -> void:
	var both := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-inner", "race_progress": 104.0, "offset": -1.2, "speed": 60.0,
			"direct_draft_p": 0.12},
		{"id": "cpu-outer", "race_progress": 104.0, "offset": 1.2, "speed": 60.0,
			"direct_draft_p": 0.12},
	], 0)
	var single := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-inner", "race_progress": 104.0, "offset": -1.2, "speed": 60.0,
			"direct_draft_p": 0.12},
	], 0)
	assert_eq(both["direct_source_ids"], ["cpu-inner", "cpu-outer"])
	assert_gt(float(both["direct_draft_p"]), float(single["direct_draft_p"]))
	assert_gt(float(both["chain_draft_p"]), float(single["chain_draft_p"]))
	var at_edge := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-edge", "race_progress": 104.0, "offset": LocalRaceMath.DRAFT_LATERAL_RANGE_M, "speed": 60.0},
	], 0)
	assert_eq(at_edge["direct_source_ids"], [])


func test_local_draft_keeps_all_four_eligible_sources_in_deterministic_order() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-c", "race_progress": 103.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-a", "race_progress": 101.5, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-b", "race_progress": 101.5, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-d", "race_progress": 104.0, "offset": 0.0, "speed": 60.0},
	], 0)
	assert_eq(details["direct_source_ids"], ["cpu-a", "cpu-b", "cpu-c", "cpu-d"])
	assert_eq(details["direct_source_details"].size(), 4)
	assert_lte(float(details["direct_draft_p"]), LocalRaceMath.DRAFT_MAX_RECEIVED_P)


func test_local_draft_requires_meaningful_forward_gap_and_uses_gentle_lateral_curve() -> void:
	var side_by_side := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-side", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
	], 0)
	var just_under_min := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-near", "race_progress": LocalRaceMath.DRAFT_FORWARD_MIN_M - 0.01 + 100.0, "offset": 0.0, "speed": 60.0},
	], 0)
	var diagonal := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-diagonal", "race_progress": 104.0, "offset": 0.9, "speed": 60.0,
			"direct_draft_p": 0.12},
	], 0)
	assert_eq(side_by_side["direct_source_ids"], [])
	assert_eq(just_under_min["direct_source_ids"], [])
	assert_eq(diagonal["direct_source_ids"], ["cpu-diagonal"])
	var source_wake := LocalRaceMath.draft_wake_from_speed(60.0)
	var expected_linear := source_wake * (1.0 - 4.0 / LocalRaceMath.DRAFT_FORWARD_MAX_M) * 0.5
	assert_gt(float(diagonal["direct_draft_p"]), expected_linear)
	var expected_linear_chain := 0.12 * LocalRaceMath.DRAFT_CHAIN_ATTENUATION * (1.0 - 4.0 / LocalRaceMath.DRAFT_FORWARD_MAX_M) * 0.5
	assert_gt(float(diagonal["chain_draft_p"]), expected_linear_chain)


func test_local_draft_chain_uses_previous_source_received_value() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "cpu-1", "race_progress": 104.0, "offset": 0.0, "speed": 60.0,
			"direct_draft_p": 0.12, "chain_draft_p": 0.03},
	], 0)
	assert_eq(details["chain_source_ids"], ["cpu-1"])
	assert_gt(float(details["chain_draft_p"]), 0.0)


func test_finished_runners_continue_to_receive_and_supply_local_draft() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 2000.0, "offset": 0.0, "speed": 60.0, "finished": true},
		{"id": "cpu-finished", "race_progress": 2004.0, "offset": 0.0, "speed": 60.0, "finished": true},
		{"id": "cpu-running", "race_progress": 2006.0, "offset": 0.5, "speed": 60.0},
	], 0)
	assert_eq(details["direct_source_ids"], ["cpu-finished", "cpu-running"])
	assert_gt(float(details["received_draft_p"]), 0.0)


func test_contact_prevention_stops_before_ahead_runner_without_repositioning() -> void:
	var others := [{"race_progress": 12.0, "offset": 0.0}]
	assert_almost_eq(LocalRaceMath.allowed_race_progress(10.0, 11.0, 0.0, others), 10.5, 0.001)
	assert_almost_eq(LocalRaceMath.allowed_race_progress(10.0, 10.25, 0.0, others), 10.25, 0.001)
	assert_almost_eq(LocalRaceMath.allowed_race_progress(10.0, 11.0, 2.0, others), 11.0, 0.001)


func test_contact_prevention_rejects_only_lateral_moves_into_another_runner() -> void:
	var others := [{"race_progress": 10.0, "offset": 0.0}]
	assert_false(LocalRaceMath.can_use_offset(10.0, 0.5, others))
	assert_true(LocalRaceMath.can_use_offset(10.0, 1.5, others))


func test_follow_speed_approaches_target() -> void:
	var s := LocalRaceMath.follow_speed_kmh(50.0, 58.0, 0.2)
	assert_gt(s, 50.0)
	assert_lt(s, 58.0)
	assert_eq(LocalRaceMath.follow_speed_kmh(57.5, 58.0, 1.0), 58.0)


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
