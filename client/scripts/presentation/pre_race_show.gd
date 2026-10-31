extends Node
## スタート前の見せ方（画面のある所だけ。レースの中身には触らない）。
## ① レース場を上から → ② 返し馬（体の写しが、ゲートの先を軽く走る）→ ③ 1体ずつ紹介 → ④ ゲートに並ぶ。
## ④ は、may_finish（準備が終わった・オンラインならサーバーが待つのをやめた）が真になるまで続け、そのあと finished を出す。
## 見せている間は、専用のカメラと文字を出し、いつもの表示（操作盤など）は隠す。終わったら元に戻す。

signal reached_lineup
signal finished

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")

const STAGE_OVERVIEW := 0
const STAGE_WARMUP := 1
const STAGE_INTRO := 2
const STAGE_LINEUP := 3
const STAGE_DONE := 4
## 場面ごとの長さ（秒）。紹介は1体ぶん。
const OVERVIEW_S := 3.0
const WARMUP_S := 4.0
const INTRO_PER_RUNNER_S := 1.0
const LINEUP_MIN_S := 2.0
## 返し馬で走る長さ（m）と、カメラが寄るときに前の画からつなぐ秒数。
const WARMUP_RUN_M := 55.0
const CAMERA_BLEND_S := 0.35
## いつもの表示のうち、見せている間も出したままにするもの（一時停止・結果の板）。
const KEEP_SHOWN := ["PausePanel", "ResultPanel"]

var _runners: Array = []
var _ui: CanvasLayer
var _race_camera: Camera3D
var _camera: Camera3D
var _gate_center := Vector3.ZERO
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
## スタンドのある側（コースの外側）。
var _stands_side := Vector3.RIGHT
var _stage := STAGE_OVERVIEW
var _stage_time := 0.0
var _intro_index := 0
var _hidden_ui: Array[CanvasItem] = []
var _copies: Array[Node3D] = []
var _overlay: Control
var _title: Label
var _card: PanelContainer
var _card_name: Label
var _card_info: Label
var _waiting: Label
var _blend_from := Transform3D.IDENTITY
var _blend_time := 0.0
## 終わってよいか（準備・サーバーの待ち）。止めている間か。
var may_finish := Callable()
var is_paused := Callable()
## ④ で「みんなの準備を待っています…」を出すか（オンラインで、ほかの人を待っている間）。
var show_waiting := false


## 見せ方を組み立てて、始める。title は上に出す文（距離など）。
func begin(track: Path3D, route: Dictionary, runners: Array, ui: CanvasLayer, race_camera: Camera3D, title: String) -> void:
	_runners = runners.duplicate()
	_runners.sort_custom(func(a: Node3D, b: Node3D) -> bool: return int(a.get("gate_index")) < int(b.get("gate_index")))
	_ui = ui
	_race_camera = race_camera
	for runner: Node3D in _runners:
		_gate_center += runner.global_position
	_gate_center /= maxf(float(_runners.size()), 1.0)
	var pose := CourseBuilder.route_pose(track.curve, route, 0.0, LocalRaceMath.lap_length_m())
	if not pose.is_empty():
		_forward = track.global_transform.basis * (pose["travel"] as Vector3)
	_forward.y = 0.0
	_forward = _forward.normalized()
	_right = _forward.cross(Vector3.UP).normalized()
	var venue := Vector3.ZERO
	var points := track.curve.get_baked_points()
	for point in points:
		venue += track.to_global(point)
	venue /= maxf(float(points.size()), 1.0)
	var outward := _gate_center - venue
	outward.y = 0.0
	_stands_side = _right if _right.dot(outward) > 0.0 else -_right
	_camera = Camera3D.new()
	_camera.name = "PreRaceCamera"
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()
	_build_overlay(title)
	for child in _ui.get_children():
		if child is CanvasItem and (child as CanvasItem).visible and not str(child.name) in KEEP_SHOWN and child != _overlay:
			(child as CanvasItem).visible = false
			_hidden_ui.append(child)
	_enter(STAGE_OVERVIEW)


## 見せている途中か。
func is_running() -> bool:
	return _stage != STAGE_DONE


