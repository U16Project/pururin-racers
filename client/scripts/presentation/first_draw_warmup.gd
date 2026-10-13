extends Node
## コースの上の物を、スタート前に一度だけ、見えない小さな画面に描いておく。
## ブラウザ版は、物を初めて描くときの準備（1回だけ）のあいだ、画面が止まる。
## レース中に初めて画面に入る物があると、そこで数秒止まるので、先に済ませる。
## 真上の高い所から、コース全体を1枚に収めて描く。終わったら、自分を消す。

const SIZE_PX := 64
## 描いておくコマ数。1コマ目は、画面の用意だけで終わることがあるので、少し多めに回す。
const FRAMES := 3
const CAMERA_FOV_DEG := 60.0
## コースの端から、画面の端までの余裕（倍率）。
const MARGIN := 1.3

var _center := Vector3.ZERO
var _radius_m := 0.0
var _frames_left := FRAMES
## 「遠いと描かない」設定を、描いておくあいだだけ外した物と、その元の距離。
var _range_limited := {}


## center と radius_m は、描いておきたい範囲（コースの中心と、いちばん遠い所までの距離）。
func setup(center: Vector3, radius_m: float) -> void:
	_center = center
	_radius_m = radius_m


## その範囲が画面に収まる、カメラの高さ。
static func camera_height_m(radius_m: float) -> float:
	return radius_m * MARGIN / tan(deg_to_rad(CAMERA_FOV_DEG) * 0.5)


func _ready() -> void:
	name = "FirstDrawWarmup"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE_PX, SIZE_PX)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.fov = CAMERA_FOV_DEG
	var height := camera_height_m(_radius_m)
	camera.far = height * 2.0
	viewport.add_child(camera)
	camera.global_transform = Transform3D(Basis.IDENTITY, _center + Vector3.UP * height).looking_at(_center, Vector3.FORWARD)
	camera.current = true
	_lift_range_limits(get_parent())


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	for node: GeometryInstance3D in _range_limited:
		if is_instance_valid(node):
			node.visibility_range_end = float(_range_limited[node])
	queue_free()


func _lift_range_limits(node: Node) -> void:
	if node is GeometryInstance3D and (node as GeometryInstance3D).visibility_range_end > 0.0:
		_range_limited[node] = (node as GeometryInstance3D).visibility_range_end
		(node as GeometryInstance3D).visibility_range_end = 0.0
	for child in node.get_children():
		_lift_range_limits(child)
