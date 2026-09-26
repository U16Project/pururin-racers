extends Node3D

const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
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
@onready var _guide_label: Label = $UI/GuideLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _result_panel: Control = %ResultPanel
@onready var _result_label: Label = %ResultLabel
@onready var _pause_return_button: Button = %PauseReturnButton
@onready var _result_return_button: Button = %ResultReturnButton
@onready var _resume_button: Button = %ResumeButton
@onready var _camera: Camera3D = $Camera3D
@onready var _start_marker: MeshInstance3D = $StartMarker
@onready var _goal_marker: MeshInstance3D = $GoalMarker

var _goal_visual := GoalVisual.new()

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
	var course_result := M5CourseBuilder.load_layout_result()
	if course_result.has("error"):
		_hud_label.text = "コース設定を確認してください：" + str(course_result.error)
		set_process(false)
		return
	LocalRaceMath.apply_course_to_path(_track)
	if LocalRaceMath.Config.values().is_empty():
		_hud_label.text = "レース設定を確認してください：" + LocalRaceMath.Config.last_error
		set_process(false)
		return
	if LocalRaceMath.DraftRules.values().is_empty():
		_hud_label.text = "ドラフト設定を確認してください：" + LocalRaceMath.DraftRules.last_error
		set_process(false)
		return
	_place_markers()
	_spawn_field()
	_guide_label.text = "←→：ライン　↑↓：出力ノッチ　V：目標速度方式へ切替　C：視点切替　CHASE中 WASD：追従調整　QE：向き　R：リセット　Esc：メニュー　緑＝スタート／発光＝ゴール"


func _unhandled_input(event: InputEvent) -> void:
	if _race_over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_V and _player != null:
			_player.call("toggle_drive_mode")
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _runners.is_empty():
		return
	if not _paused and not _race_over:
		_race_elapsed += _delta
		# ランナーは前tickに確定したドラフト値を使って移動する。
		# 移動と接触解決が終わってから、次tick用のドラフトを一括計算する。
		_share_snapshots()
		call_deferred("_finalize_draft_tick")
	if _results_pending and not _race_over and not _paused:
		_results_wait_remaining -= _delta
		if _results_wait_remaining <= 0.0:
			_show_results()
	_update_hud()


func _finalize_draft_tick() -> void:
	if _paused or _race_over or _runners.is_empty():
		return
	_resolve_contacts()
	# M5オンラインと同じく、移動後のゴール判定を先に確定する。
	# 着順とタイムを確定した後も、結果表示までは全員が接触・ドラフトを続ける。
	_check_finishes()
	var snapshots: Array = []
	for runner in _runners:
		snapshots.append(runner.call("get_snapshot"))
	for index in _runners.size():
		var details: Dictionary = LocalRaceMath.calculate_draft_details(snapshots, index)
		_runners[index].call("apply_draft_details", details)


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
		var tier := (
			LocalRaceMath.PLAYER_MAX_SPEED_KMH
			if is_player
			else LocalRaceMath.tier_speed_kmh_for_index(i + 1)
		)
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
		LocalRaceMath.goal_path_m(),
		Color(0.95, 0.95, 0.95)
	)
	_goal_visual.place(_track, LocalRaceMath.goal_path_m(), 15.0)
	_place_line_marker(_start_marker, LocalRaceMath.start_path_m(), Color(0.2, 0.85, 0.45))


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
	box.size = Vector3(15.0, 0.035, 0.12)
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 1.2
	mat.emission_energy_multiplier = 2.0
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
		for j in range(i + 1, _runners.size()):
			var second: Node3D = _runners[j]
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
	var lines := PackedStringArray([
		"順位 %d／8" % order,
		"残り %.0fm" % maxf(LocalRaceMath.RACE_DISTANCE_M - prog, 0.0),
	])
	if _player.call("is_drive_mode"):
		lines.append("出力 %+d" % int(roundi(_player.call("get_drive_level"))))
		lines.append("心拍(仮) %.0f" % _player.call("get_heart_rate_bpm"))
		lines.append("スタミナ(仮) %.0f%%" % _player.call("get_stamina"))
		lines.append_array(_drive_diagnostic_hud_lines(_player.call("get_drive_diagnostics")))
	else:
		lines.append("目標 %.0fkm/h" % tgt)
	lines.append_array(DraftHudFormatter.status_lines(
		_player.call("get_draft_status"), LocalRaceMath.DRAFT_MAX_RECEIVED_P, false, true, true
	))
	lines.append("現在 %.0fkm/h" % cur)
	lines.append("タイム %s" % LocalRaceMath.format_race_time(_race_elapsed))
	lines.append("Esc＝メニュー")
	_hud_label.text = "\n".join(lines)


func _drive_diagnostic_hud_lines(diagnostics: Dictionary) -> PackedStringArray:
	var drive_contribution := float(diagnostics.get("drive_contribution_kmh_per_s", 0.0))
	var drive_label := "制動" if drive_contribution < 0.0 else "推進力"
	return PackedStringArray([
		"%s %+.2fkm/h/s" % [drive_label, drive_contribution],
		"転がり抵抗 %+.2fkm/h/s" % -float(diagnostics.get("rolling_resistance_kmh_per_s", 0.0)),
		"空気抵抗（二乗） %+.2fkm/h/s" % -float(diagnostics.get("air_resistance_kmh_per_s", 0.0)),
		"ドラフト軽減 %+.2fkm/h/s" % float(diagnostics.get("draft_air_reduction_kmh_per_s", 0.0)),
		"計算加速度 %+.2fkm/h/s" % float(diagnostics.get("total_acceleration_kmh_per_s", 0.0)),
	])


func _live_place(runner: Node3D) -> int:
	var my_prog: float = runner.call("get_race_progress")
	var my_finished: bool = runner.call("is_finished")
	var my_finish_order: int = runner.call("get_finish_order")
	var better := 0
	for r in _runners:
		if r == runner:
			continue
		var other_finished: bool = r.call("is_finished")
		if my_finished:
			# ゴール済み同士は、進捗ではなく確定した着順だけで比較する。
			if other_finished and r.call("get_finish_order") < my_finish_order:
				better += 1
			continue
		if other_finished:
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
