extends Node3D
## ローカル簡易レース用ランナー。目標スピード追従・出力操作・左右・前方ブロック対応。
## 速度は km/h（検討事項 #24）。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
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
var _target_speed_kmh: float = 58.0
var _drive_mode: bool = false
var _drive_level: float = 0.0
var _drive_hold_direction: float = 0.0
var _drive_repeat_remaining: float = 0.0
var _drafting: bool = false
var _draft_bonus_kmh: float = 0.0
var _own_wake_p: float = 0.0
var _direct_draft_p: float = 0.0
var _chain_draft_p: float = 0.0
var _received_draft_p: float = 0.0
var _direct_source_ids: Array = []
var _chain_source_ids: Array = []
var _direct_source_details: Array = []
var _heart_rate_bpm: float = LocalRaceMath.Config.number("heart_rate_rest_bpm")
var _stamina: float = LocalRaceMath.Config.number("stamina_capacity")
var _race_progress: float = 0.0
var _finished: bool = false
var _finish_order: int = -1
var _finish_time: float = -1.0
var _straight_len: float = 0.0
var _turn_radius: float = 0.0
var _cpu_steer_timer: float = 0.0
var _cpu_trainer_timer: float = 0.0
var _cpu_trainer_profile: Dictionary = {}
var _cpu_trainer_drive_level: float = 0.0
var _drive_diagnostic_log_remaining: float = 0.0
var _paused: bool = false
var _race_active: bool = false
var _cpu_start_drive_remaining: float = 0.0
## コントローラが毎フレーム渡す他頭情報。
var _others_snapshot: Array = []


func setup_for_race(
	path: Path3D,
	gate: int,
	tier_speed_kmh: float,
	is_player: bool,
	label: String,
	pururin: Dictionary = {}
) -> void:
	_path = path
	gate_index = gate
	_base_max_speed_kmh = tier_speed_kmh
	max_speed_kmh = tier_speed_kmh
	_pururin = pururin.duplicate(true)
	player_controlled = is_player
	display_name = label
	_offset = LocalRaceMath.starting_offset_for_gate(gate)
	_target_offset = _offset
	_distance = LocalRaceMath.start_path_m()
	_race_progress = 0.0
	_finished = false
	_finish_order = -1
	_finish_time = -1.0
	# カウントダウン中は全員停止し、開始と同時に選択済みの出力で発進する。
	_current_speed_kmh = LocalRaceMath.MIN_SPEED_KMH
	_target_speed_kmh = tier_speed_kmh
	_drive_mode = is_player
	_drive_level = 0.0
	_drive_hold_direction = 0.0
	_drive_repeat_remaining = 0.0
	_cpu_steer_timer = 0.0
	_cpu_trainer_timer = 0.0
	_cpu_trainer_profile = LocalRaceMath.cpu_trainer_profile(gate) if not is_player else {}
	_cpu_trainer_drive_level = 0.0
	_drive_diagnostic_log_remaining = 0.0
	_race_active = false
	_cpu_start_drive_remaining = 0.0
	_drafting = false
	_draft_bonus_kmh = 0.0
	_clear_draft_details()
	_heart_rate_bpm = LocalRaceMath.Config.number("heart_rate_rest_bpm")
	_stamina = LocalRaceMath.Config.number("stamina_capacity")
	_straight_len = LocalRaceMath.straight_length_m()
	_turn_radius = LocalRaceMath.turn_radius_m()
	if _path != null:
		if _path.has_method("get_straight_len"):
			_straight_len = _path.get_straight_len()
		if _path.has_method("get_turn_radius"):
			_turn_radius = _path.get_turn_radius()
	_apply_pururin_race_stats()
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


func get_offset() -> float:
	return _offset


func get_distance() -> float:
	return _distance


func get_current_speed() -> float:
	return _current_speed_kmh


func get_target_speed() -> float:
	return _target_speed_kmh


func set_drive_mode(enabled: bool) -> void:
	if not player_controlled:
		return
	_drive_mode = enabled
	_drive_hold_direction = 0.0
	_drive_repeat_remaining = 0.0
	if not _drive_mode:
		# 方式を切り替えても現在速度は維持し、目標速度方式の追従先だけ同期する。
		_target_speed_kmh = LocalRaceMath.clamp_target_speed_kmh(_current_speed_kmh, _natural_top_speed_kmh)


func toggle_drive_mode() -> bool:
	set_drive_mode(not _drive_mode)
	return _drive_mode


func is_drive_mode() -> bool:
	return _drive_mode


func get_drive_level() -> float:
	return _drive_level


