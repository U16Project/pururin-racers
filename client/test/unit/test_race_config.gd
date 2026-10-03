extends GutTest

const Config := preload("res://scripts/config/local_race_config.gd")
const DraftRules := preload("res://scripts/config/m5_draft_rules.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")

func test_shipped_config_is_valid_and_cached_read_only() -> void:
	var result := Config.load_file()
	assert_true(result.has("data"))
	assert_true(Config.validate(result.data).is_empty())
	assert_true(Config.values().is_read_only())
	assert_true(Config.values().drive_force_by_level_kmh_per_s.is_read_only())
	assert_true(Config.values().heart_rate_rise_rate_by_drive_level_bpm_per_s.is_read_only())
	assert_eq(Config.number("drive_level_max"), 6.0)
	assert_almost_eq(Config.number("air_resistance_quadratic_coefficient"), 0.00204, 0.000001)
	assert_eq(Config.number("aero_air_resistance_reference_stat"), 5.0)
	assert_almost_eq(Config.number("aero_air_resistance_multiplier_per_stat"), 0.015, 0.000001)
	assert_almost_eq(Config.number("draft_response_exponent"), 1.5, 0.001)
	assert_almost_eq(Config.number("draft_aggregation_exponent"), 0.7, 0.001)
	assert_eq(Config.number("pack_draft_effective_reference_stat"), 5.0)
	assert_almost_eq(Config.number("pack_draft_effective_multiplier_per_stat"), 0.025, 0.000001)
	assert_eq(Config.values().drive_force_by_level_kmh_per_s, [0.0, 3.0, 3.5, 4.3, 5.0, 5.8, 7.2])
	assert_eq(Config.values().heart_rate_rise_rate_by_drive_level_bpm_per_s, [0.0, 1.5, 2.5, 4.0, 6.0, 9.0, 13.0])
	assert_almost_eq(Config.number("heart_rate_drive_load_scale"), 0.58, 0.001)
	assert_almost_eq(Config.number("heart_rate_recovery_exponent"), 1.2, 0.001)
	assert_almost_eq(Config.number("heart_rate_recovery_rate_scale"), 2.75, 0.001)
	assert_almost_eq(Config.number("heart_rate_rise_time_cardio_min_s"), 13.0, 0.001)
	assert_almost_eq(Config.number("heart_rate_rise_time_cardio_max_s"), 20.0, 0.001)
	assert_almost_eq(Config.number("heart_rate_recovery_time_cardio_min_s"), 27.0, 0.001)
	assert_almost_eq(Config.number("heart_rate_recovery_time_cardio_max_s"), 22.0, 0.001)
	assert_eq(Config.number("stamina_capacity_base_l"), 5.0)
	assert_eq(Config.number("stamina_capacity_per_stat_l"), 3.0)
	assert_eq(Config.number("stamina_debt_capacity_multiplier"), 1.0)
	assert_almost_eq(Config.number("stamina_consumption_min_l_per_s"), 0.0457142857142857, 0.000001)
	assert_almost_eq(Config.number("stamina_consumption_max_l_per_s"), 0.1828571428571428, 0.000001)
	assert_almost_eq(Config.number("stamina_consumption_load_multiplier"), 1.30, 0.000001)
	assert_false(Config.values().has("cpu_speed_tiers_kmh"))
	assert_false(Config.values().has("cpu_target_speed_change_kmh_per_s"))
	assert_almost_eq(Config.number("cpu_steer_reselect_min_s"), 1.0, 0.001)
	assert_almost_eq(Config.number("cpu_follow_preferred_gap_m"), 4.0, 0.001)
	assert_almost_eq(Config.number("cpu_follow_slot_lateral_spacing_m"), 1.2, 0.001)
	assert_almost_eq(Config.number("cpu_follow_slot_crowding_weight"), 1.4, 0.001)
	assert_almost_eq(Config.number("cpu_follow_slot_field_density_forward_range_m"), 5.0, 0.001)
	assert_almost_eq(Config.number("cpu_follow_slot_open_forward_threshold"), 1.20, 0.001)
	assert_almost_eq(Config.number("cpu_follow_slot_inner_bias"), 1.7, 0.001)
	assert_almost_eq(Config.number("cpu_line_distance_advantage_weight"), 4.0, 0.001)
	assert_almost_eq(Config.number("cpu_overtake_escape_lateral_spacing_m"), 4.5, 0.001)
	assert_almost_eq(Config.number("cpu_overtake_escape_steer_speed_multiplier"), 2.5, 0.001)
	assert_almost_eq(Config.number("cpu_inward_target_offset_m"), -3.0, 0.001)
	assert_eq(Config.number("heart_rate_min_bpm"), 100.0)
	assert_eq(Config.number("heart_rate_normal_max_bpm"), 200.0)
	assert_eq(Config.number("heart_rate_overheat_max_bpm"), 230.0)
	assert_almost_eq(Config.number("overheat_propulsion_efficiency_min"), 0.35, 0.001)
	assert_almost_eq(Config.number("overheat_exposure_efficiency_loss_per_s"), 0.017, 0.001)
	assert_almost_eq(Config.number("overheat_exposure_recovery_per_s"), 2.5, 0.001)
	assert_almost_eq(Config.number("stamina_debt_efficiency_min"), 0.40, 0.001)
	var draft_result := DraftRules.load_file()
	assert_true(draft_result.has("data"))
	assert_true(DraftRules.validate(draft_result.data).is_empty())
	assert_almost_eq(DraftRules.wake_reference_p(), 0.18, 0.001)
	assert_eq(DraftRules.number("chain_attenuation"), 0.5)
	assert_eq(DraftRules.number("lateral_range_m"), 3.0)
	assert_almost_eq(DraftRules.number("lateral_falloff_exponent"), 0.35, 0.001)


