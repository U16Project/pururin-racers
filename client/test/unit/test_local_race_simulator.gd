extends GutTest

const Simulator := preload("res://scripts/local_race_simulator.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")

const _RaceSessionForSetup := preload("res://scripts/race_session.gd")


## レースの場面は、ユーザーと相手が選ばれていないと走らないので、全員で出る状態にしておく。
func before_each() -> void:
	_RaceSessionForSetup.select_full_field(_RaceSessionForSetup.default_player_pururin_id())



func test_scenario_config_has_reusable_cases() -> void:
	var cases := Simulator.scenarios()
	assert_eq(cases.size(), 4)
	assert_false(Simulator.scenario_by_id("notch4_cruise").is_empty())
	assert_false(Simulator.scenario_by_id("notch6_to_zero_recovery").is_empty())
	for scenario_value: Variant in cases:
		assert_true(scenario_value is Dictionary)
		if scenario_value is Dictionary:
			assert_true((scenario_value as Dictionary).has("goals"))


func test_notch4_scenario_runs_eight_runners_to_finish() -> void:
	var simulator := Simulator.new()
	var result := simulator.run_scenario(self, Simulator.scenario_by_id("notch4_cruise"))
	assert_false(result["timed_out"])
	assert_eq(result["finished_count"], 8)
	assert_eq(result["runners"].size(), 8)
	for runner: Dictionary in result["runners"]:
		assert_true(bool(runner["finished"]))
		assert_gt(float(runner["time_s"]), 0.0)


func test_notch6_to_zero_scenario_records_heart_rate_and_recovery() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("notch6_to_zero_recovery")
	scenario["max_time_s"] = 90.0
	var result := simulator.run_scenario(self, scenario)
	# ノッチ0へ落としたプレイヤーは回復確認のため速度を落とすため、
	# このシナリオはタイムアウトを許容し、時系列値を確認する。
	assert_true(bool(result["timed_out"]) or int(result["finished_count"]) == 8)
	var samples: Array = result["samples"]
	assert_gt(samples.size(), 2)
	var peak := 0.0
	var later := 0.0
	for sample: Array in samples:
		for runner: Dictionary in sample:
			if bool(runner["player"]):
				if float(runner["time_s"]) < 45.0:
					peak = maxf(peak, float(runner["heart_rate_bpm"]))
				else:
					later = float(runner["heart_rate_bpm"])
	assert_gt(peak, 180.0)
	assert_lt(later, peak)


func test_all_scenarios_validate_complete_time_series_and_final_state() -> void:
	var simulator := Simulator.new()
	var cases := Simulator.scenarios()
	assert_eq(cases.size(), 4)
	for scenario_value: Variant in cases:
		assert_true(scenario_value is Dictionary)
		if not scenario_value is Dictionary:
			continue
		var scenario: Dictionary = scenario_value
		var result := simulator.run_scenario(self, scenario)
		var errors := Simulator.validate_result(result, scenario)
		assert_true(errors.is_empty(), "%s: %s" % [scenario.get("id", "unknown"), "; ".join(errors)])
		assert_eq(int(result.get("finished_count", 0)), 8)
		assert_false(bool(result.get("timed_out", true)))
		assert_gt((result.get("samples", []) as Array).size(), 2)
		var assessment: Dictionary = result.get("goal_assessment", {})
		assert_true(assessment.has("passed"))
		assert_true(assessment.has("checks"))
		assert_true(assessment.has("summary"))
		assert_eq(bool(assessment.get("passed", false)), str(assessment.get("status", "")) == "PASS", "保留をPASSと扱わない")
		for check_value: Variant in assessment.get("checks", []):
			assert_true(check_value is Dictionary)
			if not check_value is Dictionary:
				continue
			var check: Dictionary = check_value
			for field: String in ["id", "passed", "measured", "target", "message"]:
				assert_true(check.has(field), "%s: 判定結果に%sがありません" % [scenario.get("id", "unknown"), field])
			assert_true(check.has("status"))


