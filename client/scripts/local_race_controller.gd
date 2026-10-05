extends Node3D

const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const CourseMarkers := preload("res://scripts/presentation/course_markers.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RaceTelemetryRecorder := preload("res://scripts/race_telemetry_recorder.gd")
## ローカル簡易レースの進行・UI・8プル生成。


const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
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
var _course_markers := CourseMarkers.new()

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
## 常時表示のHUD。詳細な診断テキスト（_hud_label）はF3で切り替えるデバッグ表示。
var _race_hud: Control


func _ready() -> void:
	print("ぷるりんレーサーズ — ローカル簡易レースを開始します")
	_pause_panel.visible = false
	_result_panel.visible = false
	_race_hud = RaceHud.new()
	_race_hud.name = "RaceHud"
	$UI.add_child(_race_hud)
	$UI.move_child(_race_hud, 0)
	_hud_label.visible = false
	_guide_label.visible = false
	_layout_overlay_labels()
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
	_guide_label.text = "\n".join(PackedStringArray([
		"←→／左スティック　ライン",
		"↑↓／十字キー　ノッチ",
		"Space／A／LT　ブレーキ",
		"Y／C　視点切替",
		"右スティック／QE　向き",
		"右スティック押込／R　リセット",
		"Esc／Start　メニュー",
		"F3　詳細表示の切替",
	]))


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
		elif event.physical_keycode == KEY_F3:
			# 診断数値と操作ガイドは同じ「詳細表示」として切り替える。
			_hud_label.visible = not _hud_label.visible
			_guide_label.visible = _hud_label.visible
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _runners.is_empty():
		return
	if _player != null:
		_player.call("set_braking", _race_started and not _paused and not _race_over and RaceControllerInput.brake_pressed())
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
	_resolve_pushes()
	var snapshots: Array = []
	for runner in _runners:
		snapshots.append(runner.call("get_snapshot"))
	for index in _runners.size():
		var details: Dictionary = LocalRaceMath.calculate_draft_details(snapshots, index)
		_runners[index].call("apply_draft_details", details)
		_runners[index].call("apply_rear_assist_details", LocalRaceMath.calculate_rear_assist_details(snapshots, index))
		_runners[index].call("apply_contact_count", LocalRaceMath.lateral_contact_count(snapshots, index))


## 横に動いて他の走者に重なった分を、押し合いの勝負で解く。位置が決まってから、ドラフトなどを計算する。
func _resolve_pushes() -> void:
	var entries: Array = []
	for runner in _runners:
		entries.append(runner.call("get_push_entry"))
	var result: Dictionary = LocalRaceMath.resolve_lateral_pushes(entries)
	var offsets: Dictionary = result["offsets"]
	var contest: Array = result["contest_ids"]
	for index in _runners.size():
		var identifier := str(entries[index]["id"])
		_runners[index].call("apply_push_result", float(offsets.get(identifier, entries[index]["offset"])), identifier in contest)


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
	_course_markers.place(
		_track, _race_route, _race_distance_m, LocalRaceMath.lap_length_m(),
		LocalRaceMath.Config.number("course_marker_sign_interval_m")
	)
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
	for index in _runners.size():
		var others: Array = []
		for other_index in snaps.size():
			if other_index != index:
				others.append(snaps[other_index])
		_runners[index].call("set_others_snapshot", others)


func _check_finishes() -> void:
	if _race_over:
		return
	# 同じtickで到達した走者は、生成順ではなく補間した通過時刻で着順を決める。
	var crossings: Array = []
	for r in _runners:
		if r.call("is_finished"):
			continue
		if LocalRaceMath.has_finished(r.call("get_race_progress"), _race_distance_m):
			var lead_s: float = r.call("get_finish_crossing_lead_s", _race_distance_m)
			crossings.append({
				"runner": r,
				"time": maxf(_race_elapsed - lead_s, 0.0),
				"id": str(r.call("get_snapshot").get("id", "")),
			})
	crossings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["time"]), float(b["time"])):
			return float(a["time"]) < float(b["time"])
		return str(a["id"]) < str(b["id"])
	)
	for crossing: Dictionary in crossings:
		_finish_count += 1
		crossing["runner"].call("mark_finished", _finish_count, float(crossing["time"]))
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
	_update_race_hud()
	if not _race_started:
		_hud_label.text = "\n".join(PackedStringArray([
			"開始出力 %+d" % int(roundi(_player.call("get_drive_level"))),
			"カウント中に↑↓で開始出力を選択",
			"Esc＝メニュー",
		]))
		return
	var order := _live_place(_player)
	var prog: float = _player.call("get_race_progress")
	var cur: float = _player.call("get_actual_speed")
	var output_speed: float = _player.call("get_current_speed")
	var lines := PackedStringArray([
		"順位 %d／%d" % [order, _runners.size()],
		"残り %.0fm" % maxf(_race_distance_m - prog, 0.0),
	])
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
	lines.append("体力 %.1f / %.1fL（%.0f%%）" % [
		_player.call("get_stamina"),
		_player.call("get_stamina_capacity_l"),
		_player.call("get_stamina_ratio") * 100.0,
	])
	lines.append_array(_drive_diagnostic_hud_lines(_player.call("get_drive_diagnostics")))
	lines.append_array(DraftHudFormatter.status_lines(
		# ローカルは速度上限を直接上げず、空気抵抗軽減で自然に速度が伸びる。
		_player.call("get_draft_status"), LocalRaceMath.draft_response_reference_p(), false, true, true, false
	))
	var draft_status: Dictionary = _player.call("get_draft_status")
	lines.append("押し合い %s" % ("発生中（負荷x%.1f）" % LocalRaceMath.PUSH_LOAD_MULTIPLIER if _player.call("is_in_push_contest") else "なし"))
	lines.append("接触 %d人　負荷 心拍+%.1fbpm/s 体力-%.3fL/s" % [_player.call("get_contact_count"), _player.call("get_contact_heart_load_bpm_per_s"), _player.call("get_contact_stamina_load_l_per_s")])
	lines.append("操作性 有効%d　ライン移動 x%.2f" % [int(effective_stats.get("handling", 5)), _player.call("get_handling_steer_multiplier")])
	lines.append("後方支援 空気抵抗 -%.1f%%" % (float(draft_status.get("rear_assist_air_factor", 0.0)) * 100.0))
	lines.append("速度 実際 %.0f／出力上 %.0fkm/h" % [cur, output_speed])
	lines.append("タイム %s" % LocalRaceMath.format_race_time(_race_elapsed))
	lines.append("Esc＝メニュー")
	_hud_label.text = "\n".join(lines)


