extends Node3D
## ローカル簡易レース用ランナー。目標スピード追従・出力操作・左右・前方ブロック対応。
## 速度は km/h（検討事項 #24）。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const CpuTrainerMath := preload("res://scripts/cpu_trainer_math.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")

@export var path_path: NodePath = ^"../TrackPath"
@export var max_speed_kmh: float = 58.0
@export var steer_speed: float = 4.0
@export var player_controlled: bool = false
@export var display_name: String = "ぷるりん"
@export var gate_index: int = 0


var _path: Path3D
var _pururin: Dictionary = {}
var _base_max_speed_kmh: float = 58.0
var _effective_stats: Dictionary = {}
var _natural_top_speed_kmh: float = 58.0
var _distance: float = 0.0
var _offset: float = 0.0
var _target_offset: float = 0.0
var _current_speed_kmh: float = 0.0
var _drive_level: float = 0.0
var _drive_hold_direction: float = 0.0
var _drive_repeat_remaining: float = 0.0
var _drafting: bool = false
var _own_wake_p: float = 0.0
var _direct_draft_p: float = 0.0
var _chain_draft_p: float = 0.0
var _received_draft_p: float = 0.0
var _direct_source_ids: Array = []
var _chain_source_ids: Array = []
var _direct_source_details: Array = []
var _heart_rate_bpm: float = LocalRaceMath.Config.number("heart_rate_min_bpm")
var _heart_overage_exposure: float = 0.0
var _stamina: float = 0.0
var _stamina_capacity_l: float = 0.0
var _stamina_load_multiplier: float = 1.0
var _race_progress: float = 0.0
var _tick_start_progress: float = 0.0
var _last_tick_delta: float = 0.0
var _race_distance_m: float = RaceSession.DEFAULT_DISTANCE_M
var _race_route: Dictionary = {}
var _finished: bool = false
var _finish_order: int = -1
var _finish_time: float = -1.0
var _straight_len: float = 0.0
var _turn_radius: float = 0.0
var _cpu_steer_timer: float = 0.0
var _cpu_trainer_timer: float = 0.0
var _cpu_trainer_profile: Dictionary = {}
var _cpu_trainer_drive_level: float = 0.0
var _cpu_line_move_speed_m_per_s: float = 0.0
var _drive_diagnostic_log_remaining: float = 0.0
var _paused: bool = false
var _race_active: bool = false
var _cpu_start_drive_remaining: float = 0.0
## 比較測定専用。通常レースからは設定せず、自然最高速の旧ハード上限を再現する。
var _simulation_legacy_speed_cap: bool = false
## コントローラが毎フレーム渡す他頭情報。
var _others_snapshot: Array = []


