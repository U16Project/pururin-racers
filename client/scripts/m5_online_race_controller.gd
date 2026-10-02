extends Node3D

const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
## M5: サーバーの race_tick を描画し、目標値だけを送る。

const NetRace := preload("res://scripts/net_race_m5.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const DraftRules := preload("res://scripts/config/m5_draft_rules.gd")
const PururinVisualStyle := preload("res://scripts/pururin_visual_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TITLE_SCENE := "res://scenes/m3_intro.tscn"
const RESULT_VISUAL_HOLD_SECONDS := 10.0
const INPUT_OFFSET_RATE := 4.0
const INPUT_SPEED_RATE := 12.0
@onready var _runners_root: Node3D = $Runners
@onready var _track: Path3D = $TrackPath
@onready var _camera: Camera3D = $Camera3D
@onready var _hud_label: Label = %HudLabel
@onready var _guide_label: Label = $UI/GuideLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _result_return_button: Button = %ResultReturnButton
@onready var _pause_panel: Control = %PausePanel
@onready var _pause_return_button: Button = %PauseReturnButton
@onready var _resume_button: Button = %ResumeButton
@onready var _start_marker: MeshInstance3D = $StartMarker
@onready var _goal_marker: MeshInstance3D = $GoalMarker

var _goal_visual := GoalVisual.new()

var _net: Node
var _visuals: Dictionary = {}
var _visual_targets: Dictionary = {}
var _visual_distances: Dictionary = {}
var _visual_offsets: Dictionary = {}
var _visual_finished: Dictionary = {}
var _latest: Dictionary = {}
var _target_speed := 58.0
var _target_offset := -3.0
var _straight_len := 680.0
var _turn_radius := 115.085
var _layout: Dictionary = {}
var _route: Dictionary = {}
var _track_length := 2083.1
var _race_distance := 2000.0
var _goal_path := 400.0
var _launch_visual: MeshInstance3D
var _paused := false
var _race_result_received := false
var _visual_hold_remaining := 0.0
var _visuals_stopped := false

func _ready() -> void:
	var course_result := M5CourseBuilder.load_layout_result()
	if course_result.has("error"):
		_hud_label.text = "コース設定を確認してください：" + str(course_result.error)
		set_process(false)
		return
	if DraftRules.values().is_empty():
		_hud_label.text = "ドラフト設定を確認してください：" + DraftRules.last_error
		set_process(false)
		return
	_layout = course_result.layout
	_route = M5CourseBuilder.route_for_distance(_layout, _race_distance)
	if _route.is_empty():
		_hud_label.text = "コース設定を確認してください：m5_2000 のルートがありません"
		set_process(false)
		return
	_straight_len = float(_layout.get("straight_length_m", 680.0))
	_turn_radius = float(_layout.get("turn_radius_m", 115.085))
	_track_length = float(_layout.get("track_length_m", 2083.1))
	_goal_path = float(_layout.get("goal_path_m", 400.0))
	_track.curve = M5CourseBuilder.make_racecourse_curve(
		_straight_len, _turn_radius, 1.0
	)
	_launch_visual = MeshInstance3D.new()
	_launch_visual.name = "RouteLaunchStraight"
	_track.add_child(_launch_visual)
	_result_panel.visible = false
	_pause_panel.visible = false
	_guide_label.text = "←→／左スティック：ライン　↑↓／十字キー：目標スピード　Y/C：視点切替　右スティック左右／QE：向き　右スティック押込／R：リセット　Start/Esc：メニュー"
	_result_return_button.pressed.connect(_return_to_title)
	_pause_return_button.pressed.connect(_return_to_title)
	_resume_button.pressed.connect(_set_paused.bind(false))
	_place_markers()
	_net = NetRace.new()
	add_child(_net)
	_net.race_started.connect(_on_race_started)
	_net.race_tick_received.connect(_on_race_tick)
	_net.race_result_received.connect(_on_race_result)
	_net.connection_error.connect(_on_connection_error)
	_net.connect_race()
	_hud_label.text = "M5 オンラインレース　接続しています…"

func _unhandled_input(event: InputEvent) -> void:
	if RaceControllerInput.is_button_pressed(event, JOY_BUTTON_A) and RaceControllerInput.activate_focused_control(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if _race_result_received:
		return
	if RaceControllerInput.is_menu_pressed(event):
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif RaceControllerInput.is_cancel_pressed(event) and _paused:
		_set_paused(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()
		elif _paused:
			return
		else:
			return

func _process_player_input(delta: float) -> void:
	if _race_result_received or _paused:
		return
	if _apply_held_input(
		delta,
		Input.is_physical_key_pressed(KEY_LEFT) or RaceControllerInput.line_axis() < 0.0,
		Input.is_physical_key_pressed(KEY_RIGHT) or RaceControllerInput.line_axis() > 0.0,
		Input.is_physical_key_pressed(KEY_UP) or RaceControllerInput.notch_axis() > 0.0,
		Input.is_physical_key_pressed(KEY_DOWN) or RaceControllerInput.notch_axis() < 0.0
	) and _net != null:
		_net.send_input(_target_speed, _target_offset)

func _apply_held_input(
	delta: float, left_pressed: bool, right_pressed: bool, up_pressed: bool, down_pressed: bool
) -> bool:
	var previous_speed := _target_speed
	var previous_offset := _target_offset
	if left_pressed:
		_target_offset = maxf(-6.0, _target_offset - INPUT_OFFSET_RATE * delta)
	if right_pressed:
		_target_offset = minf(6.0, _target_offset + INPUT_OFFSET_RATE * delta)
	if up_pressed:
		_target_speed = minf(75.0, _target_speed + INPUT_SPEED_RATE * delta)
	if down_pressed:
		_target_speed = maxf(45.0, _target_speed - INPUT_SPEED_RATE * delta)
	return not is_equal_approx(previous_speed, _target_speed) or not is_equal_approx(previous_offset, _target_offset)

func _process(delta: float) -> void:
	_process_player_input(delta)
	if _race_result_received and not _visuals_stopped:
		_visual_hold_remaining = maxf(_visual_hold_remaining - maxf(delta, 0.0), 0.0)
		if is_zero_approx(_visual_hold_remaining):
			_visuals_stopped = true
	if _track == null or _track.curve == null:
		return
	if _visuals_stopped:
		return
	var path_length := _track.curve.get_baked_length()
	if path_length <= 0.0:
		return
	var smoothing := 1.0 - exp(-12.0 * maxf(delta, 0.0))
	for racer_id in _visual_targets:
		if not _visuals.has(racer_id):
			continue
		var target: Vector2 = _visual_targets[racer_id]
		var current_distance := float(_visual_distances.get(racer_id, target.x))
		var current_offset := float(_visual_offsets.get(racer_id, target.y))
		if _visual_finished.get(racer_id, false) or _race_result_received:
			current_distance += 58.0 / 3.6 * delta
			_visual_distances[racer_id] = current_distance
			_apply_visual_pose(_visuals[racer_id], current_distance, current_offset)
			continue
		var distance_delta := target.x - current_distance
		current_distance = maxf(current_distance + distance_delta * smoothing, 0.0)
		current_offset = lerpf(current_offset, target.y, smoothing)
		_visual_distances[racer_id] = current_distance
		_visual_offsets[racer_id] = current_offset
		_apply_visual_pose(_visuals[racer_id], current_distance, current_offset)

func _on_race_started(payload: Dictionary) -> void:
	_set_route(float(payload.get("distance_m", _race_distance)))
	_hud_label.text = "M5 オンラインレース　サーバー判定中"
	_on_race_tick({"racers": payload.get("racers", [])})

func _on_race_tick(payload: Dictionary) -> void:
	_latest = payload
	if payload.has("route_id"):
		_set_route(float(payload.get("distance_m", _race_distance)))
	for racer in payload.get("racers", []):
		var racer_id := str(racer.get("id", ""))
		if not _visuals.has(racer_id):
			_create_visual(racer_id, _visuals.size())
		var target_distance := float(racer.get("race_progress", 0.0))
		var target_offset := float(racer.get("offset", 0.0))
		_visual_targets[racer_id] = Vector2(target_distance, target_offset)
		_visual_finished[racer_id] = bool(racer.get("finished", false))
		if not _visual_distances.has(racer_id):
			_visual_distances[racer_id] = target_distance
			_visual_offsets[racer_id] = target_offset
			_apply_visual_pose(_visuals[racer_id], target_distance, target_offset)
		if racer_id == "player-1":
			var actual_speed := float(racer.get("actual_speed_kmh", racer.get("speed", 0.0)))
			var lines := PackedStringArray([
				"M5 オンライン",
				"残り %.0fm" % maxf(_race_distance - float(racer.get("race_progress", 0.0)), 0.0),
				"目標 %.1fkm/h" % float(racer.get("target_speed", 0.0)),
				"実測 %.1fkm/h" % actual_speed,
			])
			lines.append_array(DraftHudFormatter.status_lines(
				racer, DraftRules.wake_reference_p(), true
			))
			lines.append("タイム %s" % _format_race_time(float(payload.get("elapsed_seconds", 0.0))))
			_hud_label.text = "\n".join(lines)

func _on_race_result(payload: Dictionary) -> void:
	_race_result_received = true
	_visual_hold_remaining = RESULT_VISUAL_HOLD_SECONDS
	_visuals_stopped = false
	_paused = false
	_pause_panel.visible = false
	var lines := PackedStringArray()
	for result in payload.get("results", []):
		lines.append("%d着　%s　%s" % [
			int(result.get("rank", 0)),
			str(result.get("id", "")),
			_format_result_time(float(result.get("finish_time", result.get("time", 0.0)))),
		])
	_result_label.text = "\n".join(lines)
	_result_panel.visible = true
	_result_return_button.grab_focus()

func _set_paused(paused: bool) -> void:
	if _race_result_received:
		return
	_paused = paused
	_pause_panel.visible = paused
	if paused:
		_resume_button.grab_focus()

func _on_connection_error(message: String) -> void:
	_hud_label.text = "M5 オンライン　%s" % message

func _create_visual(racer_id: String, index: int) -> void:
	var body := MeshInstance3D.new()
	body.name = racer_id
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	body.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = PururinVisualStyle.color_for_racer_id(racer_id)
	body.material_override = material
	_runners_root.add_child(body)
	_visuals[racer_id] = body
	if racer_id == "player-1":
		_camera.set_follow_target(body)

func _place_markers() -> void:
	_place_line_marker(_goal_marker, _goal_path, Color(0.98, 0.98, 1.0))
	_goal_visual.place(_track, _goal_path, 15.0)
	_place_route_line_marker(_start_marker, 0.0, Color(0.2, 0.85, 0.45))
	_update_launch_visual()

func _set_route(distance_m: float) -> void:
	var next_route := M5CourseBuilder.route_for_distance(_layout, distance_m)
	if next_route.is_empty():
		return
	_route = next_route
	_race_distance = float(_route.get("distance_m", distance_m))
	_place_markers()


func _update_launch_visual() -> void:
	if _launch_visual == null or _track == null or _track.curve == null:
		return
	var segments: Array = _route.get("segments", [])
	if segments.is_empty() or str(segments[0].get("type", "")) != "straight":
		_launch_visual.visible = false
		return
	var launch_length := float(segments[0].get("distance_m", 0.0))
	var start_distance := fposmod(float(_route.get("start_mainline_m", 0.0)), _track_length)
	var start_xf := _track.curve.sample_baked_with_rotation(start_distance)
	# 1600mのスタート直線は、本線の接続点から逆向きへ延ばす。
	var travel := start_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(15.0, 0.12, launch_length)
	_launch_visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.38, 0.32)
	material.roughness = 0.9
	_launch_visual.material_override = material
	_launch_visual.visible = true
	_launch_visual.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		start_xf.origin + travel * launch_length * 0.5 + Vector3.UP * 0.06
	)

func _place_line_marker(node: MeshInstance3D, path_distance: float, color: Color) -> void:
	if node == null or _track == null or _track.curve == null:
		return
	var curve_xf := _track.curve.sample_baked_with_rotation(path_distance)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	var box := BoxMesh.new()
	box.size = Vector3(15.0, 0.035, 0.12)
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 1.2
	material.emission_energy_multiplier = 2.0
	node.material_override = material
	node.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 0.14
	)


func _place_route_line_marker(node: MeshInstance3D, route_distance: float, color: Color) -> void:
	if node == null or _track == null or _track.curve == null:
		return
	var pose := M5CourseBuilder.route_pose(_track.curve, _route, route_distance, _track_length)
	if pose.is_empty():
		return
	var travel: Vector3 = pose.get("travel", Vector3(0.0, 0.0, -1.0))
	var box := BoxMesh.new()
	box.size = Vector3(15.0, 0.035, 0.12)
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 1.2
	material.emission_energy_multiplier = 2.0
	node.material_override = material
	node.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		pose.get("position", Vector3.ZERO) + Vector3.UP * 0.14
	)

