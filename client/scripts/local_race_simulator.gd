extends RefCounted
## 描画・入力を使わず、既存のローカルレースシーンを最後まで進める統合ハーネス。
## 物理式・CPU判断・ドラフト・心拍・スタミナは runner/controller を再利用する。

const LocalRaceScene := preload("res://scenes/local_race.tscn")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")

const CONFIG_PATH := "res://data/config/local_race_simulation.json"


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


static func scenarios(path: String = CONFIG_PATH) -> Array:
	var loaded := load_config(path)
	if loaded.has("error"):
		return []
	var values: Variant = loaded.data.get("scenarios", [])
	return values if values is Array else []


static func scenario_by_id(identifier: String, path: String = CONFIG_PATH) -> Dictionary:
	for scenario: Variant in scenarios(path):
		if scenario is Dictionary and str(scenario.get("id", "")) == identifier:
			return scenario.duplicate(true)
	return {}


func run_scenario(parent: Node, scenario: Dictionary) -> Dictionary:
	var race := LocalRaceScene.instantiate()
	parent.add_child(race)
	# SceneTreeの通常processを止め、同じdeltaで各段階を明示的に進める。
	race.set_process(false)
	var runners: Array = race.call("get_runners_for_simulation")
	# SceneTree の初期化中（CLI の SceneTree._initialize）では、追加直後に
	# _ready がまだ呼ばれないことがある。通常の初期化を一度だけ補完する。
	if runners.is_empty():
		race.call("_ready")
		runners = race.call("get_runners_for_simulation")
	for runner in runners:
		runner.set_process(false)
		# 画面用の1秒診断ログは、統合シミュレーションのJSON出力には不要。
		runner.set("_drive_diagnostic_log_remaining", INF)
	var player_override: Variant = scenario.get("player_override", {})
	if player_override is Dictionary and not (player_override as Dictionary).is_empty():
		var override_errors: PackedStringArray = runners[0].call("apply_simulation_player_override", player_override)
		if not override_errors.is_empty():
			race.free()
			return {"error": "player_override: %s" % "; ".join(override_errors)}

	var delta := maxf(float(scenario.get("delta_s", _config_number("default_delta_s", 0.05))), 0.001)
	var max_time := maxf(float(scenario.get("max_time_s", _config_number("default_max_time_s", 180.0))), delta)
	var sample_interval := maxf(float(scenario.get("sample_interval_s", _config_number("default_sample_interval_s", 1.0))), delta)
	var schedule: Array = scenario.get("player_drive_schedule", [])
	var elapsed := 0.0
	var next_sample := 0.0
	var samples: Array = []

	# カウントダウンを省略するだけで、開始時の runner 状態は通常レースと同じにする。
	race.set("_race_started", true)
	race.set("_start_countdown_remaining", 0.0)
	for runner in runners:
		runner.call("set_race_active", true)
	_set_player_drive(runners, schedule, 0.0)

	while elapsed < max_time and not _all_finished(runners):
		var step := minf(delta, max_time - elapsed)
		_set_player_drive(runners, schedule, elapsed)
		race.set("_race_elapsed", elapsed + step)
		# 通常コントローラと同じ順番: 前tickの情報共有→移動→ゴール判定→ドラフト確定。
		race.call("_share_snapshots")
		for runner in runners:
			runner.call("_process", step)
		race.call("_finalize_draft_tick")
		elapsed += step
		if elapsed + 0.0001 >= next_sample:
			samples.append(_snapshot_runners(runners, elapsed))
			next_sample += sample_interval

	var result := {
		"scenario_id": str(scenario.get("id", "unnamed")),
		"description": str(scenario.get("description", "")),
		"elapsed_s": elapsed,
		"timed_out": not _all_finished(runners),
		"finished_count": _finished_count(runners),
		"runners": _snapshot_runners(runners, elapsed),
		"samples": samples,
	}
	result["goal_assessment"] = assess_result(result, scenario)
	race.free()
	return result