func setup_for_race(
	path: Path3D,
	gate: int,
	initial_max_speed_kmh: float,
	is_player: bool,
	label: String,
	pururin: Dictionary = {},
	race_distance_m: float = RaceSession.DEFAULT_DISTANCE_M
) -> void:
	_path = path
	gate_index = gate
	_base_max_speed_kmh = initial_max_speed_kmh
	max_speed_kmh = initial_max_speed_kmh
	_pururin = pururin.duplicate(true)
	# ランナー生成は画面の距離選択を書き換えない。
	_race_distance_m = RaceSession.normalize_distance(race_distance_m)
	_race_route = M5CourseBuilder.route_for_distance(
		LocalRaceMath.course_layout(), _race_distance_m
	)
	player_controlled = is_player
	display_name = label
	_offset = LocalRaceMath.starting_offset_for_gate(gate)
	_target_offset = _offset
	_distance = LocalRaceMath.start_path_for_distance_m(_race_distance_m)
	_race_progress = 0.0
	_tick_start_progress = 0.0
	_last_tick_delta = 0.0
	_finished = false
	_finish_order = -1
	_finish_time = -1.0
	# カウントダウン中は全員停止し、開始と同時に選択済みの出力で発進する。
	_current_speed_kmh = LocalRaceMath.MIN_SPEED_KMH
	_drive_level = 0.0
	_drive_hold_direction = 0.0
	_drive_repeat_remaining = 0.0
	_cpu_steer_timer = 0.0
	_cpu_trainer_timer = 0.0
	if not is_player:
		# roster 検証で全個体に定義済み trainer_profile_id があることを保証している。
		_cpu_trainer_profile = LocalRaceMath.cpu_trainer_profile_by_id(
			str(_pururin.get("trainer_profile_id", ""))
		)
	else:
		_cpu_trainer_profile = {}
	_cpu_trainer_drive_level = 0.0
	_cpu_line_move_speed_m_per_s = LocalRaceMath.Config.number("cpu_steer_speed_m_per_s")
	_drive_diagnostic_log_remaining = 0.0
	_race_active = false
	_cpu_start_drive_remaining = 0.0
	_drafting = false
	_clear_draft_details()
	_heart_rate_bpm = LocalRaceMath.Config.number("heart_rate_min_bpm")
	_heart_overage_exposure = 0.0
	_straight_len = LocalRaceMath.straight_length_m()
	_turn_radius = LocalRaceMath.turn_radius_m()
	if _path != null:
		if _path.has_method("get_straight_len"):
			_straight_len = _path.get_straight_len()
		if _path.has_method("get_turn_radius"):
			_turn_radius = _path.get_turn_radius()
	_apply_pururin_race_stats()
	_reset_stamina_for_effective_stats()
	_apply_pose()


func set_paused(paused: bool) -> void:
	_paused = paused


func set_race_active(active: bool) -> void:
	if _race_active == active:
		return
	_race_active = active
	if _race_active and not player_controlled:
		_cpu_start_drive_remaining = LocalRaceMath.Config.number("cpu_start_drive_duration_seconds")


func is_race_active() -> bool:
	return _race_active


func set_others_snapshot(others: Array) -> void:
	_others_snapshot = others


