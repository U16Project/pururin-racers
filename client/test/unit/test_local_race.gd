extends GutTest

const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M2CourseBuilder := preload("res://scripts/m2_course_builder.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const DraftRules := preload("res://scripts/config/m5_draft_rules.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const LocalRaceCameraScript := preload("res://scripts/local_race_camera.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)
	RaceSession.select_player_pururin(RaceSession.default_player_pururin_id())
	RaceSession.reset_stamina_load_preset()


func test_cpu_heart_safety_uses_the_highest_notch_that_lowers_an_overheated_heart() -> void:
	var current_bpm := LocalRaceMath.Config.number("heart_rate_normal_max_bpm") + 10.0
	var cardio_stat := 5
	var selected := LocalRaceMath.cpu_heart_safe_drive_level(6.0, current_bpm, cardio_stat)
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(current_bpm, selected, cardio_stat), 0.0)
	assert_eq(
		selected,
		LocalRaceMath.cpu_heart_safe_drive_level(0.0, current_bpm, cardio_stat),
		"心拍が通常上限以上では既存の追走ノッチでなく、心拍を下げられる最大ノッチを選ぶ"
	)
	if selected < LocalRaceMath.DRIVE_LEVEL_MAX:
		assert_gte(
			LocalRaceMath.heart_rate_net_rate_bpm_per_s(current_bpm, selected + 1.0, cardio_stat),
			0.0,
			"次のノッチでは心拍を下げられないため選ばない"
		)


func test_cpu_heart_safety_keeps_the_trainer_notch_below_normal_max() -> void:
	assert_eq(
		LocalRaceMath.cpu_heart_safe_drive_level(5.0, LocalRaceMath.Config.number("cpu_heart_drop_threshold_bpm") - 0.1, 5),
		5.0
	)


func test_cpu_heart_safety_starts_below_the_normal_max_and_counts_adaptation_and_extra_load() -> void:
	var threshold := LocalRaceMath.Config.number("cpu_heart_drop_threshold_bpm")
	assert_lt(threshold, LocalRaceMath.Config.number("heart_rate_normal_max_bpm"))
	# 下げ始める心拍以上なら、基本ノッチより下げる。
	assert_lt(LocalRaceMath.cpu_heart_safe_drive_level(6.0, threshold, 5), 6.0)
	# 慣れがあると下げる力が強いので、より高いノッチを選べる。
	var plain := LocalRaceMath.cpu_heart_safe_drive_level(6.0, threshold + 5.0, 5)
	var adapted := LocalRaceMath.cpu_heart_safe_drive_level(6.0, threshold + 5.0, 5, 1.0)
	assert_gte(adapted, plain)
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(threshold + 5.0, adapted, 5, 1.0), 0.0)
	# 追加の負荷があると、より低いノッチを選ぶ。
	var loaded := LocalRaceMath.cpu_heart_safe_drive_level(6.0, threshold + 5.0, 5, 0.0, 2.0)
	assert_lte(loaded, plain)
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(threshold + 5.0, loaded, 5) + 2.0, 0.0)


func test_cpu_trainer_settings_use_the_common_start_notch_and_heart_limit() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	assert_eq(float(settings["cpu_start_drive_level"]), LocalRaceMath.Config.number("cpu_start_drive_level"))
	assert_eq(float(settings["heart_rate_normal_max_bpm"]), LocalRaceMath.Config.number("heart_rate_normal_max_bpm"))


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


## 設定値から計算する期待値（設定を変えてもテストが壊れないようにする）。
func _air_resistance(speed_kmh: float, aero_multiplier: float = 1.0) -> float:
	return LocalRaceMath.AIR_RESISTANCE_QUADRATIC_COEFFICIENT * speed_kmh * speed_kmh * aero_multiplier


func _drive_force(level: int) -> float:
	return float(LocalRaceMath.DRIVE_FORCE_BY_LEVEL_KMH_PER_S[level])


## 1秒進めたあとの速度。駆動力 − 転がり抵抗 − 空気抵抗（ドラフト・補正なし）。
func _expected_speed_after_one_second(speed_kmh: float, level: int) -> float:
	return speed_kmh + _drive_force(level) - LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S - _air_resistance(speed_kmh)


func test_player_speeds_are_kmh() -> void:
	assert_eq(LocalRaceMath.PLAYER_MAX_SPEED_KMH, LocalRaceMath.Config.number("top_speed_natural_max_kmh"))
	assert_eq(LocalRaceMath.Config.number("player_start_gate_index"), 0.0)


func test_top_speed_maps_one_to_fifteen_directly_without_per_runner_tiers() -> void:
	var low := LocalRaceMath.Config.number("top_speed_natural_min_kmh")
	var high := LocalRaceMath.Config.number("top_speed_natural_max_kmh")
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(1), low)
	assert_almost_eq(LocalRaceMath.top_speed_natural_speed_kmh(5), lerpf(low, high, 4.0 / 14.0), 0.0001)
	assert_almost_eq(LocalRaceMath.top_speed_natural_speed_kmh(8), lerpf(low, high, 7.0 / 14.0), 0.0001)
	assert_eq(LocalRaceMath.top_speed_natural_speed_kmh(15), high)
	assert_almost_eq(LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(5), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(8), 0.0, 0.001)
	assert_almost_eq(_natural_speed_after_sixty_seconds(1, 5), low, 0.05)
	assert_almost_eq(_natural_speed_after_sixty_seconds(15, 5), high, 0.05)


func test_local_player_uses_roster_effective_top_speed_and_acceleration() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	var stats: Dictionary = player.call("get_effective_stats")
	assert_eq(stats["top_speed"], 8)
	assert_eq(stats["acceleration"], 5)
	assert_almost_eq(player.call("get_natural_top_speed"), LocalRaceMath.top_speed_natural_speed_kmh(8), 0.001)
	assert_almost_eq(player.call("get_max_speed"), LocalRaceMath.top_speed_natural_speed_kmh(8), 0.001)
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


func test_hikari_uses_balanced_trainer_when_selected_as_a_cpu() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	var hikari: Dictionary = PururinRosterConfig.pururin_by_id("player-1")
	runner.call("setup_for_race", null, 0, 75.0, false, str(hikari["display_name"]), hikari)
	var profile: Dictionary = runner.get("_cpu_trainer_profile")
	assert_eq(profile["id"], "balanced")
	runner.free()


func test_selected_roster_id_is_kept_in_runner_and_telemetry_snapshots() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	var sora: Dictionary = PururinRosterConfig.pururin_by_id("cpu-4")
	runner.call("setup_for_race", null, 3, 75.0, true, str(sora["display_name"]), sora)
	assert_eq(runner.call("get_snapshot")["id"], "cpu-4")
	assert_eq(runner.call("get_telemetry_snapshot")["id"], "cpu-4")
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
			60.0,
			4.0,
			int(effective_stats["top_speed"]),
			runner.call("_aero_air_resistance_multiplier")
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
			LocalRaceMath.top_speed_natural_speed_kmh(15),
			0.01,
			0.0,
			LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(acceleration),
			top_speed_adjustment,
			1.0,
			1.0,
			LocalRaceMath.stat_acceleration_response_multiplier(acceleration)
		)
	return speed


func test_acceleration_response_is_linear_and_does_not_raise_equilibrium() -> void:
	for stat: int in [1, 5, 10, 15]:
		assert_almost_eq(LocalRaceMath.stat_acceleration_response_multiplier(stat), 1.0 + 0.05 * (stat - 5), 0.00001)
		for top_speed: int in [1, 5, 10, 15]:
			assert_almost_eq(_natural_speed_after_sixty_seconds(top_speed, stat), LocalRaceMath.top_speed_natural_speed_kmh(top_speed), 0.05)
	var adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(50.0, 6.0, 5)
	var low := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.0, 0.0, adjustment, 1.0, 1.0, 0.8)
	var high := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.0, 0.0, adjustment, 1.0, 1.0, 1.5)
	assert_gt(float(high["total_acceleration_kmh_per_s"]), float(low["total_acceleration_kmh_per_s"]))
	assert_almost_eq(float(high["drive_contribution_kmh_per_s"]), float(low["drive_contribution_kmh_per_s"]), 0.00001)


func test_acceleration_response_does_not_change_coasting_braking_or_positive_notch_deceleration() -> void:
	for notch: float in [0.0, 3.0, 6.0]:
		var low := LocalRaceMath.advance_drive_speed_kmh(90.0, notch, INF, 0.1, 0.0, 0.0, 0.0, 1.0, 1.0, 0.8)
		var high := LocalRaceMath.advance_drive_speed_kmh(90.0, notch, INF, 0.1, 0.0, 0.0, 0.0, 1.0, 1.0, 1.5)
		assert_almost_eq(low, high, 0.00001)
	var braked_low := LocalRaceMath.advance_drive_speed_kmh(90.0, 6.0, INF, 0.1, 0.0, 0.0, 0.0, 1.0, 1.0, 0.8, false, true)
	var braked_high := LocalRaceMath.advance_drive_speed_kmh(90.0, 6.0, INF, 0.1, 0.0, 0.0, 0.0, 1.0, 1.0, 1.5, false, true)
	assert_almost_eq(braked_low, braked_high, 0.00001)
	var equilibrium_speed := LocalRaceMath.top_speed_natural_speed_kmh(5)
	var adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(equilibrium_speed, 6.0, 5)
	assert_almost_eq(LocalRaceMath.advance_drive_speed_kmh(equilibrium_speed, 6.0, INF, 0.1, 0.0, 0.0, adjustment, 1.0, 1.0, 1.5), equilibrium_speed, 0.00001)


func test_runner_diagnostics_include_effective_acceleration_response() -> void:
	for is_player: bool in [true, false]:
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		var akane := PururinRosterConfig.pururin_by_id("cpu-1")
		runner.call("setup_for_race", null, 2, 75.0, is_player, "アカネ", akane)
		runner.set("_current_speed_kmh", 40.0)
		runner.call("set_drive_level", 6.0)
		runner.set("_cpu_trainer_drive_level", 6.0)
		var stats: Dictionary = runner.call("get_effective_stats")
		var diagnostics: Dictionary = runner.call("get_drive_diagnostics")
		assert_almost_eq(float(diagnostics["acceleration_response_multiplier"]), LocalRaceMath.stat_acceleration_response_multiplier(int(stats["acceleration"])), 0.00001)
		assert_almost_eq(float(diagnostics["total_acceleration_kmh_per_s"]), float(diagnostics["net_force_acceleration_kmh_per_s"]) * float(diagnostics["acceleration_response_multiplier"]), 0.00001)
		runner.free()


func test_acceleration_response_keeps_force_inputs_and_applies_only_to_positive_net_force() -> void:
	for notch: float in [0.0, 2.0, 4.0, 6.0]:
		for speed: float in [40.0, 60.0, 90.0]:
			for draft: float in [0.0, 0.33]:
				for efficiency: float in [0.35, 1.0]:
					for aero: float in [LocalRaceMath.aero_air_resistance_multiplier(15), LocalRaceMath.aero_air_resistance_multiplier(1)]:
						var plain := LocalRaceMath.drive_diagnostics_kmh_per_s(speed, notch, draft, 0.0, 0.0, efficiency, aero, 1.0)
						var responsive := LocalRaceMath.drive_diagnostics_kmh_per_s(speed, notch, draft, 0.0, 0.0, efficiency, aero, 1.5)
						for field: String in ["drive_contribution_kmh_per_s", "rolling_resistance_kmh_per_s", "air_resistance_kmh_per_s", "draft_air_reduction_kmh_per_s"]:
							assert_almost_eq(float(plain[field]), float(responsive[field]), 0.00001)
						var net := float(plain["total_acceleration_kmh_per_s"])
						var expected := net * 1.5 if notch > 0.0 and net > 0.0 else net
						assert_almost_eq(float(responsive["total_acceleration_kmh_per_s"]), expected, 0.00001)


