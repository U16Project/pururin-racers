extends Node3D
## 本編非接続の、女性ローポリ試作用の撮影場面。

const Builder := preload("res://scripts/prototype/low_poly_woman_builder.gd")

const VIEW_POSITIONS := {
	"front": Vector3(0.0, 4.2, -14.5),
	"angle": Vector3(8.7, 5.4, -12.5),
	"side": Vector3(14.0, 4.8, 0.0),
}
const VIEW_TARGET := Vector3(0.0, 3.2, 0.0)

var _camera: Camera3D


func _ready() -> void:
	_build_stage()
	set_view("angle")


func set_view(view_name: String) -> void:
	if not VIEW_POSITIONS.has(view_name):
		push_error("知らない試作カメラ位置です: %s" % view_name)
		return
	_camera.position = VIEW_POSITIONS[view_name]
	_camera.look_at(VIEW_TARGET, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: set_view("front")
		KEY_2: set_view("angle")
		KEY_3: set_view("side")


func _build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#202844")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#c8d8ff")
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	key_light.light_color = Color("#fff1dc")
	key_light.light_energy = 1.5
	add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.position = Vector3(-4.0, 5.0, -5.0)
	fill_light.light_color = Color("#7ac9ff")
	fill_light.light_energy = 3.0
	fill_light.omni_range = 14.0
	add_child(fill_light)

	var floor := MeshInstance3D.new()
	floor.name = "Floor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(20.0, 20.0)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#303b5f")
	floor_material.roughness = 0.92
	floor.material_override = floor_material
	add_child(floor)

	add_child(Builder.build())
	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.current = true
	_camera.fov = 30.0
	add_child(_camera)

	for view_name: String in VIEW_POSITIONS:
		var marker := Marker3D.new()
		marker.name = "%sCameraPose" % view_name.capitalize()
		marker.position = VIEW_POSITIONS[view_name]
		add_child(marker)