## ヘッドレス検証だけが、生成済みプレイヤーの配分を一時的に差し替えるための入口。
## 通常のローカルレースやCPUランナーの設定は変更しない。
func apply_simulation_player_override(override: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not player_controlled:
		errors.append("プレイヤーランナーではありません")
		return errors
	var next_pururin := _pururin.duplicate(true)
	for key: String in ["attribute", "running_style"]:
		if override.has(key):
			next_pururin[key] = override[key]
	if override.has("allocation"):
		next_pururin["allocation"] = override["allocation"]
	if not next_pururin.has("attribute") or not next_pururin.has("running_style") or not next_pururin.has("allocation"):
		errors.append("player_override は attribute / running_style / allocation を確認してください")
		return errors
	errors.append_array(PururinStatsMath.validate_allocation(next_pururin["allocation"]))
	if not errors.is_empty():
		return errors
	_pururin = next_pururin
	_apply_pururin_race_stats()
	_reset_stamina_for_effective_stats()
	return errors


func get_offset() -> float:
	return _offset


func get_distance() -> float:
	return _distance


func get_current_speed() -> float:
	return _current_speed_kmh


func get_drive_level() -> float:
	return _drive_level


func is_drafting() -> bool:
	return _drafting


func get_draft_status() -> Dictionary:
	# HUD は生の受取率と、走行に使う応答曲線後の実効率を並べて示す。
	# 計算式は LocalRaceMath にだけ置き、表示側で再計算しない。
	return {
		"own_wake_p": _own_wake_p,
		"direct_draft_p": _direct_draft_p,
		"chain_draft_p": _chain_draft_p,
		"received_draft_p": _received_draft_p,
		"effective_draft_ratio": LocalRaceMath.draft_effective_ratio(_received_draft_p, _effective_pack_stat()),
		"pack_draft_effective_multiplier": LocalRaceMath.pack_draft_effective_multiplier(_effective_pack_stat()),
		"draft_speed_bonus_kmh": LocalRaceMath.draft_assist_speed_kmh(_received_draft_p, _effective_pack_stat()),
		"direct_source_ids": _direct_source_ids.duplicate(),
		"chain_source_ids": _chain_source_ids.duplicate(),
		"draft_source_ids": _direct_source_ids.duplicate(),
		"primary_source_id": str(_direct_source_ids[0]) if not _direct_source_ids.is_empty() else "",
		"primary_gap_m": float(_direct_source_details[0].get("gap", 0.0)) if not _direct_source_details.is_empty() else 0.0,
		"primary_line_gap_m": float(_direct_source_details[0].get("line", 0.0)) if not _direct_source_details.is_empty() else 0.0,
		"direct_source_details": _direct_source_details.duplicate(true),
	}


func get_drive_diagnostics() -> Dictionary:
	var active_drive_level := _active_drive_level()
	return LocalRaceMath.drive_diagnostics_kmh_per_s(
		_current_speed_kmh,
		active_drive_level,
		_draft_air_resistance_factor(),
		get_acceleration_force_bonus(),
		get_top_speed_drive_adjustment(),
		get_propulsion_efficiency(),
		_aero_air_resistance_multiplier(),
		get_acceleration_response_multiplier()
	)


func apply_draft_details(details: Dictionary) -> void:
	"""コントローラが移動後に一括確定したドラフト値を次tickへ渡す。"""
	_own_wake_p = float(details.get("own_wake_p", 0.0))
	_direct_draft_p = float(details.get("direct_draft_p", 0.0))
	_chain_draft_p = float(details.get("chain_draft_p", 0.0))
	_received_draft_p = float(details.get("received_draft_p", 0.0))
	_direct_source_ids = details.get("direct_source_ids", []).duplicate()
	_chain_source_ids = details.get("chain_source_ids", []).duplicate()
	_direct_source_details = details.get("direct_source_details", []).duplicate(true)
	_drafting = _received_draft_p > 0.0


func set_drive_level(level: float) -> void:
	_drive_level = LocalRaceMath.clamp_drive_level(level)


func get_heart_rate_bpm() -> float:
	return _heart_rate_bpm


func get_stamina() -> float:
	return _stamina


func get_stamina_capacity_l() -> float:
	return _stamina_capacity_l


func get_stamina_ratio() -> float:
	return clampf(_stamina / maxf(_stamina_capacity_l, 0.001), -1.0, 1.0)


func get_stamina_load_multiplier() -> float:
	return _stamina_load_multiplier


func get_overheat_ratio() -> float:
	return LocalRaceMath.overheat_ratio(_heart_rate_bpm)


func get_heart_overage_exposure() -> float:
	return _heart_overage_exposure


func get_overheat_propulsion_efficiency() -> float:
	return LocalRaceMath.overheat_exposure_propulsion_efficiency(_heart_overage_exposure)


func get_propulsion_efficiency() -> float:
	return get_overheat_propulsion_efficiency() * LocalRaceMath.stamina_debt_efficiency(
		_stamina,
		_stamina_capacity_l
	)


func get_race_progress() -> float:
	return _race_progress


func get_race_distance() -> float:
	return _race_distance_m


func get_max_speed() -> float:
	return max_speed_kmh


func get_effective_stats() -> Dictionary:
	return _effective_stats.duplicate()


func get_acceleration_force_bonus() -> float:
	return LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(int(_effective_stats.get("acceleration", 5)))


func get_acceleration_response_multiplier() -> float:
	return LocalRaceMath.stat_acceleration_response_multiplier(int(_effective_stats.get("acceleration", 5)))


func set_simulation_legacy_speed_cap(enabled: bool) -> void:
	_simulation_legacy_speed_cap = enabled


func get_natural_top_speed() -> float:
	return _natural_top_speed_kmh


func get_top_speed_drive_adjustment() -> float:
	return LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(
		_current_speed_kmh,
		_active_drive_level(),
		int(_effective_stats.get("top_speed", 5)),
		_draft_air_resistance_factor(),
		_aero_air_resistance_multiplier()
	)


func is_finished() -> bool:
	return _finished


func get_finish_order() -> int:
	return _finish_order


func get_finish_time() -> float:
	return _finish_time


## 直前tickでゴール線を越えた時点が、tick終了の何秒前かを返す。
## 同一tick内の複数到達を、配列順ではなく通過時刻で並べるために使う（M5サーバーと同じ補間）。
func get_finish_crossing_lead_s(race_distance_m: float) -> float:
	var progress_delta := _race_progress - _tick_start_progress
	if progress_delta <= 0.0 or _last_tick_delta <= 0.0:
		return 0.0
	var fraction := clampf((race_distance_m - _tick_start_progress) / progress_delta, 0.0, 1.0)
	return (1.0 - fraction) * _last_tick_delta


func mark_finished(order: int, finish_time: float) -> void:
	_finished = true
	_finish_order = order
	_finish_time = finish_time


func get_snapshot() -> Dictionary:
	return {
		"id": str(_pururin.get("id", "runner-%d" % (gate_index + 1))),
		"distance": _distance,
		"offset": _offset,
		"speed": _current_speed_kmh,
		"progress": _race_progress,
		"race_progress": _race_progress,
		"own_wake_p": _own_wake_p,
		"direct_draft_p": _direct_draft_p,
		"chain_draft_p": _chain_draft_p,
		"received_draft_p": _received_draft_p,
		"direct_source_ids": _direct_source_ids.duplicate(),
		"chain_source_ids": _chain_source_ids.duplicate(),
		"name": display_name,
		"player": player_controlled,
		"finished": _finished,
		"finish_order": _finish_order,
		"gate": gate_index,
	}


func get_telemetry_snapshot() -> Dictionary:
	var snapshot := get_snapshot()
	snapshot["drive_level"] = _active_drive_level()
	snapshot["heart_rate_bpm"] = _heart_rate_bpm
	snapshot["heart_overage_exposure"] = _heart_overage_exposure
	snapshot["stamina"] = _stamina
	snapshot["stamina_capacity_l"] = _stamina_capacity_l
	snapshot["stamina_ratio"] = get_stamina_ratio()
	snapshot["stamina_load_multiplier"] = _stamina_load_multiplier
	snapshot["overheat_ratio"] = get_overheat_ratio()
	snapshot["overheat_propulsion_efficiency"] = get_overheat_propulsion_efficiency()
	snapshot["propulsion_efficiency"] = get_propulsion_efficiency()
	snapshot["natural_top_speed_kmh"] = _natural_top_speed_kmh
	snapshot["effective_stats"] = _effective_stats.duplicate(true)
	snapshot["draft"] = get_draft_status()
	snapshot["drive_diagnostics"] = get_drive_diagnostics()
	snapshot["position"] = [global_position.x, global_position.y, global_position.z]
	snapshot["rotation_y"] = rotation.y
	return snapshot


func _active_drive_level() -> float:
	if player_controlled:
		return _drive_level
	if _cpu_start_drive_remaining > 0.0:
		return LocalRaceMath.Config.number("cpu_start_drive_level")
	return LocalRaceMath.cpu_heart_safe_drive_level(
		_cpu_trainer_drive_level,
		_heart_rate_bpm,
		int(_effective_stats.get("cardio", 5))
	)


func _ready() -> void:
	if _path == null:
		_path = get_node_or_null(path_path) as Path3D
	if _path == null or _path.curve == null:
		# コントローラが setup_for_race するまで待つ。
		return
	_apply_pose()


func _process(delta: float) -> void:
	if _paused:
		return
	if _path == null or _path.curve == null:
		return
	if not _race_active:
		# 開始前も出力だけは選べる。位置・速度・状態値は動かさない。
		if player_controlled:
			_update_drive_level_input(delta)
		return
	_apply_pururin_race_stats()
	_tick_start_progress = _race_progress
	_last_tick_delta = delta
	var previous_offset := _offset
	var route_pose := M5CourseBuilder.route_pose(
		_path.curve, _race_route, _race_progress, LocalRaceMath.lap_length_m()
	)
	var pose_distance := float(route_pose.get("mainline_distance", _distance))
	var curvature := 0.0 if bool(route_pose.get("is_straight", false)) else M2TrackMath.curvature_at(_path.curve, pose_distance)
	_update_inputs(delta, curvature)
	if not LocalRaceMath.can_use_offset(_race_progress, _offset, _others_snapshot):
		_offset = previous_offset
	var path_len := _path.curve.get_baked_length()
	if player_controlled:
		_update_drive_level_input(delta)
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			_drive_level,
			max_speed_kmh,
			delta,
			_draft_air_resistance_factor(),
			get_acceleration_force_bonus(),
			get_top_speed_drive_adjustment(),
			get_propulsion_efficiency(),
			_aero_air_resistance_multiplier(),
			get_acceleration_response_multiplier(),
			_simulation_legacy_speed_cap
		)
		_update_condition(delta)
		_update_drive_diagnostic_log(delta)
	elif _cpu_start_drive_remaining > 0.0:
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			LocalRaceMath.Config.number("cpu_start_drive_level"),
			max_speed_kmh,
			delta,
			_draft_air_resistance_factor(),
			get_acceleration_force_bonus(),
			get_top_speed_drive_adjustment(),
			get_propulsion_efficiency(),
			_aero_air_resistance_multiplier(),
			get_acceleration_response_multiplier(),
			_simulation_legacy_speed_cap
		)
		_cpu_start_drive_remaining = maxf(_cpu_start_drive_remaining - delta, 0.0)
		_update_condition_for_drive_level(LocalRaceMath.Config.number("cpu_start_drive_level"), delta)
	else:
		var cpu_drive_level := _active_drive_level()
		# 前走者に接触しても推進を0へ戻さない。進捗は allowed_race_progress が
		# 前走者の手前で止めるため、現在位置を維持したままラインの空きを待つ。
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			cpu_drive_level,
			max_speed_kmh,
			delta,
			_draft_air_resistance_factor(),
			get_acceleration_force_bonus(),
			get_top_speed_drive_adjustment(),
			get_propulsion_efficiency(),
			_aero_air_resistance_multiplier(),
			get_acceleration_response_multiplier(),
			_simulation_legacy_speed_cap
		)
		_update_condition_for_drive_level(cpu_drive_level, delta)
	var d_center := LocalRaceMath.centerline_delta_from_kmh(
		_current_speed_kmh, delta, _offset, curvature
	)
	var proposed_progress := LocalRaceMath.add_race_progress(_race_progress, d_center)
	var allowed_progress := LocalRaceMath.allowed_race_progress(
		_race_progress, proposed_progress, _offset, _others_snapshot
	)
	_race_progress = allowed_progress
	var next_pose := M5CourseBuilder.route_pose(
		_path.curve, _race_route, _race_progress, LocalRaceMath.lap_length_m()
	)
	_distance = fposmod(float(next_pose.get("mainline_distance", _distance)), path_len)
	_apply_pose()