func test_drive_level_is_clamped_and_steps_by_one() -> void:
	assert_eq(LocalRaceMath.clamp_drive_level(-9.0), 0.0)
	assert_eq(LocalRaceMath.clamp_drive_level(9.0), 6.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, 1.0), 1.0)
	assert_eq(LocalRaceMath.step_drive_level(0.0, -1.0), 0.0)
	assert_eq(LocalRaceMath.step_drive_level(5.0, 1.0), 6.0)
	assert_eq(LocalRaceMath.step_drive_level(6.0, 1.0), 6.0)
	assert_eq(LocalRaceMath.step_drive_level(1.0, -1.0), 0.0)


func test_local_player_starts_in_neutral_and_clamps_the_notch() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	assert_eq(runner.call("get_current_speed"), LocalRaceMath.MIN_SPEED_KMH)
	assert_eq(runner.call("get_drive_level"), 0.0)
	runner.call("set_drive_level", 99.0)
	assert_eq(runner.call("get_drive_level"), 6.0)
	runner.free()


func test_drive_zero_level_naturally_slows_but_respects_floor() -> void:
	var coasting := LocalRaceMath.advance_drive_speed_kmh(70.0, 0.0, 75.0, 1.0)
	assert_lt(coasting, 70.0)
	assert_eq(LocalRaceMath.advance_drive_speed_kmh(40.0, 0.0, 75.0, 1.0), 40.0)


func test_drive_maximum_output_uses_force_without_a_hard_speed_cap() -> void:
	var accelerated := LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0)
	assert_almost_eq(accelerated, _expected_speed_after_one_second(50.0, 6), 0.001)
	assert_gt(LocalRaceMath.advance_drive_speed_kmh(74.0, 6.0, 75.0, 1.0, 1.0), 75.0)


func test_drive_braking_slows_but_does_not_stop() -> void:
	# 最低速度に当たらないよう、短い時間（0.1秒）で比べる。
	var braked := LocalRaceMath.advance_drive_speed_kmh(70.0, 0.0, 75.0, 0.1, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, false, true)
	var coasting := LocalRaceMath.advance_drive_speed_kmh(70.0, 0.0, 75.0, 0.1)
	assert_almost_eq(coasting - braked, LocalRaceMath.BRAKE_DECELERATION_KMH_PER_S * 0.1, 0.001)
	assert_eq(LocalRaceMath.advance_drive_speed_kmh(40.0, 0.0, 75.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, false, true), 40.0)


func test_braking_overrides_the_notch_without_spending_fuel_or_raising_heart() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	runner.call("set_drive_level", 6.0)
	runner.call("set_braking", true)
	assert_true(runner.call("is_braking"))
	# ノッチ設定は保持され、有効な出力だけ0になる。
	assert_eq(runner.call("get_drive_level"), 6.0)
	var diagnostics: Dictionary = runner.call("get_drive_diagnostics")
	assert_almost_eq(float(diagnostics["drive_contribution_kmh_per_s"]), -LocalRaceMath.BRAKE_DECELERATION_KMH_PER_S, 0.0001)
	var stamina_before := float(runner.call("get_stamina"))
	runner.call("_update_condition", 1.0)
	assert_eq(float(runner.call("get_stamina")), stamina_before)
	runner.call("set_braking", false)
	assert_false(runner.call("is_braking"))
	assert_gt(float(runner.call("get_drive_diagnostics")["drive_contribution_kmh_per_s"]), 0.0)
	runner.free()


func test_cpu_cannot_brake() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 1, 75.0, false, "CPU", PururinRosterConfig.pururin_by_id("cpu-1"))
	runner.call("set_braking", true)
	assert_false(runner.call("is_braking"))
	runner.free()


func test_drive_coefficients_are_moderate_for_one_second_step() -> void:
	assert_eq(LocalRaceMath.DRIVE_FORCE_BY_LEVEL_KMH_PER_S, LocalRaceMath.Config.values()["drive_force_by_level_kmh_per_s"])
	assert_almost_eq(LocalRaceMath.BRAKE_DECELERATION_KMH_PER_S, LocalRaceMath.Config.number("brake_deceleration_kmh_per_s"), 0.001)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0),
		_expected_speed_after_one_second(50.0, 6),
		0.001
	)


func test_drive_notches_use_force_minus_resistance_without_speed_bands() -> void:
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 1.0, 75.0, 1.0),
		_expected_speed_after_one_second(50.0, 1),
		0.001
	)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0),
		_expected_speed_after_one_second(50.0, 6),
		0.001
	)


func test_drive_notch_one_holds_minimum_speed_when_resistance_exceeds_force() -> void:
	var from_floor := LocalRaceMath.advance_drive_speed_kmh(40.0, 1.0, 75.0, 1.0)
	var at_high_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 1.0, 75.0, 1.0)
	# 40km/h時の抵抗（転がり＋空気）は、ノッチ1の駆動力を上回る。
	var diagnostics := LocalRaceMath.drive_diagnostics_kmh_per_s(40.0, 1.0)
	assert_almost_eq(float(diagnostics["air_resistance_kmh_per_s"]), _air_resistance(40.0), 0.001)
	assert_almost_eq(float(diagnostics["total_acceleration_kmh_per_s"]), _drive_force(1) - LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S - _air_resistance(40.0), 0.001)
	assert_lt(float(diagnostics["total_acceleration_kmh_per_s"]), 0.0)
	assert_eq(from_floor, 40.0)
	assert_lt(at_high_speed, 75.0)


func test_drive_notches_one_and_two_stay_on_floor_and_three_leaves_it() -> void:
	for level in [1.0, 2.0]:
		assert_eq(
			LocalRaceMath.advance_drive_speed_kmh(LocalRaceMath.MIN_SPEED_KMH, level, 75.0, 1.0),
			LocalRaceMath.MIN_SPEED_KMH
		)
		assert_lt(LocalRaceMath.advance_drive_speed_kmh(75.0, level, 75.0, 1.0), 75.0)
	var notch_three_from_floor := LocalRaceMath.advance_drive_speed_kmh(
		LocalRaceMath.MIN_SPEED_KMH, 3.0, 75.0, 1.0
	)
	assert_gt(notch_three_from_floor, LocalRaceMath.MIN_SPEED_KMH)
	assert_lt(LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0), 75.0)


func test_drive_notch_three_and_zero_have_different_deceleration() -> void:
	var notch_three := LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0)
	var notch_zero := LocalRaceMath.advance_drive_speed_kmh(75.0, 0.0, 75.0, 1.0)
	assert_lt(notch_three, 75.0)
	# ノッチ3は駆動力が残るため、惰性（ノッチ0）より減速が弱い。
	assert_lt(notch_zero, notch_three)


func test_drive_notch_six_naturally_slows_when_resistance_exceeds_force() -> void:
	var speed := LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0)
	assert_almost_eq(speed, _expected_speed_after_one_second(50.0, 6), 0.001)
	assert_lt(LocalRaceMath.advance_drive_speed_kmh(75.0, 6.0, 75.0, 1.0), 75.0)


func test_drive_notch_three_naturally_slows_near_personal_cap() -> void:
	var next_speed := LocalRaceMath.advance_drive_speed_kmh(75.0, 3.0, 75.0, 1.0)
	assert_lt(next_speed, 75.0)
	assert_gt(next_speed, LocalRaceMath.advance_drive_speed_kmh(75.0, 0.0, 75.0, 1.0))


func test_drive_diagnostics_explain_force_resistance_and_draft_reduction() -> void:
	var open := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.0)
	var air := _air_resistance(50.0)
	var rolling := LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S
	assert_almost_eq(float(open["drive_contribution_kmh_per_s"]), _drive_force(6), 0.001)
	assert_almost_eq(float(open["rolling_resistance_kmh_per_s"]), rolling, 0.001)
	assert_almost_eq(float(open["air_resistance_kmh_per_s"]), air, 0.001)
	assert_almost_eq(float(open["draft_air_reduction_kmh_per_s"]), 0.0, 0.001)
	assert_almost_eq(float(open["total_acceleration_kmh_per_s"]), _drive_force(6) - rolling - air, 0.001)
	var drafted := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 6.0, 0.55)
	assert_almost_eq(float(drafted["draft_air_reduction_kmh_per_s"]), air * 0.55, 0.001)
	assert_almost_eq(float(drafted["total_acceleration_kmh_per_s"]), _drive_force(6) - rolling - air * 0.45, 0.001)


## 応答曲線の期待値。指数と集団適性倍率から x / (1 + x) を作る（指数の現値に依存しない）。
func _expected_effective_ratio(reference_ratio: float, pack_multiplier: float = 1.0) -> float:
	var x := pow(reference_ratio / LocalRaceMath.DRAFT_RESPONSE_REFERENCE_SCALE, LocalRaceMath.DRAFT_RESPONSE_EXPONENT) * pack_multiplier
	return x / (1.0 + x)


func test_draft_response_curve_saturates_toward_full_effect() -> void:
	var reference := LocalRaceMath.draft_response_reference_p()
	var half_received := reference * 0.5
	var three_quarters_received := reference * 0.75
	var above_reference := reference * 1.2
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(0.0), 0.0, 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(half_received), _expected_effective_ratio(0.5), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(three_quarters_received), _expected_effective_ratio(0.75), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(above_reference), _expected_effective_ratio(1.2), 0.001)
	assert_lt(LocalRaceMath.draft_effective_ratio(above_reference), 1.0)
	assert_gt(LocalRaceMath.draft_effective_ratio(above_reference), LocalRaceMath.draft_effective_ratio(reference))
	assert_almost_eq(LocalRaceMath.draft_air_resistance_factor(half_received), LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR * _expected_effective_ratio(0.5), 0.001)
	assert_almost_eq(LocalRaceMath.draft_assist_speed_kmh(three_quarters_received), 4.0 * _expected_effective_ratio(0.75), 0.001)


func test_draft_source_wake_grows_past_the_reference_speed_without_a_source_cap() -> void:
	var saved := DraftRules._cached
	var configured: Dictionary = DraftRules.load_file().data
	configured["wake_speed_gain_p"] = 0.06
	DraftRules._cached = configured
	assert_almost_eq(LocalRaceMath.draft_wake_from_speed(75.0), 0.12, 0.001)
	assert_almost_eq(LocalRaceMath.draft_wake_from_speed(300.0), 0.30, 0.001)
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "receiver", "race_progress": 0.0, "offset": 0.0, "speed": 50.0},
		{"id": "source", "race_progress": 2.0, "offset": 0.0, "speed": 300.0, "own_wake_p": 0.50},
	], 0)
	assert_gt(float(details["direct_draft_p"]), LocalRaceMath.draft_response_reference_p())
	DraftRules._cached = saved