func is_drafting() -> bool:
	return _drafting


func get_draft_bonus_kmh() -> float:
	return _draft_bonus_kmh


func get_draft_status() -> Dictionary:
	# HUD は生の受取率と、走行に使う応答曲線後の実効率を並べて示す。
	# 計算式は LocalRaceMath にだけ置き、表示側で再計算しない。
	return {
		"own_wake_p": _own_wake_p,
		"direct_draft_p": _direct_draft_p,
		"chain_draft_p": _chain_draft_p,
		"received_draft_p": _received_draft_p,
		"effective_draft_ratio": LocalRaceMath.draft_effective_ratio(_received_draft_p),
		"draft_speed_bonus_kmh": _draft_bonus_kmh,
		"direct_source_ids": _direct_source_ids.duplicate(),
		"chain_source_ids": _chain_source_ids.duplicate(),
		"draft_source_ids": _direct_source_ids.duplicate(),
		"primary_source_id": str(_direct_source_ids[0]) if not _direct_source_ids.is_empty() else "",
		"primary_gap_m": float(_direct_source_details[0].get("gap", 0.0)) if not _direct_source_details.is_empty() else 0.0,
		"primary_line_gap_m": float(_direct_source_details[0].get("line", 0.0)) if not _direct_source_details.is_empty() else 0.0,
		"direct_source_details": _direct_source_details.duplicate(true),
	}


func get_drive_diagnostics() -> Dictionary:
	return LocalRaceMath.drive_diagnostics_kmh_per_s(
		_current_speed_kmh,
		_drive_level,
		_draft_air_resistance_factor(),
		get_acceleration_force_bonus(),
		get_top_speed_drive_adjustment()
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
	_draft_bonus_kmh = LocalRaceMath.draft_assist_speed_kmh(_received_draft_p)


func set_drive_level(level: float) -> void:
	_drive_level = LocalRaceMath.clamp_drive_level(level)


func get_heart_rate_bpm() -> float:
	return _heart_rate_bpm


func get_stamina() -> float:
	return _stamina


func get_race_progress() -> float:
	return _race_progress


func get_max_speed() -> float:
	return max_speed_kmh


func get_effective_stats() -> Dictionary:
	return _effective_stats.duplicate()


func get_acceleration_force_bonus() -> float:
	return LocalRaceMath.stat_acceleration_force_bonus_kmh_per_s(int(_effective_stats.get("acceleration", 5)))


func get_natural_top_speed() -> float:
	return _natural_top_speed_kmh


func get_top_speed_drive_adjustment() -> float:
	return LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(
		_current_speed_kmh,
		_drive_level,
		int(_effective_stats.get("top_speed", 5))
	)


func is_finished() -> bool:
	return _finished


func get_finish_order() -> int:
	return _finish_order


func get_finish_time() -> float:
	return _finish_time


func mark_finished(order: int, finish_time: float) -> void:
	_finished = true
	_finish_order = order
	_finish_time = finish_time


func get_snapshot() -> Dictionary:
	return {
		"id": "player-1" if player_controlled else "cpu-%d" % (gate_index + 1),
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
		if _drive_mode and player_controlled:
			_update_drive_level_input(delta)
		return
	_apply_pururin_race_stats()
	var previous_offset := _offset
	_update_inputs(delta)
	if not LocalRaceMath.can_use_offset(_race_progress, _offset, _others_snapshot):
		_offset = previous_offset
	var path_len := _path.curve.get_baked_length()
	var blocker := LocalRaceMath.blocking_speed_kmh(
		_distance, _offset, _others_snapshot, path_len
	)
	if _drive_mode and player_controlled:
		_update_drive_level_input(delta)
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			_drive_level,
			max_speed_kmh,
			delta,
			_draft_air_resistance_factor(),
			get_acceleration_force_bonus(),
			get_top_speed_drive_adjustment()
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
			LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(
				_current_speed_kmh,
				LocalRaceMath.Config.number("cpu_start_drive_level"),
				int(_effective_stats.get("top_speed", 5))
			)
		)
		_cpu_start_drive_remaining = maxf(_cpu_start_drive_remaining - delta, 0.0)
		_update_condition_for_drive_level(LocalRaceMath.Config.number("cpu_start_drive_level"), delta)
	else:
		var cpu_drive_level := _cpu_trainer_drive_level
		if not is_zero_approx(LocalRaceMath.apply_block_cap_kmh(_target_speed_kmh, blocker) - _target_speed_kmh):
			cpu_drive_level = 0.0
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			cpu_drive_level,
			max_speed_kmh,
			delta,
			_draft_air_resistance_factor(),
			get_acceleration_force_bonus(),
			LocalRaceMath.top_speed_drive_adjustment_kmh_per_s(
				_current_speed_kmh,
				cpu_drive_level,
				int(_effective_stats.get("top_speed", 5))
			)
		)
		_update_condition_for_drive_level(_cpu_trainer_drive_level, delta)
	var curvature := M2TrackMath.curvature_at(_path.curve, _distance)
	var d_center := LocalRaceMath.centerline_delta_from_kmh(
		_current_speed_kmh, delta, _offset, curvature
	)
	var proposed_progress := LocalRaceMath.add_race_progress(_race_progress, d_center)
	var allowed_progress := LocalRaceMath.allowed_race_progress(
		_race_progress, proposed_progress, _offset, _others_snapshot
	)
	var allowed_advance := allowed_progress - _race_progress
	_race_progress = allowed_progress
	_distance = fposmod(_distance + allowed_advance, path_len)
	_apply_pose()