func _clear_draft_details() -> void:
	_own_wake_p = 0.0
	_direct_draft_p = 0.0
	_chain_draft_p = 0.0
	_received_draft_p = 0.0
	_direct_source_ids = []
	_chain_source_ids = []
	_direct_source_details = []


func _update_inputs(delta: float, curvature: float = 0.0) -> void:
	if player_controlled:
		var steer := _read_steer_axis()
		_offset = M2TrackMath.clamp_offset(_offset + steer * steer_speed * delta)
	else:
		_cpu_steer_timer -= delta
		if _cpu_steer_timer <= 0.0:
			_cpu_steer_timer = LocalRaceMath.cpu_steer_reselect_interval_s(randf())
			var line_pref := clampf(float(_cpu_trainer_profile.get("line_pref", 0.5)), 0.0, 1.0)
			var follow_candidate := LocalRaceMath.cpu_follow_candidate(
				_race_progress, _offset, _others_snapshot
			)
			if bool(follow_candidate.get("found", false)):
				var follow_slot := LocalRaceMath.cpu_follow_slot(
					_race_progress, _offset, follow_candidate, _others_snapshot, 0.0, curvature, line_pref
				)
				if bool(follow_slot.get("hold_current", false)):
					_target_offset = _offset
					_cpu_line_move_speed_m_per_s = LocalRaceMath.Config.number("cpu_steer_speed_m_per_s")
				else:
					var escape_slot := bool(follow_slot.get("escape", false))
					_target_offset = LocalRaceMath.cpu_follow_target_offset_m(
						_target_offset,
						float(follow_slot["offset"]),
						1.0 if escape_slot else -1.0
					)
					_cpu_line_move_speed_m_per_s = LocalRaceMath.cpu_line_move_speed_m_per_s(follow_slot)
			else:
				var open_line := LocalRaceMath.cpu_open_line_target_offset_m(
					_race_progress,
					_offset,
					_others_snapshot,
					line_pref,
					0.0,
					curvature
				)
				_target_offset = LocalRaceMath.cpu_follow_target_offset_m(
					_target_offset,
					float(open_line["offset"]),
					1.0
				)
				_cpu_line_move_speed_m_per_s = LocalRaceMath.Config.number("cpu_steer_speed_m_per_s")
			# ライン選択と速度方針は独立。速度はトレーナーが定期的に決める。
		_offset = move_toward(_offset, _target_offset, _cpu_line_move_speed_m_per_s * delta)
		_offset = M2TrackMath.clamp_offset(_offset)
		_cpu_trainer_timer -= delta
		if _cpu_trainer_timer <= 0.0:
			_cpu_trainer_timer = LocalRaceMath.Config.number("cpu_trainer_reselect_seconds")
			_update_cpu_drive_level()


