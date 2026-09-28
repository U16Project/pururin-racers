extends RefCounted
## 基本ステータス配分を変えたローカルレース比較の共通処理。
## 配分生成・ケース生成・結果の要約だけを担当し、物理式は Runner に委譲する。

const Simulator := preload("res://scripts/local_race_simulator.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")

const CONFIG_PATH := "res://data/config/local_race_stat_sweep.json"
const TARGET_STATS := ["acceleration", "top_speed", "cardio", "stamina"]
const SCHEDULES := ["notch4_cruise", "notch6_sustain", "notch6_to_zero_recovery"]


static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません" % path}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"error": "%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]}
	if not parser.data is Dictionary:
		return {"error": "%s: ルートはオブジェクトである必要があります" % path}
	return {"data": parser.data}


## 基準配分から対象ステータスだけを変更し、残りを1ずつ機械的に再配分する。
## これにより合計40、各1〜10を常に維持し、補正先も再現可能になる。
static func adjusted_allocation(target_stat: String, target_value: int, base: Dictionary = {}) -> Dictionary:
	var allocation := StatsMath.default_allocation() if base.is_empty() else base.duplicate(true)
	if target_stat not in allocation:
		return {}
	var min_value := 1
	var max_value := 10
	if target_value < min_value or target_value > max_value:
		return {}
	var old_value := int(allocation[target_stat])
	allocation[target_stat] = target_value
	var correction := old_value - target_value
	var other_stats: Array[String] = []
	for stat_id: String in StatsMath.Config.values()["stat_ids"]:
		if stat_id != target_stat:
			other_stats.append(stat_id)
	var index := 0
	while correction != 0 and not other_stats.is_empty():
		var stat_id: String = other_stats[index % other_stats.size()]
		var current := int(allocation[stat_id])
		if correction > 0 and current < max_value:
			allocation[stat_id] = current + 1
			correction -= 1
		elif correction < 0 and current > min_value:
			allocation[stat_id] = current - 1
			correction += 1
		index += 1
		if index > 1000:
			return {}
	return allocation if correction == 0 and StatsMath.validate_allocation(allocation).is_empty() else {}