func _clear_draft_details() -> void:
	_own_wake_p = 0.0
	_direct_draft_p = 0.0
	_chain_draft_p = 0.0
	_received_draft_p = 0.0
	_direct_source_ids = []
	_chain_source_ids = []
	_direct_source_details = []


func _update_inputs(delta: float) -> void:
	if player_controlled:
		var steer := _read_steer_axis()
		_offset = M2TrackMath.clamp_offset(_offset + steer * steer_speed * delta)
	else:
		_cpu_steer_timer -= delta
		if _cpu_steer_timer <= 0.0:
			_cpu_steer_timer = LocalRaceMath.cpu_steer_reselect_interval_s(randf())
			var follow_candidate := LocalRaceMath.cpu_follow_candidate(
				_race_progress, _offset, _others_snapshot
			)
			if bool(follow_candidate.get("found", false)):
				var follow_slot := LocalRaceMath.cpu_follow_slot(
					_race_progress, _offset, follow_candidate, _others_snapshot
				)
				_target_offset = LocalRaceMath.cpu_follow_target_offset_m(
					_target_offset, float(follow_slot["offset"])
				)
			else:
				# 追従候補がなければ、従来どおり現在ラインから小さく動かす。
				var free_target := LocalRaceMath.cpu_next_target_offset_m(_offset, randf())
				var line_pref := clampf(float(_cpu_trainer_profile.get("line_pref", 0.5)), 0.0, 1.0)
				var preferred_line := lerpf(
					M2TrackMath.MAX_ABS_OFFSET_M,
					-M2TrackMath.MAX_ABS_OFFSET_M,
					line_pref
				)
				_target_offset = lerpf(free_target, preferred_line, 0.35)
			# ライン選択と速度方針は独立。速度はトレーナーが定期的に決める。
		_offset = move_toward(_offset, _target_offset, LocalRaceMath.Config.number("cpu_steer_speed_m_per_s") * delta)
		_offset = M2TrackMath.clamp_offset(_offset)
		_cpu_trainer_timer -= delta
		if _cpu_trainer_timer <= 0.0:
			_cpu_trainer_timer = LocalRaceMath.Config.number("cpu_trainer_reselect_seconds")
			_update_cpu_target_speed()


func _update_cpu_target_speed() -> void:
	if _cpu_trainer_profile.is_empty():
		return
	var capacity := LocalRaceMath.Config.number("stamina_capacity")
	var global_gap := _cpu_global_gap_summary()
	var pace := _cpu_pace_summary()
	var decision := CpuTrainerMath.decide(_cpu_trainer_profile, {
		"progress_ratio": _race_progress / LocalRaceMath.RACE_DISTANCE_M,
		"field_size": LocalRaceMath.FIELD_SIZE,
		"live_place": _cpu_live_place(),
		"leader_gap_m": global_gap["leader_gap_m"],
		"pack_center_gap_m": global_gap["pack_center_gap_m"],
		"current_speed_kmh": _current_speed_kmh,
		"field_pace_kmh": pace["field_pace_kmh"],
		"nearest_ahead_gap_m": pace["nearest_ahead_gap_m"],
		"nearest_ahead_speed_kmh": pace["nearest_ahead_speed_kmh"],
		"acceleration_stat": float(_effective_stats.get("acceleration", 5)),
		"max_speed_kmh": _natural_top_speed_kmh,
		"stamina_ratio": _stamina / capacity,
		"has_draft": _received_draft_p > 0.0,
	}, LocalRaceMath.cpu_trainer_settings())
	_target_speed_kmh = float(decision["target_speed_kmh"])
	_cpu_trainer_drive_level = float(decision["drive_level"])


