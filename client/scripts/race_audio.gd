extends Node
## ローカルレース中だけに使う、終盤・スタート・ゴールの音声。

const STADIUM_AMBIENCE_PATH := "res://assets/audio/race/stadium_ambience.mp3"
const CROWD_CHEER_PATH := "res://assets/audio/race/crowd_cheer.mp3"
const COUNTDOWN_START_PATH := "res://assets/audio/race/countdown_start.mp3"
const HEARTBEAT_PATH := "res://assets/audio/race/heartbeat.ogg"
const BOOST_PATH := "res://assets/audio/race/boost.ogg"
const DASH_PATH := "res://assets/audio/race/dash.ogg"
const SOUND_PATHS := {
	"stadium_ambience": STADIUM_AMBIENCE_PATH,
	"crowd_cheer": CROWD_CHEER_PATH,
	"countdown_start": COUNTDOWN_START_PATH,
	"heartbeat": HEARTBEAT_PATH,
	"boost": BOOST_PATH,
	"dash": DASH_PATH,
}
## ざわめきが消えたとみなす音量。これより下は、ほぼ聞こえない。
const AMBIENCE_MIN_DB := -30.0
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
	if _ambience.stream is AudioStreamMP3:
		(_ambience.stream as AudioStreamMP3).loop = true


## 無音から鳴らし始める。大きさは set_final_stretch_level() で動かす。
func start_final_stretch_ambience() -> void:
	if _ambience.playing:
		return
	_kill_ambience_fade()
	_ambience.volume_db = AMBIENCE_MIN_DB
	_ambience.play()


## ざわめきの大きさ。0.0 でほぼ無音、1.0 でいちばん大きい。
func set_final_stretch_level(level: float) -> void:
	if _ambience_fade != null and _ambience_fade.is_running():
		return
	_ambience.volume_db = lerpf(AMBIENCE_MIN_DB, 0.0, clampf(level, 0.0, 1.0))


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


func play_countdown_start() -> void:
	_countdown.play()


## ブーストを使ったとき。実際に出たときだけ鳴らす。
func play_boost() -> void:
	_boost.play()


## ダッシュを使ったとき。実際に出たときだけ鳴らす。
func play_dash() -> void:
	_dash.play()


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


func stop_heartbeat() -> void:
	_heartbeat.stop()
	_heartbeat_elapsed_s = 0.0


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


func _player(player_name: String, path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = load(path) as AudioStream
	if player.stream == null:
		push_error("レース音声を読み込めません: %s" % path)
	add_child(player)
	return player
