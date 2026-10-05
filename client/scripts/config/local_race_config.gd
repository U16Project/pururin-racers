extends RefCounted
## ローカル出力操作の設定。JSONのみを初期値の正本とする。
## アプリ起動中に一度だけ読み込む。変更の反映はクライアント再起動時。

const M2TrackMath := preload("res://scripts/m2_track_math.gd")

const PATH := "res://data/config/local_race.json"
const NUMBER_RANGES := {
	"schema_version": [1.0, 1.0],
	"drive_level_max": [1.0, 100.0],
	"drive_level_step": [1.0, 1.0],
	"start_countdown_seconds": [0.0, 30.0],
	"player_start_drive_level": [-100.0, 100.0],
	"player_start_gate_index": [0.0, 7.0],
	"cpu_start_drive_level": [-100.0, 100.0],
	"cpu_start_drive_duration_seconds": [0.0, 30.0],
	"min_speed_kmh": [0.0, 75.0],
	"rolling_resistance_kmh_per_s": [0.0, 100.0],
	"air_resistance_quadratic_coefficient": [0.0, 100.0],
	"aero_air_resistance_reference_stat": [1.0, 15.0],
	"handling_steer_reference_stat": [1.0, 15.0],
	"push_strength_per_stat": [0.0, 0.5],
	"push_intent_multiplier": [0.1, 10.0],
	"push_passive_multiplier": [0.05, 1.0],
	"push_load_multiplier": [1.0, 20.0],
	"contact_touch_margin_m": [0.0, 3.0],
	"contact_heart_load_bpm_per_s": [0.0, 50.0],
	"contact_stamina_load_l_per_s": [0.0, 10.0],
	"contact_resistance_reference_stat": [1.0, 15.0],
	"contact_resistance_multiplier_per_stat": [0.0, 0.2],
	"handling_steer_multiplier_per_stat": [0.0, 0.2],
	"lateral_move_heart_load_bpm_per_m": [0.0, 10.0],
	"lateral_move_stamina_load_l_per_m": [0.0, 1.0],
	"lateral_move_load_multiplier_per_stat": [0.0, 0.2],
	"aero_air_resistance_multiplier_per_stat": [0.0, 0.10],
	"blocked_speed_excess_max_kmh": [0.0, 100.0],
	"block_approach_rate_per_s": [0.1, 20.0],
	"rear_assist_range_m": [0.1, 20.0],
	"rear_assist_transfer_rate": [0.0, 0.9],
	"rear_assist_aero_multiplier_per_stat": [0.0, 0.2],
	"draft_response_reference_scale": [0.1, 20.0],
	"draft_response_exponent": [1.0, 4.0],
	"draft_aggregation_exponent": [0.5, 4.0],
	"pack_draft_effective_reference_stat": [1.0, 15.0],
	"pack_draft_effective_multiplier_per_stat": [0.0, 0.20],
	"brake_deceleration_kmh_per_s": [0.001, 100.0],
	"course_marker_sign_interval_m": [10.0, 1000.0],
	"contact_lateral_range_m": [0.001, 15.0],
	"contact_longitudinal_range_m": [0.001, 15.0],
	"draft_air_resistance_factor": [0.0, 1.0],
	"drive_repeat_initial_s": [0.001, 10.0],
	"drive_repeat_interval_s": [0.001, 10.0],
	"cpu_steer_reselect_min_s": [0.001, 60.0],
	"cpu_steer_reselect_max_s": [0.001, 60.0],
	"cpu_steer_speed_m_per_s": [0.001, 100.0],
	"cpu_follow_forward_range_m": [0.001, 100.0],
	"cpu_follow_lateral_range_m": [0.001, 15.0],
	"cpu_follow_preferred_gap_m": [0.001, 100.0],
	"cpu_follow_offset_blend": [0.0, 1.0],
	"cpu_follow_slot_lateral_spacing_m": [0.001, 15.0],
	"cpu_follow_slot_inner_midpoint_blend": [0.0, 1.0],
	"cpu_follow_slot_crowding_forward_range_m": [0.001, 100.0],
	"cpu_follow_slot_crowding_lateral_range_m": [0.001, 15.0],
	"cpu_follow_slot_crowding_weight": [0.0, 100.0],
	"cpu_follow_slot_field_density_forward_range_m": [0.001, 100.0],
	"cpu_follow_slot_field_density_lateral_range_m": [0.001, 15.0],
	"cpu_follow_slot_field_density_weight": [0.0, 100.0],
	"cpu_follow_slot_open_forward_distance_m": [0.001, 15.0],
	"cpu_follow_slot_open_forward_weight": [0.0, 100.0],
	"cpu_follow_slot_open_forward_threshold": [0.0, 100.0],
	"cpu_follow_slot_inner_bias": [0.0, 100.0],
	"cpu_line_distance_advantage_weight": [0.0, 100.0],
	"cpu_overtake_bias_threshold": [-1.0, 1.0],
	"cpu_overtake_forward_distance_m": [0.001, 15.0],
	"cpu_overtake_slot_lateral_spacing_m": [0.001, 15.0],
	"cpu_overtake_slot_bias_weight": [0.0, 100.0],
	"cpu_overtake_escape_lateral_spacing_m": [0.001, 15.0],
	"cpu_overtake_escape_bias_weight": [0.0, 100.0],
	"cpu_overtake_escape_steer_speed_multiplier": [1.0, 10.0],
	"cpu_inward_target_offset_m": [-15.0, 15.0],
	"cpu_trainer_reselect_seconds": [0.05, 60.0],
	"top_speed_natural_min_kmh": [0.0, 300.0],
	"top_speed_natural_max_kmh": [0.0, 300.0],
	"acceleration_drive_force_bonus_per_stat_kmh_per_s": [0.0, 10.0],
	"acceleration_response_multiplier_per_stat": [0.0, 0.1],
	"heart_rate_min_bpm": [1.0, 300.0],
	"heart_rate_normal_max_bpm": [1.0, 300.0],
	"heart_rate_overheat_max_bpm": [1.0, 300.0],
	"heart_rate_rise_time_cardio_min_s": [0.1, 300.0],
	"heart_rate_rise_time_cardio_max_s": [0.1, 300.0],
	"heart_rate_recovery_time_cardio_min_s": [0.1, 300.0],
	"heart_rate_recovery_time_cardio_max_s": [0.1, 300.0],
	"heart_rate_recovery_exponent": [0.1, 6.0],
	"heart_adaptation_recovery_gain": [0.0, 10.0],
	"heart_adaptation_time_s": [1.0, 600.0],
	"heart_rate_recovery_rate_scale": [0.1, 10.0],
	"heart_rate_drive_load_scale": [0.01, 10.0],
	"stamina_capacity_base_l": [0.0, 10000.0],
	"stamina_capacity_per_stat_l": [0.001, 10000.0],
	"stamina_debt_capacity_multiplier": [0.0, 100.0],
	"stamina_consumption_min_l_per_s": [0.0, 100.0],
	"stamina_consumption_max_l_per_s": [0.0, 100.0],
	"stamina_consumption_load_multiplier": [0.001, 100.0],
	"stamina_heart_rate_factor_min": [0.0, 10.0],
	"stamina_heart_rate_factor_max": [0.0, 10.0],
	"stamina_debt_efficiency_min": [0.0, 1.0],
	"overheat_stamina_multiplier_max": [1.0, 10.0],
	"overheat_propulsion_efficiency_min": [0.0, 1.0],
	"overheat_exposure_efficiency_loss_per_s": [0.0001, 1.0],
	"overheat_exposure_recovery_per_s": [0.0, 100.0],
}
static var _cached: Dictionary = {}
static var _attempted := false
static var last_error := ""