func _update_cpu_drive_level() -> void:
	var settings := LocalRaceMath.cpu_trainer_settings()
	var decision := CpuTrainerMath.decide({"heart_rate_bpm": _heart_rate_bpm}, settings)
	_cpu_trainer_drive_level = LocalRaceMath.cpu_heart_safe_drive_level(
		float(decision["drive_level"]),
		_heart_rate_bpm,
		int(_effective_stats.get("cardio", 5))
	)


func _cpu_live_place() -> int:
	var better := 0
	for other_value in _others_snapshot:
		if other_value is Dictionary and float(other_value.get("race_progress", 0.0)) > _race_progress + 0.001:
			better += 1
	return better + 1


func _apply_pururin_race_stats() -> void:
	if _pururin.is_empty():
		_effective_stats = {}
		max_speed_kmh = _base_max_speed_kmh
		_natural_top_speed_kmh = _base_max_speed_kmh
		return
	_effective_stats = PururinStatsMath.effective_stats(
		str(_pururin["attribute"]),
		_pururin["allocation"],
		str(_pururin["running_style"]),
		_cpu_live_place(),
		_race_progress / _race_distance_m
	)
	_natural_top_speed_kmh = LocalRaceMath.top_speed_natural_speed_kmh(int(_effective_stats["top_speed"]))
	max_speed_kmh = _natural_top_speed_kmh


