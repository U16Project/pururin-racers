extends Node3D
## ローカル簡易レース用ランナー。目標スピード追従・出力操作・左右・前方ブロック対応。
## 速度は km/h（検討事項 #24）。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")

@export var path_path: NodePath = ^"../TrackPath"
@export var max_speed_kmh: float = 58.0
@export var steer_speed: float = 4.0
@export var player_controlled: bool = false
@export var display_name: String = "ぷるりん"
@export var gate_index: int = 0


var _path: Path3D
var _distance: float = LocalRaceMath.START_PATH_DISTANCE_M
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
var _heart_rate_bpm: float = 118.0
var _stamina: float = 100.0
var _race_progress: float = 0.0
var _finished: bool = false
var _finish_order: int = -1
var _finish_time: float = -1.0
var _straight_len: float = LocalRaceMath.TOKYO_STRAIGHT_M
var _turn_radius: float = LocalRaceMath.TOKYO_TURN_RADIUS_M
var _cpu_steer_timer: float = 0.0
var _paused: bool = false
## コントローラが毎フレーム渡す他頭情報。
var _others_snapshot: Array = []


func setup_for_race(
	path: Path3D,
	gate: int,
	tier_speed_kmh: float,
	is_player: bool,
	label: String
) -> void:
	_path = path
	gate_index = gate
	max_speed_kmh = tier_speed_kmh
	player_controlled = is_player
	display_name = label
	_offset = LocalRaceMath.starting_offset_for_gate(gate)
	_target_offset = _offset
	_distance = LocalRaceMath.START_PATH_DISTANCE_M
	_race_progress = 0.0
	_finished = false
	_finish_order = -1
	_finish_time = -1.0
	if is_player:
		# M5.1 は出力方式を標準とし、レース開始時は最低速度から発進する。
		_current_speed_kmh = LocalRaceMath.MIN_SPEED_KMH
		_target_speed_kmh = LocalRaceMath.MIN_SPEED_KMH
	else:
		_current_speed_kmh = tier_speed_kmh * 0.85
		_target_speed_kmh = tier_speed_kmh
	_drive_mode = is_player
	_drive_level = 0.0
	_drive_hold_direction = 0.0
	_drive_repeat_remaining = 0.0
	_drafting = false
	_draft_bonus_kmh = 0.0
	_heart_rate_bpm = 118.0
	_stamina = 100.0
	if _path != null:
		if _path.has_method("get_straight_len"):
			_straight_len = _path.get_straight_len()
		if _path.has_method("get_turn_radius"):
			_turn_radius = _path.get_turn_radius()
	_apply_pose()


func set_paused(paused: bool) -> void:
	_paused = paused


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
		_target_speed_kmh = LocalRaceMath.clamp_target_speed_kmh(_current_speed_kmh, max_speed_kmh)


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


func hold_behind(leader_distance: float, leader_progress: float, path_length: float) -> void:
	var allowed_progress := maxf(leader_progress - LocalRaceMath.CONTACT_LONGITUDINAL_M, 0.0)
	if _race_progress >= allowed_progress:
		_race_progress = allowed_progress
		_distance = fposmod(
			leader_distance - LocalRaceMath.CONTACT_LONGITUDINAL_M,
			path_length
		)
		_apply_pose()


func get_snapshot() -> Dictionary:
	return {
		"distance": _distance,
		"offset": _offset,
		"speed": _current_speed_kmh,
		"progress": _race_progress,
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
	_update_inputs(delta)
	var path_len := _path.curve.get_baked_length()
	var blocker := LocalRaceMath.blocking_speed_kmh(
		_distance, _offset, _others_snapshot, path_len
	)
	_drafting = false
	_draft_bonus_kmh = 0.0
	if _drive_mode and player_controlled:
		_update_drive_level_input(delta)
		var draft_leader := LocalRaceMath.draft_leader(
			_distance, _offset, _others_snapshot, path_len
		)
		var draft_factor := LocalRaceMath.DRAFT_AIR_RESISTANCE_FACTOR if not draft_leader.is_empty() else 0.0
		_drafting = not draft_leader.is_empty()
		_draft_bonus_kmh = LocalRaceMath.draft_speed_bonus_kmh(draft_factor)
		_current_speed_kmh = LocalRaceMath.advance_drive_speed_kmh(
			_current_speed_kmh,
			_drive_level,
			max_speed_kmh,
			delta,
			draft_factor
		)
		_update_condition(delta)
	else:
		var effective_target := LocalRaceMath.apply_block_cap_kmh(_target_speed_kmh, blocker)
		_current_speed_kmh = LocalRaceMath.follow_speed_kmh(
			_current_speed_kmh,
			effective_target,
			delta
		)
	var curvature := M2TrackMath.curvature_at(_path.curve, _distance)
	var d_center := LocalRaceMath.centerline_delta_from_kmh(
		_current_speed_kmh, delta, _offset, curvature
	)
	_race_progress = LocalRaceMath.add_race_progress(_race_progress, d_center)
	_distance = fposmod(_distance + d_center, path_len)
	_apply_pose()


func _update_inputs(delta: float) -> void:
	if player_controlled:
		var steer := _read_steer_axis()
		_offset = M2TrackMath.clamp_offset(_offset + steer * steer_speed * delta)
	else:
		_cpu_steer_timer -= delta
		if _cpu_steer_timer <= 0.0:
			_cpu_steer_timer = randf_range(1.2, 3.5)
			# 内寄りバイアスのランダム目標。
			_target_offset = M2TrackMath.clamp_offset(randf_range(-M2TrackMath.MAX_ABS_OFFSET_M, 2.0))
		_offset = move_toward(_offset, _target_offset, steer_speed * 0.55 * delta)
		_offset = M2TrackMath.clamp_offset(_offset)
		_target_speed_kmh = max_speed_kmh


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
	return clampf(v, -1.0, 1.0)


func _update_condition(delta: float) -> void:
	var target_heart := LocalRaceMath.heart_rate_target_bpm(_drive_level)
	_heart_rate_bpm = move_toward(_heart_rate_bpm, target_heart, 18.0 * delta)
	_stamina = clampf(
		_stamina + LocalRaceMath.stamina_delta_per_s(_drive_level) * delta,
		0.0,
		100.0
	)


func _read_steer_axis() -> float:
	var v := 0.0
	if Input.is_physical_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		v -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		v += 1.0
	return clampf(v, -1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not player_controlled or _paused or _finished:
		return
	if _drive_mode:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_UP:
			_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(
				_target_speed_kmh, 1.0, max_speed_kmh
			)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_DOWN:
			_target_speed_kmh = LocalRaceMath.step_target_speed_kmh(
				_target_speed_kmh, -1.0, max_speed_kmh
			)
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