func test_m5_course_layout_rejects_missing_and_invalid_routes() -> void:
	var shipped := M5CourseBuilder.load_file()
	assert_true(shipped.has("layout"))
	assert_true(M5CourseBuilder.validate_layout(shipped.layout).is_empty())
	assert_true(M5CourseBuilder.parse_text('{"course_id":"broken"}', "broken_course.json").error.contains("track_length_m"))
	var invalid: Dictionary = shipped.layout.duplicate(true)
	invalid.routes[0].segments[0].distance_m = 0.0
	assert_true(";".join(M5CourseBuilder.validate_layout(invalid)).contains("distance_m"))


func test_draft_hud_formatter_keeps_source_and_percent_lines() -> void:
	var lines := DraftHudFormatter.status_lines({
		"direct_draft_p": 0.12,
		"chain_draft_p": 0.06,
		"direct_source_details": [{"id": "cpu-1", "gap": 2.5, "line": 0.75}],
		"chain_source_ids": ["cpu-2"],
	}, 0.24)
	assert_eq(lines, PackedStringArray([
		"直接 50%", "連鎖 25%", "総合 75%", "対象 cpu-1（前方 2.5m／横 0.8m）、cpu-2",
	]))
	var hidden := DraftHudFormatter.status_lines({"direct_draft_p": 0.12}, 0.24, true)
	assert_eq(hidden, PackedStringArray([
		"直接 0%", "連鎖 0%", "総合 0%", "対象 なし",
	]))


func test_draft_rules_reject_invalid_range_and_unknown_key() -> void:
	var data: Dictionary = DraftRules.load_file().data
	data.forward_max_m = 0.0
	assert_true(";".join(DraftRules.validate(data)).contains("forward_max_m"))
	data = DraftRules.load_file().data
	data.forward_min_m = data.forward_max_m + 0.1
	assert_true(";".join(DraftRules.validate(data)).contains("forward_min_m"))
	data = DraftRules.load_file().data
	data.unexpected_rule = 1.0
	assert_true(";".join(DraftRules.validate(data)).contains("unexpected_rule"))
	data = DraftRules.load_file().data
	data.max_sources = 3
	assert_true(";".join(DraftRules.validate(data)).contains("max_sources"))

func test_errors_identify_file_and_setting() -> void:
	assert_true(Config.load_file("res://missing_race_config.json").error.contains("missing_race_config.json"))
	assert_true(Config.parse_text("{broken", "race.json").error.contains("race.json:"))
	assert_true(Config.parse_text("[]").has("error"))
	var data: Dictionary = Config.load_file().data
	data.erase("air_resistance_quadratic_coefficient")
	assert_true(";".join(Config.validate(data)).contains("air_resistance_quadratic_coefficient"))

func test_rejects_invalid_numbers_and_unknown_keys() -> void:
	for value in ["0.5", true, -0.1, INF, NAN]:
		var data: Dictionary = Config.load_file().data
		data.draft_air_resistance_factor = value
		assert_false(Config.validate(data).is_empty(), str(value))
	var data: Dictionary = Config.load_file().data
	data.air_resistance_coefficient = 0.024
	assert_true(";".join(Config.validate(data)).contains("air_resistance_coefficient"))
	data = Config.load_file().data
	data.aero_air_resistance_multiplier_per_stat = 0.2
	assert_true(";".join(Config.validate(data)).contains("aero_air_resistance_multiplier_per_stat"))
	data = Config.load_file().data
	data.pack_draft_effective_reference_stat = 5.5
	assert_true(";".join(Config.validate(data)).contains("pack_draft_effective_reference_stat"))

func test_cpu_profile_line_preference_is_range_checked() -> void:
	var data: Dictionary = Config.load_file().data
	data.cpu_trainer_profiles[0]["line_pref"] = 0.6
	assert_true(Config.validate(data).is_empty())
	data = Config.load_file().data
	data.cpu_trainer_profiles[0]["line_pref"] = 1.5
	assert_true(";".join(Config.validate(data)).contains("cpu_trainer_profiles[0].line_pref"))

