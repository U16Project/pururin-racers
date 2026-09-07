extends Node3D
## ローカル簡易レースの進行・UI・8 頭生成。


const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")

const TITLE_SCENE := "res://scenes/m3_intro.tscn"
const RUNNER_COLORS := [
	Color(1.0, 0.45, 0.2),
	Color(0.25, 0.75, 1.0),
	Color(0.95, 0.92, 0.35),
	Color(0.75, 0.35, 0.95),
	Color(0.35, 0.9, 0.55),
	Color(0.95, 0.55, 0.7),
	Color(0.55, 0.7, 0.95),
	Color(0.9, 0.7, 0.35),
]

@onready var _track: Path3D = $TrackPath
@onready var _runners_root: Node3D = $Runners
@onready var _hud_label: Label = %HudLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _pause_return_button: Button = %PauseReturnButton
@onready var _result_return_button: Button = %ResultReturnButton
@onready var _resume_button: Button = %ResumeButton
@onready var _camera: Camera3D = $Camera3D
@onready var _start_marker: MeshInstance3D = $StartMarker
@onready var _goal_marker: MeshInstance3D = $GoalMarker

var _runners: Array[Node3D] = []
var _paused: bool = false
var _race_over: bool = false
var _finish_count: int = 0
var _race_elapsed: float = 0.0
var _results_pending: bool = false
var _results_wait_remaining: float = 0.0
var _player: Node3D = null


func _ready() -> void:
	print("ぷるりんレーサーズ — ローカル簡易レースを開始します")
	_pause_panel.visible = false
	_result_panel.visible = false
	_pause_return_button.pressed.connect(_return_to_title)
	_result_return_button.pressed.connect(_return_to_title)
	_resume_button.pressed.connect(_set_paused.bind(false))
	_place_markers()
	_spawn_field()


func _unhandled_input(event: InputEvent) -> void:
	if _race_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _runners.is_empty():
		return
	if not _paused and not _race_over:
		_race_elapsed += _delta
	_resolve_contacts()
	_share_snapshots()
	_check_finishes()
	if _results_pending and not _race_over and not _paused:
		_results_wait_remaining -= _delta
		if _results_wait_remaining <= 0.0:
			_show_results()
	_update_hud()