func run_scenario_by_id(parent: Node, identifier: String) -> Dictionary:
	var scenario := scenario_by_id(identifier)
	if scenario.is_empty():
		return {"error": "シナリオが見つかりません: %s" % identifier}
	return run_scenario(parent, scenario)


## 観測結果を、シナリオ設定に置いた目標・許容範囲・相対条件で判定する。
## hard は走行の成立条件、soft は設計上の目標、relative は別シナリオとの比較。
## 参照結果が渡されない relative は NOT_EVALUATED として保留し、単独実行を失敗扱いにしない。
static func assess_result(result: Dictionary, scenario: Dictionary, reference_results: Dictionary = {}) -> Dictionary:
	var checks: Array = []
	var metrics := _assessment_metrics(result)
	var validation_errors := validate_result(result, scenario)
	_add_assessment_check(checks, {
		"id": "all_finished",
		"kind": "hard",
		"metric": "finished_count",
		"operator": "eq",
		"target": LocalRaceMath.FIELD_SIZE,
		"reason": "8頭すべてが完走している"
	}, metrics)
	_add_assessment_check(checks, {
		"id": "no_timeout",
		"kind": "hard",
		"metric": "timed_out",
		"operator": "eq",
		"target": false,
		"reason": "制限時間内に完走している"
	}, metrics)
	_add_assessment_check(checks, {
		"id": "state_values_valid",
		"kind": "hard",
		"metric": "validation_errors_count",
		"operator": "eq",
		"target": 0,
		"reason": "速度・心拍・スタミナ・座標などが有限かつ範囲内"
	}, metrics)
	# `goals` が正規キー。旧来の `goal_checks` も読み込めるようにして、
	# シナリオ設定の段階的な移行で判定機能を壊さない。
	var configured_checks: Variant = scenario.get("goals", scenario.get("goal_checks", []))
	if configured_checks is Array:
		for goal_value: Variant in configured_checks:
			if goal_value is Dictionary:
				_add_assessment_check(checks, goal_value, metrics, reference_results)
	var failed := 0
	var deferred := 0
	for check_value: Variant in checks:
		var check: Dictionary = check_value
		if str(check.get("status", "")) == "FAIL":
			failed += 1
		elif str(check.get("status", "")) == "NOT_EVALUATED":
			deferred += 1
	var passed := failed == 0
	var status := "PASS" if passed else "FAIL"
	var summary := "%s: %d件の目標を確認" % [status, checks.size()]
	if deferred > 0:
		summary += "（相対条件%d件は参照結果待ち）" % deferred
	if failed > 0:
		summary += "（失敗%d件）" % failed
	return {
		"passed": passed,
		"status": status,
		"checks": checks,
		"metrics": metrics,
		"summary": summary,
		"validation_errors": Array(validation_errors),
	}


static func _assessment_metrics(result: Dictionary) -> Dictionary:
	var runners: Array = result.get("runners", []) if result.get("runners", []) is Array else []
	var samples: Array = result.get("samples", []) if result.get("samples", []) is Array else []
	var player: Dictionary = {}
	for runner_value: Variant in runners:
		if runner_value is Dictionary and bool(runner_value.get("player", false)):
			player = runner_value
			break
	var player_samples: Array = []
	for sample_value: Variant in samples:
		if not sample_value is Array:
			continue
		for runner_value: Variant in sample_value:
			if runner_value is Dictionary and bool(runner_value.get("player", false)):
				player_samples.append(runner_value)
				break
	var max_heart_rate := float(player.get("heart_rate_bpm", NAN))
	var min_stamina := float(player.get("stamina", NAN))
	var max_overheat := float(player.get("overheat_ratio", NAN))
	for sample_value: Variant in player_samples:
		var sample: Dictionary = sample_value
		max_heart_rate = maxf(max_heart_rate, float(sample.get("heart_rate_bpm", NAN)))
		min_stamina = minf(min_stamina, float(sample.get("stamina", NAN)))
		max_overheat = maxf(max_overheat, float(sample.get("overheat_ratio", NAN)))
	var stamina_capacity := LocalRaceMath.Config.number("stamina_capacity")
	return {
		"finished_count": int(result.get("finished_count", -1)),
		"timed_out": bool(result.get("timed_out", true)),
		"validation_errors_count": validate_result(result).size(),
		"player_finish_stamina": float(player.get("stamina", NAN)),
		"player_finish_heart_rate": float(player.get("heart_rate_bpm", NAN)),
		"player_max_heart_rate": max_heart_rate,
		"player_min_stamina": min_stamina,
		"player_stamina_load": stamina_capacity - float(player.get("stamina", NAN)),
		"player_max_overheat_ratio": max_overheat,
	}