func test_notch6_relative_goal_compares_against_notch4_load() -> void:
	var simulator := Simulator.new()
	var notch4_scenario := Simulator.scenario_by_id("notch4_cruise")
	var notch6_scenario := Simulator.scenario_by_id("notch6_sustain")
	var notch4_result := simulator.run_scenario(self, notch4_scenario)
	var notch6_result := simulator.run_scenario(self, notch6_scenario)
	var references := {
		"notch4_cruise": notch4_result,
		"notch6_sustain": notch6_result,
	}
	var assessment := Simulator.assess_result(notch6_result, notch6_scenario, references)
	var relative_status := ""
	for check_value: Variant in assessment.get("checks", []):
		if check_value is Dictionary and str((check_value as Dictionary).get("id", "")) == "higher_load_than_notch4":
			relative_status = str((check_value as Dictionary).get("status", ""))
	assert_eq(relative_status, "PASS")
	assert_true(bool(assessment.get("passed", false)), str(assessment.get("summary", "")))


func test_cpu_snapshots_keep_active_drive_level_aligned_with_diagnostics() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("cpu_pack_and_draft")
	# CPU のスタートノッチと、そのノッチに基づく診断値を観測するだけなので、
	# 完走まで進める必要はない。
	scenario["max_time_s"] = 0.1
	scenario["sample_interval_s"] = 0.05
	var result := simulator.run_scenario(self, scenario)
	assert_false(result.has("error"))
	var samples: Array = result["samples"]
	assert_gt(samples.size(), 0)
	var cpu_count := 0
	for runner_value: Variant in samples[0]:
		if not runner_value is Dictionary:
			continue
		var runner: Dictionary = runner_value
		if bool(runner.get("player", false)):
			continue
		cpu_count += 1
		var drive_level := float(runner["drive_level"])
		var diagnostics: Dictionary = runner["drive_diagnostics"]
		var expected: Dictionary = LocalRaceMath.drive_diagnostics_kmh_per_s(
			float(runner["speed_kmh"]),
			drive_level,
			0.0,
			float(runner["acceleration_force_bonus_kmh_per_s"]),
			float(runner["top_speed_drive_adjustment_kmh_per_s"]),
			float(runner["propulsion_efficiency"])
		)
		assert_eq(drive_level, 5.0)
		assert_almost_eq(
			float(diagnostics["drive_contribution_kmh_per_s"]),
			float(expected["drive_contribution_kmh_per_s"]),
			0.001
		)
	assert_eq(cpu_count, 7)


func test_gate_overrides_replace_simulation_start_gate_only() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("cpu_pack_and_draft")
	scenario["delta_s"] = 0.001
	scenario["max_time_s"] = 0.001
	scenario["sample_interval_s"] = 0.001
	scenario["gate_overrides"] = {"cpu-7": 2, "cpu-2": 7}
	var overridden := simulator.run_scenario(self, scenario)
	assert_false(overridden.has("error"), str(overridden.get("error", "")))
	var overridden_iwa: Dictionary = {}
	for runner_value: Variant in overridden["runners"]:
		if runner_value is Dictionary and str((runner_value as Dictionary).get("id", "")) == "cpu-7":
			overridden_iwa = runner_value
			break
	assert_eq(int(overridden_iwa["gate"]), 2)
	assert_almost_eq(float(overridden_iwa["offset"]), LocalRaceMath.starting_offset_for_gate(2), 0.002)

	var regular := Simulator.scenario_by_id("cpu_pack_and_draft")
	regular["max_time_s"] = 0.0
	var unchanged := simulator.run_scenario(self, regular)
	var regular_iwa: Dictionary = {}
	for runner_value: Variant in unchanged["runners"]:
		if runner_value is Dictionary and str((runner_value as Dictionary).get("id", "")) == "cpu-7":
			regular_iwa = runner_value
			break
	assert_eq(int(regular_iwa["gate"]), 7)


func test_duplicate_gate_is_rejected() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("cpu_pack_and_draft")
	scenario["gate_overrides"] = {"cpu-7": 2}
	var result := simulator.run_scenario(self, scenario)
	assert_true(result.has("error"))
	assert_true(str(result.get("error", "")).contains("重複"))


func test_all_cpu_uses_roster_trainers_and_does_not_force_player_schedule() -> void:
	var simulator := Simulator.new()
	var result := simulator.run_scenario(self, {"id": "all_cpu", "all_cpu": true, "seed": 123, "max_time_s": 0.1, "player_drive_schedule": [{"start_s": 0, "drive_level": 0}]})
	assert_false(result.has("error"))
	for runner: Dictionary in result.runners:
		assert_false(bool(runner.player))
		assert_eq(float(runner.drive_level), LocalRaceMath.Config.number("cpu_start_drive_level"))
	assert_eq(result.seed, 123)
	assert_true(result.has("configuration"))
	assert_gt(float(result.execution_time_s), 0.0)