func _apply_visual_pose(visual: Node3D, distance: float, offset: float) -> void:
	if _track == null or _track.curve == null:
		return
	var pose := M5CourseBuilder.route_pose(_track.curve, _route, distance, _track_length)
	if pose.is_empty():
		return
	var centerline_local: Vector3 = pose.get("position", Vector3.ZERO)
	var outward: Vector3 = pose.get("outward", _stadium_outward(centerline_local))
	var pos_local := centerline_local + outward * offset + Vector3.UP * 0.75
	var travel: Vector3 = pose.get("travel", Vector3(0.0, 0.0, -1.0))
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	visual.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		pos_local
	)

func _stadium_outward(pos: Vector3) -> Vector3:
	var half_s := _straight_len * 0.5
	var eps := 0.05
	var right := Vector3(pos.x - half_s, 0.0, pos.z)
	var left := Vector3(pos.x + half_s, 0.0, pos.z)
	if right.length() <= _turn_radius + eps and pos.x >= half_s - eps:
		return right.normalized() if right.length_squared() >= 0.0001 else Vector3.RIGHT
	if left.length() <= _turn_radius + eps and pos.x <= -half_s + eps:
		return left.normalized() if left.length_squared() >= 0.0001 else Vector3.LEFT
	return Vector3.FORWARD if pos.z < 0.0 else Vector3.BACK

func _format_race_time(seconds: float) -> String:
	var total_hundredths := maxi(0, roundi(seconds * 100.0))
	var minutes := total_hundredths / 6000
	var remaining_hundredths := total_hundredths % 6000
	return "%d:%02d.%02d" % [
		minutes,
		remaining_hundredths / 100,
		remaining_hundredths % 100,
	]

func _format_result_time(seconds: float) -> String:
	var total_hundredths := maxi(0, roundi(seconds * 100.0))
	var minutes := total_hundredths / 6000
	var remaining_hundredths := total_hundredths % 6000
	return "%d:%02d.%02d" % [
		minutes,
		remaining_hundredths / 100,
		remaining_hundredths % 100,
	]

func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
