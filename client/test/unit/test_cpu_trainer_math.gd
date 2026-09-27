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


func test_trainer_cruises_below_natural_speed_then_recovers_in_finish() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.55, "patience": 0.50, "drafting_pref": 0.55}
	var early := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.20, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var finish := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.98, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_lt(float(early["target_speed_kmh"]), 65.0)
	assert_gt(float(finish["target_speed_kmh"]), float(early["target_speed_kmh"]))
	assert_almost_eq(float(finish["desired_rank"]), 1.0, 0.001)


func test_global_gap_pressure_raises_target_without_nearest_runner_input() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.45, "patience": 0.70, "drafting_pref": 0.45}
	var compact := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 7,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var delayed := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 7,
		"leader_gap_m": 50.0, "pack_center_gap_m": 25.0,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_gt(float(delayed["target_speed_kmh"]), float(compact["target_speed_kmh"]))


func test_global_gap_pressure_softens_a_runner_far_ahead_of_the_pack() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.82, "patience": 0.25, "drafting_pref": 0.30}
	var compact := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 1,
		"max_speed_kmh": 66.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var isolated := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 1,
		"pack_center_gap_m": -50.0,
		"max_speed_kmh": 66.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_lt(float(isolated["target_speed_kmh"]), float(compact["target_speed_kmh"]))


func test_chase_urgency_reduces_reserve_when_leader_gap_grows() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.45, "patience": 0.70, "drafting_pref": 0.45}
	var compact := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var detached := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"leader_gap_m": 50.0,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_gt(float(detached["target_speed_kmh"]), float(compact["target_speed_kmh"]))


func test_chase_urgency_reduces_draft_saving_when_leader_gap_grows() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.45, "patience": 0.70, "drafting_pref": 0.90}
	var compact := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": true,
	}, settings)
	var detached := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"leader_gap_m": 50.0,
		"max_speed_kmh": 65.0, "stamina_ratio": 1.0, "has_draft": true,
	}, settings)
	assert_gt(float(detached["target_speed_kmh"]), float(compact["target_speed_kmh"]))


func test_field_pace_difference_changes_target_continuously() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.55, "patience": 0.50, "drafting_pref": 0.55}
	var slow_pace := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 70.0, "current_speed_kmh": 60.0,
		"field_pace_kmh": 60.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var fast_pace := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.40, "field_size": 8, "live_place": 4,
		"max_speed_kmh": 70.0, "current_speed_kmh": 60.0,
		"field_pace_kmh": 68.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_gt(float(fast_pace["target_speed_kmh"]), float(slow_pace["target_speed_kmh"]))


func test_capability_and_ahead_gap_raise_closing_pressure_but_keep_natural_cap() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var profile := {"aggression": 0.55, "patience": 0.50, "drafting_pref": 0.55}
	var weak := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.70, "field_size": 8, "live_place": 6,
		"max_speed_kmh": 70.0, "current_speed_kmh": 62.0,
		"nearest_ahead_gap_m": 60.0, "nearest_ahead_speed_kmh": 68.0,
		"acceleration_stat": 3.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	var capable := CpuTrainerMath.decide(profile, {
		"progress_ratio": 0.70, "field_size": 8, "live_place": 6,
		"max_speed_kmh": 70.0, "current_speed_kmh": 62.0,
		"nearest_ahead_gap_m": 60.0, "nearest_ahead_speed_kmh": 68.0,
		"acceleration_stat": 15.0, "stamina_ratio": 1.0, "has_draft": false,
	}, settings)
	assert_gt(float(capable["closing_pressure_kmh"]), float(weak["closing_pressure_kmh"]))
	assert_lte(float(capable["target_speed_kmh"]), 70.0)