## ④ まで進んだか（オンラインでは、ここまで来てから、サーバーに準備ができたと知らせる）。
func is_at_lineup() -> bool:
	return _stage >= STAGE_LINEUP


## 飛ばす：④ へ進む（④ の最短の秒数も待たない。準備が終わっていれば、すぐ終わる）。
func skip() -> void:
	if _stage >= STAGE_LINEUP:
		_stage_time = LINEUP_MIN_S
		return
	_enter(STAGE_LINEUP)
	_stage_time = LINEUP_MIN_S


## すぐ終える（オンラインで、サーバーが先に進んだとき）。
func finish_now() -> void:
	if _stage == STAGE_DONE:
		return
	if _stage < STAGE_LINEUP:
		_enter(STAGE_LINEUP)
	_finish()


func _process(delta: float) -> void:
	if _stage == STAGE_DONE or (is_paused.is_valid() and bool(is_paused.call())):
		return
	_stage_time += delta
	_blend_time += delta
	match _stage:
		STAGE_OVERVIEW:
			var t := _ease(_stage_time / OVERVIEW_S)
			var from := _gate_center - _stands_side * 110.0 - _forward * 40.0 + Vector3.UP * 55.0
			var to := _gate_center - _stands_side * 30.0 - _forward * 40.0 + Vector3.UP * 14.0
			_aim(from.lerp(to, t), _gate_center)
			if _stage_time >= OVERVIEW_S:
				_enter(STAGE_WARMUP)
		STAGE_WARMUP:
			var t := _stage_time / WARMUP_S
			_move_copies(t)
			# カメラは、走っている写しの真ん中を、斜め前から追う。
			var group := _copies_center()
			_aim(group + _forward * 13.0 - _stands_side * 6.0 + Vector3.UP * 2.6, group - _forward * 3.0)
			if _stage_time >= WARMUP_S:
				_enter(STAGE_INTRO)
		STAGE_INTRO:
			var index := mini(int(_stage_time / INTRO_PER_RUNNER_S), _runners.size() - 1)
			if index != _intro_index:
				_intro_index = index
				_start_blend()
				_fill_card(_runners[index])
			var runner: Node3D = _runners[_intro_index]
			_aim(runner.global_position + _forward * 5.0 + Vector3.UP * 1.3 + _right * 0.8, runner.global_position + Vector3.UP * 0.5)
			if _stage_time >= INTRO_PER_RUNNER_S * _runners.size():
				_enter(STAGE_LINEUP)
		STAGE_LINEUP:
			_aim(_gate_center + _forward * 22.0 + Vector3.UP * 7.0 - _stands_side * 6.0, _gate_center)
			_waiting.visible = show_waiting
			if _stage_time >= LINEUP_MIN_S and (not may_finish.is_valid() or bool(may_finish.call())):
				_finish()


func _enter(stage: int) -> void:
	if _stage == STAGE_WARMUP and stage != STAGE_WARMUP:
		_end_warmup()
	_stage = stage
	_stage_time = 0.0
	_start_blend()
	_card.visible = stage == STAGE_INTRO
	_waiting.visible = false
	match stage:
		STAGE_WARMUP:
			_begin_warmup()
		STAGE_INTRO:
			_intro_index = 0
			_fill_card(_runners[0])
		STAGE_LINEUP:
			reached_lineup.emit()


func _finish() -> void:
	_stage = STAGE_DONE
	for item in _hidden_ui:
		if is_instance_valid(item):
			item.visible = true
	_hidden_ui.clear()
	_overlay.visible = false
	_race_camera.make_current()
	finished.emit()
	queue_free()


## カメラを、その位置からその点へ向ける。場面が変わった直後は、前の画からなめらかにつなぐ。
func _aim(from: Vector3, at: Vector3) -> void:
	var target := Transform3D(Basis.IDENTITY, from).looking_at(at, Vector3.UP)
	var blend := clampf(_blend_time / CAMERA_BLEND_S, 0.0, 1.0)
	_camera.global_transform = _blend_from.interpolate_with(target, _ease(blend)) if blend < 1.0 else target