func test_rejects_inconsistent_notches_and_ranges() -> void:
	var data: Dictionary = Config.load_file().data
	data.drive_level_max = 7
	assert_true(";".join(Config.validate(data)).contains("drive_force_by_level"))
	data = Config.load_file().data
	data.drive_level_max = 4.5
	assert_false(Config.validate(data).is_empty())
	data = Config.load_file().data
	data.drive_force_by_level_kmh_per_s[0] = 1
	assert_false(Config.validate(data).is_empty())
	data = Config.load_file().data
	data.heart_rate_rise_rate_by_drive_level_bpm_per_s[0] = 0.1
	assert_true("heart_rate_rise_rate_by_drive_level_bpm_per_s" in ";".join(Config.validate(data)))
	data = Config.load_file().data
	data.heart_rate_min_bpm = data.heart_rate_normal_max_bpm + 1
	assert_false(Config.validate(data).is_empty())
	data = Config.load_file().data
	data.cpu_steer_reselect_min_s = data.cpu_steer_reselect_max_s + 1.0
	assert_true(";".join(Config.validate(data)).contains("cpu_steer_reselect_min_s"))
	data = Config.load_file().data
	data.cpu_follow_preferred_gap_m = data.cpu_follow_forward_range_m + 1.0
	assert_true(";".join(Config.validate(data)).contains("cpu_follow_preferred_gap_m"))
	data = Config.load_file().data
	data.cpu_inward_target_offset_m = 99.0
	assert_true(";".join(Config.validate(data)).contains("cpu_inward_target_offset_m"))
	data = Config.load_file().data
	data.cpu_follow_slot_lateral_spacing_m = 99.0
	assert_true(";".join(Config.validate(data)).contains("cpu_follow_slot_lateral_spacing_m"))
	data = Config.load_file().data
	data.cpu_overtake_escape_lateral_spacing_m = 99.0
	assert_true(";".join(Config.validate(data)).contains("cpu_overtake_escape_lateral_spacing_m"))
	data = Config.load_file().data
	data.cpu_overtake_escape_steer_speed_multiplier = 0.5
	assert_true(";".join(Config.validate(data)).contains("cpu_overtake_escape_steer_speed_multiplier"))

func test_goal_repositions_without_duplicate_nodes_and_supports_width() -> void:
	var track := Path3D.new()
	track.curve = Curve3D.new()
	track.curve.add_point(Vector3.ZERO)
	track.curve.add_point(Vector3(0, 0, -100))
	add_child_autofree(track)
	var visual := GoalVisual.new()
	visual.place(track, 10.0, 15.0)
	var sign := track.get_node("GoalSign")
	var glow := track.get_node("GoalGlowLine") as MeshInstance3D
	assert_eq(track.get_child_count(), 4)
	assert_eq(glow.mesh.size.x, 15.0)
	var first_position := glow.position
	visual.place(track, 40.0, 20.0)
	assert_eq(track.get_child_count(), 4)
	assert_same(track.get_node("GoalSign"), sign)
	assert_same(track.get_node("GoalGlowLine"), glow)
	assert_eq(track.get_node("GoalPanelFrame").get_child_count(), 4)
	assert_eq(glow.mesh.size.x, 20.0)
	assert_eq(track.get_node("GoalPanel").mesh.size.x, 24.0)
	assert_gt(first_position.distance_to(glow.position), 29.0)
	assert_almost_eq(sign.pixel_size, 0.008 * 20.0 / 15.0, 0.00001)

func test_invalid_configuration_prevents_race_start_and_displays_error() -> void:
	var saved := Config.values()
	var saved_error := Config.last_error
	Config._cached = {}
	Config.last_error = "local_race.json: drive_level_max が不正です"
	var race: Node = load("res://scenes/local_race.tscn").instantiate()
	add_child(race)
	assert_eq(race.get_node("Runners").get_child_count(), 0)
	assert_false(race.is_processing())
	assert_true(race.get_node("UI/HudLabel").text.contains("drive_level_max"))
	race.free()
	Config._cached = saved
	Config.last_error = saved_error


func test_invalid_course_configuration_prevents_local_and_m5_start() -> void:
	var saved_result := M5CourseBuilder._cached_result
	var saved_attempted := M5CourseBuilder._attempted
	M5CourseBuilder._attempted = true
	M5CourseBuilder._cached_result = {"error": "course_layout_m5.json: track_length_m が不正です"}
	for scene_path in ["res://scenes/local_race.tscn", "res://scenes/m5_online_race.tscn"]:
		var race: Node = load(scene_path).instantiate()
		add_child(race)
		assert_false(race.is_processing())
		assert_true(race.get_node("UI/HudLabel").text.contains("track_length_m"))
		race.free()
	M5CourseBuilder._cached_result = saved_result
	M5CourseBuilder._attempted = saved_attempted
