extends SceneTree
## 強化学習：画面なしのゴドー1つぶん。Python の指示で、レースを1本ずつ走らせる。
## 起動：godot --headless --fixed-fps 30 --path client -s ../lab/rl/rl_worker.gd -- port=<Python が待つ番号> field=<出る数>
## つながったら、最初に {"obs_size", "action_sizes"} を送る（Python が、見るものと操作の大きさを知るため）。
## 人と走るとき（play.py）は --headless と --fixed-fps を付けずに、select=1 を付けて起こす（画面あり）。
##   ゲームのレース選択の画面を出し、出走表の「スタート」で、選んだ内容のまま、あなた以外の席を育てるCPUにしてレースを始める
##   （ゲームの RaceSession.race_starter に、ここの _start_from_select を入れる）。
##   そのときは、ゴドーから {"start": spec} を送り、Python が reset を返す（Python が、いちばん新しいCPUを読み直してから）。
##   結果の板の「もう1回」は同じ内容で次のレース、「戻る」はレース選択の画面へ。
## shot_after_s=<秒> shot=<png> で、画面を撮って閉じる（確かめ用）。
## Python からの指示（1行に1つの JSON）：
##   {"cmd": "reset", "spec": {seed, distance_m, lineup, seats: [育てるCPUの枠], human_gate}, "settings": rl_settings.json の中身}
##   {"cmd": "step", "actions": {"枠": [ノッチ, ライン, ブレーキ, ダッシュ, ブースト], …}}（レースの途中だけ）
##   {"cmd": "close"}
## ゴドーから：決める間ごとに {"seats": [{gate, obs, mask, reward}], "over": false}、終わったら {"seats", "over": true, "race": 結果}。

const RlLink := preload("rl_link.gd")
const RlRace := preload("rl_race.gd")
const RlObserve := preload("rl_observe.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RACE_SELECT_SCENE := "res://scenes/race_select.tscn"

var _link := RlLink.new()
var _current: Node
var _shot_after_s := -1.0
var _shot_path := ""
var _clock := 0.0
## 人と走るときの、今のレースの内容（「もう1回」で使う）。
var _play_spec := {}


func _initialize() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	_shot_after_s = float(args.get("shot_after_s", "-1"))
	_shot_path = str(args.get("shot", ""))
	if not _link.open(int(args.get("port", "0"))):
		push_error("Python につながりませんでした")
		quit(1)
		return
	_link.send({"obs_size": RlObserve.size(int(args.get("field", "8"))), "action_sizes": RlObserve.ACTION_SIZES})
	if args.get("select", "") == "1":
		RaceSession.race_starter = _start_from_select
		change_scene_to_file.call_deferred(RACE_SELECT_SCENE)
		return
	_next.call_deferred()


## 出走表の「スタート」：選んだ内容から、レースの内容を作る（あなたの席＝人、ほかの選んだ席＝育てるCPU）。
func _start_from_select() -> void:
	var lineup: Array = []
	lineup.resize(RaceSession.SLOT_COUNT)
	lineup.fill("")
	var seats: Array = []
	var trainers := {}
	for entry: Dictionary in RaceSession.field_entries():
		var gate := int(entry["gate"])
		lineup[gate] = str(entry["id"])
		if not bool(entry["player"]):
			seats.append(gate)
			trainers[str(gate)] = str(entry["trainer_id"])
	_play_spec = {
		"distance_m": RaceSession.selected_distance_m(), "lineup": lineup, "seats": seats, "trainers": trainers,
		"human_gate": RaceSession.user_slot(),
	}
	current_scene.queue_free()
	_play()


## 人と走るレースを1本始める（くじの番号だけ毎回変える）。
func _play() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var spec := _play_spec.duplicate(true)
	spec["seed"] = randi()
	_link.send({"start": spec})
	_next.call_deferred()


## 人と走るレースの「戻る」：レース選択の画面へ。
func _back_to_select() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	RaceSession.mark_returning_from_race()
	change_scene_to_file(RACE_SELECT_SCENE)


## 次の指示を待って、レースを作る。
func _next() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var message: Dictionary = _link.receive()
	if message.is_empty() or str(message.get("cmd", "")) == "close":
		quit()
		return
	if str(message["cmd"]) != "reset":
		push_error("レースの外で、reset 以外の指示が来ました: " + str(message["cmd"]))
		quit(1)
		return
	_current = RlRace.new()
	root.add_child(_current)
	_current.race_done.connect(func(): _next.call_deferred())
	_current.retry_requested.connect(func(): _play.call_deferred())
	_current.back_requested.connect(func(): _back_to_select.call_deferred())
	_current.start(_link, message["spec"], message["settings"])
	if not _current.is_ok():
		push_error("レースを作れませんでした")
		quit(1)


func _process(delta: float) -> bool:
	_clock += delta
	if _shot_after_s >= 0.0 and _clock >= _shot_after_s:
		root.get_texture().get_image().save_png(_shot_path)
		print("画面を撮りました：" + _shot_path)
		return true
	return false
