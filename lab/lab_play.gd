extends SceneTree
## CPU育成ラボ：育てている頭と、人がいっしょに走る（画面あり。このPCの中だけ）。
## 席は8つ：人が1つ。のこり7つは、自分以外のぷるりんから7体（くじ）。それぞれ、育成の最後の代の「中心」の頭が乗る。
## 結果の板の「もう1回 同条件で」で、次のレース（くじ・枠順・距離が変わる）。「戻る」でラボを閉じる。
## 結果：lab/runs/human/<日時>.json（だれがどの頭か、着順・タイムなど）。
## 起動（client/ で）：godot --path . -s ../lab/lab_play.gd -- run=<育成の out の名前> me=<自分のぷるりん> distance=2000
##   distance を書かないときは、レースごとに、設定の距離を順に回す。

const LabRace := preload("lab_race.gd")
const LabScore := preload("lab_score.gd")
const LabBatch := preload("lab_batch.gd")
const KnobBrain := preload("knob_brain.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

var _settings: Dictionary
var _run_dir := ""
var _me := ""
var _distance := 0.0
var _brains := {}
## ぷるりん → その子の頭の名前。
var _brain_of := {}
var _rng := RandomNumberGenerator.new()
var _race_count := 0
var _current: Node
## 画面を撮って閉じる（見た目の確かめ用）：撮る秒数と、置き場所。
var _shot_after_s := -1.0
var _shot_path := ""
var _clock := 0.0


func _initialize() -> void:
	var args := LabBatch.user_args()
	_settings = LabScore.load_settings()
	_run_dir = LabScore.lab_dir().path_join("runs/%s" % str(args["run"]))
	_me = str(args["me"])
	_distance = float(args.get("distance", "0"))
	_shot_after_s = float(args.get("shot_after_s", "-1"))
	_shot_path = str(args.get("shot", ""))
	_rng.randomize()
	_load_brains()
	# ゲームの部品が用意されてから始める。
	_start_race.call_deferred()


## 育成の最後の代から、ぷるりんごとの中心の頭を読む。
func _load_brains() -> void:
	var progress: Array = JSON.parse_string(FileAccess.get_file_as_string(_run_dir.path_join("progress.json")))
	var last: Dictionary = progress[-1]
	var gen_dir := _run_dir.path_join("gen_%03d" % int(last["generation"]))
	for id: String in last["pururins"]:
		var brain := KnobBrain.load_file(gen_dir.path_join("brains/%s.json" % str(last["pururins"][id]["next_center"])))
		_brains[str(brain["id"])] = brain
		_brain_of[id] = str(brain["id"])
	print("頭を読みました：%s（%d代目のあと）" % [_run_dir, int(last["generation"])])


func _start_race() -> void:
	var others: Array = (PururinRosterConfig.values()["roster"] as Array).filter(func(p): return str(p["id"]) != _me)
	LabBatch._shuffle(others, _rng)
	var seats: Array = [{"pururin": _me, "brain": ""}]
	for p: Dictionary in others.slice(0, LabBatch.FIELD - 1):
		seats.append({"pururin": str(p["id"]), "brain": _brain_of[str(p["id"])]})
	LabBatch._shuffle(seats, _rng)
	var lineup: Array = []
	var brain_gates := {}
	var human_gate := -1
	for gate in seats.size():
		lineup.append(seats[gate]["pururin"])
		if str(seats[gate]["brain"]).is_empty():
			human_gate = gate
		else:
			brain_gates[str(gate)] = seats[gate]["brain"]
	var distances: Array = _settings["distances_m"]
	var distance := _distance if _distance > 0.0 else float(distances[_race_count % distances.size()])
	var spec := {
		"seed": _rng.randi(), "distance_m": distance, "lineup": lineup, "focus_gate": -1,
		"brain_gates": brain_gates, "human_gate": human_gate,
	}
	_current = LabRace.new()
	root.add_child(_current)
	_current.race_done.connect(_on_race_done)
	_current.start(spec, _brains, _settings)
	_rewire_buttons(_current.race())
	_race_count += 1
	print("レース %d：%dm、あなたは %d 枠" % [_race_count, int(distance), human_gate + 1])


## 結果の板と一時停止の板のボタンを、ラボの動きに付け替える（ゲームのメニューへは行かない）。
func _rewire_buttons(race: Node) -> void:
	var retry: Button = race.get("_result_retry_button")
	_disconnect_all(retry)
	retry.pressed.connect(_next_race)
	for name in ["_result_return_button", "_pause_return_button"]:
		var button: Button = race.get(name)
		_disconnect_all(button)
		button.pressed.connect(quit)


static func _disconnect_all(button: Button) -> void:
	# ゲームのメニューへ行くつなぎだけを外す（ボタンの音などは残す）。
	for connection: Dictionary in button.pressed.get_connections():
		var callable: Callable = connection["callable"]
		if str(callable.get_method()) in ["_retry_same_race", "_return_to_race_select", "_on_pause_return_pressed"]:
			button.pressed.disconnect(callable)


func _next_race() -> void:
	_current.queue_free()
	_start_race.call_deferred()


func _on_race_done(result: Dictionary) -> void:
	result["me"] = _me
	result["run"] = _run_dir.get_file()
	var stamp := Time.get_datetime_string_from_system().replace(":", "")
	LabBatch.save_json(LabScore.lab_dir().path_join("runs/human/%s.json" % stamp), result)
	for row: Dictionary in result["rows"]:
		var who := "あなた" if bool(row["human"]) else str(row["brain"])
		print("  %d位 %s（%s）%.2f 秒" % [int(row["place"]), who, str(row["pururin"]), float(row["time"])])


func _process(delta: float) -> bool:
	_clock += delta
	if _shot_after_s >= 0.0 and _clock >= _shot_after_s:
		root.get_texture().get_image().save_png(_shot_path)
		print("画面を撮りました：" + _shot_path)
		return true
	return false
