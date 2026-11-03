extends Node
## スタート前の見せ方（画面のある所だけ。レースの中身には触らない）。
## ① レース場を上から → ② パドック（スタンドの前の芝生で、体の写しが輪になってゆっくり歩く）→ ③ 1体ずつ紹介 → ④ ゲートに並ぶ。
## ④ は、may_finish（準備が終わった・オンラインならサーバーが待つのをやめた）が真になるまで続け、そのあと finished を出す。
## 見せている間は、専用のカメラと文字を出し、いつもの表示（操作盤など）は隠す。終わったら元に戻す。

signal reached_lineup
## パドックの場面に入った（会場のパドックの画面が、出走表などを出す合図）。
signal paddock_entered
## パドックの場面が終わった（重ねていた出走表を、片づける合図）。
signal paddock_left
## 場面の見出し（真ん中の大きな文字）を出し終えた。
signal title_card_done
signal finished

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinPortrait := preload("res://scripts/menu/pururin_portrait.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
const PururinBodyBuilder := preload("res://scripts/presentation/pururin_body_builder.gd")
const GateBadge := preload("res://scripts/menu/gate_badge.gd")
const TrainerIcon := preload("res://scripts/menu/trainer_icon.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const Parts := preload("res://scripts/presentation/venue_parts.gd")
const RaceVenue := preload("res://scripts/presentation/race_venue.gd")

const STAGE_OVERVIEW := 0
const STAGE_PADDOCK := 1
const STAGE_INTRO := 2
const STAGE_LINEUP := 3
const STAGE_DONE := 4
## 場面ごとの長さ（秒）。紹介は1体ぶん。
const OVERVIEW_S := 3.0
## パドックの最初の、列を写す秒数と、そのあと1体ずつ紹介の札を出す秒数。
const PADDOCK_LEAD_S := 2.0
const PADDOCK_CARD_S := 1.4
const LINEUP_MIN_S := 2.0
## パドック：柵で囲んだ楕円（長さの半分・幅の半分、m）。ゴールの前から、コースの内側のテントの列より奥へ寄せた所に置く。
## 出走のぷるりんは、枠番の順に1列で、同じ向きにゆっくり周回する（本物の競馬のパドックと同じ）。
const PADDOCK_HALF_LENGTH_M := RaceVenue.PADDOCK_HALF_LENGTH_M
const PADDOCK_HALF_WIDTH_M := RaceVenue.PADDOCK_HALF_WIDTH_M
const PADDOCK_INSIDE_M := RaceVenue.PADDOCK_INSIDE_M
## 歩く道（土）の幅と、柵までの余白。
const PADDOCK_PATH_WIDTH_M := 3.0
const PADDOCK_FENCE_GAP_M := 2.6
## 周回の速さ（m/秒。平均）。
const PADDOCK_WALK_MPS := 1.6
## 本馬場入場：パドックのあと、全員がまとめて、コースの上をゲートのほうへ歩いてきて、そのまま自分の枠に入る。
## 歩き始める所（枠の後ろ、m。ばらばらに）と、歩く速さ（m/秒。平均。1体ごとに少し違う）。
const ENTRY_BACK_MIN_M := 14.0
const ENTRY_BACK_SPREAD_M := 10.0
const ENTRY_SIDE_SPREAD_M := 2.5
const ENTRY_WALK_MPS := 3.2
## 本馬場入場からゲートインまでのカメラ：ゲートの斜め後ろ（コースの内側）から、内側を回って前へ出て、
## 斜め前（コースの外側）まで、ゆっくり1本の動きで回り込む。回り終えるまでの秒数、回り込む向き（ラジアン。
## 0＝真後ろ、π/2＝内側の真横、π＝真正面）、ゲートからの距離と高さ（始め・終わり）。
const SWEEP_S := 12.0
const SWEEP_FROM_RAD := 0.45
const SWEEP_TO_RAD := PI + 0.55
const SWEEP_RADIUS_M := Vector2(26.0, 16.0)
const SWEEP_HEIGHT_M := Vector2(5.0, 2.2)
## パドックの場面の間に、カメラが輪のまわりを回る角度（ラジアン）。
const PADDOCK_CAMERA_TURN := 0.5
## パドック・入場で進む体の、動きの速さ（レース中の「走る」に対する倍率。ゆっくり）。
const PADDOCK_MOTION_RATE := 0.55
const COLOR_PADDOCK_PATH := Color(0.62, 0.47, 0.32)
## 歩き方は、1体ごとに、ときどき変える（跳ねて進む・はって進む）。止まらない。1つの歩き方を続ける秒数と、その割合。
## どちらも、体の動きに合わせて進む（体が動かないまま、すべって進むことはしない）。
## 跳ねるときは跳ねている間だけ進む。はうときは、体が前に伸びるときに大きく、縮むときに少し進む。
const GAIT_HOP := "hop"
const GAIT_CRAWL := "crawl"
const GAIT_SECONDS := Vector2(1.5, 3.5)
const GAIT_WEIGHTS := {GAIT_HOP: 0.5, GAIT_CRAWL: 0.5}
## はうときの、進む速さ（跳ねて進むときの平均に対する割合）と、縮むときにも進む分。表情を変える割合（歩き方を変えるとき）。
const CRAWL_SPEED := 0.75
const CRAWL_MIN_SHARE := 0.25
const EXPRESSION_CHANGE_CHANCE := 0.6
## パドックで、前のぷるりんに近づきすぎない間（1周に対する割合で数える前の、m）。
const PADDOCK_MIN_GAP_M := 4.0
## 場面の道しるべ（上の帯）。
const STEP_NAMES := ["レース場", "パドック", "本馬場入場", "ゲートイン"]
## 場面が変わるときの見出し（真ん中に大きく）：見出しと、小さな説明。出しておく秒数と、薄く出し入れする秒数。
const STAGE_TITLES := {
	1: ["パドック", "出走するぷるりんたちの様子を見られます"],
	2: ["本馬場入場", "ぷるりんたちがゲートへ向かいます"],
	3: ["ゲートイン", "まもなくスタートです"],
}
const TITLE_CARD_S := 1.5
const TITLE_FADE_S := 0.3
const COLOR_STEP_NOW := Color(1.0, 0.8, 0.28)
const COLOR_STEP_DONE := Color(0.32, 0.86, 0.5)
const COLOR_STEP_LATER := Color(0.74, 0.8, 0.9, 0.45)
## 紹介の札の大きさ。
const CARD_WIDTH := 640.0
const CARD_HEIGHT := 150.0
const CARD_PORTRAIT := 124.0
## カメラが寄るときに、前の画からつなぐ秒数。
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
var _hidden_ui: Array[CanvasItem] = []
var _copies: Array[Node3D] = []
var _overlay: Control
var _title: Label
var _card: PanelContainer
var _card_name: Label
var _card_portrait: Control
var _card_gate: Control
var _card_attribute: Label
var _card_attribute_mark: Control
var _card_style: Label
var _card_style_mark: Control
var _card_trainer: Label
var _card_trainer_icon: TextureRect
var _card_player_icon: Control
var _attribute_id := ""
var _style_id := ""
var _steps: Array[Label] = []
var _paddock_center := Vector3.ZERO
## パドックを写す向き（輪の真ん中から、スタンドのほう）。
var _paddock_view_dir := Vector3.FORWARD
## 自分の走者（紹介の札で、トレーナーの絵を、登録した自分のアイコンにする）と、オンラインか（ほかの人のトレーナーの絵は無い）。
var player_runner: Node3D
var online := false
## パドックで待つか（オフラインのパドック・オンラインで出走者を待つ間）。真の間は、パドックから先へ進まない。
var hold_paddock := false
## パドックで、1体ずつの紹介の札を出すか（出走表を重ねているときは出さない）。
var paddock_cards := true
## パドックで、カメラを寄せる走者（-1 なら、輪のまわりを回る）。
var _focus_index := -1
var _waiting: Label
var _notice: Label
## 場面の見出し（暗くした画面の真ん中）。出している残りの秒数（0なら出していない）。
var _title_card: Control
var _title_card_main: Label
var _title_card_sub: Label
var _title_left := 0.0
var _title_total := 0.0
## 右下の「A スキップ」（オフラインだけ。パドックで待っている間は、A は出走表の決定なので隠す）。
var _skip_row: Control
var _blend_from := Transform3D.IDENTITY
var _blend_time := 0.0
## 本馬場入場が始まってからの秒数（ゲートインの場面へ続けて数える。カメラの回り込みに使う）。
var _sweep_time := 0.0
## 終わってよいか（準備・サーバーの待ち）。止めている間か。
var may_finish := Callable()
var is_paused := Callable()
## ④ で「みんなの準備を待っています…」を出すか（オンラインで、ほかの人を待っている間）。
var show_waiting := false


## 見せ方を組み立てて、始める。title は上に出す文（距離など）。
func begin(track: Path3D, route: Dictionary, runners: Array, ui: CanvasLayer, race_camera: Camera3D, label: Dictionary, goal_position: Vector3) -> void:
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
	var inward := venue - goal_position
	inward.y = 0.0
	_paddock_center = goal_position + inward.normalized() * PADDOCK_INSIDE_M
	_paddock_center.y = _gate_center.y
	_paddock_view_dir = -inward.normalized()
	_build_paddock_ring()
	# ゲートは、パドックのあとに並ぶまで、空けておく（会場を写す間に、もうゲートにいるのは不自然なので）。
	for runner: Node3D in _runners:
		runner.visible = false
	_camera = Camera3D.new()
	_camera.name = "PreRaceCamera"
	_camera.far = 4000.0
	add_child(_camera)
	_camera.make_current()
	_build_overlay(label)
	for child in _ui.get_children():
		if child is CanvasItem and (child as CanvasItem).visible and not str(child.name) in KEEP_SHOWN and child != _overlay:
			(child as CanvasItem).visible = false
			_hidden_ui.append(child)
	_enter(STAGE_OVERVIEW)


## 見せている途中か。
func is_running() -> bool:
	return _stage != STAGE_DONE


## パドックの場面にいるか。
func is_in_paddock() -> bool:
	return _stage == STAGE_PADDOCK


## ④ まで進んだか（オンラインでは、ここまで来てから、サーバーに準備ができたと知らせる）。
func is_at_lineup() -> bool:
	return _stage >= STAGE_LINEUP


## 飛ばす：④ へ進む（④ の最短の秒数も待たない。準備が終わっていれば、すぐ終わる）。
func skip() -> void:
	if _stage >= STAGE_LINEUP:
		_stage_time = LINEUP_MIN_S
		_sweep_time = SWEEP_S
		return
	_end_warmup()
	_end_entry()
	_enter(STAGE_LINEUP)
	_stage_time = LINEUP_MIN_S
	_sweep_time = SWEEP_S
	# 飛ばしたときは、見出しも出さない。
	_title_left = 0.0
	_title_card.visible = false


## パドックで待つのをやめて、先へ（紹介 → ゲートイン）進む。
func release_paddock() -> void:
	hold_paddock = false
	_focus_index = -1
	if _stage == STAGE_PADDOCK:
		_enter(STAGE_INTRO)


## パドックで、その枠のぷるりんにカメラを寄せる（-1 で、輪のまわりを回るのに戻す）。
func focus_gate(gate: int) -> void:
	var index := -1
	for i in _runners.size():
		if int((_runners[i] as Node3D).get("gate_index")) == gate:
			index = i
	if index != _focus_index:
		_focus_index = index
		_start_blend()


## 走者が入れ替わった（オンラインで出走者が決まった・枠順が変わった）：パドックの写しを作り直す。
## 自分のぷるりんの写しは、今いる所から続けて歩く（ほかのぷるりんが、列に加わる）。
func set_runners(runners: Array) -> void:
	var in_paddock := _stage == STAGE_PADDOCK
	var kept_u := float(_copies[0].get_meta("u")) if in_paddock and _copies.size() == 1 else NAN
	if in_paddock:
		_end_warmup()
	_runners = runners.duplicate()
	_runners.sort_custom(func(a: Node3D, b: Node3D) -> bool: return int(a.get("gate_index")) < int(b.get("gate_index")))
	# ゲートは、本馬場入場で並ぶまで空けておく。
	for runner: Node3D in _runners:
		runner.visible = false
	_gate_center = Vector3.ZERO
	for runner: Node3D in _runners:
		_gate_center += runner.global_position
	_gate_center /= maxf(float(_runners.size()), 1.0)
	if in_paddock:
		_begin_warmup()
		var mine := _runners.find(player_runner)
		if not is_nan(kept_u) and mine >= 0 and mine < _copies.size():
			var shift := kept_u - float(_copies[mine].get_meta("u"))
			for copy in _copies:
				copy.set_meta("u", float(copy.get_meta("u")) + shift)
			_move_copies(0.0)


## 上の帯の右に出す、パドックの間の案内（オンラインで「出走者を集めています」など。空なら出さない）。
func set_notice(text: String) -> void:
	_notice.text = text
	_notice.visible = not text.is_empty()


## すぐ終える（オンラインで、サーバーが先に進んだとき）。
func finish_now() -> void:
	if _stage == STAGE_DONE:
		return
	_finish()


func _process(delta: float) -> void:
	if _stage == STAGE_DONE:
		return
	# 一時停止の間は、止めて、札と案内を隠す（一時停止の板と重ならないように）。
	var paused := is_paused.is_valid() and bool(is_paused.call())
	_overlay.visible = not paused
	if paused:
		return
	# 見出しを出している間は、場面の時計を止める（パドックのぷるりんは歩き続ける）。
	if _title_left > 0.0:
		_title_left = maxf(_title_left - delta, 0.0)
		var shown := _title_total - _title_left
		_title_card.modulate.a = clampf(minf(shown, _title_left) / TITLE_FADE_S, 0.0, 1.0)
		if _stage == STAGE_PADDOCK:
			_move_copies(delta)
		if _title_left <= 0.0:
			_title_card.visible = false
			title_card_done.emit()
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
				_enter(STAGE_PADDOCK)
		STAGE_PADDOCK:
			var t := _stage_time / _paddock_seconds()
			_move_copies(delta)
			# 列を写したあと、1体ずつ、横について紹介の札を出す（出走表を重ねているときは、出さない）。
			if not hold_paddock and paddock_cards and _stage_time >= PADDOCK_LEAD_S:
				var index := mini(int((_stage_time - PADDOCK_LEAD_S) / PADDOCK_CARD_S), _copies.size() - 1)
				if index != _focus_index and index >= 0:
					_focus_index = index
					_start_blend()
					_card.visible = true
					_fill_card(_runners[index])
			# カメラは、輪の外（スタンドの側）から、ゆっくり横へ回りながら写す。
			if _focus_index < 0:
				# ゆっくり横へ流しながら写す。
				var slide := lerpf(-0.6, 0.6, _ease(t)) * PADDOCK_HALF_LENGTH_M
				# 楕円の内側の芝生から、目の高さで、スタンドの側の長い辺を歩く列を写す（後ろにスタンドが見える）。
				var far_side := _paddock_center + _paddock_view_dir * PADDOCK_HALF_WIDTH_M
				var eye := _paddock_center - _paddock_view_dir * 2.0 + _forward * slide * 0.5 + Vector3.UP * 1.4
				_aim(eye, far_side + _forward * slide + Vector3.UP * 0.4)
			if _focus_index >= 0 and _focus_index < _copies.size():
				# カーソルを合わせたぷるりんを、進む先の斜め前（少し内側）から、顔が見える向きで写す。一緒に動く。
				var copy := _copies[_focus_index]
				var u := float(copy.get_meta("u"))
				var ahead := _oval_point(u + 0.01) - _oval_point(u)
				ahead.y = 0.0
				var inward := _paddock_center - copy.global_position
				inward.y = 0.0
				_aim(copy.global_position + ahead.normalized() * 4.0 + inward.normalized() * 2.2 + Vector3.UP * 0.9, copy.global_position + Vector3.UP * 0.4)
			if _stage_time >= _paddock_seconds() and not hold_paddock:
				_enter(STAGE_INTRO)
		STAGE_INTRO:
			_move_entry(delta)
			_sweep(delta)
			if _entry.is_empty():
				_enter(STAGE_LINEUP)
		STAGE_LINEUP:
			_sweep(delta)
			_waiting.visible = show_waiting
			# カメラが前まで回り終えてから、終わる。
			if _stage_time >= LINEUP_MIN_S and _sweep_time >= SWEEP_S and (not may_finish.is_valid() or bool(may_finish.call())):
				_finish()


func _enter(stage: int) -> void:
	if _stage == STAGE_PADDOCK and stage != STAGE_PADDOCK:
		_end_warmup()
		paddock_left.emit()
	_stage = stage
	_stage_time = 0.0
	_start_blend()
	_card.visible = false
	_waiting.visible = false
	_refresh_steps()
	if _skip_row != null:
		_skip_row.visible = not (stage == STAGE_PADDOCK and hold_paddock)
	if STAGE_TITLES.has(stage):
		show_title_card(STAGE_TITLES[stage][0], STAGE_TITLES[stage][1])
	match stage:
		STAGE_PADDOCK:
			_begin_warmup()
			paddock_entered.emit()
		STAGE_INTRO:
			_focus_index = -1
			_sweep_time = 0.0
			# 全員を、枠の後ろのコースの上に、ばらばらに出して、もう歩いている所から写す。
			for runner: Node3D in _runners:
				_begin_entry_of(runner)
		STAGE_LINEUP:
			reached_lineup.emit()


func _finish() -> void:
	_end_warmup()
	_end_entry()
	_stage = STAGE_DONE
	for item in _hidden_ui:
		if is_instance_valid(item):
			item.visible = true
	_hidden_ui.clear()
	_overlay.visible = false
	_race_camera.make_current()
	finished.emit()
	queue_free()


## 本馬場入場からゲートインのカメラ：後ろ（内側）から、内側を回って、前（外側）へ。写す先も、歩いてくる群れからゲートへ。
func _sweep(delta: float) -> void:
	_sweep_time += delta
	var t := _ease(minf(_sweep_time / SWEEP_S, 1.0))
	var angle := lerpf(SWEEP_FROM_RAD, SWEEP_TO_RAD, t)
	# 0＝真後ろ（-_forward）、π/2＝内側（-_stands_side）、π＝真正面（_forward）、その先は外側へ。
	var direction := -_forward * cos(angle) - _stands_side * sin(angle)
	var eye := _gate_center + direction * lerpf(SWEEP_RADIUS_M.x, SWEEP_RADIUS_M.y, t) + Vector3.UP * lerpf(SWEEP_HEIGHT_M.x, SWEEP_HEIGHT_M.y, t)
	var look := (_gate_center - _forward * ENTRY_BACK_MIN_M * 0.6).lerp(_gate_center, t) + Vector3.UP * 0.4
	_aim(eye, look)


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


# ---------------------------------------------------------------- パドック・入場

## 楕円の上の点（u は 0〜1 で1周。長い辺は、コースの進む向きにそろえる）。
func _oval_point(u: float) -> Vector3:
	var angle := TAU * u
	return _paddock_center + _forward * cos(angle) * PADDOCK_HALF_LENGTH_M + _stands_side * sin(angle) * PADDOCK_HALF_WIDTH_M


## 楕円の1周の長さ（m。おおよそ）。
func _oval_length() -> float:
	return TAU * sqrt((PADDOCK_HALF_LENGTH_M * PADDOCK_HALF_LENGTH_M + PADDOCK_HALF_WIDTH_M * PADDOCK_HALF_WIDTH_M) * 0.5)


## パドックの、土の道と白い柵を組み立てる（見せ方が終わったら、いっしょに消える）。
func _build_paddock_ring() -> void:
	var ring := Node3D.new()
	ring.name = "PaddockRing"
	add_child(ring)
	var dirt := Parts.material(COLOR_PADDOCK_PATH)
	var white := Parts.material(Parts.COLOR_WHITE)
	var pieces := 48
	for i in pieces:
		var u0 := float(i) / pieces
		var u1 := float(i + 1) / pieces
		# 柵は外側だけ（内側の芝生は、カメラを置く所。柵が手前に写らないように）。
		for layer in [[0.0, dirt, PADDOCK_PATH_WIDTH_M, 0.02], [PADDOCK_PATH_WIDTH_M * 0.5 + PADDOCK_FENCE_GAP_M, white, 0.08, 0.9]]:
			var a := _oval_point(u0)
			var b := _oval_point(u1)
			var along := (b - a)
			var out_dir := along.cross(Vector3.UP).normalized()
			if out_dir.dot(a - _paddock_center) < 0.0:
				out_dir = -out_dir
			var shift: float = layer[0]
			a += out_dir * shift
			b += out_dir * shift
			var mid := (a + b) * 0.5
			var length := a.distance_to(b) + 0.15
			var yaw := rad_to_deg(atan2(along.x, along.z))
			if layer[1] == dirt:
				Parts.box(ring, Vector3(float(layer[2]), float(layer[3]), length), mid + Vector3.UP * 0.01, dirt, Vector3(0.0, yaw, 0.0))
			else:
				# 柵：横木を2本と、継ぎ目に柱。
				for height in [0.45, 0.85]:
					Parts.box(ring, Vector3(0.06, 0.08, length), mid + Vector3.UP * height, white, Vector3(0.0, yaw, 0.0))
				Parts.box(ring, Vector3(0.1, 1.0, 0.1), a + Vector3.UP * 0.5, white)


## 走者の体の写しを作って、パドックの楕円に、枠番の順に間をあけて並べる。
func _begin_warmup() -> void:
	var count := _runners.size()
	for index in count:
		var copy := _make_copy(_runners[index])
		if copy == null:
			continue
		# 枠番の順に、1列。先頭（1枠）が前。
		copy.set_meta("u", -float(index) / float(count))
		_copies.append(copy)
	_move_copies(0.0)


## 体の写し（レース中の「走る」動きを、ゆっくりにして使う。表情も、いつもどおり変わる）。
## 体は、走者の体を写すのではなく、同じ見た目の設定から組み立て直す
## （写すと、形だけが写って、跳ねる・伸び縮み・部品の揺れの動きが写らず、すべって見えるため）。
func _make_copy(runner: Node3D) -> Node3D:
	if runner.get_node_or_null("Body") == null:
		return null
	var pururin: Dictionary = runner.get("_pururin")
	# 同じプルが何体もいるときの走者の番号（"id#2"）は、元の個体の番号に戻す。
	var look: Dictionary = pururin["look"] if pururin.has("look") else PururinLookConfig.look_for(str(pururin.get("id", "")).split("#")[0])
	var copy := PururinBodyBuilder.build(look, PururinLookConfig.values())
	add_child(copy)
	copy.call("set_motion_rate", PADDOCK_MOTION_RATE)
	_change_gait(copy)
	return copy


## 歩き方を、くじで決め直す（ときどき、表情も変える）。
func _change_gait(copy: Node3D) -> void:
	var roll := randf()
	var gait := GAIT_HOP
	for key: String in GAIT_WEIGHTS:
		roll -= float(GAIT_WEIGHTS[key])
		if roll <= 0.0:
			gait = key
			break
	copy.set_meta("gait", gait)
	copy.set_meta("gait_left", randf_range(GAIT_SECONDS.x, GAIT_SECONDS.y))
	copy.call("set_action", "walk" if gait == GAIT_CRAWL else "run")
	if randf() < EXPRESSION_CHANGE_CHANCE:
		var faces: Array = PururinLookConfig.showcase()["expressions"]
		if not faces.is_empty():
			copy.call("set_expression", str(faces[randi() % faces.size()]))


## この1コマで、写しが進む長さ（m）。体の動きに合わせる。
func _gait_step(copy: Node3D, speed_mps: float, delta: float) -> float:
	var left := float(copy.get_meta("gait_left")) - delta
	copy.set_meta("gait_left", left)
	if left <= 0.0:
		_change_gait(copy)
	match str(copy.get_meta("gait")):
		GAIT_HOP:
			return speed_mps * delta * _air(copy) * PI * 0.5
		GAIT_CRAWL:
			return speed_mps * CRAWL_SPEED * delta * _crawl_push(copy)
	return 0.0


## はうときの、進む強さ（平均は1）。体が前に伸びるときに大きく、縮むときに少し（0にはならない）。体の「walk」の伸び縮みと同じ式。
func _crawl_push(copy: Node3D) -> float:
	var hz := 0.0
	for motion: Dictionary in ((copy.get("_body_motion") as Dictionary).get("actions", {}) as Dictionary).get("walk", []):
		if str(motion.get("type", "")) == "stretch" and str(motion.get("axis", "")) == "z":
			hz = float(motion["hz"])
	if hz <= 0.0:
		return 1.0
	var wave := sin(TAU * hz * float(copy.get("_body_time")))
	var stretching := maxf(wave, 0.0)
	# 平均が1になるように：CRAWL_MIN_SHARE ＋ (1−CRAWL_MIN_SHARE)×(max(sin,0) の平均 1/π で割る)。
	return CRAWL_MIN_SHARE + (1.0 - CRAWL_MIN_SHARE) * stretching * PI


## 跳ねている（地面から離れている）割合。0＝着地、1＝いちばん高い。体の跳ねる動きと同じ式。
## 跳ねて進むときは、跳ねている間だけ前へ進む（跳ねたまま、すべるように進むと、浮いて飛んでいるように見えるため）。
func _air(copy: Node3D) -> float:
	var hz := 0.0
	for motion: Dictionary in ((copy.get("_body_motion") as Dictionary).get("actions", {}) as Dictionary).get("run", []):
		if str(motion.get("type", "")) == "hop":
			hz = float(motion["hz"])
	if hz <= 0.0:
		return 1.0
	return absf(sin(PI * hz * float(copy.get("_body_time"))))


## 写しを、楕円に沿って進ませる（跳ねている間だけ進む。進む向きを向く）。
func _move_copies(delta: float) -> void:
	var length := _oval_length()
	for index in _copies.size():
		var copy := _copies[index]
		var speed := PADDOCK_WALK_MPS
		# 前のぷるりん（枠番が1つ小さい）に近づいたら、止まらずに、ゆっくりになる。
		if index > 0 and (float(_copies[index - 1].get_meta("u")) - float(copy.get_meta("u"))) * length < PADDOCK_MIN_GAP_M:
			speed *= 0.4
		var u := float(copy.get_meta("u")) + _gait_step(copy, speed, delta) / length
		u = maxf(u, float(copy.get_meta("u")))
		copy.set_meta("u", u)
		copy.global_position = _oval_point(u)
		var ahead := _oval_point(u + 0.01) - copy.global_position
		copy.look_at(copy.global_position + ahead, Vector3.UP)


## パドックの終わり：写しを消す（走者は、入場で並ぶまで隠したまま）。
func _end_warmup() -> void:
	for copy in _copies:
		copy.queue_free()
	_copies.clear()


## 本馬場入場：その走者の写しを、ゲートの後ろに出す（着いたら、写しを消して、本物の走者を出す）。
var _entry: Array[Node3D] = []


func _begin_entry_of(runner: Node3D) -> void:
	var copy := _make_copy(runner)
	if copy == null:
		runner.visible = true
		return
	# 横は、少しずらす。ただし、1枠と最後の枠の間（コースの上）からは出ない（柵の外を歩かないように）。
	var lanes := _runners.map(func(each: Node3D) -> float: return (each.global_position - _gate_center).dot(_right))
	var lane := clampf((runner.global_position - _gate_center).dot(_right) + randf_range(-ENTRY_SIDE_SPREAD_M, ENTRY_SIDE_SPREAD_M), lanes.min(), lanes.max())
	var start := runner.global_position - _forward * (ENTRY_BACK_MIN_M + randf() * ENTRY_BACK_SPREAD_M) + _right * (lane - (runner.global_position - _gate_center).dot(_right))
	copy.set_meta("runner", runner)
	copy.set_meta("start", start)
	copy.set_meta("length", start.distance_to(runner.global_position))
	copy.set_meta("done", 0.0)
	copy.set_meta("pace", randf_range(0.85, 1.15))
	copy.global_position = start
	copy.look_at(runner.global_position, Vector3.UP)
	_entry.append(copy)


## 歩いてくる写しを、跳ねている間だけ進ませる。自分の枠に着いたら、本物の走者に替える。
func _move_entry(delta: float) -> void:
	for copy in _entry.duplicate():
		var runner: Node3D = copy.get_meta("runner")
		var length := float(copy.get_meta("length"))
		var done := minf(float(copy.get_meta("done")) + _gait_step(copy, ENTRY_WALK_MPS * float(copy.get_meta("pace")), delta), length)
		copy.set_meta("done", done)
		copy.global_position = (copy.get_meta("start") as Vector3).lerp(runner.global_position, done / maxf(length, 0.01))
		if done >= length:
			runner.visible = true
			_entry.erase(copy)
			copy.queue_free()


## パドックの場面の長さ（列を写す分＋1体ずつの紹介）。
func _paddock_seconds() -> float:
	return PADDOCK_LEAD_S + PADDOCK_CARD_S * _runners.size()


## 入場の終わり：写しを消して、ゲートの走者を出す。
func _end_entry() -> void:
	for copy in _entry:
		copy.queue_free()
	_entry.clear()
	for runner: Node3D in _runners:
		runner.visible = true


# ---------------------------------------------------------------- 文字

## label：何のレースか（kind＝遊び方の札 [文字, 色]、tags＝ルームの種類などの札、title＝ルーム名と距離）。
func _build_overlay(label: Dictionary) -> void:
	_overlay = Control.new()
	_overlay.name = "PreRaceOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_overlay)
	# 上の帯：左に距離、右に場面の道しるべ（今の場面は黄色、済んだ場面は緑の ✓）。
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_BAR, 0, 0.0, 0.0))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = MenuStyle.BAR_HEIGHT
	_overlay.add_child(bar)
	var line := ColorRect.new()
	line.color = Color(MenuStyle.COLOR_ACCENT, 0.6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -2.0
	bar.add_child(line)
	# 左：上の段に札（遊び方・ルームの種類・本戦の段階）、下の段に大きくルーム名と距離。
	var left := VBoxContainer.new()
	left.name = "RaceLabel"
	left.add_theme_constant_override("separation", 1)
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = MenuStyle.SCREEN_MARGIN
	left.offset_right = 700.0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(left)
	var tags := HBoxContainer.new()
	tags.add_theme_constant_override("separation", 6)
	left.add_child(tags)
	var kind: Array = label.get("kind", ["", Color.WHITE])
	for tag: Array in [kind] + (label.get("tags", []) as Array):
		if str(tag[0]).is_empty():
			continue
		var chip := MenuStyle.tag(str(tag[0]), tag[1], 12)
		tags.add_child(chip)
	_title = MenuStyle.bold_label(str(label.get("title", "")), 24)
	_title.name = "Title"
	left.add_child(_title)
	var steps := HBoxContainer.new()
	steps.name = "Steps"
	steps.add_theme_constant_override("separation", 10)
	steps.alignment = BoxContainer.ALIGNMENT_END
	steps.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	steps.offset_left = -720.0
	steps.offset_right = -MenuStyle.SCREEN_MARGIN
	bar.add_child(steps)
	for index in STEP_NAMES.size():
		if index > 0:
			var dash := MenuStyle.label("─", 15, COLOR_STEP_LATER)
			dash.add_theme_constant_override("outline_size", 0)
			dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			steps.add_child(dash)
		var step := MenuStyle.bold_label("", 16, MenuStyle.COLOR_TEXT, 0)
		step.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		steps.add_child(step)
		_steps.append(step)
	# オフラインでは、右下に「A スキップ」。
	if not online:
		var skip_row := HBoxContainer.new()
		_skip_row = skip_row
		skip_row.add_theme_constant_override("separation", 8)
		skip_row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		skip_row.offset_left = -170.0
		skip_row.offset_top = -48.0
		skip_row.offset_right = -MenuStyle.SCREEN_MARGIN
		skip_row.offset_bottom = -16.0
		skip_row.alignment = BoxContainer.ALIGNMENT_END
		_overlay.add_child(skip_row)
		var skip_mark := MenuStyle.mark("A", 24.0)
		skip_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		skip_row.add_child(skip_mark)
		var skip_text := MenuStyle.label("スキップ", 17, MenuStyle.COLOR_TEXT)
		skip_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		skip_row.add_child(skip_text)
	_build_card()
	_title_card = ColorRect.new()
	_title_card.name = "TitleCard"
	(_title_card as ColorRect).color = Color(0.0, 0.0, 0.0, 0.45)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 重ねた出走表より上に出す。
	_title_card.z_as_relative = false
	_title_card.z_index = 100
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.visible = false
	_overlay.add_child(_title_card)
	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.add_theme_constant_override("separation", 6)
	_title_card.add_child(title_box)
	_title_card_main = MenuStyle.bold_label("", 56, MenuStyle.COLOR_TEXT, 10)
	_title_card_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(_title_card_main)
	_title_card_sub = MenuStyle.label("", 22, MenuStyle.COLOR_TEXT)
	_title_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_box.add_child(_title_card_sub)
	_notice = MenuStyle.bold_label("", 22)
	_notice.name = "Notice"
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 下の真ん中（出走表とステータスの箱に隠れない所）。
	_notice.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_notice.offset_left = -360.0
	_notice.offset_right = 360.0
	_notice.offset_top = -82.0
	_notice.offset_bottom = -48.0
	_notice.visible = false
	_overlay.add_child(_notice)
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


## 道しるべの色と印を、今の場面に合わせる。
func _refresh_steps() -> void:
	for index in _steps.size():
		var step := _steps[index]
		var done := index < _stage
		step.text = ("✓ " if done else "%d " % (index + 1)) + str(STEP_NAMES[index])
		step.add_theme_color_override("font_color", COLOR_STEP_NOW if index == _stage else (COLOR_STEP_DONE if done else COLOR_STEP_LATER))
		# 今の場面は、大きくする。
		step.add_theme_font_size_override("font_size", 20 if index == _stage else 15)


## 真ん中に、大きな見出しと小さな説明を出す（画面を少し暗くする）。出し終えたら title_card_done。
func show_title_card(main: String, sub: String = "", seconds: float = TITLE_CARD_S) -> void:
	_title_card_main.text = main
	_title_card_sub.text = sub
	_title_card_sub.visible = not sub.is_empty()
	_title_total = seconds + TITLE_FADE_S * 2.0
	_title_left = _title_total
	_title_card.modulate.a = 0.0
	_title_card.visible = true


## 見出しを出している途中か。
func is_showing_title() -> bool:
	return _title_left > 0.0


## 紹介の札：左にぷるりんの絵、右に枠番号と名前、その下に属性・脚質（印つき）、トレーナー（絵つき）。パドックの行と同じ中身。
func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "NameCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", MenuStyle.panel_box(18.0, 12.0))
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -CARD_WIDTH * 0.5
	_card.offset_right = CARD_WIDTH * 0.5
	_card.offset_top = -CARD_HEIGHT - 28.0
	_card.offset_bottom = -28.0
	_overlay.add_child(_card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_card.add_child(row)
	_card_portrait = PururinPortrait.new()
	_card_portrait.name = "CardPortrait"
	_card_portrait.custom_minimum_size = Vector2(CARD_PORTRAIT, CARD_PORTRAIT)
	row.add_child(_card_portrait)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	column.add_child(name_row)
	_card_gate = GateBadge.new()
	_card_gate.name = "CardGate"
	name_row.add_child(_card_gate)
	_card_name = MenuStyle.bold_label("", 34)
	_card_name.name = "CardName"
	name_row.add_child(_card_name)
	var info := HBoxContainer.new()
	info.add_theme_constant_override("separation", 6)
	column.add_child(info)
	_card_attribute_mark = Control.new()
	_card_attribute_mark.custom_minimum_size = Vector2(22.0, 22.0)
	_card_attribute_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_attribute_mark.draw.connect(_draw_attribute_mark)
	info.add_child(_card_attribute_mark)
	_card_attribute = MenuStyle.label("", 19)
	_card_attribute.name = "CardAttribute"
	info.add_child(_card_attribute)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14.0, 0.0)
	info.add_child(gap)
	_card_style_mark = Control.new()
	_card_style_mark.custom_minimum_size = Vector2(RaceHud.STYLE_CHEVRON_STEP * StatsMath.rank_group_count() + 4.0, 22.0)
	_card_style_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_card_style_mark.draw.connect(_draw_style_mark)
	info.add_child(_card_style_mark)
	_card_style = MenuStyle.label("", 19)
	_card_style.name = "CardStyle"
	info.add_child(_card_style)
	var trainer := HBoxContainer.new()
	trainer.add_theme_constant_override("separation", 8)
	column.add_child(trainer)
	_card_trainer_icon = TextureRect.new()
	_card_trainer_icon.custom_minimum_size = Vector2(30.0, 30.0)
	_card_trainer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_trainer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	trainer.add_child(_card_trainer_icon)
	_card_player_icon = TrainerIcon.new()
	_card_player_icon.custom_minimum_size = Vector2(30.0, 30.0)
	trainer.add_child(_card_player_icon)
	_card_trainer = MenuStyle.label("", 17, MenuStyle.COLOR_BAR_DIM)
	_card_trainer.name = "CardTrainer"
	trainer.add_child(_card_trainer)
	_card.visible = false


