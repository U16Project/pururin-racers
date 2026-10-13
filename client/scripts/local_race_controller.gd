extends Node3D

const GoalVisual := preload("res://scripts/presentation/goal_visual.gd")
const CourseMarkers := preload("res://scripts/presentation/course_markers.gd")
const RaceVenue := preload("res://scripts/presentation/race_venue.gd")
const StartGate := preload("res://scripts/presentation/start_gate.gd")
const FinishCelebration := preload("res://scripts/presentation/finish_celebration.gd")
const DraftHudFormatter := preload("res://scripts/presentation/draft_hud_formatter.gd")
const M5CourseBuilder := preload("res://scripts/m5_course_builder.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RaceTelemetryRecorder := preload("res://scripts/race_telemetry_recorder.gd")
## ローカル簡易レースの進行・UI・8プル生成。


const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const RoundRaceHud := preload("res://scripts/presentation/round_race_hud.gd")
const FpsLabel := preload("res://scripts/debug/fps_label.gd")
const FirstDrawWarmup := preload("res://scripts/presentation/first_draw_warmup.gd")
## 表情の部品を先に作る処理に、1コマで使ってよい時間（ミリ秒）。
const FACE_PREPARE_BUDGET_MS := 8
const SunShadow := preload("res://scripts/presentation/sun_shadow.gd")
const HudStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
## 丸い操作盤の大きさ（外の輪の半径。ピクセル）と、画面の下からのすき間。
const ROUND_HUD_RADIUS := 142.0
const ROUND_HUD_BOTTOM_MARGIN := 8.0
## 丸い操作盤の絵を描き直す回数（1秒あたり）。
const ROUND_HUD_UPDATES_PER_S := 10.0
## ウェブ版オフラインテストで、順位表の絵を描き直す回数（1秒あたり）。
const RACE_HUD_UPDATES_PER_S := 4.0
## 丸い操作盤の左の端と、仮想パッドのラインのボタンの右の端との、すき間。
const ROUND_HUD_STICK_GAP := 8.0
const RaceResultBoard := preload("res://scripts/presentation/race_result_board.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const PururinVisualStyle := preload("res://scripts/pururin_visual_style.gd")
const PururinLookConfig := preload("res://scripts/config/pururin_look_config.gd")
const PururinBodyBuilder := preload("res://scripts/presentation/pururin_body_builder.gd")
const PururinStatsMath := preload("res://scripts/pururin_stats_math.gd")
const RunnerScript := preload("res://scripts/runner_local_race.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const TouchControls := preload("res://scripts/presentation/touch_controls.gd")
const ControlGuide := preload("res://scripts/presentation/control_guide.gd")

const PlayerGroundMarker := preload("res://scripts/presentation/player_ground_marker.gd")
const RACE_SELECT_SCENE := "res://scenes/race_select.tscn"
const ONLINE_LOBBY_SCENE := "res://scenes/online_lobby.tscn"
const OnlineSession := preload("res://scripts/online/online_session.gd")
const OnlineProtocol := preload("res://scripts/online/online_protocol.gd")
## オンラインで、今の操作を、変わっていなくても送り直す間（秒）。
const ONLINE_INPUT_RESEND_S := 0.25
const LOCAL_RACE_SCENE := "res://scenes/local_race.tscn"
## 結果の板を出すまでの待ち。最後の走者がゴールしてからの秒数と、ユーザーがゴールしてからの秒数（長いほうを待つ）。
const RESULT_WAIT_AFTER_LAST_S := 2.0
const RESULT_WAIT_AFTER_PLAYER_S := 5.0
const FINAL_STRETCH_DISTANCE_M := 400.0
## 首位の自プルがこの距離まで来たら、ゴール線を越える少し前から紙吹雪を始める。
const CELEBRATION_EARLY_TRIGGER_M := 8.0
## 先頭がゴールしてから、観客のざわめきが消えるまでの秒数。
const FINAL_STRETCH_FADE_OUT_S := 10.0
@onready var _track: Path3D = $TrackPath
@onready var _runners_root: Node3D = $Runners
@onready var _hud_label: Label = %HudLabel
@onready var _guide_label: Label = $UI/GuideLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _pause_panel: Control = %PausePanel
@onready var _result_panel: Control = %ResultPanel
## 着順の表（結果の板の中に、コードで足す）。
var _result_board: Control
@onready var _pause_return_button: Button = %PauseReturnButton
@onready var _result_return_button: Button = %ResultReturnButton
@onready var _resume_button: Button = %ResumeButton
@onready var _camera: Camera3D = $Camera3D
@onready var _start_marker: MeshInstance3D = $StartMarker
@onready var _goal_marker: MeshInstance3D = $GoalMarker

var _goal_visual := GoalVisual.new()
var _course_markers := CourseMarkers.new()
var _venue := RaceVenue.new()
var _start_gate := StartGate.new()
var _celebration := FinishCelebration.new()

var _runners: Array[Node3D] = []
var _paused: bool = false
var _race_over: bool = false
var _finish_count: int = 0
var _race_elapsed: float = 0.0
var _results_pending: bool = false
var _results_wait_remaining: float = 0.0
## ユーザーがゴールした時点の、操作盤の表示（ゴール後は、これを出し続ける）。
var _finish_hud_state: Dictionary = {}
var _result_retry_button: Button
## ゴールした走者の、ゴールした時点の心拍と体力（順位表の、その行に出し続ける）。走者 → {heart_bpm, fuel_ratio}。
var _finish_standing_values: Dictionary = {}
var _player: Node3D = null
var _race_started: bool = false
var _start_countdown_remaining: float = 0.0
var _start_signal_remaining: float = 0.0
## レース画面に入ってから、カウントダウンを始めるまでの待ち。
var _entry_wait_remaining: float = 0.0
var _final_stretch_ambience_started := false
## これから先に作っておく、表情の部品（[体, 表情の名前] の並び）。
var _faces_to_prepare: Array = []
var _online_ready_sent := false
## カウントダウンを始めたか（入場の待ちと、スタート前の準備が、両方終わってから true）。
var _countdown_begun := false
var _final_stretch_ambience_fading := false
## 前のtickで、自分が接触か押し合いの最中だったか。始まった瞬間だけ音を鳴らす。
var _contact_sound_was_touching := false
var _race_distance_m: float = RaceSession.DEFAULT_DISTANCE_M
var _race_route: Dictionary = {}
var _launch_visual: MeshInstance3D
var _telemetry_recorder := RaceTelemetryRecorder.new()
## 常時表示のHUD。詳細な診断テキスト（_hud_label）はF3で切り替えるデバッグ表示。
var _race_hud: Control
## オンラインのゲーム側か（サーバーのレースを映すだけで、自分では走りを計算しない）。
var _online_view := false
var _online_client: Node
## 個体のID → 走者（届いた状態を、走者に配るため）。
var _runners_by_id := {}
## 最後に送った操作と、送ってからの秒数。
var _online_sent_input := {}
var _online_input_age_s := 0.0
## カウントダウンの表示（と音）を、もう始めたか。
var _online_countdown_shown := false
## 自分の走者の、前に届いた状態（音を鳴らすきっかけを見つけるため）。
var _online_previous_own := {}
## オンラインのサーバーで、全員のレースの画面ができるのを待っているか（待っているあいだ、入場の待ちもカウントダウンも進めない）。
var _start_hold := false
## 通信ごしの人（オンラインのサーバーだけ）。人の番号 → 走者、人の番号 → 今の操作。
var _remote_runners := {}
var _remote_inputs := {}
var _round_hud: Control
## 丸い操作盤は、別の絵（SubViewport）に描いて、その絵を画面に貼る。毎コマ描き直すと重い（細かい部品が何百もある）ので、
## 絵の描き直しは、1秒に ROUND_HUD_UPDATES_PER_S 回だけにする。
var _round_hud_viewport: SubViewport
var _round_hud_view: TextureRect
var _round_hud_drawn_msec := -1000000
## ウェブ版オフラインテストのときだけ使う、順位表（前の操作盤）の絵と、その貼り先。
var _race_hud_viewport: SubViewport
var _race_hud_view: TextureRect
var _race_hud_drawn_msec := -1000000
## 画面の上の仮想パッド。
var _touch_controls: Control
var _pause_guide_button: Button
var _control_guide: Control
var _guide_pad_was_shown := false
## 詳細な診断テキストの後半（2列目）。前半は _hud_label（1列目）。どちらも操作盤の右。
var _hud_label_right: Label


func _ready() -> void:
	print("ぷるりんレーサーズ — ローカル簡易レースを開始します")
	_pause_panel.visible = false
	_result_panel.visible = false
	_race_hud = RaceHud.new()
	_race_hud.name = "RaceHud"
	if RaceSession.is_course_only():
		# ウェブ版オフラインテスト：順位表（前の操作盤）も、別の絵に描いて貼る。描き直しは、丸い操作盤と同じ回数だけ（軽くするため）。
		_race_hud_viewport = SubViewport.new()
		_race_hud_viewport.name = "RaceHudViewport"
		_race_hud_viewport.transparent_bg = true
		_race_hud_viewport.disable_3d = true
		_race_hud_viewport.size_2d_override_stretch = true
		_race_hud_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		$UI.add_child(_race_hud_viewport)
		_race_hud_viewport.add_child(_race_hud)
		_race_hud_view = TextureRect.new()
		_race_hud_view.name = "RaceHudView"
		_race_hud_view.texture = _race_hud_viewport.get_texture()
		_race_hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_race_hud_view.stretch_mode = TextureRect.STRETCH_SCALE
		_race_hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		$UI.add_child(_race_hud_view)
		$UI.move_child(_race_hud_view, 0)
	else:
		$UI.add_child(_race_hud)
		$UI.move_child(_race_hud, 0)
	# 下の操作盤は、丸い操作盤に替える（前の操作盤は、消しているだけで残してある）。
	_race_hud.set("main_panel_visible", false)
	_round_hud_viewport = SubViewport.new()
	_round_hud_viewport.name = "RoundRaceHudViewport"
	_round_hud_viewport.transparent_bg = true
	_round_hud_viewport.disable_3d = true
	_round_hud_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	$UI.add_child(_round_hud_viewport)
	_round_hud = Control.new()
	_round_hud.set_script(RoundRaceHud)
	_round_hud.name = "RoundRaceHud"
	_round_hud_viewport.add_child(_round_hud)
	_round_hud_view = TextureRect.new()
	_round_hud_view.name = "RoundRaceHudView"
	_round_hud_view.texture = _round_hud_viewport.get_texture()
	_round_hud_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_round_hud_view.stretch_mode = TextureRect.STRETCH_SCALE
	_round_hud_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_round_hud_view)
	$UI.move_child(_round_hud_view, 1)
	_place_round_hud()
	get_viewport().size_changed.connect(_place_round_hud)
	# 画面の上の仮想パッド（スマホ用。左下のボタンかF2で出し入れ）。
	_touch_controls = TouchControls.new()
	$UI.add_child(_touch_controls)
	_hud_label_right = _hud_label.duplicate()
	_hud_label_right.name = "HudLabelRight"
	_hud_label_right.unique_name_in_owner = false
	_hud_label_right.text = ""
	$UI.add_child(_hud_label_right)
	_hud_label.visible = false
	_hud_label_right.visible = false
	_guide_label.visible = false
	_layout_overlay_labels()
	_build_result_board()
	_add_pause_marks()
	_add_pause_guide_button()
	_pause_return_button.pressed.connect(_return_to_race_select)
	_result_return_button.pressed.connect(_return_to_race_select)
	_resume_button.pressed.connect(_set_paused.bind(false))
	UIAudio.bind_button_sound(_pause_return_button, "back")
	# 着順の板のボタンは、どちらも決定の音。
	UIAudio.bind_button_sound(_result_return_button, "confirmation")
	UIAudio.bind_button_sound(_resume_button, "back")
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
	# ユーザーのぷるりんが選ばれていないときは、別の個体で走らせず、止める。
	var start_problem := RaceSession.race_start_problem()
	if not start_problem.is_empty():
		_hud_label.text = "レース選択で、ユーザーのぷるりんと対戦相手を選んでください（%s）" % start_problem
		_hud_label.visible = true
		set_process(false)
		return
	_place_markers()
	_spawn_field()
	if _is_online_host():
		_stop_presentation_for_server()
	else:
		_warm_up_first_draw()
	if _online_view:
		_online_client = OnlineSession.client(get_tree())
		_online_client.message_received.connect(_on_online_message)
		_online_client.closed.connect(_leave_online_race)
		# オンラインでは、もう1回は部屋から始める。
		_result_retry_button.visible = false
		_result_return_button.text = "部屋へ戻る"
		_pause_return_button.text = "部屋へ戻る"
		# 画面ができたことは、スタート前の準備（_is_preparing）が終わってから、サーバーに知らせる（_send_online_ready_when_prepared）。
	_entry_wait_remaining = LocalRaceMath.Config.number("race_entry_wait_seconds")
	_countdown_label.visible = false
	RaceAudio.play_race_entry()
	if _entry_wait_remaining <= 0.0:
		_begin_start_countdown()
	if _player != null:
		_player.call("set_drive_level", LocalRaceMath.Config.number("player_start_drive_level"))
	_guide_label.text = "\n".join(PackedStringArray([
		"←→／左スティック　ライン",
		"↑↓／十字キー　ノッチ",
		"Xキー・Space／A／LT　ブレーキ",
		"Cキー／B　ダッシュ",
		"Zキー／X　ブースト",
		"Sキー／Y　視点切替（通常・遠距離・上空・一人称）",
		"右スティック　見回す（離すと戻る）",
		"Shift＋WASD・QE　カメラの微調整",
		"右スティック押込／R　リセット",
		"Esc／Start　メニュー",
		"F3　詳細表示の切替",
	]))


func _unhandled_input(event: InputEvent) -> void:
	# ボタンを押すと場面が変わることがあるので、画面は先に取っておく。
	var viewport := get_viewport()
	if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
		return
	if is_instance_valid(_control_guide):
		return
	if _race_over:
		return
	if RaceControllerInput.is_menu_pressed(event):
		_set_paused(not _paused)
		get_viewport().set_input_as_handled()
	elif (event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event)) and _paused:
		UIAudio.play_back()
		_set_paused(false)
		get_viewport().set_input_as_handled()
	elif not _paused and _race_started and _player != null and RaceControllerInput.is_dash_pressed(event):
		# オンラインでは、押したことをサーバーへ送る（音は、効いたことが届いてから鳴らす）。
		if _online_view:
			_online_client.send(OnlineProtocol.ACTION, {"kind": OnlineProtocol.ACTION_DASH})
		elif bool(_player.call("trigger_dash")):
			RaceAudio.play_dash()
		get_viewport().set_input_as_handled()
	elif not _paused and _race_started and _player != null and RaceControllerInput.is_boost_pressed(event):
		if _online_view:
			_online_client.send(OnlineProtocol.ACTION, {"kind": OnlineProtocol.ACTION_BOOST})
		elif bool(_player.call("trigger_boost")):
			RaceAudio.play_boost()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_set_paused(not _paused)
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F3:
			# 診断数値と操作ガイドは同じ「詳細表示」として切り替える。
			_hud_label.visible = not _hud_label.visible
			_hud_label_right.visible = _hud_label.visible
			_guide_label.visible = _hud_label.visible
			if _hud_label.visible and _player != null:
				_update_detail_text()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _runners.is_empty():
		return
	_prepare_next_face()
	if _online_view:
		_send_online_ready_when_prepared()
		_process_online_view(_delta)
		return
	# ゆっくりの戻しは、一時停止中でも進める（止めたまま、ゆっくりが残らないように）。
	_celebration.advance(_delta)
	if _player != null:
		_player.call("set_braking", _race_started and not _paused and not _race_over and RaceControllerInput.brake_pressed())
	for peer_id: int in _remote_runners:
		var remote_input: Dictionary = _remote_inputs[peer_id]
		_remote_runners[peer_id].call("set_remote_input", float(remote_input["line"]), float(remote_input["notch"]))
		_remote_runners[peer_id].call("set_braking", _race_started and not _paused and not _race_over and bool(remote_input["brake"]))
	if not _paused and not _race_started:
		# オンラインのサーバーでは、全員の画面ができるまで、入場の待ちを始めない。
		if not _start_hold:
			_update_before_start(_delta)
	elif not _paused:
		# 結果の板を出したあとも、走者は止めない（時計と記録だけ止める）。
		_update_start_signal(_delta)
		if not _race_over:
			_race_elapsed += _delta
		# ランナーは前tickに確定したドラフト値を使って移動する。
		# 移動と接触解決が終わってから、次tick用のドラフトを一括計算する。
		_share_snapshots()
		# 音と、ゴールの門の札は、画面のあるときだけ（サーバーでは、やらない）。
		if not _is_online_host():
			_update_final_stretch_audio()
			_update_heartbeat_audio(_delta)
			_update_goal_gate()
		call_deferred("_finalize_draft_tick")
		if not _race_over:
			_record_telemetry_sample()
	if _results_pending and not _race_over and not _paused:
		_results_wait_remaining -= _delta
		if _results_wait_remaining <= 0.0:
			_show_results()
	_update_hud()


## ゴールの門の札を、いちばん後ろの走者に合わせる（全員が通りすぎるまでは「あと◯周」のまま）。
func _update_goal_gate() -> void:
	var last_progress := INF
	for runner in _runners:
		last_progress = minf(last_progress, float(runner.call("get_race_progress")))
	_goal_visual.set_laps_to_go(GoalVisual.laps_to_go(_race_distance_m, LocalRaceMath.lap_length_m(), last_progress))


## 先頭走者が残り400mへ入ったら、ゴールに近づくほど観客のざわめきを大きくする。
## 先頭がゴールしたあとは下げるだけなので、ここでは触らない。
func _update_final_stretch_audio() -> void:
	if _final_stretch_ambience_fading:
		return
	var leader_progress := 0.0
	for runner in _runners:
		leader_progress = maxf(leader_progress, float(runner.call("get_race_progress")))
	var remaining := _race_distance_m - leader_progress
	if remaining > FINAL_STRETCH_DISTANCE_M:
		return
	if not _final_stretch_ambience_started:
		_final_stretch_ambience_started = true
		RaceAudio.start_final_stretch_ambience()
	RaceAudio.set_final_stretch_level(1.0 - remaining / FINAL_STRETCH_DISTANCE_M)


## ユーザーのぷるりんの心拍に合わせて音を鳴らす。ゴールしたら止める。
func _update_heartbeat_audio(delta: float) -> void:
	if _player == null:
		return
	if bool(_player.call("is_finished")):
		RaceAudio.stop_heartbeat()
		return
	RaceAudio.update_heartbeat(float(_player.call("get_heart_rate_bpm")), delta)


## 先頭がゴールした瞬間から、ざわめきをじわじわ下げ始める。
func _start_final_stretch_fade_out() -> void:
	if _final_stretch_ambience_fading:
		return
	_final_stretch_ambience_fading = true
	RaceAudio.fade_out_final_stretch_ambience(FINAL_STRETCH_FADE_OUT_S)


## 入場の待ちが終わってから、カウントダウンを進める。
func _update_before_start(delta: float) -> void:
	if not _countdown_begun:
		_entry_wait_remaining -= delta
		# 入場の待ちが過ぎ、スタート前の準備も終わってから、カウントダウンへ進む
		# （準備で画面が止まっているあいだに、スタートしないように。準備が長引いても、毎コマここで確かめる）。
		if _entry_wait_remaining > 0.0 or _is_preparing():
			return
		delta = clampf(-_entry_wait_remaining, 0.0, delta)
		_entry_wait_remaining = 0.0
		_begin_start_countdown()
	_update_start_countdown(delta)


func _begin_start_countdown() -> void:
	_countdown_begun = true
	_start_countdown_remaining = LocalRaceMath.Config.number("start_countdown_seconds")
	_countdown_label.visible = true
	_countdown_label.text = "スタートまで %d" % ceili(_start_countdown_remaining)
	RaceAudio.play_countdown_start()


## 接触か押し合いが始まった瞬間だけ鳴らす。続いているあいだは、重ねて鳴らさない。
func _update_contact_audio() -> void:
	if _player == null:
		return
	var contact_count := int(_player.call("get_contact_count"))
	var in_push := bool(_player.call("is_in_push_contest"))
	if contact_sound_starts(_contact_sound_was_touching, contact_count, in_push):
		RaceAudio.play_contact()
	_contact_sound_was_touching = contact_count > 0 or in_push


static func contact_sound_starts(was_touching: bool, contact_count: int, in_push: bool) -> bool:
	return not was_touching and (contact_count > 0 or in_push)


func _update_start_countdown(delta: float) -> void:
	_start_countdown_remaining = maxf(_start_countdown_remaining - delta, 0.0)
	if _start_countdown_remaining > 0.0:
		_countdown_label.text = "スタートまで %d" % ceili(_start_countdown_remaining)
		return
	_race_started = true
	_start_gate.clear_after_start()
	# スタートの線も、ゲートと同じときに消す（周回でもう一度通る所に、残さない）。
	create_tween().tween_callback(_start_marker.hide).set_delay(StartGate.CLEAR_DELAY_S)
	if not _is_online_host():
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
	if _paused or _runners.is_empty():
		return
	# M5オンラインと同じく、移動後のゴール判定を先に確定する。
	# 着順とタイムを確定した後も、結果表示までは全員が接触・ドラフトを続ける。
	_maybe_start_player_finish_celebration()
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
	_update_contact_audio()


## 横に動いて他の走者に重なった分を、押し合いの勝負で解く。位置が決まってから、ドラフトなどを計算する。
func _resolve_pushes() -> void:
	var entries: Array = []
	for runner in _runners:
		entries.append(runner.call("get_push_entry"))
	var result: Dictionary = LocalRaceMath.resolve_lateral_pushes(entries)
	var offsets: Dictionary = result["offsets"]
	var contest: Array = result["contest_ids"]
	var lost: Array = result["lost_ids"]
	for index in _runners.size():
		var identifier := str(entries[index]["id"])
		_runners[index].call("apply_push_result", float(offsets.get(identifier, entries[index]["offset"])), identifier in contest, identifier in lost)


func _spawn_field() -> void:
	for child in _runners_root.get_children():
		child.queue_free()
	_runners.clear()
	_player = null
	_remote_runners.clear()
	_remote_inputs.clear()
	_runners_by_id.clear()
	_online_view = RaceSession.is_online_view()
	# 出るのは、キャラが入っている枠だけ。スタートの位置は、枠の番号どおり（未選択の枠は、空けたまま）。
	var entries := RaceSession.field_entries()
	var field_size := entries.size()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var pururin := PururinRosterConfig.pururin_by_id(str(entry["id"])).duplicate(true)
		pururin["trainer_profile_id"] = entry["trainer_profile_id"]
		pururin["trainer_name"] = str(entry["trainer_name"]) if entry.has("trainer_name") else RaceSession.trainer_name_for(str(entry["id"]), bool(entry["player"]))
		var runner := Node3D.new()
		runner.name = "Runner%d" % (i + 1)
		runner.set_script(RunnerScript)
		# 体は、個体の見た目の設定から組み立てる（足元が走者の位置、正面が進む向き）。
		var body := PururinBodyBuilder.build(PururinLookConfig.look_for(str(entry["id"])), PururinLookConfig.values())
		body.name = "Body"
		runner.add_child(body)
		_runners_root.add_child(runner)
		var is_player := bool(entry["player"])
		var start_gate := int(entry["gate"])
		var label: String = pururin["display_name"]
		runner.call(
			"setup_for_race",
			_track,
			start_gate,
			LocalRaceMath.PLAYER_MAX_SPEED_KMH,
			is_player,
			label,
			pururin,
			_race_distance_m,
			field_size
		)
		_runners.append(runner)
		_runners_by_id[str(entry["id"])] = runner
		var peer_id := int(entry.get("peer_id", 0))
		# オンラインのゲーム側：全員、サーバーから届いた状態を映すだけ。自分の番号の走者が、この画面の「自分」。
		if _online_view:
			runner.set("puppet", true)
			is_player = peer_id == RaceSession.online_view_peer_id()
			peer_id = 0
		# 通信ごしの人（オンラインのサーバーだけ）：操作は通信で受け取る。この画面の「自分」にはしない。
		if peer_id != 0:
			runner.set("remote_controlled", true)
			runner.call("set_drive_level", LocalRaceMath.Config.number("player_start_drive_level"))
			# サーバーの端末に、走者ごとの1秒おきの診断の文を流さない。
			runner.set("_drive_diagnostic_log_remaining", INF)
			_remote_runners[peer_id] = runner
			_remote_inputs[peer_id] = {"line": 0.0, "notch": 0.0, "brake": false}
		elif is_player:
			_player = runner
			# 自分のぷるりんの足元に、光る目印を付ける（集団の中でも、自分が分かるように）。
			var marker := MeshInstance3D.new()
			marker.set_script(PlayerGroundMarker)
			runner.add_child(marker)
			if _camera:
				if _camera.has_method("set_follow_target"):
					_camera.call("set_follow_target", runner)
				_camera.set("overview_ortho_size", 560.0)
				_camera.set("overview_height", 500.0)


# ---------------------------------------------------------------- オンラインのゲーム側

## オンラインのゲーム側の1コマ。走りは計算しない。操作を送り、届いた状態で、音と表示だけを進める。
func _process_online_view(delta: float) -> void:
	_celebration.advance(delta)
	_send_online_input(delta)
	_update_start_signal(delta)
	_update_goal_gate()
	if _race_started and not _race_over:
		_update_heartbeat_audio(delta)
	_update_hud()


## 今の操作（ライン・ノッチ・ブレーキ）を、変わったときと、決めた間ごとに、サーバーへ送る。
func _send_online_input(delta: float) -> void:
	if _player == null or _race_over:
		return
	var input := {"line": 0.0, "notch": 0.0, "brake": false}
	if not _paused:
		input = {
			"line": float(_player.call("_read_steer_axis")),
			"notch": float(_player.call("_read_drive_axis")),
			"brake": RaceControllerInput.brake_pressed(),
		}
	_online_input_age_s += delta
	if input != _online_sent_input or _online_input_age_s >= ONLINE_INPUT_RESEND_S:
		if _online_client.send(OnlineProtocol.INPUT, input):
			_online_sent_input = input
			_online_input_age_s = 0.0


func _on_online_message(data: Dictionary) -> void:
	match str(data["t"]):
		OnlineProtocol.RACE_STATE: _apply_online_state(data)
		OnlineProtocol.RACE_RESULT: _apply_online_result(data)
		# サーバーがレースを片づけた（結果から決めた秒数がたった・全員が出た）：部屋へ戻る。
		OnlineProtocol.RACE_END: _leave_online_race()


## 届いたレースの状態を、走者と表示に入れる。
func _apply_online_state(data: Dictionary) -> void:
	for state: Dictionary in data["runners"]:
		var runner: Node3D = _runners_by_id.get(str(state["id"]))
		if runner == null:
			continue
		runner.call("apply_online_state", state)
		if runner == _player and not _race_over:
			_play_online_own_sounds(state)
	# 結果の板を出したあとも、走者の位置は映し続ける（ゴール後に流して走るのが見える）。時計と表示は、止めたまま。
	if _race_over:
		return
	_race_elapsed = float(data["elapsed"])
	if _race_started:
		return
	if bool(data["started"]):
		_race_started = true
		_start_gate.clear_after_start()
		create_tween().tween_callback(_start_marker.hide).set_delay(StartGate.CLEAR_DELAY_S)
		_countdown_label.visible = true
		_countdown_label.text = "START!"
		_start_signal_remaining = 0.8
		for runner in _runners:
			runner.call("set_race_active", true)
	elif bool(data["hold"]):
		_countdown_label.visible = true
		_countdown_label.text = "みんなの準備を待っています…"
		_online_countdown_shown = false
	elif float(data["countdown"]) > 0.0:
		if not _online_countdown_shown:
			_online_countdown_shown = true
			_countdown_label.visible = true
			RaceAudio.play_countdown_start()
		_countdown_label.text = "スタートまで %d" % ceili(float(data["countdown"]))
	else:
		# 入場の待ちのあいだは、何も出さない。
		_countdown_label.visible = false


## 自分の走者の状態の変わり目で、音を鳴らす（ノッチ・ダッシュ・ブースト・ゴール）。
func _play_online_own_sounds(state: Dictionary) -> void:
	var previous := _online_previous_own
	_online_previous_own = state
	if previous.is_empty():
		return
	match RunnerScript.notch_sound_key(float(previous["notch"]), float(state["notch"])):
		"notch_up": UIAudio.play_notch_up()
		"notch_down": UIAudio.play_notch_down()
	if float(state["dash_ratio"]) > float(previous["dash_ratio"]):
		RaceAudio.play_dash()
	if int(state["boost_uses_left"]) < int(previous["boost_uses_left"]):
		RaceAudio.play_boost()
	if bool(state["finished"]) and not bool(previous["finished"]):
		if int(state["finish_order"]) == 1:
			_start_player_finish_celebration(true)
			RaceAudio.play_player_first_goal()
		else:
			RaceAudio.play_player_finish_bell()


## 届いた着順を走者に入れて、着順の板を出す。
func _apply_online_result(data: Dictionary) -> void:
	if _race_over:
		return
	for row: Dictionary in data["rows"]:
		var runner: Node3D = _runners_by_id.get(str(row["id"]))
		if runner != null:
			runner.call("mark_finished", int(row["place"]), float(row["time"]))
	_show_results()


## オンラインのレースの画面を出て、部屋の画面へ戻る（つながりは、そのまま）。
func _leave_online_race() -> void:
	# 結果を見終わったことを、サーバーに知らせる（全員ぶんそろうと、決めた秒数を待たずに、次の準備へ進める）。
	if _online_client != null and is_instance_valid(_online_client):
		_online_client.send(OnlineProtocol.RACE_DONE)
	_celebration.stop()
	RaceSession.set_online_entries([])
	RaceSession.set_online_view(0)
	get_tree().change_scene_to_file(ONLINE_LOBBY_SCENE)


# ---------------------------------------------------------------- オンラインのサーバー側

## 画面の無いサーバーの上では、見た目だけの処理を止める（走りの計算は、そのまま）。
## 止めるもの：走者の接触の光・表情・体の動き、体の部品の動き、カメラ、画面の部品（操作盤・仮想パッドなど）。
func _stop_presentation_for_server() -> void:
	for runner in _runners:
		runner.set("presentation_enabled", false)
		var body := runner.get_node_or_null("Body")
		if body != null:
			body.process_mode = Node.PROCESS_MODE_DISABLED
	_camera.process_mode = Node.PROCESS_MODE_DISABLED
	$UI.process_mode = Node.PROCESS_MODE_DISABLED


## オンラインのサーバーの上のレースか（通信ごしの人の走者がいる）。
func _is_online_host() -> bool:
	return not _remote_runners.is_empty()


## レースの記録（あとで見返すためのファイル）に、今の状態を足す。サーバーの上では、記録しない（ファイルがたまり続けるため）。
func _record_telemetry_sample() -> void:
	if not _is_online_host():
		_telemetry_recorder.record_sample(_race_elapsed, _runners)


## 通信ごしの人の、今の操作を受け取る（オンラインのサーバーだけ）。その人の走者がいなければ、何もしない。
## line＝ライン（-1〜1）、notch＝ノッチの上げ下げ（-1〜1。押しているあいだの値）、brake＝ブレーキを押しているか。
func set_remote_input(peer_id: int, line: float, notch: float, brake: bool) -> void:
	if _remote_inputs.has(peer_id):
		_remote_inputs[peer_id] = {"line": line, "notch": notch, "brake": brake}


## 通信ごしの人が、ダッシュ（"dash"）かブースト（"boost"）を押した。使えたら true。
func trigger_remote_action(peer_id: int, action: String) -> bool:
	if _paused or not _race_started or not _remote_runners.has(peer_id):
		return false
	match action:
		"dash": return bool(_remote_runners[peer_id].call("trigger_dash"))
		"boost": return bool(_remote_runners[peer_id].call("trigger_boost"))
	return false


## 通信ごしの人の走者（いなければ null）。
func remote_runner(peer_id: int) -> Node3D:
	return _remote_runners.get(peer_id)


## 全員のレースの画面ができるまで、スタートへ向かう時計を止める（オンラインのサーバーだけ）。
func hold_start() -> void:
	_start_hold = true


func release_start_hold() -> void:
	_start_hold = false


func is_start_held() -> bool:
	return _start_hold


## 通信ごしの人が抜けた：その走者を、その個体のCPUトレーナーに任せる（オンラインのサーバーだけ）。
func release_remote_runner(peer_id: int) -> void:
	if not _remote_runners.has(peer_id):
		return
	var runner: Node3D = _remote_runners[peer_id]
	_remote_runners.erase(peer_id)
	_remote_inputs.erase(peer_id)
	runner.call("set_braking", false)
	runner.call("hand_over_to_cpu")


## オンラインで配る、レースの今の状態。
func online_state() -> Dictionary:
	var runners: Array = []
	for runner in _runners:
		runners.append(runner.call("get_online_state"))
	return {
		"elapsed": _race_elapsed,
		"started": _race_started,
		"entry_wait": maxf(_entry_wait_remaining, 0.0),
		"countdown": maxf(_start_countdown_remaining, 0.0),
		"hold": _start_hold,
		"over": _race_over,
		"runners": runners,
	}


## 着順の一覧（ゴールした順）。1体ぶん：走者のID、順位、タイム（秒）。
func online_result_rows() -> Array:
	var ordered: Array = _runners.duplicate()
	ordered.sort_custom(func(a, b): return a.call("get_finish_order") < b.call("get_finish_order"))
	var rows: Array = []
	for runner in ordered:
		rows.append({"id": str(runner.call("get_snapshot")["id"]), "place": int(runner.call("get_finish_order")), "time": float(runner.call("get_finish_time"))})
	return rows


func is_race_started() -> bool:
	return _race_started


func is_race_over() -> bool:
	return _race_over


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
	_goal_visual.set_laps_to_go(GoalVisual.laps_to_go(_race_distance_m, LocalRaceMath.lap_length_m(), 0.0))
	_place_route_marker(_start_marker, 0.0, Color(0.2, 0.85, 0.45))
	_start_marker.visible = true
	_course_markers.place(
		_track, _race_route, _race_distance_m, LocalRaceMath.lap_length_m(),
		LocalRaceMath.Config.number("course_marker_sign_interval_m"),
		LocalRaceMath.Config.number("course_marker_sign_max_remaining_m"),
		LocalRaceMath.Config.number("course_marker_sign_visible_distance_m")
	)
	_update_launch_visual()
	_venue.place(_track, ($Ground as MeshInstance3D).get_surface_override_material(0), M5CourseBuilder.load_layout(), _race_route, RaceSession.is_course_only())
	# ブラウザ版では、太陽の影を出さない（白っぽくなるため）。
	SunShadow.apply($Sun as DirectionalLight3D)
	if RaceSession.is_course_only():
		# ウェブ版オフラインテスト：軽くするために、太陽の影を切る。
		($Sun as DirectionalLight3D).shadow_enabled = false
	# 重さを確かめる表示（コマ数など）は、景色のあり・なしに関係なく、どのレースにも出す（開発の目処がつくまで）。
	if $UI.get_node_or_null("FpsLabel") == null:
		$UI.add_child(FpsLabel.new())
	_start_gate.place(_track, _race_route, LocalRaceMath.lap_length_m())


## 走者の表情の部品を、スタート前の待ち時間のうちに、1コマに1つずつ作っておく。
## レース中やゴールの瞬間に初めて作ると、そこで画面が引っかかる（スマホのブラウザ版で目立つ）。
func _queue_face_preparation() -> void:
	_faces_to_prepare.clear()
	for runner in _runners:
		var body := runner.get_node_or_null("Body")
		if body == null:
			continue
		for expression: String in body.call("expression_names"):
			if not bool(body.call("is_expression_prepared", expression)):
				_faces_to_prepare.append([body, expression])


## 1コマに、FACE_PREPARE_BUDGET_MS のあいだだけ作る（最低1つ）。速い機械では数コマで終わり、遅い機械でも、画面が止まらない。
func _prepare_next_face() -> void:
	var started := Time.get_ticks_msec()
	while not _faces_to_prepare.is_empty():
		var next: Array = _faces_to_prepare.pop_front()
		if is_instance_valid(next[0]):
			(next[0] as Node).call("prepare_expression", str(next[1]))
		if Time.get_ticks_msec() - started >= FACE_PREPARE_BUDGET_MS:
			break


## スタート前の準備（コースを一度描いておく・表情の部品を作っておく）が、まだ終わっていないか。
func _is_preparing() -> bool:
	return not _faces_to_prepare.is_empty() or has_node("FirstDrawWarmup")


## オンライン：準備が終わったら、画面ができたことを、サーバーに1回だけ知らせる
## （全員ぶんそろうと、スタートへ向かう時計が動き出す。準備の途中で知らせると、止まっているあいだにレースが始まる）。
func _send_online_ready_when_prepared() -> void:
	if _online_ready_sent or _is_preparing():
		return
	_online_ready_sent = true
	_online_client.send(OnlineProtocol.READY)


## コースの上の物を、スタート前に一度描いておく（ブラウザ版で、レース中に初めて映る物の所で止まらないように）。
func _warm_up_first_draw() -> void:
	_queue_face_preparation()
	if _track == null or _track.curve == null:
		return
	var points := _track.curve.get_baked_points()
	var center := Vector3.ZERO
	for point in points:
		center += point
	center /= maxf(float(points.size()), 1.0)
	var radius := 0.0
	for point in points:
		radius = maxf(radius, point.distance_to(center))
	var warmup := FirstDrawWarmup.new()
	warmup.setup(_track.to_global(center), radius)
	add_child(warmup)


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
	# 助走の直線は、コースと同じ土の素材で塗る。
	_launch_visual.material_override = ($TrackPath/TrackRibbon as CSGPolygon3D).material
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
		if _finish_count == 1:
			_start_final_stretch_fade_out()
		# 紙吹雪とスローは、ユーザーのぷるりんが1位でゴールしたときだけ出す。
		if _finish_count == 1 and crossing["runner"] == _player:
			_start_player_finish_celebration(true)
			RaceAudio.play_player_first_goal()
		# ユーザー自身が2位以下でゴールしたときも、ゴール線を通ったことは音で知らせる。
		elif crossing["runner"] == _player:
			RaceAudio.play_player_finish_bell()
		elif _finish_count == 1 and _player != null:
			var remaining := _race_distance_m - float(_player.call("get_race_progress"))
			RaceAudio.play_other_leader_finish(remaining, _race_distance_m)
	var all_done := true
	for r in _runners:
		if not r.call("is_finished"):
			all_done = false
			break
	if all_done and not _results_pending:
		_results_pending = true
		_results_wait_remaining = result_wait_seconds(_race_elapsed - float(_player.call("get_finish_time")) if _player != null else RESULT_WAIT_AFTER_PLAYER_S)


## 直前に首位なら、ゴール線を越える約8m前から紙吹雪を見せ始める。
func _maybe_start_player_finish_celebration() -> void:
	if _celebration.has_played() or _player == null or bool(_player.call("is_finished")):
		return
	var remaining := _race_distance_m - float(_player.call("get_race_progress"))
	if should_start_player_finish_celebration(remaining, _live_place(_player)):
		_start_player_finish_celebration(false)


static func should_start_player_finish_celebration(remaining_m: float, live_place: int) -> bool:
	return live_place == 1 and remaining_m <= CELEBRATION_EARLY_TRIGGER_M


func _start_player_finish_celebration(start_slow_motion: bool) -> void:
	var travel := -_goal_marker.global_transform.basis.z
	travel.y = 0.0
	# ウェブ版オフラインテストでは、紙ふぶきを出さない（スマホのブラウザでとても重いため）。スローの演出は、そのまま。
	_celebration.play(null if RaceSession.is_course_only() else _track, _goal_marker.global_position, 15.0, travel, start_slow_motion)


## 全員がゴールしてから、結果の板を出すまでの秒数。seconds_since_player_finish は、ユーザーがゴールしてからの秒数。
## 最後の走者のゴールから RESULT_WAIT_AFTER_LAST_S、ユーザーのゴールから RESULT_WAIT_AFTER_PLAYER_S の、遅いほうまで待つ。
static func result_wait_seconds(seconds_since_player_finish: float) -> float:
	return maxf(RESULT_WAIT_AFTER_LAST_S, RESULT_WAIT_AFTER_PLAYER_S - seconds_since_player_finish)


func _update_hud() -> void:
	if _player == null:
		return
	_update_race_hud()
	# 詳細表示（F3）の文字は、見えているときだけ作る（毎コマ作ると、見えていなくても重い）。
	if _hud_label.visible:
		_update_detail_text()


## 詳細表示（F3）の文字を作る。
func _update_detail_text() -> void:
	if not _race_started:
		_hud_label_right.text = ""
		var notch_hint := "カウント中に↑↓で開始出力を選択" if _entry_wait_remaining <= 0.0 else "↑↓で開始出力を選択"
		_hud_label.text = "\n".join(PackedStringArray([
			"開始出力 %+d" % int(roundi(_player.call("get_drive_level"))),
			notch_hint,
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
	lines.append("ダッシュ %s　ブースト %dpt 残り%d回　推進力x%.2f" % ["効果中" if _player.call("is_dash_active") else "なし", int(roundf(float(_player.call("get_boost_points")))), int(_player.call("get_boost_uses_left")), float(_player.call("get_drive_boost_multiplier"))])
	lines.append("横移動 負荷 心拍+%.1fbpm/s 体力-%.3fL/s" % [_player.call("get_lateral_move_heart_load_bpm_per_s"), _player.call("get_lateral_move_stamina_load_l_per_s")])
	lines.append("接触 %d人　負荷 心拍+%.1fbpm/s 体力-%.3fL/s" % [_player.call("get_contact_count"), _player.call("get_contact_heart_load_bpm_per_s"), _player.call("get_contact_stamina_load_l_per_s")])
	lines.append("操作性 有効%d　ライン移動 x%.2f" % [int(effective_stats.get("handling", 5)), _player.call("get_handling_steer_multiplier")])
	lines.append("後方支援 空気抵抗 -%.1f%%" % (float(draft_status.get("rear_assist_air_factor", 0.0)) * 100.0))
	lines.append("速度 実際 %.0f／出力上 %.0fkm/h" % [cur, output_speed])
	lines.append("タイム %s" % LocalRaceMath.format_race_time(_race_elapsed))
	lines.append("Esc＝メニュー")
	# 前半を1列目、後半を2列目に出す。
	var left_count := ceili(lines.size() * 0.5)
	_hud_label.text = "\n".join(lines.slice(0, left_count))
	_hud_label_right.text = "\n".join(lines.slice(left_count))


## 詳細表示（診断数値・操作ガイド）の配置。診断は、操作盤の右に2列（左は順位表と操作盤が使う）。ガイドは右上に縦並び。
func _layout_overlay_labels() -> void:
	var outline := Color(0.03, 0.05, 0.1, 0.9)
	var panel_top := -(RaceHud.PANEL_BOTTOM_MARGIN + RaceHud.PANEL_HEIGHT)
	var column_width := 320.0
	for label: Label in [_hud_label, _hud_label_right]:
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = panel_top
		label.offset_bottom = -RaceHud.PANEL_BOTTOM_MARGIN
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.clip_text = false
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_constant_override("line_spacing", -5)
		label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
		label.add_theme_color_override("font_outline_color", outline)
		label.add_theme_constant_override("outline_size", 5)
	var first_left := RaceHud.panel_left(get_viewport().get_visible_rect().size.x) + RaceHud.PANEL_WIDTH + 12.0
	_hud_label.offset_left = first_left
	_hud_label.offset_right = first_left + column_width
	_hud_label_right.offset_left = first_left + column_width
	_hud_label_right.offset_right = first_left + column_width * 2.0
	_guide_label.anchor_left = 1.0
	_guide_label.anchor_right = 1.0
	_guide_label.anchor_top = 0.0
	_guide_label.anchor_bottom = 0.0
	_guide_label.offset_left = -440.0
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


## 丸い操作盤の位置。左の端を、仮想パッドのラインのボタンのすぐ右に、下の端を、画面の下に寄せる
## （名前のための外側の余白は、画面の外へ出してよい）。
func _place_round_hud() -> void:
	var screen := get_viewport().get_visible_rect().size
	# 絵は、画面の実際の点の細かさで描く（拡大してぼやけないように）。貼るときに、もとの大きさへ戻す。
	var zoom := maxf(get_viewport().get_stretch_transform().get_scale().x, 1.0)
	_round_hud.call("set_radius", ROUND_HUD_RADIUS * zoom)
	var drawn_size := _round_hud.custom_minimum_size.ceil()
	_round_hud_viewport.size = Vector2i(drawn_size)
	_round_hud.position = Vector2.ZERO
	_round_hud.size = drawn_size
	var left := TouchControls.LINE_BUTTONS_RIGHT + ROUND_HUD_STICK_GAP
	var center := Vector2(left + ROUND_HUD_RADIUS, screen.y - ROUND_HUD_BOTTOM_MARGIN - ROUND_HUD_RADIUS)
	_round_hud_view.size = drawn_size / zoom
	_round_hud_view.position = center - _round_hud_view.size * 0.5
	_round_hud_drawn_msec = -1000000
	if _race_hud_viewport != null:
		# 順位表の絵は、画面いっぱい。画面の実際の点の細かさで描く。
		_race_hud_viewport.size = Vector2i((screen * zoom).ceil())
		_race_hud_viewport.size_2d_override = Vector2i(screen.ceil())
		_race_hud_view.position = Vector2.ZERO
		_race_hud_view.size = screen


func _update_race_hud() -> void:
	if _race_hud == null:
		return
	# 操作盤に渡す値は、描き直すコマでだけ作る（順位表の値づくりなどが、毎コマだと重いため）。
	# 順位表を画面にそのまま出しているとき（ウェブ版オフラインテスト以外）は、今までどおり毎コマ。
	var now := Time.get_ticks_msec()
	var race_hud_due := _race_hud_viewport == null or float(now - _race_hud_drawn_msec) >= 1000.0 / RACE_HUD_UPDATES_PER_S
	var round_hud_due := float(now - _round_hud_drawn_msec) >= 1000.0 / ROUND_HUD_UPDATES_PER_S
	if not race_hud_due and not round_hud_due:
		return
	var air_breakdown: Dictionary = _player.call("get_air_reduction_breakdown")
	var place := _live_place(_player) if _race_started else 0
	var style_id := str(_player.call("get_running_style_id"))
	var has_style := not style_id.is_empty()
	var attribute_id := str(_player.call("get_attribute_id"))
	var state := {
		"place": place,
		"player_name": str(_player.get("display_name")),
		"trainer_name": RaceSession.trainer_name_for(str(_player.call("get_snapshot")["id"]), true),
		"style_group_index": PururinStatsMath.style_rank_group_index(style_id) if has_style else -1,
		"style_group_count": PururinStatsMath.rank_group_count() if has_style else 0,
		"style_rank_bonus": PururinStatsMath.rank_bonus(style_id, place, _runners.size()) if has_style and place > 0 else 0,
		"attribute_id": attribute_id,
		"attribute_color": Color.from_string(str(HudStatsConfig.values()["attributes"][attribute_id]["color"]), Color.WHITE) if not attribute_id.is_empty() else Color.WHITE,
		"field_size": _runners.size(),
		"remaining_m": maxf(_race_distance_m - float(_player.call("get_race_progress")), 0.0),
		"race_distance_m": _race_distance_m,
		"dash_ratio": _player.call("get_dash_time_ratio"),
		"boost_ratio": _player.call("get_boost_time_ratio"),
		"boost_points": _player.call("get_boost_points"),
		"boost_uses_left": _player.call("get_boost_uses_left"),
		"boost_max_uses": int(LocalRaceMath.Config.number("boost_max_uses")),
		"runners": _hud_runner_marks(),
		"standings": _hud_standings(),
		"time_text": LocalRaceMath.format_race_time(_race_elapsed),
		"time_s": _race_elapsed,
		"speed_kmh": _player.call("get_actual_speed"),
		"notch": int(roundi(_player.call("get_drive_level"))),
		"notch_max": int(LocalRaceMath.DRIVE_LEVEL_MAX),
		"braking": _player.call("is_braking"),
		"fuel_ratio": _player.call("get_stamina_ratio"),
		"heart_bpm": _player.call("get_heart_rate_bpm"),
		# 鼓動の音が鳴っていないあいだ（スタート前・ゴール後）は、光らせない。
		"heart_beat_phase": RaceAudio.heartbeat_phase(float(_player.call("get_heart_rate_bpm"))) if _race_started and not bool(_player.call("is_finished")) else 1.0,
		"heart_min_bpm": LocalRaceMath.Config.number("heart_rate_min_bpm"),
		"heart_normal_max_bpm": LocalRaceMath.Config.number("heart_rate_normal_max_bpm"),
		"heart_max_bpm": LocalRaceMath.Config.number("heart_rate_overheat_max_bpm"),
		"air_green": float(air_breakdown["aero_rear"]),
		"air_blue": float(air_breakdown["draft"]),
		"countdown": not _race_started,
	}
	if bool(_player.call("is_finished")):
		# 操作盤は、ゴールした時点の表示で止める（あとで見返せるように）。順位表だけは、動かし続ける。
		if _finish_hud_state.is_empty():
			state["time_text"] = LocalRaceMath.format_race_time(float(_player.call("get_finish_time")))
			state["time_s"] = float(_player.call("get_finish_time"))
			_finish_hud_state = state
		var frozen := _finish_hud_state.duplicate()
		frozen["standings"] = state["standings"]
		state = frozen
	if _race_hud_viewport == null:
		_race_hud.call("update_state", state)
	elif race_hud_due:
		# 順位表と丸い操作盤は、同じコマで描き直さない（重いコマを作らないため）。
		_race_hud_drawn_msec = now
		_race_hud.call("update_state", state)
		_race_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return
	if round_hud_due:
		_round_hud_drawn_msec = now
		_round_hud.call("update_state", state)
		_round_hud_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


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


## 左上の順位表に出す全走者。今の順位の順（ゴール済みは着順で上）。
func _hud_standings() -> Array:
	var rows: Array = []
	for runner in _runners:
		var place := _live_place(runner)
		var style_id := str(runner.call("get_running_style_id"))
		var has_style := not style_id.is_empty()
		var finished := bool(runner.call("is_finished"))
		var condition := {"heart_bpm": float(runner.call("get_heart_rate_bpm")), "fuel_ratio": float(runner.call("get_stamina_ratio"))}
		if finished:
			# ゴールした行の心拍と体力は、ゴールした時点の数字で止める。
			if not _finish_standing_values.has(runner):
				_finish_standing_values[runner] = condition
			condition = _finish_standing_values[runner]
		rows.append({
			"place": place,
			"name": str(runner.get("display_name")),
			"color": PururinVisualStyle.color_for_racer_id(str(runner.call("get_snapshot")["id"])),
			"player": runner == _player,
			"finished": finished,
			"finish_time": float(runner.call("get_finish_time")),
			"style_group_index": PururinStatsMath.style_rank_group_index(style_id) if has_style else -1,
			"style_group_count": PururinStatsMath.rank_group_count() if has_style else 0,
			"style_rank_bonus": PururinStatsMath.rank_bonus(style_id, place, _runners.size()) if has_style else 0,
			"heart_bpm": float(condition["heart_bpm"]),
			"fuel_ratio": float(condition["fuel_ratio"]),
		})
	# 同じ順位（横並び）は、元の並びのままにする。
	for index in rows.size():
		rows[index]["index"] = index
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["place"] < b["place"] if a["place"] != b["place"] else a["index"] < b["index"])
	return rows


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
	_celebration.stop()
	RaceAudio.stop_final_stretch_ambience()
	RaceAudio.stop_heartbeat()
	if not _online_view and not _is_online_host():
		_telemetry_recorder.finalize(_race_elapsed, _runners)
	# 結果の板を出しても、走者は止めない。
	_race_over = true
	_pause_panel.visible = false
	_result_panel.visible = true
	# 結果の板と重ならないように、仮想パッドは引っ込める。
	_touch_controls.call("set_pad_shown", false)
	_result_board.call("set_rows", _result_rows())
	if _result_retry_button.visible:
		_result_retry_button.grab_focus()
	else:
		_result_return_button.grab_focus()
	RaceAudio.play_result_applause()


## 着順の表の中身。着順の順に、着順・名前・色・ユーザーかどうか・タイム。
func _result_rows() -> Array:
	var ordered: Array = _runners.duplicate()
	ordered.sort_custom(func(a, b): return a.call("get_finish_order") < b.call("get_finish_order"))
	var rows: Array = []
	for r in ordered:
		rows.append({
			"place": int(r.call("get_finish_order")),
			"name": str(r.get("display_name")),
			"trainer": str((r.get("_pururin") as Dictionary)["trainer_name"]),
			"color": PururinVisualStyle.color_for_racer_id(str(r.call("get_snapshot")["id"])),
			"player": r == _player,
			"time_text": LocalRaceMath.format_race_time(float(r.call("get_finish_time"))),
		})
	return rows


## 一時停止の板に、ゲームパッドのボタンのマークを付ける：STARTで開く・閉じる、Bでレースに戻る。
func _add_pause_marks() -> void:
	var title: Label = _pause_panel.get_node("PauseBox/PauseTitle")
	var font := title.get_theme_font("font")
	var text_width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
	var start_mark := MenuStyle.mark("START", 22.0)
	start_mark.name = "StartMark"
	title.add_child(start_mark)
	start_mark.set_anchors_preset(Control.PRESET_CENTER)
	start_mark.offset_left = text_width * 0.5 + 12.0
	start_mark.offset_right = start_mark.offset_left + start_mark.custom_minimum_size.x
	start_mark.offset_top = -11.0
	start_mark.offset_bottom = 11.0
	MenuStyle.add_mark(_resume_button, "B", 24.0)


## 一時停止の板から開く操作ガイド。閉じると板へ戻り、レースは一時停止のまま。
func _add_pause_guide_button() -> void:
	var box := _pause_panel.get_node("PauseBox") as VBoxContainer
	_pause_guide_button = MenuStyle.button("操作ガイド", 20, MenuStyle.COLOR_BUTTON_QUIET)
	_pause_guide_button.name = "PauseControlGuideButton"
	_pause_guide_button.custom_minimum_size = Vector2(0.0, 44.0)
	_pause_guide_button.pressed.connect(_open_control_guide_from_pause)
	UIAudio.bind_button_sound(_pause_guide_button, "confirmation")
	box.add_child(_pause_guide_button)
	box.move_child(_pause_guide_button, _pause_return_button.get_index())
	_resume_button.focus_neighbor_bottom = _resume_button.get_path_to(_pause_guide_button)
	_pause_guide_button.focus_neighbor_top = _pause_guide_button.get_path_to(_resume_button)
	_pause_guide_button.focus_neighbor_bottom = _pause_guide_button.get_path_to(_pause_return_button)
	_pause_return_button.focus_neighbor_top = _pause_return_button.get_path_to(_pause_guide_button)
	_pause_panel.offset_top = -150.0
	_pause_panel.offset_bottom = 150.0


func _open_control_guide_from_pause() -> void:
	if not _paused or is_instance_valid(_control_guide):
		return
	_guide_pad_was_shown = bool(_touch_controls.call("is_pad_shown"))
	_touch_controls.call("set_pad_shown", false)
	_touch_controls.set_process_input(false)
	_pause_panel.visible = false
	var guide := ControlGuide.new()
	_control_guide = guide
	$UI.add_child(guide)
	guide.closed.connect(_on_control_guide_closed)


func _on_control_guide_closed() -> void:
	_control_guide = null
	if is_instance_valid(_touch_controls):
		_touch_controls.set_process_input(true)
		_touch_controls.call("set_pad_shown", _guide_pad_was_shown if not _race_over else false)
	_guide_pad_was_shown = false
	if _paused and not _race_over:
		_pause_panel.visible = true
		_pause_guide_button.grab_focus()


## 結果の板の中身を組む：見出しの下に飾りの線、着順の表、戻るボタン。
func _build_result_board() -> void:
	var box: VBoxContainer = _result_panel.get_node("ResultBox")
	var title: Label = box.get_node("ResultTitle")
	# 文字だけの着順（ResultLabel）は、この場面を土台にしているオンライン用の場面が使う。ローカルでは表を出すので隠す。
	(box.get_node("ResultLabel") as Label).visible = false
	title.add_theme_color_override("font_color", RaceHud.COLOR_GOLD)
	var line := ColorRect.new()
	line.color = Color(RaceHud.COLOR_GOLD, 0.7)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	box.add_child(line)
	box.move_child(line, title.get_index() + 1)
	_result_board = RaceResultBoard.new()
	_result_board.name = "ResultBoard"
	box.add_child(_result_board)
	box.move_child(_result_board, line.get_index() + 1)
	# 板の大きさは固定。表は上から並べ、戻るボタンは、板の一番下に置く。
	var spacer := Control.new()
	spacer.name = "ResultSpacer"
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(spacer)
	box.move_child(spacer, _result_return_button.get_index())
	# 一番下に、ボタンを2つ横に並べる：「もう1回 同条件で」と「レース選択へ戻る」。
	var buttons := HBoxContainer.new()
	buttons.name = "ResultButtons"
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_result_retry_button = MenuStyle.button("もう1回 同条件で", 20)
	_result_retry_button.name = "ResultRetryButton"
	_result_retry_button.custom_minimum_size = Vector2(0.0, 56.0)
	_result_retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_retry_button.pressed.connect(_retry_same_race)
	UIAudio.bind_button_sound(_result_retry_button, "confirmation")
	buttons.add_child(_result_retry_button)
	_result_return_button.reparent(buttons)
	MenuStyle.style_button(_result_return_button, 20, MenuStyle.COLOR_BUTTON_QUIET)
	_result_return_button.custom_minimum_size = Vector2(0.0, 56.0)
	_result_return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_retry_button.focus_neighbor_right = _result_retry_button.get_path_to(_result_return_button)
	_result_return_button.focus_neighbor_left = _result_return_button.get_path_to(_result_retry_button)


func _set_paused(paused: bool) -> void:
	_paused = paused
	# オンラインでは、レースはサーバーで進んでいるので、止めない（板を出すだけ）。
	if not _online_view:
		for r in _runners:
			r.call("set_paused", paused)
	if _race_over:
		_pause_panel.visible = false
		return
	_pause_panel.visible = paused
	if paused:
		_resume_button.grab_focus()


## 場面を抜けるときは、必ず速さをふつうに戻す（スローの最中にメニューへ戻っても、残さない）。
func _exit_tree() -> void:
	_celebration.stop()
	RaceAudio.stop_final_stretch_ambience()
	RaceAudio.stop_heartbeat()
	RaceAudio.stop_race_oneshots()


## 同じ距離・同じ枠順・同じ顔ぶれで、もう1回走る（レース選択で決めた内容は、そのまま）。
func _retry_same_race() -> void:
	_celebration.stop()
	get_tree().change_scene_to_file(LOCAL_RACE_SCENE)


func _return_to_race_select() -> void:
	_celebration.stop()
	if _online_view:
		_leave_online_race()
		return
	RaceSession.mark_returning_from_race()
	get_tree().change_scene_to_file(RACE_SELECT_SCENE)
