extends Node3D
## ローカル簡易レース用ランナー。目標スピード追従・左右・前方ブロック対応。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")

@export var path_path: NodePath = ^"../TrackPath"
@export var max_speed: float = 15.0
@export var steer_speed: float = 4.0
@export var player_controlled: bool = false
@export var display_name: String = "ぷるりん"
@export var gate_index: int = 0


var _path: Path3D
var _distance: float = LocalRaceMath.START_PATH_DISTANCE_M
var _offset: float = 0.0
var _target_offset: float = 0.0
var _current_speed: float = 0.0
var _target_speed: float = 15.0
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


func setup_for_race(path: Path3D, gate: int, tier_speed: float, is_player: bool, label: String) -> void:
	_path = path
	gate_index = gate
	max_speed = tier_speed
	player_controlled = is_player
	display_name = label
	_offset = LocalRaceMath.starting_offset_for_gate(gate)
	_target_offset = _offset
	_distance = LocalRaceMath.START_PATH_DISTANCE_M
	_race_progress = 0.0
	_finished = false
	_finish_order = -1
	_finish_time = -1.0
	_current_speed = tier_speed * 0.85
	_target_speed = tier_speed
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
	return _current_speed


func get_target_speed() -> float:
	return _target_speed


func get_race_progress() -> float:
	return _race_progress


func get_max_speed() -> float:
	return max_speed


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
		"speed": _current_speed,
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
	var blocker := LocalRaceMath.blocking_speed(
		_distance, _offset, _others_snapshot, path_len
	)
	var effective_target := LocalRaceMath.apply_block_cap(_target_speed, blocker)
	_current_speed = LocalRaceMath.follow_speed(
		_current_speed,
		effective_target,
		delta
	)
	var ground_speed := _current_speed
	var curvature := M2TrackMath.curvature_at(_path.curve, _distance)
	var d_center := LocalRaceMath.centerline_delta(ground_speed, delta, _offset, curvature)
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
		_target_speed = max_speed


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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_UP:
			_target_speed = LocalRaceMath.step_target_speed(_target_speed, 1.0, max_speed)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_DOWN:
			_target_speed = LocalRaceMath.step_target_speed(_target_speed, -1.0, max_speed)
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