static func _add_assessment_check(checks: Array, definition: Dictionary, metrics: Dictionary, reference_results: Dictionary = {}) -> void:
	var check := definition.duplicate(true)
	# レポートを機械的に集計できる共通フィールドを必ず持たせる。
	# target は相対条件の参照待ちでは null のままになる。
	if not check.has("target"):
		check["target"] = null
	var metric := str(check.get("metric", ""))
	var operator := str(check.get("operator", "between"))
	var kind := str(check.get("kind", "soft"))
	var measured: Variant = metrics.get(metric, null)
	var status := "FAIL"
	var reason := str(check.get("reason", metric))
	if kind == "relative":
		var reference_id := str(check.get("reference_scenario", ""))
		var reference: Variant = reference_results.get(reference_id, null)
		if reference is Dictionary:
			var reference_metrics: Dictionary = reference.get("goal_assessment", {}).get("metrics", {})
			var reference_metric := str(check.get("reference_metric", metric))
			var reference_value: Variant = reference_metrics.get(reference_metric, null)
			if measured is float and reference_value is float and is_finite(float(measured)) and is_finite(float(reference_value)):
				var relative_definition := {"operator": operator, "target": float(reference_value)}
				status = "PASS" if _matches_goal(float(measured), relative_definition) else "FAIL"
				reason = "%s（基準 %s=%s）" % [reason, reference_id, str(reference_value)]
			else:
				status = "NOT_EVALUATED"
		else:
			status = "NOT_EVALUATED"
	else:
		if measured == null:
			status = "FAIL"
		elif measured is bool:
			status = "PASS" if bool(measured) == bool(check.get("target", false)) else "FAIL"
		elif is_finite(float(measured)):
			status = "PASS" if _matches_goal(float(measured), check) else "FAIL"
		else:
			status = "FAIL"
	check["measured"] = measured
	check["status"] = status
	check["passed"] = status == "PASS"
	check["reason"] = reason
	check["message"] = reason
	checks.append(check)


static func _matches_goal(measured: float, definition: Dictionary) -> bool:
	var operator := str(definition.get("operator", "between"))
	var target := float(definition.get("target", 0.0))
	match operator:
		"eq":
			return is_equal_approx(measured, target)
		"lt":
			return measured < target
		"lte":
			return measured <= target
		"gt":
			return measured > target
		"gte":
			return measured >= target
		"between":
			return measured >= float(definition.get("min", -INF)) and measured <= float(definition.get("max", INF))
	return false