func test_isolated_reuses_actual_condition_update_and_restores_config() -> void:
	var simulator := Simulator.new()
	var old_coefficient := LocalRaceMath.Config.number("acceleration_response_multiplier_per_stat")
	var condition := {"id": "isolated", "mode": "isolated", "config_overrides": {"acceleration_response_multiplier_per_stat": 0.025}, "isolated": {"effective_stats": {"cardio": 10, "stamina": 15}, "body_enabled": true, "duration_s": 0.1, "delta_s": 0.1, "sample_interval_s": 0.1, "drive_schedule": [{"start_s": 0.0, "drive_level": 6.0}]}}
	var result := simulator.run_case(self, condition)
	assert_false(result.has("error"), str(result.get("error", "")))
	var expected_heart := LocalRaceMath.Config.number("heart_rate_min_bpm") + LocalRaceMath.heart_rate_net_rate_bpm_per_s(LocalRaceMath.Config.number("heart_rate_min_bpm"), 6, 10) * 0.1
	assert_almost_eq(float(result.metrics.heart_rate_bpm), expected_heart, 0.0001)
	var expected_stamina := LocalRaceMath.stamina_capacity_l(15) + LocalRaceMath.stamina_delta_l_per_s(6, expected_heart) * 0.1
	assert_almost_eq(float(result.metrics.stamina), expected_stamina, 0.0001)
	assert_eq(LocalRaceMath.Config.number("acceleration_response_multiplier_per_stat"), old_coefficient)
	assert_eq(result.stats_basis, "fixed_effective_stats_without_allocation_attribute_or_style")


func test_isolated_equal_cruise_and_different_acceleration_times() -> void:
	var simulator := Simulator.new()
	var slow := simulator.run_case(self, {"mode": "isolated", "isolated": {"effective_stats": {"acceleration": 1}, "duration_s": 300, "delta_s": 0.05}})
	var fast := simulator.run_case(self, {"mode": "isolated", "isolated": {"effective_stats": {"acceleration": 15}, "duration_s": 300, "delta_s": 0.05}})
	assert_almost_eq(float(slow.metrics.speed_kmh), float(fast.metrics.speed_kmh), 0.001)
	assert_gt(float(slow.metrics.threshold_times.speed_60_s), float(fast.metrics.threshold_times.speed_60_s))


func test_relative_without_reference_is_not_pass() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("notch6_sustain")
	var result := simulator.run_scenario(self, scenario)
	assert_false(bool(result.goal_assessment.passed))
	assert_eq(str(result.goal_assessment.status), "NOT_EVALUATED")


func test_invalid_case_types_do_not_change_config_or_session() -> void:
	var simulator := Simulator.new()
	var previous_config := LocalRaceMath.Config.values().duplicate(true)
	var previous_session := Simulator.session_snapshot()
	for key in ["scenario", "isolated"]:
		for invalid_value: Variant in [[], "invalid", null]:
			var condition := {"mode": "isolated", "config_overrides": {"acceleration_response_multiplier_per_stat": 0.025}, "scenario": {"distance_m": 1200}, "isolated": {"duration_s": 0.1}}
			condition[key] = invalid_value
			var result := simulator.run_case(self, condition)
			assert_true(result.has("error"), "%s: %s" % [key, str(invalid_value)])
			assert_eq(LocalRaceMath.Config.values(), previous_config)
			assert_eq(Simulator.session_snapshot(), previous_session)
	# 型が正しいトップレベルで、内部scheduleが不正な場合も復元する。
	var result := simulator.run_case(self, {"mode": "isolated", "config_overrides": {"acceleration_response_multiplier_per_stat": 0.025}, "scenario": {"distance_m": 1200}, "isolated": {"drive_schedule": null}})
	assert_true(result.has("error"))
	assert_eq(LocalRaceMath.Config.values(), previous_config)
	assert_eq(Simulator.session_snapshot(), previous_session)


func test_invalid_scenario_schedule_and_gate_types_return_errors() -> void:
	var simulator := Simulator.new()
	for key in ["player_drive_schedule", "gate_overrides", "player_override"]:
		for invalid_value: Variant in ["invalid", null]:
			var scenario := {key: invalid_value}
			assert_true(simulator.run_scenario(self, scenario).has("error"))
	for schedule: Array in [[null], [{"start_s": [], "drive_level": 6}], [{"start_s": 0, "drive_level": {}}]]:
		assert_true(simulator.run_scenario(self, {"player_drive_schedule": schedule}).has("error"))