func _draft_air_resistance_factor() -> float:
	return LocalRaceMath.draft_air_resistance_factor(_received_draft_p, _effective_pack_stat())


func _aero_air_resistance_multiplier() -> float:
	return LocalRaceMath.aero_air_resistance_multiplier(int(_effective_stats.get("aero", 5)))


func _effective_pack_stat() -> int:
	return int(_effective_stats.get("pack", 5))


func _update_drive_diagnostic_log(delta: float) -> void:
	_drive_diagnostic_log_remaining -= delta
	if _drive_diagnostic_log_remaining > 0.0:
		return
	_drive_diagnostic_log_remaining += 1.0
	var diagnostics := get_drive_diagnostics()
	var drive_contribution := float(diagnostics["drive_contribution_kmh_per_s"])
	var drive_label := "制動" if drive_contribution < 0.0 else "推進力"
	print(
		"出力診断（%s） %s %+.2fkm/h/s　転がり抵抗 %+.2fkm/h/s　空気抵抗（二乗） %+.2fkm/h/s　ドラフト軽減 %+.2fkm/h/s　計算加速度 %+.2fkm/h/s" % [
			display_name,
			drive_label,
			drive_contribution,
			-float(diagnostics["rolling_resistance_kmh_per_s"]),
			-float(diagnostics["air_resistance_kmh_per_s"]),
			float(diagnostics["draft_air_reduction_kmh_per_s"]),
			float(diagnostics["total_acceleration_kmh_per_s"]),
		]
	)