## シミュレーション結果の時系列と最終状態を、画面実行と同じ制約で検証する。
## 戦略や物理式をここで再計算せず、Runner が返した観測値だけを検証する。
static func validate_result(result: Dictionary, scenario: Dictionary = {}) -> PackedStringArray:
	var errors := PackedStringArray()
	var runner_values: Variant = result.get("runners", [])
	var samples_values: Variant = result.get("samples", [])
	if not runner_values is Array or runner_values.size() != LocalRaceMath.FIELD_SIZE:
		errors.append("runners は %d 頭必要です" % LocalRaceMath.FIELD_SIZE)
		return errors
	if not samples_values is Array or samples_values.is_empty():
		errors.append("時系列 samples が空です")
	var timed_out := bool(result.get("timed_out", true))
	var finished_count := int(result.get("finished_count", -1))
	if timed_out:
		errors.append("タイムアウトしています")
	if finished_count != LocalRaceMath.FIELD_SIZE:
		errors.append("完走数が不正です: %d" % finished_count)

	var expected_ids: Array[String] = []
	var final_by_id := {}
	for value: Variant in runner_values:
		if not value is Dictionary:
			errors.append("最終 runner の形式が不正です")
			continue
		var runner: Dictionary = value
		var identifier := str(runner.get("id", ""))
		if identifier.is_empty() or identifier in expected_ids:
			errors.append("runner ID が空または重複しています: %s" % identifier)
		else:
			expected_ids.append(identifier)
			final_by_id[identifier] = runner
		_validate_runner_state(runner, "最終 %s" % identifier, errors)

	if final_by_id.size() == LocalRaceMath.FIELD_SIZE:
		var ranks: Array[int] = []
		var finish_orders: Array[int] = []
		for identifier: String in expected_ids:
			var runner: Dictionary = final_by_id[identifier]
			if not bool(runner.get("finished", false)):
				errors.append("%s が未完走です" % identifier)
			var rank := int(runner.get("rank", 0))
			var finish_order := int(runner.get("finish_order", 0))
			ranks.append(rank)
			finish_orders.append(finish_order)
			if rank != finish_order:
				errors.append("%s の順位%dと完走順%dが不一致です" % [identifier, rank, finish_order])
		if not _is_complete_permutation(ranks, LocalRaceMath.FIELD_SIZE):
			errors.append("最終順位が1〜%dの重複なしになっていません" % LocalRaceMath.FIELD_SIZE)
		if not _is_complete_permutation(finish_orders, LocalRaceMath.FIELD_SIZE):
			errors.append("完走順が1〜%dの重複なしになっていません" % LocalRaceMath.FIELD_SIZE)

	var previous_distances := {}
	for sample_index: int in samples_values.size():
		var sample_value: Variant = samples_values[sample_index]
		if not sample_value is Array:
			errors.append("sample[%d] の形式が不正です" % sample_index)
			continue
		var seen_ids := {}
		for value: Variant in sample_value:
			if not value is Dictionary:
				errors.append("sample[%d] の runner 形式が不正です" % sample_index)
				continue
			var runner: Dictionary = value
			var identifier := str(runner.get("id", ""))
			seen_ids[identifier] = true
			_validate_runner_state(runner, "sample[%d] %s" % [sample_index, identifier], errors)
			var distance := float(runner.get("race_progress_m", runner.get("distance_m", -1.0)))
			if previous_distances.has(identifier) and distance + 0.0001 < float(previous_distances[identifier]):
				errors.append("%s の距離が減少しています" % identifier)
			previous_distances[identifier] = distance
		if seen_ids.size() != LocalRaceMath.FIELD_SIZE:
			errors.append("sample[%d] の runner 数が%dです" % [sample_index, seen_ids.size()])
	return errors


