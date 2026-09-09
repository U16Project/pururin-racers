extends Node3D
## M5: サーバーの race_tick を描画し、目標値だけを送る。

const NetRace := preload("res://scripts/net_race_m5.gd")
const M2TrackMath := preload("res://scripts/m2_track_math.gd")
const M4GroupRaceMath := preload("res://scripts/m4_group_race_math.gd")
const TITLE_SCENE := "res://scenes/m3_intro.tscn"
const MAX_DRAFT_RECEIVED_P := 0.24
const COLORS := [
	Color(1.0, 0.45, 0.2), Color(0.25, 0.75, 1.0), Color(0.95, 0.92, 0.35),
	Color(0.75, 0.35, 0.95), Color(0.35, 0.9, 0.55), Color(0.95, 0.55, 0.7),
	Color(0.55, 0.7, 0.95), Color(0.9, 0.7, 0.35),
]

@onready var _runners_root: Node3D = $Runners
@onready var _track: Path3D = $TrackPath
@onready var _camera: Camera3D = $Camera3D
@onready var _hud_label: Label = %HudLabel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _result_return_button: Button = %ResultReturnButton
@onready var _start_marker: MeshInstance3D = $StartMarker
@onready var _goal_marker: MeshInstance3D = $GoalMarker

var _net: Node
var _visuals: Dictionary = {}
var _visual_targets: Dictionary = {}
var _visual_distances: Dictionary = {}
var _visual_offsets: Dictionary = {}
var _visual_finished: Dictionary = {}
var _latest: Dictionary = {}
var _target_speed := 58.0
var _target_offset := -3.0
var _straight_len := 526.0
var _turn_radius := 164.0

func _ready() -> void:
	_straight_len = _track.get_straight_len()
	_turn_radius = _track.get_turn_radius()
	_result_panel.visible = false
	_result_return_button.pressed.connect(_return_to_title)
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_LEFT:
			_target_offset = maxf(-6.0, _target_offset - 0.5)
		elif event.physical_keycode == KEY_RIGHT:
			_target_offset = minf(6.0, _target_offset + 0.5)
		elif event.physical_keycode == KEY_UP:
			_target_speed = minf(75.0, _target_speed + 1.0)
		elif event.physical_keycode == KEY_DOWN:
			_target_speed = maxf(45.0, _target_speed - 1.0)
		else:
			return
		_net.send_input(_target_speed, _target_offset)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _track == null or _track.curve == null:
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
		var distance_delta := fposmod(target.x - current_distance + path_length * 0.5, path_length) - path_length * 0.5
		current_distance = fposmod(current_distance + distance_delta * smoothing, path_length)
		current_offset = lerpf(current_offset, target.y, smoothing)
		_visual_distances[racer_id] = current_distance
		_visual_offsets[racer_id] = current_offset
		_apply_visual_pose(_visuals[racer_id], current_distance, current_offset)

func _on_race_started(payload: Dictionary) -> void:
	_hud_label.text = "M5 オンラインレース　サーバー判定中"
	_on_race_tick({"racers": payload.get("racers", [])})

func _on_race_tick(payload: Dictionary) -> void:
	_latest = payload
	for racer in payload.get("racers", []):
		var racer_id := str(racer.get("id", ""))
		if not _visuals.has(racer_id):
			_create_visual(racer_id, _visuals.size())
		var target_distance := float(racer.get("distance", 0.0))
		var target_offset := float(racer.get("offset", 0.0))
		_visual_targets[racer_id] = Vector2(target_distance, target_offset)
		_visual_finished[racer_id] = bool(racer.get("finished", false))
		if not _visual_distances.has(racer_id):
			_visual_distances[racer_id] = target_distance
			_visual_offsets[racer_id] = target_offset
			_apply_visual_pose(_visuals[racer_id], target_distance, target_offset)
		if racer_id == "player-1":
			var draft_text := _draft_status_text(racer)
			_hud_label.text = "M5 オンライン　残り %.0fm　目標 %.1fkm/h　現在 %.1fkm/h" % [
				maxf(2000.0 - float(racer.get("race_progress", 0.0)), 0.0),
				float(racer.get("target_speed", 0.0)),
				float(racer.get("speed", 0.0)),
			]
			_hud_label.text += "\nタイム %s　%s" % [
				_format_race_time(float(payload.get("elapsed_seconds", 0.0))),
				draft_text,
			]

func _draft_status_text(racer: Dictionary) -> String:
	var direct_source_ids: Array = racer.get("direct_source_ids", [])
	if direct_source_ids.is_empty():
		return "単独走（ドラフト 0%）"
	var direct_percent := maxf(0.0, float(racer.get("direct_draft_p", 0.0))) / MAX_DRAFT_RECEIVED_P * 100.0
	var chain_percent := maxf(0.0, float(racer.get("chain_draft_p", 0.0))) / MAX_DRAFT_RECEIVED_P * 100.0
	return "ドラフト 直接 %.0f%% ＋ 連鎖 %.0f%%　対象 %s　前方 %.1fm　横 %.1fm" % [
		direct_percent,
		chain_percent,
		str(racer.get("primary_source_id", direct_source_ids[0])),
		float(racer.get("primary_gap_m", 0.0)),
		float(racer.get("primary_line_gap_m", 0.0)),
	]

func _on_race_result(payload: Dictionary) -> void:
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
	material.albedo_color = COLORS[index % COLORS.size()]
	body.material_override = material
	_runners_root.add_child(body)
	_visuals[racer_id] = body
	if racer_id == "player-1":
		_camera.set_follow_target(body)

func _place_markers() -> void:
	_place_line_marker(_goal_marker, M4GroupRaceMath.GOAL_PATH_DISTANCE_M, Color(0.95, 0.95, 0.95))
	_place_line_marker(_start_marker, M4GroupRaceMath.START_PATH_DISTANCE_M, Color(0.2, 0.85, 0.45))

func _place_line_marker(node: MeshInstance3D, path_distance: float, color: Color) -> void:
	if node == null or _track == null or _track.curve == null:
		return
	var curve_xf := _track.curve.sample_baked_with_rotation(path_distance)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	var box := BoxMesh.new()
	box.size = Vector3(15.0, 0.025, 1.5)
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.35
	node.material_override = material
	node.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 0.14
	)

func _apply_visual_pose(visual: Node3D, distance: float, offset: float) -> void:
	if _track == null or _track.curve == null:
		return
	var path_length := _track.curve.get_baked_length()
	var path_distance := fposmod(distance, path_length)
	var local_xf := _track.curve.sample_baked_with_rotation(path_distance)
	var centerline_local := local_xf.origin
	var outward := M2TrackMath.stadium_outward(centerline_local, _straight_len, _turn_radius)
	var pos_local := centerline_local + outward * offset + Vector3.UP * 0.75
	var travel := -local_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	visual.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		pos_local
	)

func _format_race_time(seconds: float) -> String:
	var total_tenths := maxi(0, roundi(seconds * 10.0))
	var minutes := total_tenths / 600
	var remaining_tenths := total_tenths % 600
	return "%d:%02d.%d" % [minutes, remaining_tenths / 10, remaining_tenths % 10]

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
