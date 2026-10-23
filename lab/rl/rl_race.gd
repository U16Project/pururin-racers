extends Node
## 強化学習：レースを1本走らせる。育てるCPUの席は「通信ごしの人」と同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で動かす。
## spec.seats に書いた枠が、育てるCPUの席（ふつうは8席全部）。書いていない枠は、今のゲームのCPU。
## レースの作り方は lab/lab_race.gd と同じ（オンラインのサーバーと同じ作り方）。
## 決める間ごとに、全部の席の「見たもの・選べる操作・点」をまとめて Python に送り、返ってきた操作を席に入れる。
## ゴールした席は、レースが終わるまで、操作を「何もしない」だけにして待つ（点は0）。レースが終わったら、全部の席の結果を送る。

signal race_done

const LOCAL_RACE_SCENE := "res://scenes/local_race.tscn"
const ONLINE_SERVER_SCRIPT := "res://scripts/online/online_server.gd"
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const LabSituation := preload("../lab_situation.gd")
const RlObserve := preload("rl_observe.gd")

const TRAINEE_NAME := "（訓練中CPU）"
## 席の、通信の番号（1枠目が 1001）。
const PEER_BASE := 1000
## ゴールしたあとの選べる操作：どれも「何もしない」だけ。
const IDLE_MASK := [0, 1, 0, 0, 1, 0, 1, 0, 1, 0, 1, 0]

var _link
var _race: Node
var _spec: Dictionary
var _settings: Dictionary
var _inside := -1.0
var _elapsed := 0.0
var _next_decide_s := 0.0
var _done := false
var _first_finish_s := -1.0
## 枠 → 席の記録（今の操作、進んだ距離、ダッシュ・ブーストの回数、性格の数え など）。
var _seats := {}


func start(link, spec: Dictionary, settings: Dictionary) -> void:
	_link = link
	_spec = spec
	_settings = settings
	# JSON から来た番号は小数なので、整数にそろえる。
	var seat_gates: Array = (spec.get("seats", []) as Array).map(func(g): return int(g))
	var OnlineServerScript: GDScript = load(ONLINE_SERVER_SCRIPT)
	var entries: Array = []
	for gate in (spec["lineup"] as Array).size():
		var pururin := PururinRosterConfig.pururin_by_id(str(spec["lineup"][gate]))
		var peer := PEER_BASE + gate + 1 if seat_gates.has(gate) else 0
		entries.append(OnlineServerScript._entry(gate, pururin, peer, TRAINEE_NAME if peer != 0 else ""))
		if peer != 0:
			_seats[gate] = {
				"peer": peer, "steer": 0.0, "brake": false, "last_progress": 0.0, "mid_place": 0, "dash": 0, "boost": 0,
				"steps": 0, "paid": false, "frame": RlObserve.trainer_frame(str(pururin["id"])),
				"fit": {"place_hit": 0, "place_n": 0, "draft_hit": 0, "draft_n": 0},
			}
	entries = OnlineServerScript._with_runner_ids(entries)
	# ゲームのCPUは、ラインを選ぶところでくじを使う。同じ番号なら同じ走りになるように、くじをそろえる。
	seed(int(spec["seed"]))
	RaceSession.select_distance(float(spec["distance_m"]))
	RaceSession.set_course_only(true)
	RaceSession.set_online_entries(entries)
	_race = (load(LOCAL_RACE_SCENE) as PackedScene).instantiate()
	# オンラインのサーバーと同じ扱いにする（レースの記録ファイルを書かない・音を鳴らさない）。
	_race.set("_online_host", true)
	add_child(_race)
	RaceSession.set_online_entries([])
	var track: Path3D = _race.get("_track")
	_inside = LabSituation.inside_sign(track.curve)


func is_ok() -> bool:
	return _race != null and _race.has_method("get_runners_for_simulation")


