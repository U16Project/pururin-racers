extends Node
## CPU育成ラボ：レースを1本走らせる。頭の席は「通信ごしの人」と同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で操作する。
## ほかの席は、今のゲームのCPU。ゲームのファイルは変えずに、オンラインのサーバーと同じ作り方でレースを作る。
## 画面なしの早回し（lab_worker.gd）でも、画面ありの再生でも、同じこれを使う。

signal race_done(result: Dictionary)

## レースの場面とオンラインのサーバーは、起動のあと（ゲームの共通の部品＝音などが用意されてから）に読む。
## 先に読むと、画面なしの起動（-s）で、その部品が見つからない。
const LOCAL_RACE_SCENE := "res://scenes/local_race.tscn"
const ONLINE_SERVER_SCRIPT := "res://scripts/online/online_server.gd"
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const KnobBrain := preload("knob_brain.gd")
const LabSituation := preload("lab_situation.gd")

## 頭の席に付ける名前。
const TRAINEE_NAME := "（訓練中CPU）"
## 頭の席の、通信の番号（レースの中で見分けるためだけ。1枠目が 1001）。
const PEER_BASE := 1000
## 行きたいラインから、これ以上ずれていたら動く（m）。
const LINE_TOLERANCE_M := 0.2
## これ以上かかったら、レースを打ち切る（秒・レースの中の時間）。
const TIME_LIMIT_S := 600.0

var _race: Node
var _spec: Dictionary
var _brains := {}
var _seats := {}
## 全員（頭の席もゲームのCPUも）の、走りの記録。枠 → {ゴールの体力・心拍、上限超えの時間、ノッチの平均}。
var _stats := {}
var _decide_every_s := 0.0
var _inside := -1.0
var _elapsed := 0.0
var _done := false
## 人の席の枠（いなければ -1）。
var _human_gate := -1
## 1位がゴールしてから、この秒数がたったら打ち切る（人がいないレースだけ）。
var _cut_after_s := 0.0
## 1位がゴールしたときの時間（まだなら -1）。
var _first_finish_s := -1.0
var _cut := false
## 頭の判断を、毎回記録するか（確かめ用）。
var _trace := false


## spec: {seed, distance_m, lineup: [ぷるりんの番号（枠順）], focus_gate: 点を付ける枠, brain_gates: {枠: 頭の名前},
##        human_gate: 人の席の枠（人と走るときだけ）}
## brains: {頭の名前: 頭}。settings: ラボの設定（decide_every_s など）。
func start(spec: Dictionary, brains: Dictionary, settings: Dictionary) -> void:
	_spec = spec
	_brains = brains
	_human_gate = int(spec.get("human_gate", -1))
	_trace = bool(spec.get("trace", false))
	_decide_every_s = float(settings["decide_every_s"])
	_cut_after_s = float(settings["cut_after_winner_s"])
	var OnlineServerScript: GDScript = load(ONLINE_SERVER_SCRIPT)
	var entries: Array = []
	var brain_gates: Dictionary = spec["brain_gates"]
	for gate in (spec["lineup"] as Array).size():
		var pururin := PururinRosterConfig.pururin_by_id(str(spec["lineup"][gate]))
		var brain_id := str(brain_gates.get(str(gate), ""))
		var peer := PEER_BASE + gate + 1 if not brain_id.is_empty() else 0
		var entry: Dictionary = OnlineServerScript._entry(gate, pururin, peer, TRAINEE_NAME if peer != 0 else "")
		# 人の席（画面ありで、人がいっしょに走るとき）：この画面の「自分」。名前は、トレーナーの名前。
		if gate == _human_gate:
			entry["player"] = true
			entry["trainer_name"] = RaceSession.trainer_name_for(str(pururin["id"]), true)
		entries.append(entry)
		if peer != 0:
			_seats[peer] = {"brain_id": brain_id, "gate": gate, "next_decide_s": 0.0, "command": {}, "dash_at": [], "boost_at": [], "brake_s": 0.0,
				"memory": {}, "trace": []}
	entries = OnlineServerScript._with_runner_ids(entries)
	# ゲームのCPUは、ラインを選ぶところでくじを使う。同じ番号なら、同じ走りになるように、くじをそろえる。
	seed(int(spec["seed"]))
	RaceSession.select_distance(float(spec["distance_m"]))
	# 人と走るときは、景色もふつうに出す。
	RaceSession.set_course_only(_human_gate < 0)
	RaceSession.set_online_entries(entries)
	_race = (load(LOCAL_RACE_SCENE) as PackedScene).instantiate()
	# オンラインのサーバーと同じ扱いにする（レースの記録ファイルを書かない・音を鳴らさない）。
	# 頭の席があるレースは、もともとこの扱いになる。ゲームのCPUだけのレースも、同じ条件でそろえる。
	_race.set("_online_host", true)
	add_child(_race)
	RaceSession.set_online_entries([])
	if _human_gate >= 0:
		_show_for_human()
	var track: Path3D = _race.get("_track")
	_inside = LabSituation.inside_sign(track.curve)