func test_aero_and_pack_stats_use_continuous_baseline_multipliers() -> void:
	assert_almost_eq(LocalRaceMath.aero_air_resistance_multiplier(1), 1.0 + LocalRaceMath.AERO_AIR_RESISTANCE_MULTIPLIER_PER_STAT * 4.0, 0.001)
	assert_almost_eq(LocalRaceMath.aero_air_resistance_multiplier(5), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.aero_air_resistance_multiplier(15), 1.0 - LocalRaceMath.AERO_AIR_RESISTANCE_MULTIPLIER_PER_STAT * 10.0, 0.001)
	var aero_one := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, 0.0, 0.0, 0.0, 1.0, LocalRaceMath.aero_air_resistance_multiplier(1))
	var aero_five := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, 0.0, 0.0, 0.0, 1.0, LocalRaceMath.aero_air_resistance_multiplier(5))
	var aero_fifteen := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, 0.0, 0.0, 0.0, 1.0, LocalRaceMath.aero_air_resistance_multiplier(15))
	assert_almost_eq(float(aero_one["air_resistance_kmh_per_s"]), _air_resistance(50.0, LocalRaceMath.aero_air_resistance_multiplier(1)), 0.001)
	assert_almost_eq(float(aero_five["air_resistance_kmh_per_s"]), _air_resistance(50.0), 0.001)
	assert_almost_eq(float(aero_fifteen["air_resistance_kmh_per_s"]), _air_resistance(50.0, LocalRaceMath.aero_air_resistance_multiplier(15)), 0.001)
	assert_almost_eq(float(aero_one["rolling_resistance_kmh_per_s"]), float(aero_fifteen["rolling_resistance_kmh_per_s"]), 0.001)
	var half_received := LocalRaceMath.draft_response_reference_p() * 0.5
	assert_almost_eq(LocalRaceMath.pack_draft_effective_multiplier(1), 1.0 - LocalRaceMath.PACK_DRAFT_EFFECTIVE_MULTIPLIER_PER_STAT * 4.0, 0.001)
	assert_almost_eq(LocalRaceMath.pack_draft_effective_multiplier(5), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.pack_draft_effective_multiplier(15), 1.0 + LocalRaceMath.PACK_DRAFT_EFFECTIVE_MULTIPLIER_PER_STAT * 10.0, 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(half_received, 1), _expected_effective_ratio(0.5, LocalRaceMath.pack_draft_effective_multiplier(1)), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(half_received, 5), _expected_effective_ratio(0.5), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(half_received, 15), _expected_effective_ratio(0.5, LocalRaceMath.pack_draft_effective_multiplier(15)), 0.001)
	assert_almost_eq(LocalRaceMath.draft_effective_ratio(LocalRaceMath.draft_response_reference_p(), 15), _expected_effective_ratio(1.0, LocalRaceMath.pack_draft_effective_multiplier(15)), 0.001)
	assert_lt(LocalRaceMath.draft_effective_ratio(LocalRaceMath.draft_response_reference_p(), 15), 1.0)
	assert_eq(LocalRaceMath.draft_effective_ratio(0.0, 15), 0.0)


func test_draft_aggregation_uses_same_general_formula_for_one_two_and_three_sources() -> void:
	var contribution := LocalRaceMath.draft_response_reference_p() * 0.48
	var one := LocalRaceMath.draft_aggregate_contributions_p([contribution]) / LocalRaceMath.draft_response_reference_p()
	var two := LocalRaceMath.draft_aggregate_contributions_p([contribution, contribution]) / LocalRaceMath.draft_response_reference_p()
	var three := LocalRaceMath.draft_aggregate_contributions_p([contribution, contribution, contribution]) / LocalRaceMath.draft_response_reference_p()
	# 同じ寄与 n 個の p ノルム合成は、寄与 × n^(1/指数)。
	var aggregation := LocalRaceMath.DRAFT_AGGREGATION_EXPONENT
	assert_almost_eq(one, 0.48, 0.002)
	assert_almost_eq(two, 0.48 * pow(2.0, 1.0 / aggregation), 0.002)
	assert_almost_eq(three, 0.48 * pow(3.0, 1.0 / aggregation), 0.002)
	assert_gt(two, one * 2.0)
	assert_eq(LocalRaceMath.draft_aggregate_contributions_p([]), 0.0)
	assert_almost_eq(LocalRaceMath.draft_aggregate_contributions_p([contribution * 10.0]), contribution * 10.0, 0.001)
	assert_lt(LocalRaceMath.draft_assist_speed_kmh(contribution * 3.0), 4.0)
	assert_gt(
		LocalRaceMath.draft_assist_speed_kmh(contribution * 3.0),
		LocalRaceMath.draft_assist_speed_kmh(contribution)
	)


func test_draft_response_curve_reduces_air_resistance_and_stays_below_full_cancel() -> void:
	var half_received := LocalRaceMath.draft_response_reference_p() * 0.5
	var three_quarters_received := LocalRaceMath.draft_response_reference_p() * 0.75
	var open := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, 0.0)
	var half := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(half_received))
	var three_quarters := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(three_quarters_received))
	var above_reference := LocalRaceMath.drive_diagnostics_kmh_per_s(50.0, 0.0, LocalRaceMath.draft_air_resistance_factor(LocalRaceMath.draft_response_reference_p() * 1.2))
	assert_almost_eq(float(open["draft_air_reduction_kmh_per_s"]), 0.0, 0.001)
	assert_almost_eq(float(half["draft_air_reduction_kmh_per_s"]), _air_resistance(50.0) * LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR * _expected_effective_ratio(0.5), 0.001)
	assert_almost_eq(float(three_quarters["draft_air_reduction_kmh_per_s"]), _air_resistance(50.0) * LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR * _expected_effective_ratio(0.75), 0.001)
	assert_gt(float(above_reference["draft_air_reduction_kmh_per_s"]), float(three_quarters["draft_air_reduction_kmh_per_s"]))
	assert_lt(float(above_reference["draft_air_reduction_kmh_per_s"]), _air_resistance(50.0) * LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR)


func test_quadratic_air_resistance_grows_with_speed_and_draft_keeps_rolling_resistance() -> void:
	var low := LocalRaceMath.drive_diagnostics_kmh_per_s(40.0, 0.0, 0.0)
	var high := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 0.0, 0.0)
	var drafted := LocalRaceMath.drive_diagnostics_kmh_per_s(75.0, 0.0, 1.0)
	assert_lt(float(low["air_resistance_kmh_per_s"]), float(high["air_resistance_kmh_per_s"]))
	assert_almost_eq(float(low["air_resistance_kmh_per_s"]), _air_resistance(40.0), 0.001)
	assert_almost_eq(float(high["air_resistance_kmh_per_s"]), _air_resistance(75.0), 0.001)
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


func test_cpu_open_line_high_line_pref_moves_inside_when_current_line_is_blocked() -> void:
	var others := [
		{"id": "left", "race_progress": 100.0, "offset": -0.2},
		{"id": "right", "race_progress": 100.0, "offset": 0.2},
	]
	var neutral := LocalRaceMath.cpu_open_line_target_offset_m(100.0, 0.0, others, 0.5)
	var inside := LocalRaceMath.cpu_open_line_target_offset_m(100.0, 0.0, others, 0.95)
	assert_lt(float(inside["offset"]), float(neutral["offset"]))


func test_cpu_open_line_moves_toward_inside_preference_when_nearby_space_is_open() -> void:
	var line_pref := 0.8
	var preferred := lerpf(M2TrackMath.MAX_ABS_OFFSET_M, -M2TrackMath.MAX_ABS_OFFSET_M, line_pref)
	var selected := LocalRaceMath.cpu_open_line_target_offset_m(100.0, 2.0, [
		{"id": "behind", "race_progress": 98.0, "offset": -4.1},
	], line_pref)
	assert_true(selected["found"])
	assert_eq(str(selected["name"]), "open_line")
	assert_almost_eq(float(selected["offset"]), preferred, 0.001)
	assert_lt(float(selected["offset"]), 2.0)


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


func test_follow_slot_targets_profile_inside_line_until_overtake_intent_is_strong() -> void:
	var leader := {
		"found": true, "id": "neighbor", "race_progress": 8.0,
		"forward_gap_m": 3.0, "offset": 4.8,
	}
	var field := [leader, {"id": "pack", "race_progress": 10.0, "offset": -1.0}]
	var settling := LocalRaceMath.cpu_follow_slot(5.0, 6.75, leader, field, 0.0, 0.0, 0.90)
	var passing := LocalRaceMath.cpu_follow_slot(5.0, 6.75, leader, field, 1.0, 0.0, 0.90)
	var preferred := lerpf(M2TrackMath.MAX_ABS_OFFSET_M, -M2TrackMath.MAX_ABS_OFFSET_M, 0.90)
	assert_eq(str(settling["name"]), "inside_line")
	assert_almost_eq(float(settling["offset"]), preferred, 0.001)
	assert_true(str(passing["name"]).begins_with("overtake_"))
	assert_gt(float(passing["offset"]), preferred)


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


func test_drafting_reduces_resistance_and_can_exceed_natural_top_speed() -> void:
	var open_speed := LocalRaceMath.advance_drive_speed_kmh(
		75.0, 5.0, 100.0, 1.0, 0.0
	)
	var drafted_speed := LocalRaceMath.advance_drive_speed_kmh(
		75.0, 5.0, 100.0, 1.0, 0.55
	)
	assert_gt(drafted_speed, open_speed)
	assert_gt(LocalRaceMath.advance_drive_speed_kmh(75.0, 6.0, 75.0, 1.0, 1.0), 75.0)
	assert_gt(
		LocalRaceMath.advance_drive_speed_kmh(90.0, 6.0, 120.0, 1.0, 1.0),
		90.0
	)


func test_simulation_legacy_speed_cap_is_explicit_and_off_by_default() -> void:
	var without_cap := LocalRaceMath.advance_drive_speed_kmh(75.0, 6.0, 75.0, 0.1, 1.0)
	var with_cap := LocalRaceMath.advance_drive_speed_kmh(75.0, 6.0, 75.0, 0.1, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, true)
	assert_gt(without_cap, 75.0)
	assert_almost_eq(with_cap, 75.0, 0.00001)


func test_real_runner_draft_lifts_speed_above_natural_speed_on_notch_six() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	player.call("set_drive_level", 6.0)
	player.set("_race_active", true)
	player.set("_current_speed_kmh", 75.0)
	player.set("_received_draft_p", LocalRaceMath.draft_response_reference_p() * 4.0)
	player.set("_current_speed_kmh", player.call("get_natural_top_speed"))
	player.set("_actual_speed_kmh", player.call("get_natural_top_speed"))
	player.call("_process", 0.05)
	# ドラフトで空気抵抗が軽くなる分、自然最高速を超えて自然に伸びる。
	assert_gt(float(player.call("get_current_speed")), float(player.call("get_natural_top_speed")))
	assert_true(is_finite(float(player.call("get_current_speed"))))
	assert_lt(float(player.call("get_telemetry_snapshot")["draft"]["effective_draft_ratio"]), 1.0)
	race.set("_race_started", true)
	race.call("_update_hud")
	var hud: Label = race.get_node("UI/HudLabel")
	assert_true(hud.text.contains("加速応答 ×"))
	assert_false(hud.text.contains("推進補正"))
	player.call("set_simulation_legacy_speed_cap", true)
	player.set("_current_speed_kmh", 75.0)
	player.call("_process", 0.016667)
	assert_lte(float(player.call("get_current_speed")), float(player.call("get_max_speed")))
	race.free()


func _notch_six_equilibrium_speed(stat: int, draft_factor: float, aero_multiplier: float) -> float:
	var speed := 40.0
	var natural_speed := LocalRaceMath.top_speed_natural_speed_kmh(stat)
	for _tick in 1800:
		var adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(speed, 6.0, stat, aero_multiplier)
		speed = LocalRaceMath.advance_drive_speed_kmh(speed, 6.0, natural_speed, 0.1, draft_factor, 0.0, adjustment, 1.0, aero_multiplier, LocalRaceMath.stat_acceleration_response_multiplier(stat))
	return speed


