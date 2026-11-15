extends MeshInstance3D
## カメラで見ている「ほかの子」の頭の上に浮かぶ、下向きの小さな三角の目印。
## 自分の足元の輪（player_ground_marker.gd）と区別するため、形・場所・色を変えている。
## 見た目だけ。見ている子の子にして置く（自分を見ているときは出さない）。

## 足元からの高さ（m）と、上下にゆれる幅（m）・速さ（回/秒）、回る速さ（度/秒）。
const HEIGHT_M := 1.5
const BOB_M := 0.06
const BOB_HZ := 1.2
const TURN_DEG_PER_S := 90.0
## 三角の、上の半径と高さ（m）。
const RADIUS_M := 0.28
const LENGTH_M := 0.42
const COLOR := Color(1.0, 0.86, 0.25, 0.95)

var _seconds := 0.0


func _ready() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = RADIUS_M
	cone.bottom_radius = 0.0
	cone.height = LENGTH_M
	cone.radial_segments = 3
	cone.rings = 1
	mesh = cone
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.albedo_color = COLOR
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_seconds += delta
	position = Vector3.UP * (HEIGHT_M + sin(_seconds * TAU * BOB_HZ) * BOB_M)
	rotation.y = deg_to_rad(TURN_DEG_PER_S) * _seconds


## 目印を、その子の上へ移す。null なら隠す。
func attach_to(runner: Node3D) -> void:
	if get_parent() == runner:
		return
	if get_parent() != null:
		get_parent().remove_child(self)
	if runner == null:
		return
	runner.add_child(self)
