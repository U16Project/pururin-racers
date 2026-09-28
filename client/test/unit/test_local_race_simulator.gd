extends GutTest

const Simulator := preload("res://scripts/local_race_simulator.gd")


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
		assert_true(bool(assessment.get("passed", false)), "%s: %s" % [scenario.get("id", "unknown"), assessment.get("summary", "")])
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