func test_notch_six_converges_to_natural_speed_without_draft_and_exceeds_it_with_draft() -> void:
	for stat: int in [1, 5, 10, 15]:
		var natural_speed := LocalRaceMath.top_speed_natural_speed_kmh(stat)
		var solo := _notch_six_equilibrium_speed(stat, 0.0, LocalRaceMath.aero_air_resistance_multiplier(15))
		assert_true(is_finite(solo))
		assert_almost_eq(solo, natural_speed, 0.05)
		# ドラフトは最高速の上限を作らず、空気抵抗の軽減分だけ自然に速度が伸びる。
		assert_gt(_notch_six_equilibrium_speed(stat, 0.2, LocalRaceMath.aero_air_resistance_multiplier(15)), solo + 0.5)
		assert_gt(_notch_six_equilibrium_speed(stat, 0.4, LocalRaceMath.aero_air_resistance_multiplier(15)), _notch_six_equilibrium_speed(stat, 0.2, LocalRaceMath.aero_air_resistance_multiplier(15)))
	var open_adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(60.0, 4.0, 10, 1.0)
	var drafted_adjustment := open_adjustment
	var open_notch_four := LocalRaceMath.advance_drive_speed_kmh(60.0, 4.0, 70.0, 1.0, 0.0, 0.0, open_adjustment)
	var drafted_notch_four := LocalRaceMath.advance_drive_speed_kmh(60.0, 4.0, 70.0, 1.0, 0.4, 0.0, drafted_adjustment)
	assert_gt(drafted_notch_four, open_notch_four)


func test_heart_rate_uses_continuous_rise_rates_and_cardio_modifiers() -> void:
	assert_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(0.0), 0.0)
	assert_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(-1.0), 0.0)
	var rates: Array = LocalRaceMath.Config.values()["heart_rate_rise_rate_by_drive_level_bpm_per_s"]
	for level in range(1, 7):
		assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(float(level)), float(rates[level]), 0.001)
	assert_lt(LocalRaceMath.heart_rate_rise_rate_for_drive_level(4.0), LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.0))
	assert_lt(LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.0), LocalRaceMath.heart_rate_rise_rate_for_drive_level(6.0))
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_for_drive_level(5.5), (float(rates[5]) + float(rates[6])) * 0.5, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5), float(rates[6]), 0.001)
	assert_gt(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 1), LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5))
	assert_lt(LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 15), LocalRaceMath.heart_rate_rise_rate_bpm_per_s(6.0, 5))
	assert_gt(
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 6.0, 5),
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(200.0, 6.0, 5)
	)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 4.0, 5), 0.0)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 5.0, 5), LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 4.0, 5))
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(180.0, 2.0, 5), 0.0)
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(150.0, 3.0, 5), 0.0)
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
	for drive_level in [3.0]:
		var heart_rate_three := 100.0
		for _step in 1200:
			heart_rate_three = clampf(
				heart_rate_three + LocalRaceMath.heart_rate_net_rate_bpm_per_s(heart_rate_three, drive_level, 5) * 0.1,
				100.0,
				230.0
			)
		settled[drive_level] = heart_rate_three
	# ノッチ4は、約2000mに当たる時間の間、慣れも含めて、通常上限（200）を超えない。ノッチ3より高い。
	var notch_four_with_adaptation := 100.0
	var adaptation := 0.0
	for _step in 1200:
		notch_four_with_adaptation = clampf(
			notch_four_with_adaptation + LocalRaceMath.heart_rate_net_rate_bpm_per_s(notch_four_with_adaptation, 4.0, 5, adaptation) * 0.1,
			100.0,
			230.0
		)
		adaptation = LocalRaceMath.heart_adaptation_next(adaptation, notch_four_with_adaptation, 0.1)
	assert_lt(notch_four_with_adaptation, LocalRaceMath.Config.number("heart_rate_normal_max_bpm"))
	assert_gt(settled[4.0], settled[3.0])
	assert_gt(settled[5.0], 200.0)
	assert_almost_eq(settled[5.0], 230.0, 0.001)
	assert_almost_eq(settled[6.0], 230.0, 0.001)
	assert_gt(
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(230.0, 6.0, 5),
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(230.0, 5.0, 5)
	)
	# 張り付く心拍の少し下では上がり続け、少し上では下がる（釣り合いの点がある）。
	assert_gt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(settled[4.0] - 5.0, 4.0, 5), 0.0)
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(settled[4.0] + 5.0, 4.0, 5), 0.0)
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
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(1), 13.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(5), 15.0, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(10), 17.5, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_rise_time_s(15), 20.0, 0.001)
	var recovery_min := LocalRaceMath.Config.number("heart_rate_recovery_time_cardio_min_s")
	var recovery_max := LocalRaceMath.Config.number("heart_rate_recovery_time_cardio_max_s")
	assert_almost_eq(LocalRaceMath.heart_rate_recovery_time_s(1), recovery_min, 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_recovery_time_s(5), lerpf(recovery_min, recovery_max, 4.0 / 14.0), 0.001)
	assert_almost_eq(LocalRaceMath.heart_rate_recovery_time_s(15), recovery_max, 0.001)
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
	# 戻る速さは、戻す時間から決まる基準の速さ × 倍率を超えない。
	assert_gt(
		LocalRaceMath.heart_rate_net_rate_bpm_per_s(200.0, 0.0, 5),
		-LocalRaceMath.heart_rate_recovery_rate_base_bpm_per_s(5) * LocalRaceMath.Config.number("heart_rate_recovery_rate_scale")
	)
	assert_eq(LocalRaceMath.heart_rate_net_rate_bpm_per_s(100.0, 0.0, 5), 0.0)


func test_heart_adaptation_moves_toward_the_heart_level_and_strengthens_recovery() -> void:
	var low := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var high := LocalRaceMath.Config.number("heart_rate_overheat_max_bpm")
	# 心拍が最低なら0へ、最高なら1へ向かう。
	assert_almost_eq(LocalRaceMath.heart_adaptation_next(0.5, low, 1.0), 0.5 - 0.5 * (1.0 / LocalRaceMath.Config.number("heart_adaptation_time_s")), 0.0001)
	assert_gt(LocalRaceMath.heart_adaptation_next(0.2, high, 1.0), 0.2)
	assert_lte(LocalRaceMath.heart_adaptation_next(0.99, high, 1000.0), 1.0)
	# 慣れが1のとき、下げる力は（1 + 効き）倍。
	var gain := LocalRaceMath.Config.number("heart_adaptation_recovery_gain")
	var plain := LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(170.0, 5)
	assert_almost_eq(LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(170.0, 5, 1.0), plain * (1.0 + gain), 0.0001)
	assert_almost_eq(LocalRaceMath.heart_rate_natural_recovery_rate_bpm_per_s(170.0, 5, 0.0), plain, 0.0001)


func test_with_adaptation_the_heart_rate_peaks_and_then_eases_down_at_a_steady_notch() -> void:
	var heart := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var adaptation := 0.0
	var peak := heart
	for _step in 1300:
		heart = clampf(heart + LocalRaceMath.heart_rate_net_rate_bpm_per_s(heart, 4.0, 5, adaptation) * 0.1, 100.0, 230.0)
		adaptation = LocalRaceMath.heart_adaptation_next(adaptation, heart, 0.1)
		peak = maxf(peak, heart)
	assert_lt(heart, peak)
	# 慣れがなければ、同じノッチで最高から下がることはない。
	var plain := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var plain_peak := plain
	for _step in 1300:
		plain = clampf(plain + LocalRaceMath.heart_rate_net_rate_bpm_per_s(plain, 4.0, 5) * 0.1, 100.0, 230.0)
		plain_peak = maxf(plain_peak, plain)
	assert_almost_eq(plain, plain_peak, 0.001)


func test_lateral_move_load_is_proportional_to_distance_and_smaller_for_high_handling() -> void:
	assert_eq(LocalRaceMath.lateral_move_heart_load_bpm(0.0, 5), 0.0)
	assert_eq(LocalRaceMath.lateral_move_stamina_load_l(0.0, 5), 0.0)
	var one := LocalRaceMath.lateral_move_heart_load_bpm(1.0, 5)
	assert_gt(one, 0.0)
	assert_almost_eq(LocalRaceMath.lateral_move_heart_load_bpm(3.0, 5), one * 3.0, 0.0001)
	assert_almost_eq(LocalRaceMath.lateral_move_heart_load_bpm(1.0, 5), LocalRaceMath.Config.number("lateral_move_heart_load_bpm_per_m"), 0.0001)
	assert_lt(LocalRaceMath.lateral_move_heart_load_bpm(1.0, 15), LocalRaceMath.lateral_move_heart_load_bpm(1.0, 5))
	assert_gt(LocalRaceMath.lateral_move_stamina_load_l(1.0, 1), LocalRaceMath.lateral_move_stamina_load_l(1.0, 5))
	assert_gte(LocalRaceMath.lateral_move_load_multiplier(15), 0.2)


func test_lateral_move_adds_heart_and_stamina_load_to_the_runner() -> void:
	var results := {}
	for moved: float in [0.0, 2.0]:
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
		runner.set("_effective_stats", {"handling": 5, "stamina": 5, "cardio": 5})
		runner.call("_reset_stamina_for_effective_stats")
		runner.set("_lateral_move_m", moved)
		var heart_before := float(runner.call("get_heart_rate_bpm"))
		var stamina_before := float(runner.call("get_stamina"))
		runner.call("_update_condition_for_drive_level", 0.0, 1.0)
		results[moved] = {"heart": float(runner.call("get_heart_rate_bpm")) - heart_before, "stamina": stamina_before - float(runner.call("get_stamina"))}
		runner.free()
	assert_gt(float(results[2.0]["heart"]), float(results[0.0]["heart"]))
	assert_gt(float(results[2.0]["stamina"]), float(results[0.0]["stamina"]))
	assert_almost_eq(
		float(results[2.0]["stamina"]) - float(results[0.0]["stamina"]),
		LocalRaceMath.lateral_move_stamina_load_l(2.0, 5),
		0.0001
	)


func test_line_speed_penalty_grows_toward_the_edge_of_the_course_in_corners() -> void:
	var curvature := 1.0 / 164.0
	var edge := M2TrackMath.MAX_ABS_OFFSET_M
	var reference_speed := LocalRaceMath.Config.number("line_speed_penalty_reference_speed_kmh")
	var outer_edge := LocalRaceMath.Config.number("line_speed_penalty_outer_edge")
	# 中央では遅くならない。直線では、端でも遅くならない。
	assert_eq(LocalRaceMath.line_speed_multiplier(0.0, curvature, reference_speed), 1.0)
	assert_eq(LocalRaceMath.line_speed_multiplier(edge, 0.0, reference_speed), 1.0)
	# 外側の端・基準の速さ・操作性5で、設定の遅れ。
	assert_almost_eq(LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed), 1.0 - outer_edge, 0.0001)
	# 内側（距離倍率が小さい側）は、外側より軽い。
	var inner := LocalRaceMath.line_speed_multiplier(-edge, curvature, reference_speed)
	assert_almost_eq(inner, 1.0 - outer_edge * LocalRaceMath.Config.number("line_speed_penalty_inner_ratio"), 0.0001)
	assert_gt(inner, LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed))
	# 中央から離れるほど遅い。端までの半分では、端の4分の1の遅れ。
	assert_almost_eq(1.0 - LocalRaceMath.line_speed_multiplier(edge * 0.5, curvature, reference_speed), outer_edge * 0.25, 0.0001)
	# 速いほど、遅れが大きい。操作性が高いほど、遅れが小さい。
	assert_lt(LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed * 1.2), LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed))
	assert_gt(LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed, 15), LocalRaceMath.line_speed_multiplier(edge, curvature, reference_speed, 5))
	# 曲がる向きが逆でも、内側は内側。
	assert_almost_eq(LocalRaceMath.line_speed_multiplier(edge, -curvature, reference_speed), inner, 0.0001)


