extends SceneTree
## 強化学習：画面なしのゴドー1つぶん。Python の指示で、レースを1本ずつ走らせる。
## 起動：godot --headless --fixed-fps 30 --path client -s ../lab/rl/rl_worker.gd -- port=<Python が待つ番号> field=<出る数>
## つながったら、最初に {"obs_size", "action_sizes"} を送る（Python が、見るものと操作の大きさを知るため）。
## 人と走るとき（play.py）は --headless と --fixed-fps を付けずに、select=1 を付けて起こす（画面あり）。
##   つながったら、Python から選べるCPUの一覧 {"cmd": "choices", "items": [{id, label}]} が届く。
##   まず、CPUを選ぶ画面（rl_picker.gd）を出す。決定で、ゲームのレース選択の画面へ。
##   出走表の「スタート」で、選んだ内容のまま、各枠をCPUを選ぶ画面で選んだとおりに走らせる
##   （ゲームの RaceSession.race_starter に、ここの _start_from_select を入れる）。
##   そのときは、ゴドーから {"start": spec}（drivers：枠 → CPUの id）を送り、Python が reset を返す（いちばん新しいCPUを読み直してから）。
##   結果の板の「もう1回」は同じ内容で次のレース、「戻る」はCPUを選ぶ画面へ。レース選択の「戻る」も、CPUを選ぶ画面へ。
## shot_after_s=<秒> shot=<png> で、画面を撮って閉じる（確かめ用）。
## Python からの指示（1行に1つの JSON）：
##   {"cmd": "reset", "spec": {seed, distance_m, lineup, seats: [育てるCPUの枠], human_gate}, "settings": rl_settings.json の中身}
##   {"cmd": "step", "actions": {"枠": [ノッチ, ライン, ブレーキ, ダッシュ, ブースト], …}}（レースの途中だけ）
##   {"cmd": "close"}
## ゴドーから：決める間ごとに {"seats": [{gate, obs, mask, reward}], "over": false}、終わったら {"seats", "over": true, "race": 結果}。

const RlLink := preload("rl_link.gd")
const RlRace := preload("rl_race.gd")
const RlObserve := preload("rl_observe.gd")
const RlPicker := preload("rl_picker.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RACE_SELECT_SCENE := "res://scenes/race_select.tscn"

var _link := RlLink.new()
var _current: Node
var _shot_after_s := -1.0
var _shot_path := ""
var _clock := 0.0
## 人と走るときの、今のレースの内容（「もう1回」で使う）。
var _play_spec := {}
## 選べるCPUの一覧（play.py から）と、CPUを選ぶ画面で選んだ内容（{me, others}）。
var _choices: Array = []
var _selection := {}
var _picker: Node


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
		var choices: Dictionary = _link.receive()
		_choices = choices.get("items", [])
		RaceSession.race_starter = _start_from_select
		RaceSession.slot_driver_label = _driver_label_for_slot
		# レース選択の「戻る」は、ゲームのメニューではなく、CPUを選ぶ画面へ。
		RaceSession.race_select_back = func(): _show_picker.call_deferred()
		_show_picker.call_deferred()
		return
	_next.call_deferred()


## CPUを選ぶ画面を出す。決定で、レース選択の画面へ。
func _show_picker() -> void:
	if current_scene != null and is_instance_valid(current_scene):
		current_scene.queue_free()
	_picker = RlPicker.new()
	root.add_child(_picker)
	current_scene = _picker
	_picker.setup(_choices, _selection)
	_picker.decided.connect(func(selection: Dictionary):
		_selection = selection
		change_scene_to_file.call_deferred(RACE_SELECT_SCENE))


## 出走表の「スタート」：選んだ内容から、レースの内容を作る。
## あなたの枠（レース選択で自分にした枠）は、CPUを選ぶ画面のいちばん上の行のとおり（あなた、またはCPU＝観戦）。
## 相手の枠には、枠の順に、相手1〜7の行のCPUを当てはめる。
func _start_from_select() -> void:
	var lineup: Array = []
	lineup.resize(RaceSession.SLOT_COUNT)
	lineup.fill("")
	var seats: Array = []
	var trainers := {}
	var drivers := {}
	var labels := {}
	var shorts := {}
	var others: Array = _selection.get("others", [])
	var me := str(_selection.get("me", RlPicker.HUMAN))
	var human_gate := -1
	var watch_gate := -1
	var index := 0
	for entry: Dictionary in RaceSession.field_entries():
		var gate := int(entry["gate"])
		lineup[gate] = str(entry["id"])
		trainers[str(gate)] = str(entry["trainer_id"])
		var driver := ""
		if bool(entry["player"]):
			if me == RlPicker.HUMAN:
				human_gate = gate
				continue
			watch_gate = gate
			driver = me
		else:
			driver = str(others[index]) if index < others.size() else (str(_choices[0]["id"]) if not _choices.is_empty() else "")
			index += 1
		seats.append(gate)
		drivers[str(gate)] = driver
		labels[str(gate)] = _label_of(driver)
		shorts[str(gate)] = _short_of(driver)
	_play_spec = {
		"distance_m": RaceSession.selected_distance_m(), "lineup": lineup, "seats": seats, "trainers": trainers,
		"human_gate": human_gate, "watch_gate": watch_gate, "drivers": drivers, "labels": labels, "shorts": shorts,
	}
	current_scene.queue_free()
	_play()


## レース選択と出走表のトレーナー欄に出す、その枠を走らせるCPUの名前（あなたが走る枠は空）。
## 相手の枠は、空きの枠を除いて、枠の順に相手1〜7。
func _driver_label_for_slot(slot: int) -> String:
	var me := str(_selection.get("me", RlPicker.HUMAN))
	if RaceSession.is_user_slot(slot):
		return "" if me == RlPicker.HUMAN else _short_of(me)
	var others: Array = _selection.get("others", [])
	var index := 0
	for gate in RaceSession.SLOT_COUNT:
		if RaceSession.is_user_slot(gate) or RaceSession.slot_pururin_id(gate).is_empty():
			continue
		if gate == slot:
			return _short_of(str(others[index])) if index < others.size() else ""
		index += 1
	return ""


## 順位表に出す、短いCPUの名前（例：「育成1」「脚質1 20:27」）。
static func _short_of(id: String) -> String:
	var name := id.get_slice(":", 1)
	var parts := name.split("_")
	if id.begins_with("pool:") and parts.size() >= 3:
		return "%s %s:%s" % [parts[0], parts[2].substr(0, 2), parts[2].substr(2, 2)]
	return name


func _label_of(id: String) -> String:
	for choice: Dictionary in _choices:
		if str(choice["id"]) == id:
			return str(choice["label"])
	return id


## 人と走るレースを1本始める（くじの番号だけ毎回変える）。
func _play() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	var spec := _play_spec.duplicate(true)
	spec["seed"] = randi()
	_link.send({"start": spec})
	_next.call_deferred()


## 人と走るレースの「戻る」：CPUを選ぶ画面へ（決定で、レース選択へ）。
func _back_to_picker() -> void:
	if _current != null:
		_current.queue_free()
		_current = null
	RaceSession.mark_returning_from_race()
	_show_picker()


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
	_current.back_requested.connect(func(): _back_to_picker.call_deferred())
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