func _cpu_pace_summary() -> Dictionary:
	var speed_total := _current_speed_kmh
	var runner_count := 1
	var nearest_ahead_gap := INF
	var nearest_ahead_speed := _current_speed_kmh
	for other_value in _others_snapshot:
		if not other_value is Dictionary:
			continue
		speed_total += float(other_value.get("speed", _current_speed_kmh))
		runner_count += 1
		var gap := float(other_value.get("race_progress", _race_progress)) - _race_progress
		if gap > 0.001 and gap < nearest_ahead_gap:
			nearest_ahead_gap = gap
			nearest_ahead_speed = float(other_value.get("speed", _current_speed_kmh))
	return {
		"field_pace_kmh": speed_total / float(runner_count),
		"nearest_ahead_gap_m": 0.0 if is_inf(nearest_ahead_gap) else nearest_ahead_gap,
		"nearest_ahead_speed_kmh": nearest_ahead_speed,
	}


func _cpu_global_gap_summary() -> Dictionary:
	var progress_values: Array[float] = [_race_progress]
	for other_value in _others_snapshot:
		if other_value is Dictionary:
			progress_values.append(float(other_value.get("race_progress", _race_progress)))
	progress_values.sort()
	var leader_progress: float = _race_progress
	var pack_center_progress: float = _race_progress
	if not progress_values.is_empty():
		leader_progress = progress_values.back()
		var median_index: int = int(progress_values.size() / 2)
		pack_center_progress = progress_values[median_index]
	return {
		"leader_gap_m": maxf(leader_progress - _race_progress, 0.0),
		# 符号を残す。集団より前に出たCPUは負値になり、独走の抑制へ使える。
		"pack_center_gap_m": pack_center_progress - _race_progress,
	}


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
		_race_progress / LocalRaceMath.RACE_DISTANCE_M
	)
	_natural_top_speed_kmh = LocalRaceMath.top_speed_natural_speed_kmh(int(_effective_stats["top_speed"]))
	max_speed_kmh = LocalRaceMath.HARD_SPEED_CAP_KMH
	if not _drive_mode:
		_target_speed_kmh = LocalRaceMath.clamp_target_speed_kmh(_target_speed_kmh, _natural_top_speed_kmh)


func _draft_air_resistance_factor() -> float:
	return LocalRaceMath.draft_air_resistance_factor(_received_draft_p)


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
	var target_heart := LocalRaceMath.heart_rate_target_bpm(drive_level)
	_heart_rate_bpm = move_toward(_heart_rate_bpm, target_heart, LocalRaceMath.Config.number("heart_rate_change_bpm_per_s") * delta)
	_stamina = clampf(
		_stamina + LocalRaceMath.stamina_delta_per_s(drive_level) * delta,
		0.0,
		LocalRaceMath.Config.number("stamina_capacity")
	)


func _read_steer_axis() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v += 1.0
	v += RaceControllerInput.line_axis()
	return clampf(v, -1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled or _paused:
		return
	if _drive_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_UP:
			_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(
				_target_speed_kmh, 1.0, _natural_top_speed_kmh
			)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_DOWN:
			_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(
				_target_speed_kmh, -1.0, _natural_top_speed_kmh
			)
			get_viewport().set_input_as_handled()
	elif RaceControllerInput.is_button_pressed(event, JOY_BUTTON_DPAD_UP):
		_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(_target_speed_kmh, 1.0, _natural_top_speed_kmh)
		get_viewport().set_input_as_handled()
	elif RaceControllerInput.is_button_pressed(event, JOY_BUTTON_DPAD_DOWN):
		_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(_target_speed_kmh, -1.0, _natural_top_speed_kmh)
		get_viewport().set_input_as_handled()


func _apply_pose() -> void:
	if _path == null or _path.curve == null:
		return
	var local_xf: Transform3D = _path.curve.sample_baked_with_rotation(_distance)
	var centerline_local := local_xf.origin
	var outward := M2TrackMath.stadium_outward(centerline_local, _straight_len, _turn_radius)
	var pos_local := centerline_local + outward * _offset
	var travel := -local_xf.basis.z
	travel.y = 0.0
	if travel.length_squared() < 0.0001:
		travel = Vector3(0.0, 0.0, -1.0)
	else:
		travel = travel.normalized()
	var basis := Basis.looking_at(travel, Vector3.UP)
	global_transform = _path.global_transform * Transform3D(basis, pos_local)