func test_drive_change_load_is_proportional_to_levels_and_smaller_for_high_handling() -> void:
	assert_eq(LocalRaceMath.drive_change_heart_load_bpm(0.0, 5), 0.0)
	assert_eq(LocalRaceMath.drive_change_stamina_load_l(0.0, 5), 0.0)
	assert_almost_eq(LocalRaceMath.drive_change_heart_load_bpm(1.0, 5), LocalRaceMath.Config.number("drive_change_heart_load_bpm_per_level"), 0.0001)
	assert_almost_eq(LocalRaceMath.drive_change_heart_load_bpm(3.0, 5), LocalRaceMath.drive_change_heart_load_bpm(1.0, 5) * 3.0, 0.0001)
	assert_lt(LocalRaceMath.drive_change_heart_load_bpm(1.0, 15), LocalRaceMath.drive_change_heart_load_bpm(1.0, 5))
	assert_gt(LocalRaceMath.drive_change_stamina_load_l(1.0, 1), LocalRaceMath.drive_change_stamina_load_l(1.0, 5))
	assert_gte(LocalRaceMath.drive_change_load_multiplier(15), 0.2)


func test_changing_the_notch_adds_heart_and_stamina_load_but_the_first_frame_does_not() -> void:
	var results := {}
	for change: float in [0.0, 3.0]:
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
		runner.set("_effective_stats", {"handling": 5, "stamina": 5, "cardio": 5})
		runner.call("_reset_stamina_for_effective_stats")
		runner.set("_drive_level", 2.0)
		# 最初のフレームは、前のノッチが決まっていないので、負荷を数えない。
		runner.call("_update_condition_for_drive_level", 2.0, 1.0)
		var heart_before := float(runner.call("get_heart_rate_bpm"))
		var stamina_before := float(runner.call("get_stamina"))
		runner.set("_drive_level", 2.0 + change)
		runner.call("_update_condition_for_drive_level", 2.0 + change, 1.0)
		results[change] = {"heart": float(runner.call("get_heart_rate_bpm")) - heart_before, "stamina": stamina_before - float(runner.call("get_stamina"))}
		runner.free()
	assert_gt(float(results[3.0]["heart"]), float(results[0.0]["heart"]))
	var stamina_gap := float(results[3.0]["stamina"]) - float(results[0.0]["stamina"])
	assert_gt(stamina_gap, LocalRaceMath.drive_change_stamina_load_l(3.0, 5) * 0.99)


func _draft_received(handling: int, line_gap: float) -> float:
	var snapshot := [
		{"id": "me", "race_progress": 100.0, "offset": 0.0, "speed": 60.0, "handling": handling},
		{"id": "front", "race_progress": 103.0, "offset": line_gap, "speed": 60.0},
	]
	return float(LocalRaceMath.calculate_draft_details(snapshot, 0)["received_draft_p"])


func test_handling_widens_the_lateral_range_that_draft_reaches() -> void:
	var lateral_range := float(LocalRaceMath.DRAFT_LATERAL_RANGE_M)
	var straight := _draft_received(5, 0.0)
	assert_gt(straight, 0.0)
	# 操作性5は、今の効き方（1 − 横の差 ÷ 効く横幅）。
	assert_almost_eq(_draft_received(5, 1.0) / straight, pow(1.0 - 1.0 / lateral_range, LocalRaceMath.DRAFT_LATERAL_FALLOFF_EXPONENT), 0.0001)
	# 操作性が高いほど、同じ横の差で効く。低いほど効かない。真後ろは変わらない。
	assert_gt(_draft_received(15, 1.0), _draft_received(5, 1.0))
	assert_lt(_draft_received(1, 1.0), _draft_received(5, 1.0))
	assert_almost_eq(_draft_received(15, 0.0), straight, 0.0001)
	# 操作性が高いと、基準の横幅より外の走者からも効く。
	assert_eq(_draft_received(5, lateral_range + 0.2), 0.0)
	assert_gt(_draft_received(15, lateral_range + 0.2), 0.0)
	assert_almost_eq(LocalRaceMath.draft_lateral_range_multiplier(5), 1.0, 0.0001)
	assert_gte(LocalRaceMath.draft_lateral_range_multiplier(1), 0.5)


func test_provisional_cardio_range_makes_low_cardio_notch_four_and_full_effort_costly() -> void:
	var low_cardio_cruise := 100.0
	var high_cardio_full_effort := 100.0
	for _step in 1200:
		low_cardio_cruise = clampf(low_cardio_cruise + LocalRaceMath.heart_rate_net_rate_bpm_per_s(low_cardio_cruise, 4.0, 1) * 0.1, 100.0, 230.0)
		high_cardio_full_effort = clampf(high_cardio_full_effort + LocalRaceMath.heart_rate_net_rate_bpm_per_s(high_cardio_full_effort, 6.0, 15) * 0.1, 100.0, 230.0)
	var mid_cardio_cruise := 100.0
	for _step in 1200:
		mid_cardio_cruise = clampf(mid_cardio_cruise + LocalRaceMath.heart_rate_net_rate_bpm_per_s(mid_cardio_cruise, 4.0, 5) * 0.1, 100.0, 230.0)
	# 心肺が低いほど、同じノッチ4でも心拍が高く落ち着く。心肺が高くても、フルでは通常上限を超える。
	assert_gt(low_cardio_cruise, mid_cardio_cruise)
	assert_gt(high_cardio_full_effort, LocalRaceMath.Config.number("heart_rate_normal_max_bpm"))


func test_stamina_capacity_is_fuel_tank_and_consumption_is_stat_independent() -> void:
	var capacity_base := LocalRaceMath.Config.number("stamina_capacity_base_l")
	var capacity_per_stat := LocalRaceMath.Config.number("stamina_capacity_per_stat_l")
	for stamina_stat: int in [1, 5, 10, 15]:
		assert_almost_eq(LocalRaceMath.stamina_capacity_l(stamina_stat), capacity_base + capacity_per_stat * stamina_stat, 0.0001)
	assert_gt(LocalRaceMath.stamina_capacity_l(15), LocalRaceMath.stamina_capacity_l(1))
	assert_eq(LocalRaceMath.stamina_delta_l_per_s(0.0, 200.0), 0.0)
	assert_eq(LocalRaceMath.stamina_delta_l_per_s(-1.0, 200.0), 0.0)
	assert_lt(LocalRaceMath.stamina_delta_l_per_s(6.0, 200.0), 0.0)
	assert_almost_eq(
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 200.0, 1.15),
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 200.0, 1.15),
		0.000001
	)
	assert_gt(
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 200.0, 1.45),
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 200.0, 1.15)
	)
	assert_gt(
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 200.0, 1.30),
		LocalRaceMath.stamina_consumption_l_per_s(6.0, 100.0, 1.30)
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
	assert_almost_eq(LocalRaceMath.overheat_exposure_propulsion_efficiency(exposure), maxf(1.0 - exposure * LocalRaceMath.Config.number("overheat_exposure_efficiency_loss_per_s"), LocalRaceMath.Config.number("overheat_propulsion_efficiency_min")), 0.002)
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
	assert_almost_eq(LocalRaceMath.stamina_debt_efficiency(0.0, 20.0), 1.0, 0.001)
	assert_almost_eq(LocalRaceMath.stamina_debt_efficiency(-20.0, 20.0), LocalRaceMath.Config.number("stamina_debt_efficiency_min"), 0.001)
	assert_almost_eq(LocalRaceMath.stamina_debt_efficiency(-35.0, 35.0), LocalRaceMath.Config.number("stamina_debt_efficiency_min"), 0.001)
	assert_almost_eq(
		LocalRaceMath.advance_drive_speed_kmh(50.0, 6.0, 75.0, 1.0, 0.0, 0.0, 0.0, 0.75),
		50.0 + _drive_force(6) * 0.75 - LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S - _air_resistance(50.0),
		0.001
	)


func _speed_after_thirty_seconds_at_heart(heart_bpm: float) -> float:
	var speed := 69.0
	var exposure := 0.0
	for _step in 600:
		exposure = LocalRaceMath.update_overheat_exposure(exposure, heart_bpm, 0.05)
		var top_speed_adjustment := LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(speed, 6.0, 9)
		speed = LocalRaceMath.advance_drive_speed_kmh(
			speed,
			6.0,
			120.0,
			0.05,
			0.0,
			0.0,
			top_speed_adjustment,
			LocalRaceMath.overheat_exposure_propulsion_efficiency(exposure)
		)
	return speed


func test_220_bpm_thirty_seconds_lowers_single_runner_speed() -> void:
	# 220bpmを30秒続けると、通常の心拍のときより、明らかに遅くなる（数値の決め打ちはしない）。
	var normal := _speed_after_thirty_seconds_at_heart(150.0)
	var overheated := _speed_after_thirty_seconds_at_heart(220.0)
	assert_gt(normal - overheated, 3.0)
	assert_gt(overheated, LocalRaceMath.MIN_SPEED_KMH)


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
	player.set("_received_draft_p", LocalRaceMath.draft_response_reference_p())
	player.set("_direct_draft_p", LocalRaceMath.draft_response_reference_p())
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
	assert_true(lines.has("実効 %d%%" % int(roundf(_expected_effective_ratio(1.0) * 100.0))))
	assert_true(lines.has("集団補正 x1.00"))
	assert_false(hud.text.contains("上限補正"))
	assert_true(lines.has("対象1 CPU2 前4.0m 横1.0m"))
	assert_true(lines.has("推進力 +0.00km/h/s"))
	assert_true(lines.has("転がり抵抗 %+.2fkm/h/s" % -LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S))
	# 40km/h・空力5・基準比100%の組み合わせ。設定の現値に依存せず式から期待値を作る。
	var air := LocalRaceMath.AIR_RESISTANCE_QUADRATIC_COEFFICIENT * 40.0 * 40.0
	assert_true(lines.has("空気抵抗（二乗） %+.2fkm/h/s" % -air))
	var reduction := air * LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR * _expected_effective_ratio(1.0)
	assert_true(lines.has("ドラフト軽減 %+.2fkm/h/s" % reduction))
	assert_true(lines.has("計算加速度 %+.2fkm/h/s" % (-(LocalRaceMath.ROLLING_RESISTANCE_KMH_PER_S + air - reduction))))
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
	assert_true(solo_lines.has("集団補正 x1.00"))
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
	player.set("_effective_stats", {"aero": 15, "pack": 15})
	player.set("_current_speed_kmh", 57.0)
	player.call("set_drive_level", 3.0)
	# 生の44%表示へ丸まる43.5%は、集団15の補正後に実効約35%となる。
	var received := LocalRaceMath.draft_response_reference_p() * 0.435
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
	assert_true(lines.has("実効 %d%%" % int(roundf(_expected_effective_ratio(0.435, LocalRaceMath.pack_draft_effective_multiplier(15)) * 100.0))))
	assert_true(lines.has("集団補正 x%.2f" % LocalRaceMath.pack_draft_effective_multiplier(15)))
	assert_true(lines.has("空力 有効15　抵抗補正 x%.2f" % LocalRaceMath.aero_air_resistance_multiplier(15)))
	var expected_air := LocalRaceMath.AIR_RESISTANCE_QUADRATIC_COEFFICIENT * 57.0 * 57.0 * LocalRaceMath.aero_air_resistance_multiplier(15)
	assert_true(lines.has("空気抵抗（二乗） %+.2fkm/h/s" % -expected_air))
	var expected_reduction := expected_air * LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR * _expected_effective_ratio(0.435, LocalRaceMath.pack_draft_effective_multiplier(15))
	assert_true(lines.has("ドラフト軽減 %+.2fkm/h/s" % expected_reduction))
	assert_true(hud.text.contains("計算加速度"))
	var telemetry: Dictionary = player.call("get_telemetry_snapshot")
	assert_almost_eq(float(telemetry["draft"]["effective_draft_ratio"]), _expected_effective_ratio(0.435, LocalRaceMath.pack_draft_effective_multiplier(15)), 0.001)
	assert_almost_eq(float(telemetry["draft"]["pack_draft_effective_multiplier"]), LocalRaceMath.pack_draft_effective_multiplier(15), 0.001)
	assert_almost_eq(float(telemetry["drive_diagnostics"]["air_resistance_multiplier"]), LocalRaceMath.aero_air_resistance_multiplier(15), 0.001)
	player.free()
	race.free()


