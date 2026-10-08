extends GutTest

const Simulator := preload("res://scripts/local_race_simulator.gd")
const Sweep := preload("res://scripts/local_race_stat_sweep.gd")

const _RaceSessionForSetup := preload("res://scripts/race_session.gd")


## レースの場面は、ユーザーと相手が選ばれていないと走らないので、全員で出る状態にしておく。
func before_each() -> void:
	_RaceSessionForSetup.select_full_field(_RaceSessionForSetup.default_player_pururin_id())



func test_stat_sweep_config_has_60_valid_variants() -> void:
	var loaded := Sweep.load_config()
	assert_false(loaded.has("error"), str(loaded.get("error", "")))
	var variants: Array = loaded.data.get("variants", [])
	assert_eq(variants.size(), 60)
	var ids := {}
	for value: Variant in variants:
		assert_true(value is Dictionary)
		if not value is Dictionary:
			continue
		var variant: Dictionary = value
		var identifier := str(variant.get("variant_id", ""))
		assert_false(identifier.is_empty())
		assert_false(ids.has(identifier))
		ids[identifier] = true
		assert_true(Sweep.validate_profile({"id": identifier, "allocation": variant.get("allocation", {})}).is_empty())
	assert_eq(ids.size(), 60)


func test_stat_sweep_builds_48_stat_levels_and_12_focus_runs() -> void:
	var loaded := Sweep.load_config()
	var cases: Array = Sweep.build_cases(loaded.data)
	assert_eq(cases.size(), 60)
	var stat_level_count := 0
	var focus_count := 0
	for value: Variant in cases:
		if not value is Dictionary:
			continue
		if str((value as Dictionary).get("case_kind", "")) == "stat_level":
			stat_level_count += 1
		elif str((value as Dictionary).get("case_kind", "")) == "focus_profile":
			focus_count += 1
	assert_eq(stat_level_count, 48)
	assert_eq(focus_count, 12)


func test_simulator_applies_player_override_for_sweep_case() -> void:
	var simulator := Simulator.new()
	var scenario := Simulator.scenario_by_id("notch4_cruise")
	scenario["max_time_s"] = 5.0
	scenario["player_override"] = {"allocation": {
		"top_speed": 10,
		"acceleration": 5,
		"stamina": 5,
		"cardio": 5,
		"aero": 5,
		"pack": 5,
		"contact_resistance": 1,
		"handling": 4,
	}}
	var result := simulator.run_scenario(self, scenario)
	assert_false(result.has("error"), str(result.get("error", "")))
	var player := Sweep.player_snapshot(result)
	assert_true(player.has("effective_stats"))
	assert_gte(int((player.get("effective_stats", {}) as Dictionary).get("top_speed", 0)), 10)
