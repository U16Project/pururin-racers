extends Node3D
## Claudeさんが作った手続き生成のレース場を、そのまま自由カメラで見て回る画面。

const EXPLORATION_DISTANCE_M := 1600.0
const COURSE_WIDTH_M := 15.0
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const CourseMarkers := preload("res://scripts/presentation/course_markers.gd")
const RaceVenue := preload("res://scripts/presentation/race_venue.gd")
const StartGate := preload("res://scripts/presentation/start_gate.gd")

@onready var _track: Path3D = $TrackPath
@onready var _ground: MeshInstance3D = $Ground
@onready var _launch_visual: MeshInstance3D = $TrackPath/RouteLaunchStraight
@onready var _camera: Camera3D = $ExplorationCamera
@onready var _guide_label: Label = $UI/GuidePanel/GuideLabel

var _goal_visual := GoalVisual.new()
var _course_markers := CourseMarkers.new()
var _venue := RaceVenue.new()
var _start_gate := StartGate.new()
var _guide_prefix := ""


func _ready() -> void:
	var result := M5CourseBuilder.load_layout_result()
	if result.has("error"):
		_guide_label.text = "コース設定を確認してください：%s\nEsc／B　タイトルへ戻る" % str(result["error"])
		set_process(false)
		return
	LocalRaceMath.apply_course_to_path(_track)
	var layout: Dictionary = result["layout"]
	var route := M5CourseBuilder.route_for_distance(layout, EXPLORATION_DISTANCE_M)
	if route.is_empty():
		_guide_label.text = "1600mルートが見つかりません。\nEsc／B　タイトルへ戻る"
		set_process(false)
		return
	_place_launch_straight(route, float(layout["track_length_m"]))
	_venue.place(_track, _ground.get_surface_override_material(0), layout, route)
	_start_gate.place(_track, route, float(layout["track_length_m"]))
	_goal_visual.place(_track, float(layout["goal_path_m"]), COURSE_WIDTH_M)
	_goal_visual.set_laps_to_go(0)
	_course_markers.place(
		_track,
		route,
		EXPLORATION_DISTANCE_M,
		float(layout["track_length_m"]),
		LocalRaceMath.Config.number("course_marker_sign_interval_m"),
		LocalRaceMath.Config.number("course_marker_sign_max_remaining_m")
	)
	_guide_prefix = "\n".join(PackedStringArray([
		"WASD／左スティック／十字ボタン　前後左右",
		"マウス／右スティック　見回す",
		"Space／R2　上昇　　Ctrl／L2　下降",
		"Shift　高速移動　　ホイール　移動速度",
		"Esc／B　タイトルへ戻る",
	]))
	_camera.move_speed_changed.connect(_update_speed_label)
	_update_speed_label(float(_camera.get("move_speed_mps")))


func _place_launch_straight(route: Dictionary, lap_length_m: float) -> void:
	var segments: Array = route.get("segments", [])
	if segments.is_empty() or str(segments[0].get("type", "")) != "straight":
		_launch_visual.visible = false
		return
	var launch_length := float(segments[0].get("distance_m", 0.0))
	var join_pose := M5CourseBuilder.route_pose(_track.curve, route, launch_length, lap_length_m)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(COURSE_WIDTH_M, 0.12, launch_length)
	_launch_visual.mesh = mesh
	_launch_visual.material_override = ($TrackPath/TrackRibbon as CSGPolygon3D).material
	var travel: Vector3 = join_pose["travel"]
	var center: Vector3 = join_pose["position"] - travel * (launch_length * 0.5)
	_launch_visual.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP), center + Vector3.UP * 0.02
	)


func _update_speed_label(speed_mps: float) -> void:
	_guide_label.text = "%s\n移動速度　%.0f m/s" % [_guide_prefix, speed_mps]
