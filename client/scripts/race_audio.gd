extends Node
## ローカルレースの音声。入場、カウントダウン、走行、ゴール。

const STADIUM_AMBIENCE_PATH := "res://assets/audio/race/stadium_ambience.mp3"
const CROWD_CHEER_PATH := "res://assets/audio/race/crowd_cheer.mp3"
const COUNTDOWN_START_PATH := "res://assets/audio/race/countdown_start.mp3"
const HEARTBEAT_PATH := "res://assets/audio/race/heartbeat.ogg"
const BOOST_PATH := "res://assets/audio/race/boost.mp3"
const DASH_PATH := "res://assets/audio/race/dash.mp3"
const SPOTLIGHT_PATH := "res://assets/audio/race/spotlight.mp3"
const GOAL_BELL_PATH := "res://assets/audio/race/goal_bell.mp3"
const CONTACT_PATH := "res://assets/audio/race/contact.mp3"
const RESULT_APPLAUSE_PATH := "res://assets/audio/race/result_applause.mp3"
const SOUND_PATHS := {
	"stadium_ambience": STADIUM_AMBIENCE_PATH,
	"crowd_cheer": CROWD_CHEER_PATH,
	"countdown_start": COUNTDOWN_START_PATH,
	"heartbeat": HEARTBEAT_PATH,
	"boost": BOOST_PATH,
	"dash": DASH_PATH,
	"spotlight": SPOTLIGHT_PATH,
	"goal_bell": GOAL_BELL_PATH,
	"contact": CONTACT_PATH,
	"result_applause": RESULT_APPLAUSE_PATH,
}
## ざわめきが消えたとみなす音量。これより下は、ほぼ聞こえない。
const AMBIENCE_MIN_DB := -30.0
## レース画面に入ったときのざわめき。終盤は、ここからさらに大きくする。
const AMBIENCE_ENTRY_DB := -10.0
const AMBIENCE_LOUD_DB := 0.0
## 自分以外が1位でゴールした鐘。ゴールのそばは大きく、遠いと小さい。
## 元の鐘素材は平均音量が低いため、ゴール直前では明確に聞こえる音量へ補正する。
const BELL_NEAR_DB := 5.0
const BELL_FAR_DB := -32.0
## 心拍の音。ふだんは小さく、危ない心拍数から大きくしていく。
const HEARTBEAT_QUIET_DB := -24.0
const HEARTBEAT_LOUD_DB := -6.0
const HEARTBEAT_LOUD_START_BPM := 190.0
const HEARTBEAT_LOUD_FULL_BPM := 230.0
## 鳴る間隔の基準。この心拍数のとき、ちょうど1秒おきに鳴る。
## 心拍数が上がれば間隔はせまく、下がれば広くなる。
const HEARTBEAT_PACE_BPM := 200.0
## ブーストとダッシュの音量。
const DRIVE_ACTION_DB := -6.0

var _ambience: AudioStreamPlayer
var _cheer: AudioStreamPlayer
var _countdown: AudioStreamPlayer
var _heartbeat: AudioStreamPlayer
var _boost: AudioStreamPlayer
var _dash: AudioStreamPlayer
var _spotlight: AudioStreamPlayer
var _bell: AudioStreamPlayer
var _contact: AudioStreamPlayer
var _applause: AudioStreamPlayer
var _ambience_fade: Tween
## 次の拍までの、たまった時間。
var _heartbeat_elapsed_s := 0.0


func _ready() -> void:
	_ambience = _player("StadiumAmbience", STADIUM_AMBIENCE_PATH)
	_cheer = _player("CrowdCheer", CROWD_CHEER_PATH)
	_countdown = _player("CountdownStart", COUNTDOWN_START_PATH)
	_heartbeat = _player("Heartbeat", HEARTBEAT_PATH)
	_heartbeat.volume_db = HEARTBEAT_QUIET_DB
	_boost = _player("Boost", BOOST_PATH)
	_boost.volume_db = DRIVE_ACTION_DB
	_dash = _player("Dash", DASH_PATH)
	_dash.volume_db = DRIVE_ACTION_DB
	_spotlight = _player("Spotlight", SPOTLIGHT_PATH)
	_bell = _player("GoalBell", GOAL_BELL_PATH)
	_contact = _player("Contact", CONTACT_PATH)
	_contact.volume_db = DRIVE_ACTION_DB
	_applause = _player("ResultApplause", RESULT_APPLAUSE_PATH)


## レース画面に入ったとき。スポットライトと入場の歓声を、それぞれ1回だけ鳴らす。
func play_race_entry() -> void:
	_spotlight.play()
	_set_ambience_loop(false)
	_kill_ambience_fade()
	_ambience.volume_db = AMBIENCE_ENTRY_DB
	_ambience.play()


## 終盤の歓声。ここからゴールまで途切れさせないので、繰り返し再生にする。
## 入場の歓声がまだ鳴っていれば、そのまま引き継ぐ。
func start_final_stretch_ambience() -> void:
	_set_ambience_loop(true)
	_ensure_ambience_playing(AMBIENCE_ENTRY_DB)


## 終盤のざわめき。0.0 は入場時の大きさ、1.0 はいちばん大きい。
func set_final_stretch_level(level: float) -> void:
	if _ambience_fade != null and _ambience_fade.is_running():
		return
	_ambience.volume_db = lerpf(AMBIENCE_ENTRY_DB, AMBIENCE_LOUD_DB, clampf(level, 0.0, 1.0))