static func validate_profile(profile: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if str(profile.get("id", "")).is_empty():
		errors.append("profile id が空です")
	var allocation: Variant = profile.get("allocation", {})
	errors.append_array(StatsMath.validate_allocation(allocation))
	return errors


static func build_cases(config: Dictionary) -> Array:
	var cases: Array = []
	var configured_variants: Variant = config.get("variants", [])
	if configured_variants is Array and not configured_variants.is_empty():
		for variant_value: Variant in configured_variants:
			if not variant_value is Dictionary:
				continue
			var variant: Dictionary = variant_value
			var scenario_id := str(variant.get("scenario_id", "notch4_cruise"))
			var scenario := Simulator.scenario_by_id(scenario_id)
			if scenario.is_empty():
				continue
			# 明示的な variants も、基準シナリオの目標値を引き継がない。
			# スイープの判定は完走・値域と、後段の単調性評価で行う。
			scenario["goals"] = []
			var allocation: Dictionary = variant.get("allocation", {}).duplicate(true)
			scenario["player_override"] = {"allocation": allocation}
			var case := variant.duplicate(true)
			case["scenario"] = scenario
			case["scenario_id"] = scenario_id
			case["allocation"] = allocation
			cases.append(case)
		return cases
	var stat_levels: Array = config.get("stat_levels", [1, 5, 9, 10])
	var target_stats: Array = config.get("target_stats", TARGET_STATS)
	var schedules: Array = config.get("schedules", SCHEDULES)
	for stat_value: Variant in target_stats:
		var stat_id := str(stat_value)
		for level_value: Variant in stat_levels:
			var level := int(level_value)
			var allocation := adjusted_allocation(stat_id, level)
			if allocation.is_empty():
				continue
			var group_id := "%s_level_%d" % [stat_id, level]
			for schedule_value: Variant in schedules:
				var schedule_id := str(schedule_value)
				cases.append(_make_case(
					"%s_%s" % [group_id, schedule_id],
					group_id,
					stat_id,
					level,
					allocation,
					schedule_id,
					"stat_level"
				))
	for profile_value: Variant in config.get("focus_profiles", []):
		if not profile_value is Dictionary:
			continue
		var profile: Dictionary = profile_value
		if not validate_profile(profile).is_empty():
			continue
		var profile_id := str(profile.get("id", "focus"))
		var group_id := "profile_%s" % profile_id
		var allocation: Dictionary = profile.get("allocation", {}).duplicate(true)
		for repeat_index in int(config.get("focus_repetitions", 3)):
			cases.append(_make_case(
				"%s_run_%d" % [group_id, repeat_index + 1],
				group_id,
				str(profile.get("focus_stat", "")),
				int(allocation.get(str(profile.get("focus_stat", "")), 0)),
				allocation,
				"notch4_cruise",
				"focus_profile"
			))
	return cases


static func _make_case(variant_id: String, group_id: String, target_stat: String, target_value: int, allocation: Dictionary, schedule_id: String, case_kind: String) -> Dictionary:
	var scenario := Simulator.scenario_by_id(schedule_id)
	if scenario.is_empty():
		return {}
	# 通常シナリオの心拍・スタミナ目標は基準配分専用。
	# ステータスを振ったケースへそのまま適用すると、特化型を誤ってFAILにするため、
	# スイープでは完走・範囲チェックと後段の方向性評価だけを共通判定にする。
	scenario["goals"] = []
	scenario["player_override"] = {"allocation": allocation}
	return {
		"variant_id": variant_id,
		"comparison_group": group_id,
		"case_kind": case_kind,
		"target_stat": target_stat,
		"target_value": target_value,
		"allocation": allocation.duplicate(true),
		"scenario_id": schedule_id,
		"scenario": scenario,
	}


static func player_snapshot(result: Dictionary) -> Dictionary:
	for value: Variant in result.get("runners", []):
		if value is Dictionary and bool(value.get("player", false)):
			return value
	return {}


static func player_metrics(result: Dictionary) -> Dictionary:
	var player := player_snapshot(result)
	var assessment: Dictionary = result.get("goal_assessment", {})
	var metrics: Dictionary = assessment.get("metrics", {})
	var time_to_60 := _time_to_speed(result, 60.0)
	return {
		"finish_time_s": float(player.get("finish_time_s", -1.0)),
		"rank": int(player.get("rank", -1)),
		"speed_kmh": float(player.get("speed_kmh", NAN)),
		"natural_top_speed_kmh": float(player.get("natural_top_speed_kmh", NAN)),
		"heart_rate_bpm": float(player.get("heart_rate_bpm", NAN)),
		"max_heart_rate_bpm": float(metrics.get("player_max_heart_rate", NAN)),
		"stamina": float(player.get("stamina", NAN)),
		"min_stamina": float(metrics.get("player_min_stamina", NAN)),
		"stamina_load": float(metrics.get("player_stamina_load", NAN)),
		"time_to_60_s": time_to_60,
		"effective_stats": player.get("effective_stats", {}),
	}


static func build_record(case: Dictionary, result: Dictionary) -> Dictionary:
	var player := player_snapshot(result)
	var finish_order: Array = []
	for value: Variant in result.get("runners", []):
		if value is Dictionary:
			var runner: Dictionary = value
			var order := int(runner.get("finish_order", 0))
			if order > 0:
				finish_order.resize(maxi(finish_order.size(), order))
				finish_order[order - 1] = {"id": runner.get("id", ""), "name": runner.get("display_name", ""), "rank": runner.get("rank", 0), "finish_time_s": runner.get("finish_time_s", -1.0)}
	return {
		"variant_id": case.get("variant_id", ""),
		"comparison_group": case.get("comparison_group", ""),
		"case_kind": case.get("case_kind", ""),
		"target_stat": case.get("target_stat", ""),
		"target_value": case.get("target_value", 0),
		"raw_allocation": case.get("allocation", {}),
		"effective_stats": player.get("effective_stats", {}),
		"scenario_id": case.get("scenario_id", ""),
		"goal_assessment": result.get("goal_assessment", {}),
		"elapsed_s": result.get("elapsed_s", 0.0),
		"timed_out": result.get("timed_out", true),
		"finished_count": result.get("finished_count", 0),
		"player": player_metrics(result),
		"finish_order": finish_order,
	}


static func _time_to_speed(result: Dictionary, target_speed: float) -> float:
	for sample_value: Variant in result.get("samples", []):
		if not sample_value is Array:
			continue
		for runner_value: Variant in sample_value:
			if runner_value is Dictionary and bool(runner_value.get("player", false)) and float(runner_value.get("speed_kmh", 0.0)) >= target_speed:
				return float(runner_value.get("time_s", -1.0))
	return -1.0


static func assess_monotonicity(records: Array) -> Dictionary:
	var by_stat := {}
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		if str(record.get("scenario_id", "")) != "notch4_cruise":
			continue
		if str(record.get("case_kind", "")) != "stat_level":
			continue
		var stat_id := str(record.get("target_stat", ""))
		if stat_id.is_empty():
			continue
		if not by_stat.has(stat_id):
			by_stat[stat_id] = []
		by_stat[stat_id].append(record)
	var checks := {}
	for stat_id: String in by_stat:
		var values: Array = by_stat[stat_id]
		values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("target_value", 0)) < int(b.get("target_value", 0)))
		var observed := []
		for value: Variant in values:
			var record: Dictionary = value
			var player: Dictionary = record.get("player", {})
			observed.append({
				"target_value": record.get("target_value", 0),
				"natural_top_speed_kmh": player.get("natural_top_speed_kmh", NAN),
				"time_to_60_s": player.get("time_to_60_s", NAN),
				"max_heart_rate_bpm": player.get("max_heart_rate_bpm", NAN),
				"stamina_load": player.get("stamina_load", NAN),
			})
		var metric_name := _monotonic_metric_for_stat(stat_id)
		var increasing := stat_id == "top_speed"
		var evaluable_count := 0
		for value: Variant in observed:
			if is_finite(float((value as Dictionary).get(metric_name, NAN))) and float((value as Dictionary).get(metric_name, NAN)) >= 0.0:
				evaluable_count += 1
		var passed := _values_monotonic(observed, metric_name, increasing)
		checks[stat_id] = {
			"passed": passed,
			"status": "NOT_EVALUATED" if evaluable_count < 2 else ("PASS" if passed else "FAIL"),
			"evaluable_count": evaluable_count,
			"metric": metric_name,
			"values": observed,
		}
	return checks


static func _monotonic_metric_for_stat(stat_id: String) -> String:
	match stat_id:
		"top_speed": return "natural_top_speed_kmh"
		"acceleration": return "time_to_60_s"
		"cardio": return "max_heart_rate_bpm"
		"stamina": return "stamina_load"
	return "natural_top_speed_kmh"


static func _values_monotonic(values: Array, metric: String, increasing: bool) -> bool:
	if values.size() < 2:
		return false
	var usable: Array[float] = []
	for value: Variant in values:
		var measured := float((value as Dictionary).get(metric, NAN))
		# -1 は「到達していない」を示す欠測値で、順序比較へ入れない。
		if is_finite(measured) and measured >= 0.0:
			usable.append(measured)
	if usable.size() < 2:
		return false
	var previous := usable[0]
	for index in range(1, usable.size()):
		var current := usable[index]
		if increasing and current + 0.001 < previous:
			return false
		if not increasing and current > previous + 0.001:
			return false
		previous = current
	return true