func runner_snapshot_for_hud(race: Node3D, player: Node3D) -> void:
	race.set("_player", player)
	race.set("_race_started", true)
	race.call("_update_hud")


func test_local_race_uses_its_own_camera_with_adjustable_views() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var camera: Camera3D = race.get_node("Camera3D")
	assert_eq(camera.get_script(), LocalRaceCameraScript)
	assert_eq(camera.get("view"), LocalRaceCameraScript.View.DEFAULT)
	var target := Node3D.new()
	add_child(target)
	target.global_position = Vector3(3.0, 0.0, 4.0)
	camera.call("set_follow_target", target)
	camera.call("_process", 0.0)
	var settings: Dictionary = LocalRaceCameraScript.VIEW_SETTINGS[LocalRaceCameraScript.View.DEFAULT]
	var initial_position := camera.global_position
	assert_almost_eq(initial_position.y, float(settings["height"]), 0.001)
	assert_almost_eq(initial_position.z - target.global_position.z, float(settings["back"]), 0.001)
	# 向きの微調整は、カメラの位置を動かさない。
	camera.set("_yaw_offset", PI * 0.5)
	camera.call("_process", 0.0)
	assert_almost_eq(camera.global_position.x, initial_position.x, 0.001)
	assert_almost_eq(camera.global_position.z, initial_position.z, 0.001)
	# 微調整は、元に戻せる。
	camera.set("_back_offset", 10.0)
	camera.set("_lateral_offset", 8.0)
	camera.call("_reset_adjustment")
	camera.call("_process", 0.0)
	assert_almost_eq(camera.global_position.x, initial_position.x, 0.001)
	assert_almost_eq(camera.global_position.z, initial_position.z, 0.001)
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


func test_drive_has_no_curve_or_line_speed_penalty() -> void:
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
	assert_gt(float(details["direct_draft_p"]), 0.0)


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


func test_local_draft_direct_and_chain_total_is_not_capped() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "receiver", "race_progress": 0.0, "offset": 0.0, "speed": 60.0},
		{"id": "source", "race_progress": 1.5, "offset": 0.0, "speed": 300.0,
			"direct_draft_p": LocalRaceMath.draft_response_reference_p() * 2.0,
			"chain_draft_p": LocalRaceMath.draft_response_reference_p() * 2.0},
	], 0)
	var total := float(details["direct_draft_p"]) + float(details["chain_draft_p"])
	assert_gt(total, LocalRaceMath.draft_response_reference_p())
	assert_almost_eq(float(details["received_draft_p"]), total, 0.000001)


func test_finished_runners_continue_to_receive_and_supply_local_draft() -> void:
	var details := LocalRaceMath.calculate_draft_details([
		{"id": "player-1", "race_progress": 2000.0, "offset": 0.0, "speed": 60.0, "finished": true},
		{"id": "cpu-finished", "race_progress": 2004.0, "offset": 0.0, "speed": 60.0, "finished": true},
		{"id": "cpu-running", "race_progress": 2006.0, "offset": 0.5, "speed": 60.0},
	], 0)
	assert_eq(details["direct_source_ids"], ["cpu-finished", "cpu-running"])
	assert_gt(float(details["received_draft_p"]), 0.0)


func test_body_gap_is_an_ellipse() -> void:
	var longitudinal := LocalRaceMath.CONTACT_LONGITUDINAL_M
	var lateral := LocalRaceMath.BLOCK_LATERAL_M
	assert_almost_eq(LocalRaceMath.required_longitudinal_gap(0.0), longitudinal, 0.0001)
	assert_almost_eq(LocalRaceMath.required_longitudinal_gap(lateral), 0.0, 0.0001)
	assert_almost_eq(LocalRaceMath.required_longitudinal_gap(lateral * 2.0), 0.0, 0.0001)
	assert_lt(LocalRaceMath.required_longitudinal_gap(lateral * 0.9), LocalRaceMath.required_longitudinal_gap(lateral * 0.5))
	assert_almost_eq(LocalRaceMath.required_lateral_gap(0.0), lateral, 0.0001)
	assert_almost_eq(LocalRaceMath.required_lateral_gap(longitudinal), 0.0, 0.0001)


func test_contact_prevention_never_passes_through_and_eases_in() -> void:
	var gap := LocalRaceMath.CONTACT_LONGITUDINAL_M
	var others := [{"race_progress": 12.0, "offset": 0.0, "actual_speed": 0.0}]
	var delta := 1.0 / 60.0
	# 遠いうちは提案どおり進む。
	assert_almost_eq(LocalRaceMath.allowed_race_progress(0.0, 0.1, 0.0, others, delta), 0.1, 0.0001)
	# 横に離れていれば妨げない。
	var wide := LocalRaceMath.BLOCK_LATERAL_M + 0.5
	assert_almost_eq(LocalRaceMath.allowed_race_progress(10.0, 11.0, wide, others, delta), 11.0, 0.0001)
	# 止まった前走者に速い走者が近づいても、1フレームで張り付かず、重ならない。
	var progress := 10.0
	var first_step := -1.0
	for i in 600:
		var next := LocalRaceMath.allowed_race_progress(progress, progress + 60.0 / 3.6 * delta, 0.0, others, delta)
		if first_step < 0.0:
			first_step = next - progress
		assert_lte(next, 12.0 - gap + 0.0001)
		assert_gte(next, progress)
		progress = next
	assert_gt(first_step, 0.0)
	assert_almost_eq(progress, 12.0 - gap, 0.01)


func test_contact_prevention_follows_leader_speed_smoothly() -> void:
	var delta := 1.0 / 60.0
	var leader_kmh := 55.0
	var follower_kmh := 60.0
	var leader := 20.0
	var follower := 10.0
	var previous_move := follower_kmh / 3.6 * delta
	var max_drop_kmh := 0.0
	for i in 1200:
		leader += leader_kmh / 3.6 * delta
		var others := [{"race_progress": leader, "offset": 0.0, "actual_speed": leader_kmh}]
		var next := LocalRaceMath.allowed_race_progress(follower, follower + follower_kmh / 3.6 * delta, 0.0, others, delta)
		assert_lte(next, leader - LocalRaceMath.CONTACT_LONGITUDINAL_M + 0.0001)
		var move := next - follower
		max_drop_kmh = maxf(max_drop_kmh, (previous_move - move) / delta * 3.6)
		previous_move = move
		follower = next
	# 1フレームの落ち幅は、速度差（5km/h）よりずっと小さい。
	assert_lt(max_drop_kmh, 1.0)
	assert_almost_eq(previous_move / delta * 3.6, leader_kmh, 0.5)


func test_front_block_applies_only_to_a_runner_almost_straight_ahead() -> void:
	var delta := 1.0 / 60.0
	var others := [{"race_progress": 12.0, "offset": 0.0, "actual_speed": 0.0}]
	var front := LocalRaceMath.FRONT_BLOCK_LATERAL_M
	# 真後ろに近い（横の差が小さい）と、前の走者の手前で止まる。
	var behind := 10.0
	for i in 600:
		behind = LocalRaceMath.allowed_race_progress(behind, behind + 0.3, front * 0.5, others, delta)
	assert_lt(behind, 12.0)
	# 斜め・横（横の差がそれ以上）では、前後では止めない（横の押し合いで解く）。
	assert_almost_eq(LocalRaceMath.allowed_race_progress(11.5, 11.8, front + 0.01, others, delta), 11.8, 0.0001)
	assert_lt(front, LocalRaceMath.BLOCK_LATERAL_M)


func test_contact_prevention_rejects_only_lateral_moves_into_another_runner() -> void:
	var others := [{"race_progress": 10.0, "offset": 0.0}]
	assert_false(LocalRaceMath.can_use_offset(10.0, 0.5, others))
	assert_true(LocalRaceMath.can_use_offset(10.0, 1.5, others))


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
	assert_eq(LocalRaceMath.format_race_time(58.449), "0分58秒44")
	assert_eq(LocalRaceMath.format_race_time(83.44), "1分23秒44")
	assert_eq(LocalRaceMath.format_race_time(125.0), "2分05秒00")
	assert_eq(LocalRaceMath.format_race_time(119.999), "1分59秒99")
	assert_eq(LocalRaceMath.format_race_time(-1.0), "0分00秒00")


func test_innermost_gate_is_most_negative_offset() -> void:
	var gate0 := LocalRaceMath.starting_offset_for_gate(0)
	var gate7 := LocalRaceMath.starting_offset_for_gate(7)
	assert_lt(gate0, gate7)
	assert_lt(gate0, 0.0)


func test_stamina_capacity_uses_pre_race_stats_regardless_of_running_style() -> void:
	# 生成時は他頭情報が無く全員1位扱いになるため、順位補正を容量へ混ぜない。
	var base: Dictionary = PururinRosterConfig.pururin_by_id("player-1").duplicate(true)
	var capacities := {}
	for style_id in ["escape", "pace", "stalk", "closer"]:
		var pururin := base.duplicate(true)
		pururin["running_style"] = style_id
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 0, 75.0, false, "テスト", pururin)
		capacities[style_id] = float(runner.call("get_stamina_capacity_l"))
		runner.free()
	var pre_race := PururinStatsMath.pre_race_stats(str(base["attribute"]), base["allocation"])
	for style_id in capacities:
		assert_almost_eq(capacities[style_id], LocalRaceMath.stamina_capacity_l(int(pre_race["stamina"])), 0.0001, style_id)


func test_same_tick_finishers_are_ordered_by_crossing_time_not_spawn_order() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player := Node3D.new()
	var cpu := Node3D.new()
	for runner in [player, cpu]:
		runner.set_script(RunnerScript)
		add_child(runner)
	player.call("setup_for_race", null, 0, 75.0, true, "プレイヤー")
	cpu.call("setup_for_race", null, 1, 75.0, false, "CPU")
	var distance := float(race.get("_race_distance_m"))
	# プレイヤーは生成順で先だが、線を越えたのはCPUが先。
	player.set("_tick_start_progress", distance - 1.0)
	player.set("_race_progress", distance + 0.5)
	player.set("_last_tick_delta", 0.1)
	cpu.set("_tick_start_progress", distance - 0.1)
	cpu.set("_race_progress", distance + 1.0)
	cpu.set("_last_tick_delta", 0.1)
	var racers: Array[Node3D] = [player, cpu]
	race.set("_runners", racers)
	race.set("_race_elapsed", 10.0)
	race.call("_check_finishes")
	assert_eq(int(cpu.call("get_finish_order")), 1)
	assert_eq(int(player.call("get_finish_order")), 2)
	assert_almost_eq(float(cpu.call("get_finish_time")), 10.0 - 0.1 * (1.0 - 0.1 / 1.1), 0.0001)
	assert_almost_eq(float(player.call("get_finish_time")), 10.0 - 0.1 * (1.0 - 1.0 / 1.5), 0.0001)
	player.free()
	cpu.free()
	race.free()