## 指定の秒数をかけて、じわじわ消す。
func fade_out_final_stretch_ambience(seconds: float) -> void:
	if not _ambience.playing:
		return
	_kill_ambience_fade()
	if seconds <= 0.0:
		stop_final_stretch_ambience()
		return
	_ambience_fade = create_tween()
	_ambience_fade.tween_property(_ambience, "volume_db", AMBIENCE_MIN_DB, seconds)
	_ambience_fade.tween_callback(_on_ambience_fade_finished)


func stop_final_stretch_ambience() -> void:
	_kill_ambience_fade()
	_ambience.stop()
	_ambience.volume_db = AMBIENCE_MIN_DB


func play_player_first_cheer() -> void:
	_cheer.play()


## 1位ゴールは、鐘と歓声を必ず同時に鳴らす。
func play_player_first_goal() -> void:
	play_player_finish_bell()
	play_player_first_cheer()


## 自分が着順に関係なくゴールした瞬間のベル。1位の歓声とは別に、必ず鳴らす。
func play_player_finish_bell() -> void:
	_bell.volume_db = BELL_NEAR_DB
	_bell.play()


func play_countdown_start() -> void:
	_countdown.play()


## ブーストを使ったとき。実際に出たときだけ鳴らす。
func play_boost() -> void:
	_boost.play()


## ダッシュを使ったとき。実際に出たときだけ鳴らす。
func play_dash() -> void:
	_dash.play()


## 自分以外が1位でゴールしたとき。remaining_m は、自分の残り距離。
func play_other_leader_finish(remaining_m: float, race_distance_m: float) -> void:
	_bell.volume_db = other_leader_finish_volume_db(remaining_m, race_distance_m)
	_bell.play()


## ゴールのそば（残り0）は BELL_NEAR_DB、スタート地点（残り＝距離）は BELL_FAR_DB。
static func other_leader_finish_volume_db(remaining_m: float, race_distance_m: float) -> float:
	if race_distance_m <= 0.0:
		return BELL_NEAR_DB
	var far := clampf(remaining_m / race_distance_m, 0.0, 1.0)
	return lerpf(BELL_NEAR_DB, BELL_FAR_DB, far)


## 接触か押し合いが始まったとき。
func play_contact() -> void:
	_contact.play()


## 着順の板を出したとき。
func play_result_applause() -> void:
	_applause.play()


## ユーザーのぷるりんの心拍に合わせて鳴らす。毎フレーム、今の心拍数と経過時間を渡す。
func update_heartbeat(bpm: float, delta: float) -> void:
	if bpm <= 0.0:
		return
	_heartbeat.volume_db = _heartbeat_volume_db(bpm)
	var interval_s := HEARTBEAT_PACE_BPM / bpm
	_heartbeat_elapsed_s += delta
	if _heartbeat_elapsed_s < interval_s:
		return
	# 間が開きすぎたとき（一時停止あけなど）に、まとめて鳴らさない。
	_heartbeat_elapsed_s = fmod(_heartbeat_elapsed_s, interval_s)
	_heartbeat.play()


## 今の鼓動の進み具合（0＝音が鳴った瞬間、1＝次の音の直前）。操作盤のハートを、音に合わせて光らせるのに使う。
func heartbeat_phase(bpm: float) -> float:
	if bpm <= 0.0:
		return 1.0
	return clampf(_heartbeat_elapsed_s / (HEARTBEAT_PACE_BPM / bpm), 0.0, 1.0)


func stop_heartbeat() -> void:
	_heartbeat.stop()
	_heartbeat_elapsed_s = 0.0


## 場面を抜けるとき。鳴りっぱなしの効果音を止める。ざわめきと心拍は、それぞれの止め関数。
func stop_race_oneshots() -> void:
	for player in [_spotlight, _bell, _contact, _countdown, _dash, _boost, _cheer, _applause]:
		if player != null:
			player.stop()


func is_final_stretch_ambience_playing() -> bool:
	return _ambience.playing


## 危ない心拍数（190）から上は、限界（230）に向かってだんだん大きくする。
func _heartbeat_volume_db(bpm: float) -> float:
	if bpm <= HEARTBEAT_LOUD_START_BPM:
		return HEARTBEAT_QUIET_DB
	var over := (bpm - HEARTBEAT_LOUD_START_BPM) / (HEARTBEAT_LOUD_FULL_BPM - HEARTBEAT_LOUD_START_BPM)
	return lerpf(HEARTBEAT_QUIET_DB, HEARTBEAT_LOUD_DB, clampf(over, 0.0, 1.0))


## 消え終わったとき。tween は自分で終わるので、ここでは止めるだけ。
func _on_ambience_fade_finished() -> void:
	_ambience_fade = null
	_ambience.stop()
	_ambience.volume_db = AMBIENCE_MIN_DB


func _kill_ambience_fade() -> void:
	if _ambience_fade != null:
		_ambience_fade.kill()
		_ambience_fade = null


func _set_ambience_loop(enabled: bool) -> void:
	if _ambience.stream is AudioStreamMP3:
		(_ambience.stream as AudioStreamMP3).loop = enabled


## 鳴っていなければ、指定の大きさで流し始める。鳴っているあいだは何もしない
## （終盤に大きくしたぶんを、入場時の大きさへ戻さないため）。
func _ensure_ambience_playing(volume_db: float) -> void:
	if _ambience.playing:
		return
	_kill_ambience_fade()
	_ambience.volume_db = volume_db
	_ambience.play()


func _player(player_name: String, path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = load(path) as AudioStream
	if player.stream == null:
		push_error("レース音声を読み込めません: %s" % path)
	add_child(player)
	return player
