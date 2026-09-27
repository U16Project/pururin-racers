extends GutTest

const CpuTrainerMath := preload("res://scripts/cpu_trainer_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")


func test_front_profile_targets_a_more_forward_position_than_draft_profile() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var common_state := {
		"progress_ratio": 0.30,
		"field_size": 8,
		"live_place": 6,
		"max_speed_kmh": 56.0,
		"stamina_ratio": 1.0,
		"has_draft": false,
	}
	var front := CpuTrainerMath.decide({
		"aggression": 0.82, "patience": 0.25, "drafting_pref": 0.30,
	}, common_state, settings)
	var draft := CpuTrainerMath.decide({
		"aggression": 0.35, "patience": 0.80, "drafting_pref": 0.90,
	}, common_state, settings)
	assert_lt(float(front["desired_rank"]), float(draft["desired_rank"]))
	assert_gt(float(front["target_speed_kmh"]), float(draft["target_speed_kmh"]))


func test_trainer_pushes_later_in_the_race_without_distance_specific_events() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.55, "patience": 0.50, "drafting_pref": 0.55}
	var early := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 56.0, "stamina_ratio": 0.8, "has_draft": true,
	}, settings)
	var late := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.90, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 56.0, "stamina_ratio": 0.8, "has_draft": true,
	}, settings)
	assert_gt(float(late["target_speed_kmh"]), float(early["target_speed_kmh"]))
	assert_gt(float(late["drive_level"]), float(early["drive_level"]))