func test_actual_speed_matches_output_speed_when_free_and_drops_when_blocked() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	player.set("_race_active", true)
	player.call("set_drive_level", 3.0)
	player.set("_current_speed_kmh", 60.0)
	player.set("_others_snapshot", [])
	for _tick in 40:
		player.call("_process", 0.05)
	assert_almost_eq(float(player.call("get_actual_speed")), float(player.call("get_current_speed")), 1.0)
	# 同じラインの少し前にいる走者にふさがれると、出力上の速度が高くても実際には進めない。
	var ahead := {
		"id": "blocker", "race_progress": float(player.call("get_race_progress")) + LocalRaceMath.CONTACT_LONGITUDINAL_M + 0.2,
		"progress": 0.0, "offset": float(player.call("get_offset")), "speed": 40.0,
	}
	player.set("_others_snapshot", [ahead])
	player.set("_current_speed_kmh", 70.0)
	for _tick in 40:
		player.call("_process", 0.05)
	# 出力上の速度は、実際の速度に上限ぶんしか上乗せできない（最低速度は下回らない）。
	assert_lte(float(player.call("get_current_speed")), maxf(float(player.call("get_actual_speed")) + LocalRaceMath.BLOCKED_SPEED_EXCESS_MAX_KMH, LocalRaceMath.MIN_SPEED_KMH) + 0.01)
	assert_lt(float(player.call("get_actual_speed")), 15.0)
	race.free()


func _rear_snapshot(behind_m: float, offset_gap: float = 0.0) -> Array:
	var wake := LocalRaceMath.draft_wake_from_speed(60.0)
	return [
		{"id": "front", "race_progress": 100.0, "offset": 0.0, "speed": 60.0},
		{"id": "rear", "race_progress": 100.0 - behind_m, "offset": offset_gap, "speed": 60.0, "own_wake_p": wake},
	]


func test_rear_assist_uses_runners_behind_within_range_and_lateral_limit() -> void:
	var inside := LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0), 0)
	assert_gt(float(inside["rear_assist_p"]), 0.0)
	assert_eq(inside["rear_source_ids"], ["rear"])
	# 近すぎる（接触距離）、範囲外の後方、横に離れすぎ、前にいる走者は対象外。
	assert_eq(float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(LocalRaceMath.DRAFT_FORWARD_MIN_M - 0.1), 0)["rear_assist_p"]), 0.0)
	assert_eq(float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(LocalRaceMath.REAR_ASSIST_RANGE_M + 0.1), 0)["rear_assist_p"]), 0.0)
	assert_eq(float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0, LocalRaceMath.DRAFT_LATERAL_RANGE_M + 0.1), 0)["rear_assist_p"]), 0.0)
	assert_eq(float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0), 1)["rear_assist_p"]), 0.0)


func test_rear_assist_shrinks_with_distance_and_lateral_offset() -> void:
	var near := float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0), 0)["rear_assist_p"])
	var far := float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(4.0), 0)["rear_assist_p"])
	var off_line := float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0, 1.5), 0)["rear_assist_p"])
	assert_gt(near, far)
	assert_gt(near, off_line)


func test_rear_assist_does_not_chain_and_stays_below_full_reduction() -> void:
	# 後ろの走者が、さらに後ろの走者から受けていても、前の走者への寄与は増えない。
	var wake := LocalRaceMath.draft_wake_from_speed(60.0)
	var plain := _rear_snapshot(2.0)
	var chained := _rear_snapshot(2.0)
	chained[1]["direct_draft_p"] = 1.0
	chained[1]["chain_draft_p"] = 1.0
	assert_almost_eq(
		float(LocalRaceMath.calculate_rear_assist_details(chained, 0)["rear_assist_p"]),
		float(LocalRaceMath.calculate_rear_assist_details(plain, 0)["rear_assist_p"]),
		0.00001
	)
	for aero: int in [1, 5, 15]:
		assert_lte(LocalRaceMath.rear_assist_air_factor(1000.0, aero), LocalRaceMath.REAR_ASSIST_TRANSFER_RATE)
	assert_lt(LocalRaceMath.combined_air_reduction_factor(0.8, LocalRaceMath.REAR_ASSIST_TRANSFER_RATE), 1.0)
	assert_eq(LocalRaceMath.combined_air_reduction_factor(0.0, 0.0), 0.0)
	assert_gt(wake, 0.0)


func test_higher_aero_receives_more_rear_assist() -> void:
	var received := float(LocalRaceMath.calculate_rear_assist_details(_rear_snapshot(2.0), 0)["rear_assist_p"])
	assert_gt(LocalRaceMath.rear_assist_air_factor(received, 15), LocalRaceMath.rear_assist_air_factor(received, 5))
	assert_gt(LocalRaceMath.rear_assist_air_factor(received, 5), LocalRaceMath.rear_assist_air_factor(received, 1))
	assert_eq(LocalRaceMath.rear_assist_air_factor(0.0, 15), 0.0)


func test_runner_air_reduction_combines_draft_and_rear_assist() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	runner.set("_effective_stats", {"aero": 10, "pack": 5})
	var without_rear: float = runner.call("_draft_air_resistance_factor")
	runner.call("apply_rear_assist_details", {"rear_assist_p": 0.3, "rear_source_ids": ["x"]})
	assert_gt(float(runner.call("_draft_air_resistance_factor")), without_rear)
	assert_almost_eq(float(runner.call("get_draft_status")["rear_assist_air_factor"]), LocalRaceMath.rear_assist_air_factor(0.3, 10), 0.00001)
	runner.free()


func test_air_reduction_breakdown_matches_the_resistance_used_for_driving() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	for aero: int in [5, 10, 15]:
		runner.set("_effective_stats", {"aero": aero, "pack": 5})
		runner.set("_received_draft_p", LocalRaceMath.draft_response_reference_p() * 2.0)
		runner.call("apply_rear_assist_details", {"rear_assist_p": 0.2, "rear_source_ids": ["x"]})
		var breakdown: Dictionary = runner.call("get_air_reduction_breakdown")
		var diagnostics: Dictionary = runner.call("get_drive_diagnostics")
		var base_air := LocalRaceMath.AIR_RESISTANCE_QUADRATIC_COEFFICIENT * pow(maxf(float(runner.call("get_current_speed")), LocalRaceMath.MIN_SPEED_KMH), 2.0)
		# 実際に残る空気抵抗 ＝ 元の抵抗 × (1 − 合計の減り)。
		var remaining := float(diagnostics["air_resistance_kmh_per_s"]) - float(diagnostics["draft_air_reduction_kmh_per_s"])
		assert_almost_eq(remaining, base_air * (1.0 - float(breakdown["total"])), 0.0001, "aero %d" % aero)
		assert_almost_eq(float(breakdown["aero_rear"]) + float(breakdown["draft"]), float(breakdown["total"]), 0.00001)
		assert_gt(float(breakdown["draft"]), 0.0)
	runner.free()


func test_air_reduction_breakdown_shows_no_green_for_low_aero() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	runner.set("_effective_stats", {"aero": 1, "pack": 5})
	var breakdown: Dictionary = runner.call("get_air_reduction_breakdown")
	assert_eq(float(breakdown["aero_rear"]), 0.0)
	assert_eq(float(breakdown["total"]), 0.0)
	runner.free()


func test_speed_excess_over_actual_is_limited_but_not_below_minimum() -> void:
	assert_eq(LocalRaceMath.limit_speed_excess_kmh(81.0, 58.0, 8.0), 66.0)
	assert_eq(LocalRaceMath.limit_speed_excess_kmh(60.0, 58.0, 8.0), 60.0)
	assert_eq(LocalRaceMath.limit_speed_excess_kmh(50.0, 58.0, 8.0), 50.0)
	assert_eq(LocalRaceMath.limit_speed_excess_kmh(45.0, 10.0, 8.0), LocalRaceMath.MIN_SPEED_KMH)


func test_blocked_runner_cannot_store_much_more_speed_than_it_moves() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	var player: Node = race.get_node("Runners/Runner1")
	player.set("_race_active", true)
	player.call("set_drive_level", 4.0)
	player.set("_current_speed_kmh", 60.0)
	var ahead := {
		"id": "blocker", "race_progress": float(player.call("get_race_progress")) + LocalRaceMath.CONTACT_LONGITUDINAL_M + 0.2,
		"progress": 0.0, "offset": float(player.call("get_offset")), "speed": 40.0,
	}
	player.set("_others_snapshot", [ahead])
	player.set("_received_draft_p", LocalRaceMath.draft_response_reference_p() * 8.0)
	for _tick in 120:
		player.call("_process", 0.05)
	var limit := maxf(float(player.call("get_actual_speed")) + LocalRaceMath.BLOCKED_SPEED_EXCESS_MAX_KMH, LocalRaceMath.MIN_SPEED_KMH)
	assert_lte(float(player.call("get_current_speed")), limit + 0.01)
	race.free()


func test_handling_scales_line_movement_speed_around_the_reference_stat() -> void:
	var reference := LocalRaceMath.HANDLING_STEER_REFERENCE_STAT
	assert_almost_eq(LocalRaceMath.handling_steer_multiplier(reference), 1.0, 0.00001)
	assert_gt(LocalRaceMath.handling_steer_multiplier(15), 1.0)
	assert_lt(LocalRaceMath.handling_steer_multiplier(1), 1.0)
	assert_almost_eq(
		LocalRaceMath.handling_steer_multiplier(15),
		1.0 + LocalRaceMath.HANDLING_STEER_MULTIPLIER_PER_STAT * (15 - reference),
		0.00001
	)
	assert_gt(LocalRaceMath.handling_steer_multiplier(1), 0.0)


func test_cpu_with_higher_handling_moves_to_its_target_line_faster() -> void:
	var moved := {}
	for handling: int in [1, 15]:
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 1, 75.0, false, "CPU", PururinRosterConfig.pururin_by_id("cpu-1"))
		runner.set("_effective_stats", {"handling": handling})
		runner.set("_offset", 0.0)
		runner.set("_target_offset", 5.0)
		runner.set("_cpu_steer_timer", 100.0)
		runner.set("_cpu_trainer_timer", 100.0)
		runner.set("_cpu_line_move_speed_m_per_s", 1.0)
		runner.call("_update_inputs", 1.0)
		moved[handling] = float(runner.get("_offset"))
		runner.free()
	assert_gt(float(moved[15]), float(moved[1]))
	assert_almost_eq(float(moved[15]), LocalRaceMath.handling_steer_multiplier(15), 0.0001)


func _contact_snapshot(progress_gap: float, side_gap: float) -> Array:
	return [
		{"id": "me", "race_progress": 100.0, "offset": 0.0},
		{"id": "other", "race_progress": 100.0 + progress_gap, "offset": side_gap},
	]


