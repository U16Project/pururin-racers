extends Node3D
## M2: distance + offset 走行。左右キー／十字左右で offset。
## Path3D.sample_baked_with_rotation / Curve3D（Godot 4.7）。
## 実測: bake 進行方向は -basis.z。向きは looking_at で揃える。


const M2TrackMath := preload("res://scripts/m2_track_math.gd")

@export var path_path: NodePath = ^"../TrackPath"
@export var speed: float = 8.0
@export var steer_speed: float = 4.0
## false のとき locked_offset 固定（ダミー用）。
@export var steer_enabled: bool = true
@export var locked_offset: float = 0.0


var _path: Path3D
var _distance: float = 0.0
var _offset: float = 0.0
var _straight_len: float = 28.0
var _turn_radius: float = 18.0


func _ready() -> void:
	_path = get_node_or_null(path_path) as Path3D
	if _path == null or _path.curve == null:
		push_error("runner_m2: Path3D / Curve3D が見つかりません")
		set_process(false)
		return
	if _path.has_method("get_straight_len"):
		_straight_len = _path.get_straight_len()
	if _path.has_method("get_turn_radius"):
		_turn_radius = _path.get_turn_radius()
	if not steer_enabled:
		_offset = M2TrackMath.clamp_offset(locked_offset)
	_apply_pose()


func _process(delta: float) -> void:
	if _path == null or _path.curve == null:
		return
	if steer_enabled:
		var steer := _read_steer_axis()
		_offset = M2TrackMath.clamp_offset(_offset + steer * steer_speed * delta)
	else:
		_offset = M2TrackMath.clamp_offset(locked_offset)
	var length := _path.curve.get_baked_length()
	var curvature := M2TrackMath.curvature_at(_path.curve, _distance)
	_distance = M2TrackMath.advance_distance(
		_distance, delta, speed, length, _offset, curvature
	)
	_apply_pose()


func get_offset() -> float:
	return _offset


func get_distance() -> float:
	return _distance


func _read_steer_axis() -> float:
	var v := 0.0
	# 左 = 内側（負の offset）、右 = 外側（正）
	if Input.is_physical_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT):
		v += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		v -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		v += 1.0
	return clampf(v, -1.0, 1.0)


func _apply_pose() -> void:
	var local_xf: Transform3D = _path.curve.sample_baked_with_rotation(_distance)
	var centerline_local := local_xf.origin
	var outward := M2TrackMath.stadium_outward(centerline_local, _straight_len, _turn_radius)
	# 負 offset = 内側 = -outward
	var pos_local := centerline_local + outward * _offset
	# bake の進行は -basis.z（Godot 4.7 実測）。-Z が進行になるよう向きを揃える。
	var travel := -local_xf.basis.z
	travel.y = 0.0
	if travel.length_squared() < 0.0001:
		travel = Vector3(0.0, 0.0, -1.0)
	else:
		travel = travel.normalized()
	var basis := Basis.looking_at(travel, Vector3.UP)
	global_transform = _path.global_transform * Transform3D(basis, pos_local)
