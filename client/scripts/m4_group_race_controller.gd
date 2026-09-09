extends Node3D
## M4 集団プロトタイプ。プレイヤー＋内側型＋外側型の3体を生成する。

const M4GroupRaceMath := preload("res://scripts/m4_group_race_math.gd")
const RunnerScript := preload("res://scripts/runner_m4.gd")
const TITLE_SCENE := "res://scenes/m3_intro.tscn"
const RUNNER_COLORS := [
	Color(1.0, 0.45, 0.2),
	Color(0.25, 0.75, 1.0),
	Color(0.95, 0.92, 0.35),
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
var _player: Node3D
var _paused := false
var _race_over := false
var _finish_count := 0
var _race_elapsed := 0.0
var _results_pending := false
var _results_wait_remaining := 0.0

func _ready() -> void:
	print("ぷるりんレーサーズ — M4 集団プロトタイプを開始します")
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _runners.is_empty():
		return
	if not _paused and not _race_over:
		_race_elapsed += delta
	_share_snapshots()
	_resolve_contacts()
	_check_finishes()
	if _results_pending and not _race_over and not _paused:
		_results_wait_remaining -= delta
		if _results_wait_remaining <= 0.0:
			_show_results()
	_update_hud()

func _spawn_field() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	for index in 3:
		var role: String = ["player", "inner", "outer"][index]
		var runner := Node3D.new()
		runner.name = "M4Runner%d" % (index + 1)
		runner.set_script(RunnerScript)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = sphere
		body.position = Vector3(0.0, 0.75, 0.0)
		var material := StandardMaterial3D.new()
		material.albedo_color = RUNNER_COLORS[index]
		body.material_override = material
		runner.add_child(body)
		_runners_root.add_child(runner)
		runner.call("setup_for_race", _track, role, index == 0)
		_runners.append(runner)
		if index == 0:
			_player = runner
			_camera.set_follow_target(runner)
			_camera.overview_ortho_size = 560.0
			_camera.overview_height = 500.0

func _place_markers() -> void:
	_place_line_marker(_goal_marker, M4GroupRaceMath.GOAL_PATH_DISTANCE_M, Color(0.95, 0.95, 0.95))
	_place_line_marker(_start_marker, M4GroupRaceMath.START_PATH_DISTANCE_M, Color(0.2, 0.85, 0.45))

func _place_line_marker(node: MeshInstance3D, path_distance: float, color: Color) -> void:
	var xf := _track.curve.sample_baked_with_rotation(path_distance)
	var travel := -xf.basis.z
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
		Basis.looking_at(travel, Vector3.UP), xf.origin + Vector3.UP * 0.14
	)

func _share_snapshots() -> void:
	var snapshots: Array = []
	for runner in _runners:
		snapshots.append(runner.call("get_snapshot"))
	for index in _runners.size():
		var others: Array = snapshots.duplicate()
		others.remove_at(index)
		_runners[index].call("set_others_snapshot", others)

func _resolve_contacts() -> void:
	for i in _runners.size():
		for j in range(i + 1, _runners.size()):
			var first := _runners[i]
			var second := _runners[j]
			if not M4GroupRaceMath.contact_overlaps(
				first.call("get_race_progress"), first.call("get_offset"),
				second.call("get_race_progress"), second.call("get_offset")
			):
				continue
			if first.call("get_race_progress") > second.call("get_race_progress"):
				second.call("hold_behind", first.call("get_distance"), first.call("get_race_progress"), _track.curve.get_baked_length())
			else:
				first.call("hold_behind", second.call("get_distance"), second.call("get_race_progress"), _track.curve.get_baked_length())

func _check_finishes() -> void:
	for runner in _runners:
		if not runner.call("is_finished") and runner.call("get_race_progress") >= M4GroupRaceMath.RACE_DISTANCE_M:
			_finish_count += 1
			runner.call("mark_finished", _finish_count, _race_elapsed)
	if _finish_count == _runners.size() and not _results_pending:
		_results_pending = true
		_results_wait_remaining = 1.5

func _update_hud() -> void:
	if _player == null:
		return
	var drafting := "ドラフト中" if _player.call("is_drafting") else "単独走"
	_hud_label.text = "M4 集団レース　残り %.0fm　目標 %.0fkm/h　現在 %.0fkm/h　タイム %s　%s　Esc＝メニュー" % [
		maxf(M4GroupRaceMath.RACE_DISTANCE_M - _player.call("get_race_progress"), 0.0),
		_player.call("get_target_speed"),
		_player.call("get_current_speed"),
		M4GroupRaceMath.format_race_time(_race_elapsed),
		drafting,
	]

func _show_results() -> void:
	_race_over = true
	_set_paused(true)
	_result_panel.visible = true
	var ordered := _runners.duplicate()
	ordered.sort_custom(func(a, b): return a.call("get_finish_order") < b.call("get_finish_order"))
	var lines := PackedStringArray()
	for runner in ordered:
		lines.append(
			"%d着　%s　%s" % [
				runner.call("get_finish_order"),
				runner.call("get_display_name"),
				M4GroupRaceMath.format_race_time(runner.call("get_finish_time")),
			]
		)
	_result_label.text = "\n".join(lines)
	_result_return_button.grab_focus()

func _set_paused(paused: bool) -> void:
	_paused = paused
	for runner in _runners:
		runner.call("set_paused", paused or _race_over)
	_pause_panel.visible = paused and not _race_over
	if paused and not _race_over:
		_resume_button.grab_focus()

func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE_SCENE)
