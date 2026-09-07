extends Camera3D
## M2: 後方追従が主。C キーで真上俯瞰トグル。
## 俯瞰は遠近で速度感が消えないよう正射影＋真上（設計の「頭上やや後方」よりフラット。M2 確認用）。
## Camera3D.look_at / projection（Godot 4.7）。


@export var target_path: NodePath = ^"../Runner"
@export var follow_distance: float = 8.0
@export var follow_height: float = 2.5
## 真上カメラの高さ（地面との干渉回避用。見た目スケールは ortho size）。
@export var overview_height: float = 80.0
## 正射影の縦方向サイズ(m)。競馬場形全体が入る目安。
@export var overview_ortho_size: float = 72.0

var _target: Node3D
var _overview: bool = false
var _chase_fov: float = 75.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_chase_fov = fov
	current = true


func set_follow_target(node: Node3D) -> void:
	_target = node


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_C:
			_overview = not _overview
			if not _overview:
				_restore_chase_projection()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _overview:
		_apply_overview()
		return
	if _target == null:
		return
	# Runner は Basis.looking_at(travel) で -Z = 進行。後方追従。
	var forward := -_target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, 1.0)
	else:
		forward = forward.normalized()
	var cam_pos := _target.global_position - forward * follow_distance + Vector3.UP * follow_height
	global_position = cam_pos
	look_at(_target.global_position + Vector3.UP * 0.6, Vector3.UP)


func _apply_overview() -> void:
	# 真上＋正射影。ホーム直線（z<0）が画面下になるよう up = +Z。
	projection = PROJECTION_ORTHOGONAL
	size = overview_ortho_size
	global_position = Vector3(0.0, overview_height, 0.0)
	look_at(Vector3.ZERO, Vector3(0.0, 0.0, 1.0))


func _restore_chase_projection() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = _chase_fov
