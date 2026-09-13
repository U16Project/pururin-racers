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

var _goal_sign: Label3D
var _goal_glow_line: MeshInstance3D
var _goal_panel: MeshInstance3D
var _goal_panel_frame: Node3D

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
		LocalRaceMath.GOAL_PATH_DISTANCE_M,
		Color(0.95, 0.95, 0.95)
	)
	_place_goal_glow_line()
	_place_goal_fx()
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


func _place_goal_fx() -> void:
	if _track == null or _track.curve == null:
		return
	var curve_xf := _track.curve.sample_baked_with_rotation(LocalRaceMath.GOAL_PATH_DISTANCE_M)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	if _goal_panel == null:
		_goal_panel = MeshInstance3D.new()
		_goal_panel.name = "GoalPanel"
		_track.add_child(_goal_panel)
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(19.0, 4.0, 0.08)
	_goal_panel.mesh = panel_mesh
	var panel_material := StandardMaterial3D.new()
	panel_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	panel_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel_material.albedo_color = Color(0.08, 0.68, 0.34, 0.055)
	panel_material.emission_enabled = true
	panel_material.emission = Color(0.04, 0.92, 0.34)
	panel_material.emission_energy_multiplier = 5.5
	_goal_panel.material_override = panel_material
	var goal_transform := _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 2.0
	)
	_goal_panel.global_transform = goal_transform
	if _goal_panel_frame == null:
		_goal_panel_frame = Node3D.new()
		_goal_panel_frame.name = "GoalPanelFrame"
		_track.add_child(_goal_panel_frame)
		var frame_material := StandardMaterial3D.new()
		frame_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		frame_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		frame_material.albedo_color = Color(0.03, 0.58, 0.24, 0.9)
		frame_material.emission_enabled = true
		frame_material.emission = Color(0.02, 1.0, 0.32)
		frame_material.emission_energy_multiplier = 7.0
		_make_goal_panel_frame_bar(
			"Top", Vector3(19.4, 0.1, 0.12), Vector3(0.0, 2.05, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Bottom", Vector3(19.4, 0.1, 0.12), Vector3(0.0, -2.05, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Left", Vector3(0.1, 4.0, 0.12), Vector3(-9.65, 0.0, 0.0), frame_material
		)
		_make_goal_panel_frame_bar(
			"Right", Vector3(0.1, 4.0, 0.12), Vector3(9.65, 0.0, 0.0), frame_material
		)
	_goal_panel_frame.global_transform = goal_transform * Transform3D(
		Basis.IDENTITY, Vector3(0.0, 0.0, 0.06)
	)
	if _goal_sign == null:
		_goal_sign = Label3D.new()
		_goal_sign.name = "GoalSign"
		_goal_sign.text = "GOAL"
		_goal_sign.font_size = 720
		_goal_sign.pixel_size = 0.008
		_goal_sign.modulate = Color(0.92, 1.0, 0.86, 1.0)
		_goal_sign.outline_size = 160
		_goal_sign.outline_modulate = Color(0.01, 0.08, 0.16, 1.0)
		_goal_sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_track.add_child(_goal_sign)
	_goal_sign.global_transform = goal_transform * Transform3D(
		Basis.IDENTITY, Vector3(0.0, 6.4, 0.05)
	)


func _place_goal_glow_line() -> void:
	if _track == null or _track.curve == null:
		return
	if _goal_glow_line == null:
		_goal_glow_line = MeshInstance3D.new()
		_goal_glow_line.name = "GoalGlowLine"
		_track.add_child(_goal_glow_line)
	var curve_xf := _track.curve.sample_baked_with_rotation(LocalRaceMath.GOAL_PATH_DISTANCE_M)
	var travel := -curve_xf.basis.z
	travel.y = 0.0
	travel = travel.normalized() if travel.length_squared() >= 0.0001 else Vector3(0.0, 0.0, -1.0)
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(15.0, 0.08, 0.7)
	_goal_glow_line.mesh = glow_box
	var glow_material := StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(0.08, 0.78, 0.62, 0.66)
	glow_material.emission_enabled = true
	glow_material.emission = Color(0.04, 1.0, 0.68)
	glow_material.emission_energy_multiplier = 14.0
	_goal_glow_line.material_override = glow_material
	_goal_glow_line.global_transform = _track.global_transform * Transform3D(
		Basis.looking_at(travel, Vector3.UP),
		curve_xf.origin + Vector3.UP * 0.22
	)


func _make_goal_panel_frame_bar(
	bar_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D
) -> void:
	var bar := MeshInstance3D.new()
	bar.name = bar_name
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = size
	bar.mesh = bar_mesh
	bar.material_override = material
	bar.position = local_position
	_goal_panel_frame.add_child(bar)


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
	var mode_text := "出力 %+d　心拍(仮) %.0f　スタミナ(仮) %.0f%%" % [
		int(roundi(_player.call("get_drive_level"))),
		_player.call("get_heart_rate_bpm"),
		_player.call("get_stamina"),
	] if _player.call("is_drive_mode") else "目標 %.0fkm/h" % tgt
	var draft_text := "ドラフト中 +%.1fkm/h" % _player.call("get_draft_bonus_kmh") if _player.call("is_drafting") else "単独走"
	_hud_label.text = "順位 %d／8　残り %.0fm　%s　%s　現在 %.0fkm/h　タイム %s　Esc＝メニュー" % [
		order,
		maxf(LocalRaceMath.RACE_DISTANCE_M - prog, 0.0),
		mode_text,
		draft_text,
		cur,
		LocalRaceMath.format_race_time(_race_elapsed),
	]


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
