extends RefCounted
## ローカル出力操作の設定。JSONのみを初期値の正本とする。
## アプリ起動中に一度だけ読み込む。変更の反映はクライアント再起動時。

const M2TrackMath := preload("res://scripts/m2_track_math.gd")

const PATH := "res://data/config/local_race.json"
const NUMBER_RANGES := {
	"schema_version": [1.0, 1.0],
	"drive_level_min": [-100.0, -1.0],
	"drive_level_max": [1.0, 100.0],
	"drive_level_step": [1.0, 1.0],
	"start_countdown_seconds": [0.0, 30.0],
	"player_start_drive_level": [-100.0, 100.0],
	"cpu_start_drive_level": [-100.0, 100.0],
	"cpu_start_drive_duration_seconds": [0.0, 30.0],
	"min_speed_kmh": [0.0, 75.0],
	"rolling_resistance_kmh_per_s": [0.0, 100.0],
	"air_resistance_quadratic_coefficient": [0.0, 100.0],
	"draft_response_exponent": [1.0, 4.0],
	"draft_effective_max_ratio": [0.001, 1.0],
	"draft_aggregation_exponent": [1.0, 4.0],
	"brake_deceleration_per_level": [0.001, 100.0],
	"draft_air_resistance_factor": [0.0, 1.0],
	"drive_repeat_initial_s": [0.001, 10.0],
	"drive_repeat_interval_s": [0.001, 10.0],
	"cpu_steer_reselect_min_s": [0.001, 60.0],
	"cpu_steer_reselect_max_s": [0.001, 60.0],
	"cpu_steer_target_delta_max_m": [0.0, 15.0],
	"cpu_steer_speed_m_per_s": [0.001, 100.0],
	"cpu_follow_forward_range_m": [0.001, 100.0],
	"cpu_follow_lateral_range_m": [0.001, 15.0],
	"cpu_follow_preferred_gap_m": [0.001, 100.0],
	"cpu_follow_offset_blend": [0.0, 1.0],
	"cpu_follow_slot_lateral_spacing_m": [0.001, 15.0],
	"cpu_follow_slot_crowding_forward_range_m": [0.001, 100.0],
	"cpu_follow_slot_crowding_lateral_range_m": [0.001, 15.0],
	"cpu_follow_slot_crowding_weight": [0.0, 100.0],
	"cpu_follow_slot_inner_bias": [0.0, 100.0],
	"cpu_inward_target_offset_m": [-15.0, 15.0],
	"cpu_inward_target_blend": [0.0, 1.0],
	"cpu_trainer_reselect_seconds": [0.05, 60.0],
	"cpu_target_speed_change_kmh_per_s": [0.01, 100.0],
	"top_speed_natural_min_kmh": [0.0, 90.0],
	"top_speed_natural_max_kmh": [0.0, 90.0],
	"acceleration_drive_force_bonus_per_stat_kmh_per_s": [0.0, 10.0],
	"cpu_trainer_finish_start_progress": [0.0, 1.0],
	"cpu_trainer_finish_full_progress": [0.0, 1.0],
	"cpu_trainer_reserve_max_kmh": [0.0, 25.0],
	"cpu_trainer_position_push_max_kmh": [0.0, 25.0],
	"cpu_trainer_finish_push_max_kmh": [0.0, 25.0],
	"cpu_trainer_draft_saving_max_kmh": [0.0, 25.0],
	"cpu_trainer_low_stamina_saving_max_kmh": [0.0, 25.0],
	"heart_rate_rest_bpm": [1.0, 300.0],
	"heart_rate_max_bpm": [1.0, 300.0],
	"heart_rate_change_bpm_per_s": [0.001, 300.0],
	"stamina_capacity": [0.001, 10000.0],
	"stamina_low_effort_delta_per_s": [-1000.0, 1000.0],
	"stamina_max_effort_delta_per_s": [-1000.0, 0.0],
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
		if not NUMBER_RANGES.has(key) and key not in ["drive_force_by_level_kmh_per_s", "cpu_speed_tiers_kmh", "cpu_trainer_profiles", "cpu_trainer_profile_cycle"]:
			errors.append("%s: 未知の設定項目です" % key)
	if not errors.is_empty():
		return errors
	for key in ["drive_level_min", "drive_level_max", "drive_level_step"]:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	for key in ["player_start_drive_level", "cpu_start_drive_level"]:
		if float(data[key]) != floorf(float(data[key])):
			errors.append("%s: 整数が必要です" % key)
	if absf(data.drive_level_min) > data.drive_level_max:
		errors.append("drive_level_min: 絶対値は drive_level_max 以下にしてください")
	for key in ["player_start_drive_level", "cpu_start_drive_level"]:
		if float(data[key]) < float(data.drive_level_min) or float(data[key]) > float(data.drive_level_max):
			errors.append("%s: drive_level_min〜drive_level_max の範囲にしてください" % key)
	if data.heart_rate_rest_bpm > data.heart_rate_max_bpm:
		errors.append("heart_rate_rest_bpm: heart_rate_max_bpm 以下にしてください")
	for pair in [
		["cpu_steer_reselect_min_s", "cpu_steer_reselect_max_s"],
	]:
		if float(data[pair[0]]) > float(data[pair[1]]):
			errors.append("%s: %s 以下にしてください" % [pair[0], pair[1]])
	if float(data.cpu_follow_preferred_gap_m) > float(data.cpu_follow_forward_range_m):
		errors.append("cpu_follow_preferred_gap_m: cpu_follow_forward_range_m 以下にしてください")
	if float(data.cpu_trainer_finish_start_progress) > float(data.cpu_trainer_finish_full_progress):
		errors.append("cpu_trainer_finish_start_progress: cpu_trainer_finish_full_progress 以下にしてください")
	if float(data.top_speed_natural_min_kmh) > float(data.top_speed_natural_max_kmh):
		errors.append("top_speed_natural_min_kmh: top_speed_natural_max_kmh 以下にしてください")
	if absf(float(data.cpu_inward_target_offset_m)) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_inward_target_offset_m: コースの可動範囲内にしてください")
	if float(data.cpu_follow_slot_lateral_spacing_m) > M2TrackMath.MAX_ABS_OFFSET_M:
		errors.append("cpu_follow_slot_lateral_spacing_m: コースの可動範囲内にしてください")
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
	var speed_tiers: Variant = data.get("cpu_speed_tiers_kmh")
	if not speed_tiers is Array:
		errors.append("cpu_speed_tiers_kmh: 1個以上の配列が必須です")
	elif speed_tiers.is_empty():
		errors.append("cpu_speed_tiers_kmh: 1個以上の配列が必須です")
	else:
		var previous_tier := float(data.min_speed_kmh)
		for i in speed_tiers.size():
			var tier: Variant = speed_tiers[i]
			if not (tier is float or tier is int):
				errors.append("cpu_speed_tiers_kmh[%d]: 数値が必要です" % i)
			elif not is_finite(float(tier)) or tier < previous_tier or tier > 90.0:
				errors.append("cpu_speed_tiers_kmh[%d]: 最低速度以上の非減少値かつ90以下にしてください" % i)
			else:
				previous_tier = float(tier)
	var profiles: Variant = data.get("cpu_trainer_profiles")
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
			for key in ["aggression", "patience", "drafting_pref", "line_pref"]:
				var value: Variant = profile.get(key)
				if not (value is float or value is int) or not is_finite(float(value)) or value < 0.0 or value > 1.0:
					errors.append("cpu_trainer_profiles[%d].%s: 0〜1の数値が必要です" % [index, key])
	var cycle: Variant = data.get("cpu_trainer_profile_cycle")
	if not cycle is Array or cycle.is_empty():
		errors.append("cpu_trainer_profile_cycle: 1個以上の配列が必要です")
	else:
		for index in cycle.size():
			if not cycle[index] is String or not profile_ids.has(str(cycle[index])):
				errors.append("cpu_trainer_profile_cycle[%d]: 定義済みプロフィールIDが必要です" % index)
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
			_cached.cpu_speed_tiers_kmh.make_read_only()
			_cached.make_read_only()
	return _cached

static func number(key: String) -> float:
	var data := values()
	assert(not data.is_empty(), last_error)
	return float(data[key])
