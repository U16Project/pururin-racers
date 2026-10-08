extends RefCounted
## ぷるりんの体を、画面の絵として写すための小さな舞台（別の3Dの世界、カメラ、明かり、回る台）。
## レース選択画面の絵（止まった絵・回る絵）に使う。背景は透明。

## カメラが体を見下ろす角度（度）と、体のどの高さを画面のまん中にするか（m）。
const CAMERA_PITCH_DEG := 10.0
const CAMERA_TARGET_HEIGHT_M := 0.72
const CAMERA_DISTANCE_M := 6.0
## 明かりの向き（度）。体の左上の前から照らす。
const LIGHT_ROTATION_DEG := Vector3(-62.0, 228.0, 0.0)
const TURNTABLE_NAME := "Turntable"


## 舞台を作る。size_px は絵の一辺（ピクセル）、view_height_m は、絵の縦に写る範囲（m）。
## 体は、turntable(viewport) に付ける。
static func make(size_px: int, view_height_m: float) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(size_px, size_px)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var environment := Environment.new()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ROTATION_DEG
	viewport.add_child(light)
	# 体の正面（−Z）の側から、少し見下ろす。
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = view_height_m
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var target := Vector3(0.0, CAMERA_TARGET_HEIGHT_M, 0.0)
	camera.look_at_from_position(target + Vector3(0.0, sin(pitch), -cos(pitch)) * CAMERA_DISTANCE_M, target, Vector3.UP)
	camera.current = true
	viewport.add_child(camera)
	var table := Node3D.new()
	table.name = TURNTABLE_NAME
	viewport.add_child(table)
	return viewport


## 体を乗せる、回る台。
static func turntable(viewport: SubViewport) -> Node3D:
	return viewport.get_node(TURNTABLE_NAME) as Node3D