## 札に、その走者を入れる。
func _fill_card(runner: Node3D) -> void:
	var pururin: Dictionary = (runner.get("_pururin") as Dictionary).duplicate()
	var gate := int(runner.get("gate_index"))
	# 同じプルが何体もいるときの走者の番号（"id#2"）は、絵を組み立てるときは、元の個体の番号に戻す。
	pururin["id"] = str(pururin.get("id", "")).split("#")[0]
	_card_portrait.call("set_pururin", pururin)
	_card_gate.call("setup", gate, 40.0)
	_card_gate.queue_redraw()
	_card_name.text = str(pururin.get("display_name", ""))
	var stats: Dictionary = PururinStatsConfig.values()
	_attribute_id = str(pururin.get("attribute", ""))
	_card_attribute.text = str((stats.get("attributes", {}).get(_attribute_id, {}) as Dictionary).get("label", ""))
	_style_id = str(runner.call("get_running_style_id"))
	_card_style.text = str((stats.get("running_styles", {}).get(_style_id, {}) as Dictionary).get("label", ""))
	_card_attribute_mark.queue_redraw()
	_card_style_mark.queue_redraw()
	var is_player := runner == player_runner
	_card_player_icon.visible = is_player
	if is_player:
		_card_player_icon.call("show_registered")
	var trainer: Dictionary = {} if is_player or online else RaceSession.trainer_for_slot(gate)
	var portrait := str(trainer.get("portrait_path", ""))
	_card_trainer_icon.texture = load(portrait) if not portrait.is_empty() else null
	_card_trainer_icon.visible = _card_trainer_icon.texture != null
	_card_trainer.text = "トレーナー　%s" % str(pururin.get("trainer_name", ""))


func _draw_attribute_mark() -> void:
	if _attribute_id.is_empty():
		return
	var color := Color.from_string(str((PururinStatsConfig.values()["attributes"].get(_attribute_id, {}) as Dictionary).get("color", "#ffffff")), Color.WHITE)
	PururinDetail.draw_attribute_mark(_card_attribute_mark, _card_attribute_mark.size * 0.5, 20.0, _attribute_id, color)


func _draw_style_mark() -> void:
	if _style_id.is_empty():
		return
	RaceHud.draw_style_chevrons(_card_style_mark, Vector2(1.0, _card_style_mark.size.y * 0.5), RaceHud.COLOR_STYLE_MATCH, StatsMath.rank_group_count(), StatsMath.style_rank_group_index(_style_id), 1.0)