func _spawn_field() -> void:
	for child in _runners_root.get_children():
		child.queue_free()
	_runners.clear()
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	for i in LocalRaceMath.FIELD_SIZE:
		var runner := Node3D.new()
		runner.name = "Runner%d" % (i + 1)
		runner.set_script(RunnerScript)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = sphere
		body.position = Vector3(0.0, 0.75, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = RUNNER_COLORS[i % RUNNER_COLORS.size()]
		mat.roughness = 0.4
		body.material_override = mat
		runner.add_child(body)
		_runners_root.add_child(runner)
		var is_player := i == 0
		var label := "あなた" if is_player else "CPU%d" % (i + 1)
		var tier := LocalRaceMath.PLAYER_MAX_SPEED if is_player else LocalRaceMath.tier_speed_for_index(i + 1)
		runner.call(
			"setup_for_race",
			_track,
			i,
			tier,
			is_player,
			label
		)
		_runners.append(runner)
		if is_player:
			_player = runner
			if _camera:
				if _camera.has_method("set_follow_target"):
					_camera.call("set_follow_target", runner)
				_camera.set("overview_ortho_size", 560.0)
				_camera.set("overview_height", 500.0)


func _place_markers() -> void:
	if _track == null or _track.curve == null:
		return
	_place_line_marker(
		_goal_marker,
		LocalRaceMath.GOAL_PATH_DISTANCE_M,
		Color(0.95, 0.95, 0.95)
	)
	_place_line_marker(_start_marker, LocalRaceMath.START_PATH_DISTANCE_M, Color(0.2, 0.85, 0.45))


func _place_line_marker(node: MeshInstance3D, path_d: float, color: Color) -> void:
	var xf: Transform3D = _track.curve.sample_baked_with_rotation(path_d)
	var travel := -xf.basis.z
	travel.y = 0.0
	if travel.length_squared() < 1e-8:
		travel = Vector3(0.0, 0.0, -1.0)
	else:
		travel = travel.normalized()
	var box := BoxMesh.new()
	# X = コース横断、Z = 進行方向の幅を持つ、地面より上の帯。
	box.size = Vector3(15.0, 0.025, 1.5)
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.35
	node.material_override = mat
	var basis := Basis.looking_at(travel, Vector3.UP)
	node.global_transform = _track.global_transform * Transform3D(
		basis,
		xf.origin + Vector3.UP * 0.14
	)


func _resolve_contacts() -> void:
	var path_length := _track.curve.get_baked_length()
	for i in _runners.size():
		var first: Node3D = _runners[i]
		if first.call("is_finished"):
			continue
		for j in range(i + 1, _runners.size()):
			var second: Node3D = _runners[j]
			if second.call("is_finished"):
				continue
			var first_progress: float = first.call("get_race_progress")
			var second_progress: float = second.call("get_race_progress")
			var first_offset: float = first.call("get_offset")
			var second_offset: float = second.call("get_offset")
			if not LocalRaceMath.contact_overlaps(
				first_progress,
				first_offset,
				second_progress,
				second_offset
			):
				continue
			if first_progress > second_progress:
				second.call(
					"hold_behind",
					first.call("get_distance"),
					first_progress,
					path_length
				)
			elif second_progress > first_progress:
				first.call(
					"hold_behind",
					second.call("get_distance"),
					second_progress,
					path_length
				)


func _share_snapshots() -> void:
	var snaps: Array = []
	for r in _runners:
		snaps.append(r.call("get_snapshot"))
	for r in _runners:
		var others: Array = []
		var self_snap: Dictionary = r.call("get_snapshot")
		for s in snaps:
			if s.get("gate", -1) == self_snap.get("gate", -2):
				continue
			others.append(s)
		r.call("set_others_snapshot", others)


func _check_finishes() -> void:
	if _race_over:
		return
	for r in _runners:
		if r.call("is_finished"):
			continue
		if LocalRaceMath.has_finished(r.call("get_race_progress")):
			_finish_count += 1
			r.call("mark_finished", _finish_count, _race_elapsed)
	var all_done := true
	for r in _runners:
		if not r.call("is_finished"):
			all_done = false
			break
	if all_done and not _results_pending:
		_results_pending = true
		_results_wait_remaining = 2.0


func _update_hud() -> void:
	if _player == null:
		return
	var order := _live_place(_player)
	var prog: float = _player.call("get_race_progress")
	var tgt: float = _player.call("get_target_speed")
	var cur: float = _player.call("get_current_speed")
	_hud_label.text = "順位 %d／8　残り %.0fm　目標 %.0f　現在 %.1f　タイム %s　Esc＝メニュー" % [
		order,
		maxf(LocalRaceMath.RACE_DISTANCE_M - prog, 0.0),
		tgt,
		cur,
		LocalRaceMath.format_race_time(_race_elapsed),
	]


func _live_place(runner: Node3D) -> int:
	var my_prog: float = runner.call("get_race_progress")
	var better := 0
	for r in _runners:
		if r == runner:
			continue
		if r.call("is_finished"):
			better += 1
			continue
		if r.call("get_race_progress") > my_prog + 0.001:
			better += 1
	return better + 1


func _show_results() -> void:
	_race_over = true
	_set_paused(true)
	_pause_panel.visible = false
	_result_panel.visible = true
	var lines: PackedStringArray = []
	var ordered: Array = _runners.duplicate()
	ordered.sort_custom(func(a, b): return a.call("get_finish_order") < b.call("get_finish_order"))
	for r in ordered:
		var ord: int = r.call("get_finish_order")
		var nm: String = r.get("display_name")
		var finish_time: float = r.call("get_finish_time")
		lines.append(
			"%d着　%s　%s" % [
				ord,
				nm,
				LocalRaceMath.format_race_time(finish_time),
			]
		)
	_result_label.text = "\n".join(lines)
	_result_return_button.grab_focus()


func _set_paused(paused: bool) -> void:
	_paused = paused
	for r in _runners:
		r.call("set_paused", paused or _race_over)
	if _race_over:
		_pause_panel.visible = false
		return
	_pause_panel.visible = paused
	if paused:
		_resume_button.grab_focus()


func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