## レースが作れたか（ゲームの部品が読めなかったときは false）。
func is_ok() -> bool:
	return _race != null and _race.has_method("get_runners_for_simulation")


## 人と走るとき：サーバーの扱いで止まった、画面・音・人の操作を、ふつうのオフラインのレースと同じに戻す。
## （人がいるレースは、ふつうのオフラインと同じく、レースの記録ファイルを書く。）
func _show_for_human() -> void:
	_race.set("_online_host", false)
	_race.set_process_unhandled_input(true)
	for runner: Node3D in _race.call("get_runners_for_simulation"):
		runner.set("presentation_enabled", true)
		var body := runner.get_node_or_null("Body")
		if body != null:
			body.process_mode = Node.PROCESS_MODE_INHERIT
	(_race.get("_camera") as Node).process_mode = Node.PROCESS_MODE_INHERIT
	_race.get_node("UI").process_mode = Node.PROCESS_MODE_INHERIT


func race() -> Node:
	return _race


func _process(delta: float) -> void:
	if not is_ok() or _done:
		return
	var runners: Array = _race.call("get_runners_for_simulation")
	if bool(_race.call("is_race_started")):
		_elapsed += delta
		for runner: Node3D in runners:
			_count(runner, delta)
	var track: Path3D = _race.get("_track")
	for peer: int in _seats:
		_drive(peer, _seats[peer], runners, track, delta)
	if _first_finish_s < 0.0 and runners.any(func(r): return bool(r.call("is_finished"))):
		_first_finish_s = _elapsed
	# ゴールできない頭（ブレーキを押しっぱなしなど）を待たない。
	_cut = _human_gate < 0 and _first_finish_s >= 0.0 and _elapsed - _first_finish_s > _cut_after_s
	if bool(_race.call("is_race_over")) or _cut or _elapsed > TIME_LIMIT_S:
		_done = true
		race_done.emit(_result(runners))


func _count(runner: Node3D, delta: float) -> void:
	var gate := int(runner.get("gate_index"))
	if not _stats.has(gate):
		_stats[gate] = {"over_s": 0.0, "notch_s": 0.0, "run_s": 0.0}
	var st: Dictionary = _stats[gate]
	if st.has("finish_stamina"):
		return
	if bool(runner.call("is_finished")):
		st["finish_stamina"] = float(runner.call("get_stamina_ratio"))
		st["finish_heart"] = float(runner.call("get_heart_rate_bpm"))
		return
	if float(runner.call("get_overheat_ratio")) > 0.0:
		st["over_s"] = float(st["over_s"]) + delta
	st["notch_s"] = float(st["notch_s"]) + float(runner.call("get_telemetry_snapshot")["drive_level"]) * delta
	st["run_s"] = float(st["run_s"]) + delta