func _update_drive_level_input(delta: float) -> void:
	var direction := _read_drive_axis()
	if is_zero_approx(direction):
		_drive_hold_direction = 0.0
		_drive_repeat_remaining = 0.0
		return
	if not is_equal_approx(direction, _drive_hold_direction):
		_drive_hold_direction = direction
		_drive_repeat_remaining = LocalRaceMath.DRIVE_REPEAT_INITIAL_S
		_drive_level = LocalRaceMath.step_drive_level(_drive_level, direction)
		return
	_drive_repeat_remaining -= delta
	while _drive_repeat_remaining <= 0.0:
		_drive_level = LocalRaceMath.step_drive_level(_drive_level, direction)
		_drive_repeat_remaining += LocalRaceMath.DRIVE_REPEAT_INTERVAL_S


func _read_drive_axis() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_UP):
		v += 1.0
	if Input.is_physical_key_pressed(KEY_DOWN):
		v -= 1.0
	v += RaceControllerInput.notch_axis()
	return clampf(v, -1.0, 1.0)


func _update_condition(delta: float) -> void:
	_update_condition_for_drive_level(_drive_level, delta)


func _update_condition_for_drive_level(drive_level: float, delta: float) -> void:
	var cardio_stat := int(_effective_stats.get("cardio", 5))
	_heart_rate_bpm += LocalRaceMath.heart_rate_net_rate_bpm_per_s(_heart_rate_bpm, drive_level, cardio_stat) * delta
	_heart_rate_bpm = clampf(
			_heart_rate_bpm,
			LocalRaceMath.Config.number("heart_rate_min_bpm"),
			LocalRaceMath.Config.number("heart_rate_overheat_max_bpm")
	)
	_heart_overage_exposure = LocalRaceMath.update_overheat_exposure(
		_heart_overage_exposure,
		_heart_rate_bpm,
		delta
	)
	var stamina_delta := LocalRaceMath.stamina_delta_l_per_s(
		drive_level,
		_heart_rate_bpm,
		_stamina_load_multiplier
	)
	var debt_limit := LocalRaceMath.stamina_debt_limit_l(_stamina_capacity_l)
	_stamina = clampf(
		_stamina + stamina_delta * delta,
		-debt_limit,
		_stamina_capacity_l
	)


func _reset_stamina_for_effective_stats() -> void:
	# 容量はレース中に変えないため、順位・区間補正を含まない出走前値で決める。
	# 生成時は他頭情報が無く全員が1位扱いになり、脚質で容量がずれるのを防ぐ。
	var stamina_stat := int(_effective_stats.get("stamina", 5))
	if not _pururin.is_empty():
		stamina_stat = int(PururinStatsMath.pre_race_stats(
			str(_pururin["attribute"]), _pururin["allocation"]
		)["stamina"])
	_stamina_capacity_l = LocalRaceMath.stamina_capacity_l(stamina_stat)
	_stamina_load_multiplier = RaceSession.selected_stamina_load_multiplier()
	_stamina = _stamina_capacity_l


func _read_steer_axis() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v += 1.0
	v += RaceControllerInput.line_axis()
	return clampf(v, -1.0, 1.0)


func _apply_pose() -> void:
	if _path == null or _path.curve == null:
		return
	var route_pose := M5CourseBuilder.route_pose(
		_path.curve, _race_route, _race_progress, LocalRaceMath.lap_length_m()
	)
	if route_pose.is_empty():
		return
	var centerline_local: Vector3 = route_pose["position"]
	var outward: Vector3 = route_pose["outward"]
	var pos_local := centerline_local + outward * _offset
	var travel: Vector3 = route_pose["travel"]
	var basis := Basis.looking_at(travel, Vector3.UP)
	global_transform = _path.global_transform * Transform3D(basis, pos_local)