func _process(delta: float) -> void:
	if not is_ok() or _done or not bool(_race.call("is_race_started")):
		return
	_elapsed += delta
	var runners: Array = _race.call("get_runners_for_simulation")
	for runner: Node3D in runners:
		var gate := int(runner.get("gate_index"))
		if _seats.has(gate) and int(_seats[gate]["mid_place"]) == 0 and float(runner.call("get_race_progress")) >= float(_spec["distance_m"]) * 0.5:
			_seats[gate]["mid_place"] = _place_of(runner, runners)
	if _first_finish_s < 0.0 and runners.any(func(r): return bool(r.call("is_finished"))):
		_first_finish_s = _elapsed
	var cut := _first_finish_s >= 0.0 and _elapsed - _first_finish_s > float(_settings["cut_after_winner_s"])
	if bool(_race.call("is_race_over")) or cut or _elapsed > float(_settings["time_limit_s"]):
		_finish(runners, cut)
		return
	if _seats.is_empty():
		return
	var notch_press := false
	_next_decide_s -= delta
	if _next_decide_s <= 0.0:
		_next_decide_s = float(_settings["decide_every_s"])
		var reports: Array = []
		for runner: Node3D in runners:
			var gate := int(runner.get("gate_index"))
			if _seats.has(gate):
				reports.append(_report(runner, runners, _seats[gate]))
		_link.send({"seats": reports, "over": false})
		var reply: Dictionary = _link.receive()
		if reply.is_empty() or str(reply.get("cmd", "")) != "step":
			# Python が止まった・別の指示が来た：このレースは捨てる。別の指示は、次に読む。
			_link.pending = reply
			_done = true
			race_done.emit()
			return
		notch_press = true
		var actions: Dictionary = reply["actions"]
		for gate: int in _seats:
			if actions.has(str(gate)):
				_apply(gate, _seats[gate], actions[str(gate)])
	for gate: int in _seats:
		var seat: Dictionary = _seats[gate]
		_race.call("set_remote_input", int(seat["peer"]), float(seat["steer"]), float(seat.get("notch", 0.0)) if notch_press else 0.0, bool(seat["brake"]))


## 1席ぶんの、見たもの・選べる操作・この間にもらった点。
func _report(runner: Node3D, runners: Array, seat: Dictionary) -> Dictionary:
	var me: Dictionary = runner.call("get_telemetry_snapshot")
	var finished := bool(runner.call("is_finished"))
	var reward := 0.0
	var mask: Array = IDLE_MASK
	if not finished:
		_count_fit(runner, runners, seat)
		reward = _progress_reward(runner, seat)
		mask = Array(RlObserve.mask_from(me, float(runner.call("get_drive_level")), _inside))
	elif not bool(seat["paid"]):
		# ゴールした直後の1回だけ、着順の点を渡す。
		seat["paid"] = true
		reward = _progress_reward(runner, seat) + _goal_reward(runner, runners, seat)
	else:
		seat["steer"] = 0.0
		seat["brake"] = false
	return {
		"gate": int(runner.get("gate_index")), "reward": reward, "mask": mask,
		"obs": Array(RlObserve.from_records(me, _snapshots(runners, runner), _ctx(runner))),
	}


func _apply(gate: int, seat: Dictionary, action: Array) -> void:
	seat["steps"] = int(seat["steps"]) + 1
	seat["notch"] = float(int(action[0]) - 1)
	# ラインの「内」は、offset では _inside の向き。
	seat["steer"] = float(int(action[1]) - 1) * -_inside
	seat["brake"] = int(action[2]) == 1
	if int(action[3]) == 1 and bool(_race.call("trigger_remote_action", int(seat["peer"]), "dash")):
		seat["dash"] = int(seat["dash"]) + 1
	if int(action[4]) == 1 and bool(_race.call("trigger_remote_action", int(seat["peer"]), "boost")):
		seat["boost"] = int(seat["boost"]) + 1


func _snapshots(runners: Array, me: Node3D) -> Array:
	var out: Array = []
	for runner: Node3D in runners:
		if runner != me:
			out.append(runner.call("get_telemetry_snapshot"))
	return out


func _ctx(runner: Node3D) -> Dictionary:
	var track: Path3D = _race.get("_track")
	return {
		"distance_m": float(_spec["distance_m"]), "elapsed_s": _elapsed, "curve": track.curve, "route": runner.get("_race_route"),
		"inside": _inside, "field": int(_settings["field"]), "scales": _settings["observe"],
	}


## 前に何体いるか＋1。ゴールした走者は、ゴールの順で前。
func _place_of(runner: Node3D, runners: Array) -> int:
	if bool(runner.call("is_finished")):
		return int(runner.call("get_finish_order"))
	var progress := float(runner.call("get_race_progress"))
	var better := 0
	for other: Node3D in runners:
		if other != runner and (bool(other.call("is_finished")) or float(other.call("get_race_progress")) > progress):
			better += 1
	return better + 1


## 性格に合った走りを数える。中ほど（style.mid_from〜mid_to の割合）は「いたい順位」と風よけ、
## 終盤（mid_to より後）は、終盤にいたい順位（late_place）があるトレーナーだけ、その順位を数える。
func _count_fit(runner: Node3D, runners: Array, seat: Dictionary) -> void:
	var frame: Dictionary = seat["frame"]
	if frame.is_empty():
		return
	var fit: Dictionary = seat["fit"]
	var style: Dictionary = _settings["reward"]["style"]
	var ratio := float(runner.call("get_race_progress")) / float(_spec["distance_m"])
	var place := _place_of(runner, runners)
	var wanted: Array = []
	if ratio >= float(style["mid_from"]) and ratio < float(style["mid_to"]):
		wanted = frame.get("place", [])
		var follows := float((frame.get("follow_m", [0, 0]) as Array)[1]) > 0.0
		var drafting := float(runner.call("get_telemetry_snapshot")["draft"]["received_draft_p"]) >= float(style["draft_at_least"])
		fit["draft_n"] = int(fit["draft_n"]) + 1
		if drafting == follows:
			fit["draft_hit"] = int(fit["draft_hit"]) + 1
	elif ratio >= float(style["mid_to"]) and frame.has("late_place"):
		wanted = frame["late_place"]
	if wanted.size() == 2:
		fit["place_n"] = int(fit["place_n"]) + 1
		if place >= int(wanted[0]) and place <= int(wanted[1]):
			fit["place_hit"] = int(fit["place_hit"]) + 1