func _drive(peer: int, seat: Dictionary, runners: Array, track: Path3D, delta: float) -> void:
	var runner: Node3D = _race.call("remote_runner", peer)
	if runner == null or not bool(_race.call("is_race_started")):
		return
	if bool(runner.call("is_finished")):
		_race.call("set_remote_input", peer, 0.0, 0.0, false)
		return
	var command: Dictionary = seat["command"]
	seat["next_decide_s"] = float(seat["next_decide_s"]) - delta
	var notch_press := 0.0
	if float(seat["next_decide_s"]) <= 0.0:
		seat["next_decide_s"] = _decide_every_s
		var situation := LabSituation.read(runner, runners, track.curve, runner.get("_race_route"), _inside, _elapsed)
		command = KnobBrain.decide(_brains[str(seat["brain_id"])], situation, seat["memory"])
		seat["command"] = command
		# 確かめ用の記録（spec の trace が true のときだけ。結果が大きくなるため）。
		if _trace:
			(seat["trace"] as Array).append({
				"t": snappedf(_elapsed, 0.1), "m": snappedf(float(situation["progress_m"]), 1.0), "phase": command["phase"],
				"notch": int(situation["notch"]), "target": int(command["target_notch"]), "heart": roundi(float(situation["heart_bpm"])),
				"stamina": snappedf(float(situation["stamina"]), 0.01), "line": snappedf(float(situation["line_m"]), 0.1),
				"ahead_gap": snappedf(minf(float(situation["ahead_gap_m"]), 999.0), 0.1), "target_line": snappedf(float(command["target_line_m"]), 0.1),
			})
		# ノッチは、決めた回ごとに1段だけ動かす（押してすぐ離す）。
		notch_press = float(command["notch"])
		var progress := float(runner.call("get_race_progress"))
		# ダッシュは、効いているあいだに押し直さない（残り時間が延びるだけで、押した数が増えるため）。
		if bool(command["dash"]) and not bool(runner.call("is_dash_active")) and bool(_race.call("trigger_remote_action", peer, "dash")):
			(seat["dash_at"] as Array).append(snappedf(progress, 1.0))
			seat["memory"]["last_dash_s"] = _elapsed
		if bool(command["boost"]) and bool(_race.call("trigger_remote_action", peer, "boost")):
			(seat["boost_at"] as Array).append(snappedf(progress, 1.0))
	if command.is_empty():
		return
	# ラインは、毎コマ、行きたいラインへ向けて押し、着いたら離す（押しっぱなしで行き過ぎないように）。
	var line_m := -_inside * float(runner.call("get_offset"))
	var to_go := float(command["target_line_m"]) - line_m
	var steer := 0.0
	if absf(to_go) > LINE_TOLERANCE_M:
		# ラインのマイナス（内）は、offset では _inside の向き。
		steer = -_inside * signf(to_go)
	_race.call("set_remote_input", peer, steer, notch_press, bool(command["brake"]))
	if bool(command["brake"]):
		seat["brake_s"] = float(seat["brake_s"]) + delta


## 1レースの結果：距離、くじの番号、出た全員の {頭の名前（ゲームのCPUは空）, ぷるりん, 着順, タイム, 残った体力, …}。
func _result(runners: Array) -> Dictionary:
	# 着順：ゴールした走者はゴールの順。打ち切りでゴールしていない走者は、その後ろに、進んだ距離の順。
	var ordered: Array = runners.duplicate()
	ordered.sort_custom(func(a, b):
		var fa := int(a.call("get_finish_order"))
		var fb := int(b.call("get_finish_order"))
		if fa > 0 and fb > 0:
			return fa < fb
		if (fa > 0) != (fb > 0):
			return fa > 0
		return float(a.call("get_race_progress")) > float(b.call("get_race_progress")))
	var out_rows: Array = []
	for index in ordered.size():
		var runner: Node3D = ordered[index]
		var row := {"id": str(runner.call("get_snapshot")["id"]), "place": index + 1, "time": float(runner.call("get_finish_time")) if bool(runner.call("is_finished")) else -1.0}
		var gate := int(runner.get("gate_index"))
		var st: Dictionary = _stats.get(gate, {"over_s": 0.0, "notch_s": 0.0, "run_s": 0.0})
		var item := {
			"gate": gate, "pururin": str(row["id"]), "place": int(row["place"]), "time": float(row["time"]), "brain": "",
			"human": gate == _human_gate,
			# ゴールしていなければ、今の値。
			"stamina_left": float(st.get("finish_stamina", runner.call("get_stamina_ratio"))),
			"heart_at_finish": float(st.get("finish_heart", runner.call("get_heart_rate_bpm"))),
			"over_heart_s": float(st["over_s"]),
			"avg_notch": float(st["notch_s"]) / maxf(float(st["run_s"]), 0.001),
			"dash_at": [], "boost_at": [], "dash_uses": 0, "boost_uses": 0, "brake_s": 0.0,
		}
		var peer := PEER_BASE + gate + 1
		if _seats.has(peer):
			var seat: Dictionary = _seats[peer]
			item["brain"] = str(seat["brain_id"])
			item["dash_at"] = seat["dash_at"]
			item["boost_at"] = seat["boost_at"]
			item["dash_uses"] = (seat["dash_at"] as Array).size()
			item["boost_uses"] = (seat["boost_at"] as Array).size()
			item["brake_s"] = float(seat["brake_s"])
			if _trace:
				item["trace"] = seat["trace"]
		out_rows.append(item)
	return {
		"seed": int(_spec["seed"]), "distance_m": float(_spec["distance_m"]), "lineup": _spec["lineup"],
		"focus_gate": int(_spec["focus_gate"]), "brain_gates": _spec["brain_gates"], "timed_out": _elapsed > TIME_LIMIT_S,
		"cut": _cut, "race_s": _elapsed, "rows": out_rows,
	}
