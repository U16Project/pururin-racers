extends Node3D

const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RaceTelemetryRecorder := preload("res://scripts/race_telemetry_recorder.gd")
## ローカル簡易レースの進行・UI・8プル生成。


const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinVisualStyle := preload("res://scripts/pururin_visual_style.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")

const TITLE_SCENE := "res://scenes/m3_intro.tscn"
@onready var _track: Path3D = $TrackPath
@onready var _runners_root: Node3D = $Runners
@onready var _hud_label: Label = %HudLabel
@onready var _guide_label: Label = $UI/GuideLabel
@onready var _countdown_label: Label = %CountdownLabel
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
var _race_started: bool = false
var _start_countdown_remaining: float = 0.0
var _start_signal_remaining: float = 0.0
var _race_distance_m: float = RaceSession.DEFAULT_DISTANCE_M
var _race_route: Dictionary = {}
var _launch_visual: MeshInstance3D
var _telemetry_recorder := RaceTelemetryRecorder.new()


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
	_race_distance_m = RaceSession.selected_distance_m()
	_race_route = M5CourseBuilder.route_for_distance(
		M5CourseBuilder.load_layout(), _race_distance_m
	)
	_launch_visual = MeshInstance3D.new()
	_launch_visual.name = "RouteLaunchStraight"
	_track.add_child(_launch_visual)
	if LocalRaceMath.Config.values().is_empty():
		_hud_label.text = "レース設定を確認してください：" + LocalRaceMath.Config.last_error
		set_process(false)
		return
	if LocalRaceMath.DraftRules.values().is_empty():
		_hud_label.text = "ドラフト設定を確認してください：" + LocalRaceMath.DraftRules.last_error
		set_process(false)
		return
	if PururinRosterConfig.values().is_empty():
		_hud_label.text = "ぷるりん設定を確認してください：" + PururinRosterConfig.last_error
		set_process(false)
		return
	_place_markers()
	_spawn_field()
	_start_countdown_remaining = LocalRaceMath.Config.number("start_countdown_seconds")
	if _player != null:
		_player.call("set_drive_level", LocalRaceMath.Config.number("player_start_drive_level"))
	_guide_label.text = "←→／左スティック：ライン　↑↓／十字キー：出力ノッチ　Y/C：視点切替　右スティック左右／QE：向き　右スティック押込／R：リセット　Start/Esc：メニュー"


func _unhandled_input(event: InputEvent) -> void:
	if RaceControllerInput.is_button_pressed(event, JOY_BUTTON_A) and RaceControllerInput.activate_focused_control(get_viewport()):
		get_viewport().set_input_as_handled()
		return
	if _race_over:
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
		elif event.physical_keycode == KEY_V and _race_started and _player != null:
			_player.call("toggle_drive_mode")
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _runners.is_empty():
		return
	if not _paused and not _race_started:
		_update_start_countdown(_delta)
	elif not _paused and not _race_over:
		_update_start_signal(_delta)
		_race_elapsed += _delta
		# ランナーは前tickに確定したドラフト値を使って移動する。
		# 移動と接触解決が終わってから、次tick用のドラフトを一括計算する。
		_share_snapshots()
		call_deferred("_finalize_draft_tick")
		_telemetry_recorder.record_sample(_race_elapsed, _runners)
	if _results_pending and not _race_over and not _paused:
		_results_wait_remaining -= _delta
		if _results_wait_remaining <= 0.0:
			_show_results()
	_update_hud()


func _update_start_countdown(delta: float) -> void:
	_start_countdown_remaining = maxf(_start_countdown_remaining - delta, 0.0)
	if _start_countdown_remaining > 0.0:
		_countdown_label.text = "スタートまで %d" % ceili(_start_countdown_remaining)
		return
	_race_started = true
	_telemetry_recorder.start(_race_distance_m)
	_countdown_label.text = "START!"
	_start_signal_remaining = 0.8
	for runner in _runners:
		runner.call("set_race_active", true)


