extends Node3D
## M1: Path3D 上を distance で 1 体走行（lateral offset = 0）。

const M1Distance := preload("res://scripts/m1_distance.gd")

@export var path_path: NodePath = ^"../TrackPath"
@export var speed: float = 4.0

var _path: Path3D
var _distance: float = 0.0


func _ready() -> void:
	_path = get_node_or_null(path_path) as Path3D
	if _path == null or _path.curve == null:
		push_error("runner_m1: Path3D / Curve3D が見つかりません")
		set_process(false)
		return
	_apply_pose()


func _process(delta: float) -> void:
	if _path == null or _path.curve == null:
		return
	var length := _path.curve.get_baked_length()
	_distance = M1Distance.advance(_distance, delta, speed, length)
	_apply_pose()


func _apply_pose() -> void:
	# Curve3D.sample_baked* は曲線ローカル座標（Godot 4.7 Path3D / Curve3D）。
	var local_xf: Transform3D = _path.curve.sample_baked_with_rotation(_distance)
	global_transform = _path.global_transform * local_xf