func _start_blend() -> void:
	_blend_from = _camera.global_transform
	_blend_time = 0.0 if _stage != STAGE_OVERVIEW or _stage_time > 0.0 else CAMERA_BLEND_S


static func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


# ---------------------------------------------------------------- 返し馬

## 走者の体の写しを作って、走者は隠す（写しだけが走る。本物の位置は動かさない）。
func _begin_warmup() -> void:
	for runner: Node3D in _runners:
		var body := runner.get_node_or_null("Body") as Node3D
		if body == null:
			continue
		var copy := body.duplicate() as Node3D
		copy.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(copy)
		copy.global_transform = body.global_transform
		copy.set_meta("start", runner.global_position)
		copy.set_meta("delay", randf_range(0.0, 0.25))
		copy.set_meta("pace", randf_range(0.85, 1.1))
		_copies.append(copy)
		runner.visible = false


## 写しを、ゲートの先へ走らせる（少しずつずらして、跳ねながら）。
func _move_copies(t: float) -> void:
	for copy in _copies:
		var local_t := clampf((t - float(copy.get_meta("delay"))) / (1.0 - float(copy.get_meta("delay"))), 0.0, 1.0)
		var distance := WARMUP_RUN_M * local_t * float(copy.get_meta("pace"))
		var start: Vector3 = copy.get_meta("start")
		var hop := absf(sin(local_t * TAU * 5.0)) * 0.25
		copy.global_position = start + _forward * distance + Vector3.UP * hop
		copy.look_at(copy.global_position + _forward, Vector3.UP)


## 写しの真ん中（写しが無ければ、ゲートの真ん中）。
func _copies_center() -> Vector3:
	if _copies.is_empty():
		return _gate_center
	var center := Vector3.ZERO
	for copy in _copies:
		center += copy.global_position
	center /= float(_copies.size())
	center.y = _gate_center.y
	return center


## 返し馬の終わり：写しを消して、走者（ゲートに並んだまま）を戻す。
func _end_warmup() -> void:
	for copy in _copies:
		copy.queue_free()
	_copies.clear()
	for runner: Node3D in _runners:
		runner.visible = true


# ---------------------------------------------------------------- 文字

func _build_overlay(title: String) -> void:
	_overlay = Control.new()
	_overlay.name = "PreRaceOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_overlay)
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_BAR, 0, MenuStyle.SCREEN_MARGIN, 10.0))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_overlay.add_child(bar)
	_title = MenuStyle.bold_label(title, 26)
	_title.name = "Title"
	bar.add_child(_title)
	_card = PanelContainer.new()
	_card.name = "NameCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", MenuStyle.panel_box(24.0, 12.0))
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -260.0
	_card.offset_right = 260.0
	_card.offset_top = -132.0
	_card.offset_bottom = -40.0
	_overlay.add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_card.add_child(column)
	_card_name = MenuStyle.bold_label("", 30)
	_card_name.name = "CardName"
	column.add_child(_card_name)
	_card_info = MenuStyle.label("", 18, MenuStyle.COLOR_BAR_DIM)
	_card_info.name = "CardInfo"
	column.add_child(_card_info)
	_card.visible = false
	_waiting = MenuStyle.bold_label("みんなの準備を待っています…", 24)
	_waiting.name = "Waiting"
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_waiting.offset_left = -300.0
	_waiting.offset_right = 300.0
	_waiting.offset_top = -100.0
	_waiting.offset_bottom = -60.0
	_waiting.visible = false
	_overlay.add_child(_waiting)


## 紹介の札：「1枠 アカネ」と、トレーナー・脚質。
func _fill_card(runner: Node3D) -> void:
	var pururin: Dictionary = runner.get("_pururin")
	_card_name.text = "%d枠　%s" % [int(runner.get("gate_index")) + 1, str(pururin.get("display_name", ""))]
	var style_id := str(runner.call("get_running_style_id"))
	var styles: Dictionary = PururinStatsConfig.values().get("running_styles", {})
	var style := str((styles.get(style_id, {}) as Dictionary).get("label", ""))
	_card_info.text = "トレーナー %s　%s" % [str(pururin.get("trainer_name", "")), style]