static func load_file(path: String = PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません (%s)" % [path, FileAccess.get_open_error()]}
	return parse_text(file.get_as_text(), path)

static func parse_text(content: String, source: String = PATH) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"error": "%s:%d: %s" % [source, parser.get_error_line(), parser.get_error_message()]}
	var errors := validate(parser.data)
	if not errors.is_empty():
		return {"error": "%s: %s" % [source, "; ".join(errors)]}
	return {"data": parser.data}

static func validate(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["ルートはオブジェクトである必要があります"])
	for key in NUMBER_RANGES:
		var value: Variant = data.get(key)
		var limits: Array = NUMBER_RANGES[key]
		if not (value is float or value is int):
			errors.append("%s: 数値が必須です" % key)
		elif not is_finite(float(value)) or value < limits[0] or value > limits[1]:
			errors.append("%s: 範囲 %s〜%s 外です" % [key, limits[0], limits[1]])
	for key in data:
		if not NUMBER_RANGES.has(key) and key not in ["drive_force_by_level_kmh_per_s", "heart_rate_rise_rate_by_drive_level_bpm_per_s", "cpu_trainer_profiles"]:
			errors.append("%s: 未知の設定項目です" % key)
	if not errors.is_empty():
		return errors
	for key in ["drive_level_max", "drive_level_step"]:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	for key in ["aero_air_resistance_reference_stat", "pack_draft_effective_reference_stat", "handling_steer_reference_stat", "contact_resistance_reference_stat"]:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	for key in ["player_start_drive_level", "cpu_start_drive_level"]:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	if float(data.player_start_gate_index) != floorf(float(data.player_start_gate_index)):
		errors.append("player_start_gate_index: 整数が必要です")
	for key in ["player_start_drive_level", "cpu_start_drive_level"]:
		if float(data[key]) < 0.0 or float(data[key]) > float(data.drive_level_max):
			errors.append("%s: 0〜drive_level_max の範囲にしてください" % key)
	if data.heart_rate_min_bpm > data.heart_rate_normal_max_bpm:
		errors.append("heart_rate_min_bpm: heart_rate_normal_max_bpm 以下にしてください")
	if data.heart_rate_normal_max_bpm > data.heart_rate_overheat_max_bpm:
		errors.append("heart_rate_normal_max_bpm: heart_rate_overheat_max_bpm 以下にしてください")
	if data.heart_rate_rise_time_cardio_min_s > data.heart_rate_rise_time_cardio_max_s:
		errors.append("heart_rate_rise_time_cardio_min_s: heart_rate_rise_time_cardio_max_s 以下にしてください")
	if data.heart_rate_recovery_time_cardio_min_s < data.heart_rate_recovery_time_cardio_max_s:
		errors.append("heart_rate_recovery_time_cardio_min_s: heart_rate_recovery_time_cardio_max_s 以上にしてください")
	if data.stamina_consumption_min_l_per_s > data.stamina_consumption_max_l_per_s:
		errors.append("stamina_consumption_min_l_per_s: stamina_consumption_max_l_per_s 以下にしてください")
	if data.stamina_heart_rate_factor_min > data.stamina_heart_rate_factor_max:
		errors.append("stamina_heart_rate_factor_min: stamina_heart_rate_factor_max 以下にしてください")
	for pair in [
		["cpu_steer_reselect_min_s", "cpu_steer_reselect_max_s"],
	]:
		if float(data[pair[0]]) > float(data[pair[1]]):
			errors.append("%s: %s 以下にしてください" % [pair[0], pair[1]])
	if float(data.cpu_follow_preferred_gap_m) > float(data.cpu_follow_forward_range_m):
		errors.append("cpu_follow_preferred_gap_m: cpu_follow_forward_range_m 以下にしてください")
	if float(data.push_passive_multiplier) > float(data.push_intent_multiplier):
		errors.append("push_passive_multiplier: push_intent_multiplier 以下にしてください")
	if float(data.top_speed_natural_min_kmh) > float(data.top_speed_natural_max_kmh):
		errors.append("top_speed_natural_min_kmh: top_speed_natural_max_kmh 以下にしてください")
	if absf(float(data.cpu_inward_target_offset_m)) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_inward_target_offset_m: コースの可動範囲内にしてください")
	if float(data.cpu_follow_slot_lateral_spacing_m) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_follow_slot_lateral_spacing_m: コースの可動範囲内にしてください")
	if float(data.cpu_overtake_slot_lateral_spacing_m) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_overtake_slot_lateral_spacing_m: コースの可動範囲内にしてください")
	if float(data.cpu_overtake_escape_lateral_spacing_m) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_overtake_escape_lateral_spacing_m: コースの可動範囲内にしてください")
	var forces: Variant = data.get("drive_force_by_level_kmh_per_s")
	if not forces is Array:
		errors.append("drive_force_by_level_kmh_per_s: 配列が必須です")
	else:
		if forces.size() != int(data.drive_level_max) + 1:
			errors.append("drive_force_by_level_kmh_per_s: 要素数は drive_level_max + 1 が必要です")
		var previous := 0.0
		for i in forces.size():
			var force: Variant = forces[i]
			if not (force is float or force is int):
				errors.append("drive_force_by_level_kmh_per_s[%d]: 数値が必要です" % i)
			elif not is_finite(float(force)) or force < previous or force > 100.0 or (i == 0 and force != 0):
				errors.append("drive_force_by_level_kmh_per_s[%d]: 0番は0、以降は単調増加で100以下にしてください" % i)
			else:
				previous = float(force)
	var profiles: Variant = data.get("cpu_trainer_profiles")
	var heart_rise_rates: Variant = data.get("heart_rate_rise_rate_by_drive_level_bpm_per_s")
	if not heart_rise_rates is Array:
		errors.append("heart_rate_rise_rate_by_drive_level_bpm_per_s: 配列が必須です")
	else:
		if heart_rise_rates.size() != int(data.drive_level_max) + 1:
			errors.append("heart_rate_rise_rate_by_drive_level_bpm_per_s: 要素数は drive_level_max + 1 が必要です")
		var previous_rate := 0.0
		for i in heart_rise_rates.size():
			var rate: Variant = heart_rise_rates[i]
			if not (rate is float or rate is int):
				errors.append("heart_rate_rise_rate_by_drive_level_bpm_per_s[%d]: 数値が必要です" % i)
			elif not is_finite(float(rate)) or rate < previous_rate or rate > 100.0 or (i == 0 and rate != 0):
				errors.append("heart_rate_rise_rate_by_drive_level_bpm_per_s[%d]: 0番は0、以降は単調増加で100以下にしてください" % i)
			else:
				previous_rate = float(rate)
	var profile_ids := {}
	if not profiles is Array or profiles.is_empty():
		errors.append("cpu_trainer_profiles: 1個以上の配列が必要です")
	else:
		for index in profiles.size():
			var profile: Variant = profiles[index]
			if not profile is Dictionary:
				errors.append("cpu_trainer_profiles[%d]: オブジェクトが必要です" % index)
				continue
			var identifier := str(profile.get("id", ""))
			if identifier.is_empty() or profile_ids.has(identifier):
				errors.append("cpu_trainer_profiles[%d].id: 空または重複です" % index)
				continue
			profile_ids[identifier] = true
			for key in ["line_pref"]:
				var value: Variant = profile.get(key)
				if not (value is float or value is int) or not is_finite(float(value)) or value < 0.0 or value > 1.0:
					errors.append("cpu_trainer_profiles[%d].%s: 0〜1の数値が必要です" % [index, key])
	return errors

static func values() -> Dictionary:
	if not _attempted:
		_attempted = true
		var result := load_file()
		if result.has("error"):
			last_error = result.error
			push_error(last_error)
		else:
			_cached = result.data
			_cached.drive_force_by_level_kmh_per_s.make_read_only()
			_cached.heart_rate_rise_rate_by_drive_level_bpm_per_s.make_read_only()
			_cached.make_read_only()
	return _cached

static func number(key: String) -> float:
	var data := values()
	assert(not data.is_empty(), last_error)
	return float(data[key])