static func _validate_runner_state(runner: Dictionary, label: String, errors: PackedStringArray) -> void:
	var speed := float(runner.get("speed_kmh", runner.get("speed", NAN)))
	if not is_finite(speed) or speed < LocalRaceMath.MIN_SPEED_KMH or speed > LocalRaceMath.HARD_SPEED_CAP_KMH + 0.001:
		errors.append("%s の速度が範囲外です: %f" % [label, speed])
	var target_speed := float(runner.get("target_speed_kmh", NAN))
	if not is_finite(target_speed) or target_speed < 0.0 or target_speed > LocalRaceMath.HARD_SPEED_CAP_KMH + 0.001:
		errors.append("%s の目標速度が範囲外です: %f" % [label, target_speed])
	for key: String in ["natural_top_speed_kmh", "acceleration_force_bonus_kmh_per_s", "top_speed_drive_adjustment_kmh_per_s"]:
		if not is_finite(float(runner.get(key, NAN))):
			errors.append("%s の%sが不正です" % [label, key])
	var distance := float(runner.get("race_progress_m", runner.get("progress", NAN)))
	if not is_finite(distance) or distance < 0.0:
		errors.append("%s の距離が不正です: %f" % [label, distance])
	var heart_rate := float(runner.get("heart_rate_bpm", NAN))
	var heart_min := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var heart_max := LocalRaceMath.Config.number("heart_rate_overheat_max_bpm")
	if not is_finite(heart_rate) or heart_rate < heart_min - 0.001 or heart_rate > heart_max + 0.001:
		errors.append("%s の心拍が範囲外です: %f" % [label, heart_rate])
	var stamina := float(runner.get("stamina", NAN))
	var stamina_min := -LocalRaceMath.Config.number("stamina_debt_limit")
	var stamina_max := LocalRaceMath.Config.number("stamina_capacity")
	if not is_finite(stamina) or stamina < stamina_min - 0.001 or stamina > stamina_max + 0.001:
		errors.append("%s のスタミナが範囲外です: %f" % [label, stamina])
	var drive_level := float(runner.get("drive_level", NAN))
	if not is_finite(drive_level) or drive_level < LocalRaceMath.DRIVE_LEVEL_MIN - 0.001 or drive_level > LocalRaceMath.DRIVE_LEVEL_MAX + 0.001:
		errors.append("%s のノッチが範囲外です: %f" % [label, drive_level])
	var draft_value: Variant = runner.get("draft_status", runner.get("draft", {}))
	if not draft_value is Dictionary:
		errors.append("%s のドラフト状態が不正です" % label)
	else:
		var draft: Dictionary = draft_value
		for key: String in ["own_wake_p", "direct_draft_p", "chain_draft_p", "received_draft_p", "effective_draft_ratio"]:
			var ratio := float(draft.get(key, NAN))
			if not is_finite(ratio) or ratio < -0.001 or ratio > 1.001:
				errors.append("%s のドラフト率%sが範囲外です: %f" % [label, key, ratio])
		var bonus := float(draft.get("draft_speed_bonus_kmh", NAN))
		if not is_finite(bonus):
			errors.append("%s のドラフト速度補正が不正です" % label)
		var source_details: Variant = draft.get("direct_source_details", [])
		if not source_details is Array:
			errors.append("%s のドラフト対象詳細が不正です" % label)
		else:
			for detail_value: Variant in source_details:
				if not detail_value is Dictionary:
					errors.append("%s のドラフト対象詳細の形式が不正です" % label)
					continue
				var contribution := float(detail_value.get("contribution_p", NAN))
				if not is_finite(contribution) or contribution < -0.001 or contribution > 1.001:
					errors.append("%s のドラフト対象寄与率が範囲外です: %f" % [label, contribution])
	for key: String in ["overheat_ratio", "propulsion_efficiency"]:
		var ratio := float(runner.get(key, NAN))
		if not is_finite(ratio) or ratio < -0.001 or ratio > 1.001:
			errors.append("%s の%sが範囲外です: %f" % [label, key, ratio])
	var diagnostics_value: Variant = runner.get("drive_diagnostics", {})
	if not diagnostics_value is Dictionary:
		errors.append("%s の速度診断が不正です" % label)
	else:
		for key: String in ["drive_contribution_kmh_per_s", "rolling_resistance_kmh_per_s", "air_resistance_kmh_per_s", "draft_air_reduction_kmh_per_s", "total_acceleration_kmh_per_s"]:
			if not is_finite(float(diagnostics_value.get(key, NAN))):
				errors.append("%s の速度診断%sが不正です" % [label, key])
	var world_position: Variant = runner.get("world_position", [])
	var rotation: Variant = runner.get("rotation", [])
	if not world_position is Array or world_position.size() != 3 or not rotation is Array or rotation.size() != 3:
		errors.append("%s のワールド座標または向きが不正です" % label)
	else:
		for component: Variant in world_position:
			if not is_finite(float(component)):
				errors.append("%s のワールド座標に非有限値があります" % label)
		for component: Variant in rotation:
			if not is_finite(float(component)):
				errors.append("%s の向きに非有限値があります" % label)
	var effective_stats: Variant = runner.get("effective_stats", {})
	if not effective_stats is Dictionary:
		errors.append("%s の有効ステータスが不正です" % label)
	else:
		for stat_name: String in effective_stats:
			if not is_finite(float(effective_stats[stat_name])):
				errors.append("%s の有効ステータス%sが不正です" % [label, stat_name])


