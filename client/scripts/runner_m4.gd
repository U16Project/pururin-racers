extends Node3D
## M4 集団プロトタイプ用ランナー。能力値とドラフト補助を表示・操作に反映する。

const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const M4GroupRaceMath := preload("res://scripts/m4_group_race_math.gd")

@export var path_path: NodePath = ^"../TrackPath"

var _path: Path3D
var _profile: Dictionary
var _role := "player"
var _player_controlled := false
var _distance := M4GroupRaceMath.START_PATH_DISTANCE_M
var _offset := 0.0
var _target_offset := 0.0
var _current_speed_kmh := 0.0
var _target_speed_kmh := 58.0
var _race_progress := 0.0
var _others_snapshot: Array = []
var _paused := false
var _finished := false
var _finish_order := -1
var _finish_time := -1.0
var _drafting := false
var _draft_speed_kmh := -1.0
var _straight_len := 526.0
var _turn_radius := 164.0
var _cpu_steer_timer := 0.0

func setup_for_race(path: Path3D, role: String, is_player: bool) -> void:
	_path = path
	_role = role
	_player_controlled = is_player
	_profile = M4GroupRaceMath.profile_for(role)
	_offset = _starting_offset(role)
	_target_offset = _offset
	_current_speed_kmh = (
		M4GroupRaceMath.PLAYER_INITIAL_SPEED_KMH
		if is_player
		else float(_profile["max_speed_kmh"]) * 0.82
	)
	_target_speed_kmh = (
		M4GroupRaceMath.PLAYER_INITIAL_SPEED_KMH
		if is_player
		else float(_profile["max_speed_kmh"])
	)
	_distance = M4GroupRaceMath.START_PATH_DISTANCE_M
	_race_progress = 0.0
	_finished = false
	_finish_order = -1
	_finish_time = -1.0
	if _path:
		_straight_len = _path.get_straight_len()
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

func get_race_progress() -> float:
	return _race_progress

func get_current_speed() -> float:
	return _current_speed_kmh

func get_target_speed() -> float:
	return _target_speed_kmh

func get_max_speed() -> float:
	return float(_profile.get("max_speed_kmh", M4GroupRaceMath.NORMAL_SPEED_CAP_KMH))

func get_display_name() -> String:
	return str(_profile.get("name", "ぷるりん"))

func is_drafting() -> bool:
	return _drafting

func get_profile() -> Dictionary:
	return _profile.duplicate()

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
	var allowed := maxf(leader_progress - M4GroupRaceMath.CONTACT_LONGITUDINAL_M, 0.0)
	if _race_progress >= allowed:
		_race_progress = allowed
		_distance = fposmod(leader_distance - M4GroupRaceMath.CONTACT_LONGITUDINAL_M, path_length)
		_apply_pose()

func get_snapshot() -> Dictionary:
	return {
		"distance": _distance,
		"offset": _offset,
		"speed": _current_speed_kmh,
		"progress": _race_progress,
		"role": _role,
	}

func _ready() -> void:
	if _path == null:
		_path = get_node_or_null(path_path) as Path3D
	if _path and _path.curve:
		_apply_pose()

func _process(delta: float) -> void:
	if _paused or _path == null or _path.curve == null:
		return
	_update_inputs(delta)
	var path_len := _path.curve.get_baked_length()
	var leader := M4GroupRaceMath.draft_leader(_distance, _offset, _others_snapshot, path_len)
	_drafting = not leader.is_empty()
	_draft_speed_kmh = leader.get("speed", -1.0)
	var effective_target := M4GroupRaceMath.draft_assist_target_kmh(
		_target_speed_kmh,
		_draft_speed_kmh,
		int(_profile.get("group_affinity", 0)),
		get_max_speed()
	)
	_current_speed_kmh = M4GroupRaceMath.follow_speed_kmh(
		_current_speed_kmh,
		effective_target,
		delta,
		int(_profile.get("acceleration", 1))
	)
	var curvature := M2TrackMath.curvature_at(_path.curve, _distance)
	var advance := M4GroupRaceMath.centerline_delta_from_kmh(
		_current_speed_kmh, delta, _offset, curvature
	)
	_race_progress += maxf(advance, 0.0)
	_distance = fposmod(_distance + advance, path_len)
	_apply_pose()

func _update_inputs(delta: float) -> void:
	if _player_controlled:
		var steer := 0.0
		if Input.is_physical_key_pressed(KEY_LEFT):
			steer -= 1.0
		if Input.is_physical_key_pressed(KEY_RIGHT):
			steer += 1.0
		_offset = M2TrackMath.clamp_offset(_offset + steer * 4.0 * delta)
		return
	_cpu_steer_timer -= delta
	if _cpu_steer_timer <= 0.0:
		_cpu_steer_timer = 1.5 if _role == "inner" else 2.4
		_target_offset = _starting_offset(_role) + randf_range(-0.7, 0.7)
	_offset = move_toward(_offset, M2TrackMath.clamp_offset(_target_offset), 3.0 * delta)

func _unhandled_input(event: InputEvent) -> void:
	if not _player_controlled or _paused or _finished:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_UP:
			_target_speed_kmh = M4GroupRaceMath.step_target_speed_kmh(_target_speed_kmh, 1.0, get_max_speed())
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_DOWN:
			_target_speed_kmh = M4GroupRaceMath.step_target_speed_kmh(_target_speed_kmh, -1.0, get_max_speed())
			get_viewport().set_input_as_handled()

func _starting_offset(role: String) -> float:
	match role:
		"inner":
			return -4.5
		"outer":
			return 4.5
		_:
			return -1.5

func _apply_pose() -> void:
	if _path == null or _path.curve == null:
		return
	var local_xf := _path.curve.sample_baked_with_rotation(_distance)
	var centerline_local := local_xf.origin
	var outward := M2TrackMath.stadium_outward(centerline_local, _straight_len, _turn_radius)
	var pos_local := centerline_local + outward * _offset
	var travel := -local_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	global_transform = _path.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		pos_local
	)
