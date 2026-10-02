extends GutTest

const CpuTrainerMath := preload("res://scripts/cpu_trainer_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")


func test_cpu_uses_start_drive_level_while_heart_has_headroom() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var decision := CpuTrainerMath.decide({
		"heart_rate_bpm": float(settings["heart_rate_normal_max_bpm"]) - 1.0,
	}, settings)
	assert_eq(int(decision["drive_level"]), int(settings["cpu_start_drive_level"]))


func test_cpu_heart_safety_lowers_the_start_notch_at_normal_heart_limit() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var heart_rate := float(settings["heart_rate_normal_max_bpm"])
	var selected := LocalRaceMath.cpu_heart_safe_drive_level(
		float(CpuTrainerMath.decide({"heart_rate_bpm": heart_rate}, settings)["drive_level"]),
		heart_rate,
		5
	)
	assert_lt(selected, float(settings["cpu_start_drive_level"]))
	assert_lt(LocalRaceMath.heart_rate_net_rate_bpm_per_s(heart_rate, selected, 5), 0.0)


func test_cpu_notch_ignores_position_distance_and_fuel_inputs() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var relaxed := {
		"heart_rate_bpm": 160.0,
		"progress_ratio": 0.05,
		"live_place": 1,
		"leader_gap_m": 0.0,
		"pack_center_gap_m": -30.0,
		"current_speed_kmh": 70.0,
		"field_pace_kmh": 70.0,
		"stamina_ratio": 1.0,
	}
	var pressured := relaxed.duplicate()
	pressured["progress_ratio"] = 0.95
	pressured["live_place"] = 8
	pressured["leader_gap_m"] = 100.0
	pressured["pack_center_gap_m"] = 80.0
	pressured["current_speed_kmh"] = 40.0
	pressured["field_pace_kmh"] = 75.0
	pressured["stamina_ratio"] = 0.0
	assert_eq(
		int(CpuTrainerMath.decide(relaxed, settings)["drive_level"]),
		int(CpuTrainerMath.decide(pressured, settings)["drive_level"])
	)