static func _is_complete_permutation(values: Array[int], count: int) -> bool:
	if values.size() != count:
		return false
	var expected := {}
	for value in values:
		if value < 1 or value > count or expected.has(value):
			return false
		expected[value] = true
	return expected.size() == count


func _config_number(key: String, fallback: float) -> float:
	var loaded := load_config()
	if loaded.has("error"):
		return fallback
	return float(loaded.data.get(key, fallback))


func _set_player_drive(runners: Array, schedule: Array, elapsed: float) -> void:
	if runners.is_empty():
		return
	var level := 0.0
	for entry: Variant in schedule:
		if entry is Dictionary and elapsed + 0.0001 >= float(entry.get("start_s", 0.0)):
			level = float(entry.get("drive_level", 0.0))
		runners[0].call("set_drive_level", level)


func _all_finished(runners: Array) -> bool:
	return not runners.is_empty() and _finished_count(runners) == runners.size()


func _finished_count(runners: Array) -> int:
	var count := 0
	for runner in runners:
		if runner.call("is_finished"):
			count += 1
	return count


func _snapshot_runners(runners: Array, elapsed: float) -> Array:
	var values: Array = []
	for runner in runners:
		# 実レースのテレメトリと同じ経路を使う。CPU は内部の
		# _cpu_trainer_drive_level で走るため、プレイヤー入力用の
		# get_drive_level() をここで読むと、診断値とノッチが食い違う。
		var snapshot: Dictionary = runner.call("get_telemetry_snapshot")
		var finished := bool(runner.call("is_finished"))
		snapshot["time_s"] = runner.call("get_finish_time") if finished else elapsed
		snapshot["finish_time_s"] = runner.call("get_finish_time")
		snapshot["distance_m"] = float(runner.call("get_distance"))
		snapshot["path_distance_m"] = float(runner.call("get_distance"))
		snapshot["race_progress_m"] = float(runner.call("get_race_progress"))
		snapshot["speed_kmh"] = float(runner.call("get_current_speed"))
		snapshot["target_speed_kmh"] = float(runner.call("get_target_speed"))
		snapshot["heart_rate_bpm"] = float(runner.call("get_heart_rate_bpm"))
		snapshot["stamina"] = float(runner.call("get_stamina"))
		snapshot["drive_mode"] = bool(runner.call("is_drive_mode"))
		snapshot["race_active"] = bool(runner.call("is_race_active"))
		snapshot["natural_top_speed_kmh"] = float(runner.call("get_natural_top_speed"))
		snapshot["overheat_ratio"] = float(runner.call("get_overheat_ratio"))
		snapshot["propulsion_efficiency"] = float(runner.call("get_propulsion_efficiency"))
		snapshot["effective_stats"] = runner.call("get_effective_stats")
		snapshot["acceleration_force_bonus_kmh_per_s"] = float(runner.call("get_acceleration_force_bonus"))
		snapshot["top_speed_drive_adjustment_kmh_per_s"] = float(runner.call("get_top_speed_drive_adjustment"))
		snapshot["drive_diagnostics"] = runner.call("get_drive_diagnostics")
		snapshot["draft_status"] = runner.call("get_draft_status")
		snapshot["draft"] = snapshot["draft_status"]
		var world_position: Vector3 = runner.global_position
		var rotation: Vector3 = runner.global_rotation
		snapshot["world_position"] = _vector3_to_array(world_position)
		snapshot["rotation"] = _vector3_to_array(rotation)
		snapshot["rank"] = _rank_for(runner, runners)
		values.append(snapshot)
	return values


static func _vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _rank_for(runner: Node, runners: Array) -> int:
	var better := 0
	for other in runners:
		if other == runner:
			continue
		if runner.call("is_finished"):
			if other.call("is_finished") and int(other.call("get_finish_order")) < int(runner.call("get_finish_order")):
				better += 1
			elif not other.call("is_finished"):
				better += 1
		elif other.call("is_finished") or float(other.call("get_race_progress")) > float(runner.call("get_race_progress")) + 0.001:
			better += 1
	return better + 1