func _update_start_signal(delta: float) -> void:
	if _start_signal_remaining <= 0.0:
		return
	_start_signal_remaining = maxf(_start_signal_remaining - delta, 0.0)
	if _start_signal_remaining <= 0.0:
		_countdown_label.visible = false


func _finalize_draft_tick() -> void:
	if _paused or _race_over or _runners.is_empty():
		return
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
	_player = null
	var sphere := SphereMesh.new()
	sphere.radius = 0.75
	sphere.height = 1.5
	var selected_player_id := RaceSession.selected_player_pururin_id()
	var roster: Array = PururinRosterConfig.values()["roster"]
	var field_roster: Array = []
	# 選択した操作個体の開始ゲートは設定で変更できる。CPUには残りのゲートを順番に割り当てる。
	for pururin: Dictionary in roster:
		if str(pururin.get("id", "")) == selected_player_id:
			field_roster.append(pururin)
	for pururin: Dictionary in roster:
		if str(pururin.get("id", "")) != selected_player_id:
			field_roster.append(pururin)
	var player_gate := clampi(int(LocalRaceMath.Config.number("player_start_gate_index")), 0, LocalRaceMath.FIELD_SIZE - 1)
	var next_cpu_gate := 0
	for i in field_roster.size():
		var pururin: Dictionary = field_roster[i]
		var runner := Node3D.new()
		runner.name = "Runner%d" % (i + 1)
		runner.set_script(RunnerScript)
		var body := MeshInstance3D.new()
		body.name = "Body"
		body.mesh = sphere
		body.position = Vector3(0.0, 0.75, 0.0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = PururinVisualStyle.color_for_pururin(pururin)
		mat.roughness = 0.4
		body.material_override = mat
		runner.add_child(body)
		_runners_root.add_child(runner)
		var is_player: bool = str(pururin.get("id", "")) == selected_player_id
		var start_gate := player_gate if is_player else next_cpu_gate
		if not is_player:
			while next_cpu_gate == player_gate:
				next_cpu_gate += 1
			start_gate = next_cpu_gate
			next_cpu_gate += 1
		var label: String = pururin["display_name"]
		runner.call(
			"setup_for_race",
			_track,
			start_gate,
			LocalRaceMath.PLAYER_MAX_SPEED_KMH,
			is_player,
			label,
			pururin,
			_race_distance_m
		)
		_runners.append(runner)
		if is_player:
			_player = runner
			if _camera:
				if _camera.has_method("set_follow_target"):
					_camera.call("set_follow_target", runner)
				_camera.set("overview_ortho_size", 560.0)
				_camera.set("overview_height", 500.0)


## ヘッドレス統合シミュレーションが通常レースの生成済みランナーを再利用するための参照。
func get_runners_for_simulation() -> Array:
	return _runners.duplicate()


func _place_markers() -> void:
	if _track == null or _track.curve == null:
		return
	var goal_pose := M5CourseBuilder.route_pose(
		_track.curve, _race_route, _race_distance_m, LocalRaceMath.lap_length_m()
	)
	var goal_path := float(goal_pose.get("mainline_distance", LocalRaceMath.goal_path_m()))
	_place_line_marker(
		_goal_marker,
		goal_path,
		Color(0.95, 0.95, 0.95)
	)
	_goal_visual.place(_track, goal_path, 15.0)
	_place_route_marker(_start_marker, 0.0, Color(0.2, 0.85, 0.45))
	_update_launch_visual()


func _place_route_marker(node: MeshInstance3D, route_distance_m: float, color: Color) -> void:
	var pose := M5CourseBuilder.route_pose(
		_track.curve, _race_route, route_distance_m, LocalRaceMath.lap_length_m()
	)
	if pose.is_empty():
		return
	var box := BoxMesh.new()
	box.size = Vector3(15.0, 0.035, 0.12)
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 1.2
	mat.emission_energy_multiplier = 2.0
	node.material_override = mat
	var basis := Basis.looking_at(pose["travel"], Vector3.UP)
	node.global_transform = _track.global_transform * Transform3D(
		basis, pose["position"] + Vector3.UP * 0.14
	)


func _update_launch_visual() -> void:
	if _launch_visual == null:
		return
	var segments: Array = _race_route.get("segments", [])
	if segments.is_empty() or str(segments[0].get("type", "")) != "straight":
		_launch_visual.visible = false
		return
	var launch_length := float(segments[0].get("distance_m", 0.0))
	var join_pose := M5CourseBuilder.route_pose(
		_track.curve, _race_route, launch_length, LocalRaceMath.lap_length_m()
	)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(15.0, 0.12, launch_length)
	_launch_visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.38, 0.32, 1.0)
	mat.roughness = 0.9
	_launch_visual.material_override = mat
	_launch_visual.visible = true
	var travel: Vector3 = join_pose["travel"]
	var center: Vector3 = join_pose["position"] - travel * (launch_length * 0.5)
	_launch_visual.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP), center + Vector3.UP * 0.02
	)


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
		if LocalRaceMath.has_finished(r.call("get_race_progress"), _race_distance_m):
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
	if not _race_started:
		_hud_label.text = "\n".join(PackedStringArray([
			"開始出力 %+d" % int(roundi(_player.call("get_drive_level"))),
			"カウント中に↑↓で開始出力を選択",
			"Esc＝メニュー",
		]))
		return
	var order := _live_place(_player)
	var prog: float = _player.call("get_race_progress")
	var tgt: float = _player.call("get_target_speed")
	var cur: float = _player.call("get_current_speed")
	var lines := PackedStringArray([
		"順位 %d／8" % order,
		"残り %.0fm" % maxf(_race_distance_m - prog, 0.0),
	])
	if _player.call("is_drive_mode"):
		var effective_stats: Dictionary = _player.call("get_effective_stats")
		lines.append("出力 %+d" % int(roundi(_player.call("get_drive_level"))))
		if effective_stats.has("top_speed") and effective_stats.has("acceleration"):
			lines.append("最高速 有効%d　自然到達 %.1fkm/h" % [effective_stats["top_speed"], _player.call("get_natural_top_speed")])
			lines.append("加速 有効%d　加速応答 ×%.2f" % [effective_stats["acceleration"], _player.call("get_acceleration_response_multiplier")])
		if effective_stats.has("aero"):
			lines.append("空力 有効%d　抵抗補正 x%.2f" % [
				effective_stats["aero"],
				LocalRaceMath.aero_air_resistance_multiplier(int(effective_stats["aero"])),
			])
		lines.append("心拍 %.0f/%.0f" % [
			_player.call("get_heart_rate_bpm"),
			LocalRaceMath.Config.number("heart_rate_normal_max_bpm"),
		])
		lines.append("200超過 負荷 %.1fs　推進効率 %.0f%%" % [
			_player.call("get_heart_overage_exposure"),
			_player.call("get_propulsion_efficiency") * 100.0,
		])
		lines.append("燃料 %.1f / %.1fL（%.0f%%）" % [
			_player.call("get_stamina"),
			_player.call("get_stamina_capacity_l"),
			_player.call("get_stamina_ratio") * 100.0,
		])
		lines.append_array(_drive_diagnostic_hud_lines(_player.call("get_drive_diagnostics")))
	else:
		lines.append("目標 %.0fkm/h" % tgt)
	lines.append_array(DraftHudFormatter.status_lines(
		# ローカルは速度上限を直接上げず、空気抵抗軽減で自然に速度が伸びる。
		_player.call("get_draft_status"), LocalRaceMath.draft_response_reference_p(), false, true, true, false
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
	_telemetry_recorder.finalize(_race_elapsed, _runners)
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