## 詳細表示（診断数値・操作ガイド）の配置。診断は左の順位表示の下に小さく、ガイドは右側に縦並び。
## 項目が増えても順位表示や下部ゲージに重ならないよう、診断は左端の列に収める。
func _layout_overlay_labels() -> void:
	var outline := Color(0.03, 0.05, 0.1, 0.9)
	_hud_label.position = Vector2(16.0, 190.0)
	_hud_label.size = Vector2(420.0, 480.0)
	_hud_label.clip_text = false
	_hud_label.add_theme_font_size_override("font_size", 13)
	_hud_label.add_theme_constant_override("line_spacing", -3)
	_hud_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_hud_label.add_theme_color_override("font_outline_color", outline)
	_hud_label.add_theme_constant_override("outline_size", 5)
	_guide_label.anchor_left = 1.0
	_guide_label.anchor_right = 1.0
	_guide_label.anchor_top = 0.0
	_guide_label.anchor_bottom = 0.0
	_guide_label.offset_left = -280.0
	_guide_label.offset_right = -16.0
	_guide_label.offset_top = 24.0
	_guide_label.offset_bottom = 300.0
	_guide_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_guide_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_guide_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_guide_label.add_theme_font_size_override("font_size", 15)
	_guide_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	_guide_label.add_theme_color_override("font_outline_color", outline)
	_guide_label.add_theme_constant_override("outline_size", 5)


func _update_race_hud() -> void:
	if _race_hud == null:
		return
	var air_breakdown: Dictionary = _player.call("get_air_reduction_breakdown")
	_race_hud.call("update_state", {
		"place": _live_place(_player) if _race_started else 0,
		"field_size": _runners.size(),
		"remaining_m": maxf(_race_distance_m - float(_player.call("get_race_progress")), 0.0),
		"race_distance_m": _race_distance_m,
		"runners": _hud_runner_marks(),
		"time_text": LocalRaceMath.format_race_time(_race_elapsed),
		"speed_kmh": _player.call("get_actual_speed"),
		"notch": int(roundi(_player.call("get_drive_level"))),
		"notch_max": int(LocalRaceMath.DRIVE_LEVEL_MAX),
		"braking": _player.call("is_braking"),
		"fuel_ratio": _player.call("get_stamina_ratio"),
		"heart_bpm": _player.call("get_heart_rate_bpm"),
		"heart_min_bpm": LocalRaceMath.Config.number("heart_rate_min_bpm"),
		"heart_normal_max_bpm": LocalRaceMath.Config.number("heart_rate_normal_max_bpm"),
		"heart_max_bpm": LocalRaceMath.Config.number("heart_rate_overheat_max_bpm"),
		"air_green": float(air_breakdown["aero_rear"]),
		"air_blue": float(air_breakdown["draft"]),
		"countdown": not _race_started,
	})


## 進行バーに出す全走者の位置（割合）・自分かどうか・色。
func _hud_runner_marks() -> Array:
	var marks: Array = []
	for runner in _runners:
		marks.append({
			"ratio": RaceHud.progress_ratio(float(runner.call("get_race_progress")), _race_distance_m),
			"player": runner == _player,
			"color": PururinVisualStyle.color_for_racer_id(str(runner.call("get_snapshot")["id"])),
		})
	return marks


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