## 性格に合った走りの点（着順・タイム差の点より、はっきり小さい）。
func _style_reward(seat: Dictionary) -> float:
	var fit: Dictionary = seat["fit"]
	var style: Dictionary = _settings["reward"]["style"]
	var out := 0.0
	if int(fit["place_n"]) > 0:
		out += float(style["place"]) * float(fit["place_hit"]) / float(fit["place_n"])
	if int(fit["draft_n"]) > 0:
		out += float(style["draft"]) * float(fit["draft_hit"]) / float(fit["draft_n"])
	return out


## ゴール（または打ち切り）の点：着順の点＋1位とのタイム差の点＋性格に合った走りの点。
func _goal_reward(runner: Node3D, runners: Array, seat: Dictionary) -> float:
	var place := _place_of(runner, runners)
	var weights: Dictionary = _settings["reward"]
	var table: Array = weights["place"]
	var reward := float(table[mini(place, table.size()) - 1])
	# 1位でなかったときは、1位とのタイム差が小さいほど少し足す（2位の点＋この点が、1位の点を越えないようにしておく）。
	if place > 1 and bool(runner.call("is_finished")):
		var gap_s := float(runner.call("get_finish_time")) - _winner_time(runners)
		reward += float(weights["gap_bonus"]) * clampf(1.0 - gap_s / float(weights["gap_scale_s"]), 0.0, 1.0)
	return reward + _style_reward(seat)


## ゴールした中で、いちばん早いタイム（だれもゴールしていなければ -1）。
func _winner_time(runners: Array) -> float:
	var best := -1.0
	for runner: Node3D in runners:
		if bool(runner.call("is_finished")):
			var t := float(runner.call("get_finish_time"))
			best = t if best < 0.0 else minf(best, t)
	return best


func _progress_reward(runner: Node3D, seat: Dictionary) -> float:
	var progress := minf(float(runner.call("get_race_progress")), float(_spec["distance_m"]))
	var gained := progress - float(seat["last_progress"])
	seat["last_progress"] = progress
	return gained / float(_spec["distance_m"]) * float(_settings["reward"]["progress_total"])


## レースが終わった：全部の席（席がなければ、全員）の結果を送る。ゴールしていない席には、ここで着順の点を渡す。
func _finish(runners: Array, cut: bool) -> void:
	_done = true
	var reports: Array = []
	var results: Array = []
	var winner := _winner_time(runners)
	for runner: Node3D in runners:
		var gate := int(runner.get("gate_index"))
		var finished := bool(runner.call("is_finished"))
		var result := {
			"gate": gate, "pururin": str(spec_id(gate)), "seat": _seats.has(gate), "place": _place_of(runner, runners),
			"time": float(runner.call("get_finish_time")) if finished else -1.0, "winner_time": winner,
			"stamina_left": float(runner.call("get_stamina_ratio")),
		}
		if _seats.has(gate):
			var seat: Dictionary = _seats[gate]
			var reward := 0.0
			if not bool(seat["paid"]):
				seat["paid"] = true
				reward = _progress_reward(runner, seat) + _goal_reward(runner, runners, seat)
			_race.call("set_remote_input", int(seat["peer"]), 0.0, 0.0, false)
			var fit: Dictionary = seat["fit"]
			result.merge({
				"mid_place": int(seat["mid_place"]) if int(seat["mid_place"]) > 0 else int(result["place"]),
				"dash_uses": seat["dash"], "boost_uses": seat["boost"], "steps": seat["steps"],
				"style_reward": _style_reward(seat),
				"place_fit": float(fit["place_hit"]) / maxf(float(fit["place_n"]), 1.0),
				"draft_fit": float(fit["draft_hit"]) / maxf(float(fit["draft_n"]), 1.0),
			})
			var report := _report(runner, runners, seat)
			report["reward"] = reward
			reports.append(report)
		results.append(result)
	_link.send({
		"seats": reports, "over": true,
		"race": {"seed": int(_spec["seed"]), "distance_m": float(_spec["distance_m"]), "race_s": _elapsed, "cut": cut, "results": results},
	})
	race_done.emit()


func spec_id(gate: int) -> String:
	return str(_spec["lineup"][gate])