func test_lateral_contact_counts_only_runners_touching_side_by_side() -> void:
	var lateral := LocalRaceMath.BLOCK_LATERAL_M
	var margin := LocalRaceMath.CONTACT_TOUCH_MARGIN_M
	var longitudinal := LocalRaceMath.CONTACT_LONGITUDINAL_M
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(0.0, lateral), 0), 1)
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(longitudinal - 0.1, lateral + margin - 0.01), 0), 1)
	# 余裕より離れている、前後に離れている、同じライン上の前後の接触は対象外。
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(0.0, lateral + margin + 0.1), 0), 0)
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(longitudinal + 0.1, lateral), 0), 0)
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(longitudinal, 0.0), 0), 0)
	assert_eq(LocalRaceMath.lateral_contact_count(_contact_snapshot(0.5, lateral - 0.5), 0), 0)


func test_lateral_contact_count_has_a_maximum_of_two() -> void:
	var lateral := LocalRaceMath.BLOCK_LATERAL_M
	var snapshot := [
		{"id": "me", "race_progress": 100.0, "offset": 0.0},
		{"id": "left", "race_progress": 100.0, "offset": -lateral},
		{"id": "right", "race_progress": 100.0, "offset": lateral},
		{"id": "third", "race_progress": 100.2, "offset": lateral + 0.1},
	]
	assert_eq(LocalRaceMath.lateral_contact_count(snapshot, 0), LocalRaceMath.CONTACT_COUNT_MAX)


func test_contact_resistance_reduces_the_load() -> void:
	var reference := LocalRaceMath.CONTACT_RESISTANCE_REFERENCE_STAT
	assert_almost_eq(LocalRaceMath.contact_resistance_multiplier(reference), 1.0, 0.00001)
	assert_lt(LocalRaceMath.contact_resistance_multiplier(15), LocalRaceMath.contact_resistance_multiplier(5))
	assert_gt(LocalRaceMath.contact_resistance_multiplier(1), 1.0)
	assert_gte(LocalRaceMath.contact_resistance_multiplier(15), 0.2)
	assert_eq(LocalRaceMath.contact_heart_load_bpm_per_s(0, 1), 0.0)
	assert_almost_eq(LocalRaceMath.contact_heart_load_bpm_per_s(2, reference), 2.0 * LocalRaceMath.CONTACT_HEART_LOAD_BPM_PER_S, 0.00001)
	assert_gt(LocalRaceMath.contact_stamina_load_l_per_s(1, 1), LocalRaceMath.contact_stamina_load_l_per_s(1, 15))


func test_contact_adds_heart_and_stamina_load_that_a_high_resistance_runner_resists() -> void:
	var results := {}
	for resistance: int in [1, 15]:
		var runner := Node3D.new()
		runner.set_script(RunnerScript)
		add_child(runner)
		runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
		runner.set("_effective_stats", {"contact_resistance": resistance, "stamina": 5, "cardio": 5})
		runner.call("_reset_stamina_for_effective_stats")
		runner.call("apply_contact_count", 2)
		var stamina_before := float(runner.call("get_stamina"))
		var heart_before := float(runner.call("get_heart_rate_bpm"))
		runner.call("_update_condition_for_drive_level", 0.0, 1.0)
		results[resistance] = {"heart": float(runner.call("get_heart_rate_bpm")) - heart_before, "stamina": stamina_before - float(runner.call("get_stamina"))}
		runner.free()
	assert_gt(float(results[1]["heart"]), float(results[15]["heart"]))
	assert_gt(float(results[1]["stamina"]), float(results[15]["stamina"]))
	assert_gt(float(results[15]["heart"]), 0.0)


func _push_entry(identifier: String, offset: float, old_offset: float, stat: int = 5, progress: float = 100.0) -> Dictionary:
	return {"id": identifier, "progress": progress, "offset": offset, "old_offset": old_offset, "stat": stat}


func _offset_of(result: Dictionary, identifier: String) -> float:
	return float(result["offsets"][identifier])


func _neighbor(progress: float, offset: float, stat: int) -> Dictionary:
	return {"race_progress": progress, "offset": offset, "contact_resistance": stat}


func test_only_a_runner_with_higher_contact_resistance_may_move_into_another_body() -> void:
	var edge := LocalRaceMath.required_lateral_gap(0.0)
	var others := [_neighbor(100.0, 0.0, 8)]
	# 接触耐性が低い・同じなら、縁で止まる（左右どちらからでも）。
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge - 0.2, -edge + 0.5, 100.0, 7, others), -edge, 0.0001)
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(edge + 0.2, edge - 0.5, 100.0, 7, others), edge, 0.0001)
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge - 0.2, -edge + 0.5, 100.0, 8, others), -edge, 0.0001)
	# 高ければ、そのまま入る。
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge - 0.2, -edge + 0.5, 100.0, 9, others), -edge + 0.5, 0.0001)


func test_moves_that_do_not_enter_a_body_are_left_alone() -> void:
	var edge := LocalRaceMath.required_lateral_gap(0.0)
	var strong := [_neighbor(100.0, 0.0, 15)]
	# 体の外への移動は止めない。
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge - 0.5, -edge - 0.2, 100.0, 1, strong), -edge - 0.2, 0.0001)
	# 前後が離れていれば止めない。
	var far := [_neighbor(100.0 + LocalRaceMath.CONTACT_LONGITUDINAL_M + 1.0, 0.0, 15)]
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge - 0.2, 0.2, 100.0, 1, far), 0.2, 0.0001)
	# すでに重なっている相手は、押し合いに任せる。
	assert_almost_eq(LocalRaceMath.limit_offset_by_stronger_neighbors(-edge + 0.3, -edge + 0.5, 100.0, 1, strong), -edge + 0.5, 0.0001)


func test_the_runner_with_lower_contact_resistance_takes_the_whole_overlap() -> void:
	var w := LocalRaceMath.BLOCK_LATERAL_M
	# AとBが0.5m重なっている。Aのほうが接触耐性が高い。Aは動かず、Bが重なり全部ぶん押し出される。
	var result := LocalRaceMath.resolve_lateral_pushes([_push_entry("A", 0.5, 0.5, 9), _push_entry("B", w, w, 5)])
	assert_almost_eq(_offset_of(result, "A"), 0.5, 0.0001)
	assert_almost_eq(_offset_of(result, "B"), 0.5 + w, 0.0001)
	assert_true("A" in result["contest_ids"] and "B" in result["contest_ids"])
	# 逆なら、Aが押し出される。
	var reverse := LocalRaceMath.resolve_lateral_pushes([_push_entry("A", 0.5, 0.5, 3), _push_entry("B", w, w, 5)])
	assert_almost_eq(_offset_of(reverse, "B"), w, 0.0001)
	assert_almost_eq(_offset_of(reverse, "A"), 0.0, 0.0001)


func test_equal_contact_resistance_splits_the_overlap_in_half() -> void:
	var w := LocalRaceMath.BLOCK_LATERAL_M
	var result := LocalRaceMath.resolve_lateral_pushes([_push_entry("A", 0.4, 0.4, 5), _push_entry("B", w, w, 5)])
	assert_almost_eq(_offset_of(result, "A"), 0.2, 0.0001)
	assert_almost_eq(_offset_of(result, "B"), w + 0.2, 0.0001)


func test_a_diagonal_overlap_from_moving_forward_is_resolved_sideways() -> void:
	# 後ろのAが前へ進んで、斜め前のBと重なった（どちらも横には動いていない）。
	var gap := LocalRaceMath.CONTACT_LONGITUDINAL_M * 0.5
	var needed := LocalRaceMath.required_lateral_gap(gap)
	var lateral := needed * 0.6
	var result := LocalRaceMath.resolve_lateral_pushes([
		_push_entry("A", 0.0, 0.0, 8, 100.0 - gap), _push_entry("B", lateral, lateral, 5, 100.0)])
	# 接触耐性が高いAは動かず、Bが横へ離される。重なりは解ける。
	assert_almost_eq(_offset_of(result, "A"), 0.0, 0.0001)
	assert_almost_eq(_offset_of(result, "B"), needed, 0.0001)


func test_pushing_chains_to_the_next_runner() -> void:
	var w := LocalRaceMath.BLOCK_LATERAL_M
	# 右(R)が中(M)に重なり、押された中が左(L)に重なる。左が弱ければ左も押される。
	var result := LocalRaceMath.resolve_lateral_pushes([
		_push_entry("L", 0.0, 0.0, 1), _push_entry("M", w, w, 5), _push_entry("R", 2.0 * w - 0.6, 2.0 * w - 0.6, 10)
	])
	assert_lt(_offset_of(result, "L"), 0.0)
	assert_almost_eq(_offset_of(result, "R"), 2.0 * w - 0.6, 0.0001)
	assert_gte(_offset_of(result, "M") - _offset_of(result, "L"), w - 0.001)
	assert_gte(_offset_of(result, "R") - _offset_of(result, "M"), w - 0.001)


func test_push_cannot_move_a_runner_through_the_wall_and_the_other_gives_way() -> void:
	var wall := M2TrackMath.MAX_ABS_OFFSET_M
	var w := LocalRaceMath.BLOCK_LATERAL_M
	var entries := [_push_entry("A", wall - w + 0.5, wall - w + 0.5, 15), _push_entry("B", wall, wall, 1)]
	var result := LocalRaceMath.resolve_lateral_pushes(entries)
	assert_lte(_offset_of(result, "B"), wall + 0.0001)
	assert_gte(_offset_of(result, "B") - _offset_of(result, "A"), w - 0.001)


func test_push_result_does_not_depend_on_the_order_of_runners() -> void:
	var w := LocalRaceMath.BLOCK_LATERAL_M
	var a := _push_entry("L", 0.0, 0.0, 3)
	var b := _push_entry("M", w, w, 5)
	var c := _push_entry("R", 2.0 * w - 0.6, 2.0 * w - 0.6, 10)
	var first := LocalRaceMath.resolve_lateral_pushes([a, b, c])
	var second := LocalRaceMath.resolve_lateral_pushes([c, a, b])
	for identifier: String in ["L", "M", "R"]:
		assert_almost_eq(_offset_of(first, identifier), _offset_of(second, identifier), 0.001, identifier)


func test_runners_that_are_not_close_in_progress_do_not_contest() -> void:
	var w := LocalRaceMath.BLOCK_LATERAL_M
	var far := LocalRaceMath.CONTACT_LONGITUDINAL_M + 1.0
	var result := LocalRaceMath.resolve_lateral_pushes([_push_entry("A", 0.5, 0.5, 5), _push_entry("B", w, w, 5, 100.0 + far)])
	assert_eq(result["contest_ids"], [])
	assert_almost_eq(_offset_of(result, "A"), 0.5, 0.0001)


func test_push_contest_multiplies_the_contact_load() -> void:
	var runner := Node3D.new()
	runner.set_script(RunnerScript)
	add_child(runner)
	runner.call("setup_for_race", null, 0, 75.0, true, "あなた")
	runner.set("_effective_stats", {"contact_resistance": 5})
	runner.call("apply_contact_count", 1)
	var normal := float(runner.call("get_contact_heart_load_bpm_per_s"))
	runner.call("apply_push_result", float(runner.call("get_offset")), true)
	assert_almost_eq(float(runner.call("get_contact_heart_load_bpm_per_s")), normal * LocalRaceMath.PUSH_LOAD_MULTIPLIER, 0.0001)
	runner.call("apply_push_result", float(runner.call("get_offset")), false)
	assert_almost_eq(float(runner.call("get_contact_heart_load_bpm_per_s")), normal, 0.0001)
	runner.free()
