extends RefCounted
## 育てたCPU（強化学習の頭）で、CPUの席を動かす。オフラインのレースでも、オンラインのサーバーでも、同じこれを使う。
## 席は、オンラインで「通信ごしの人」が使うのと同じ入口（ライン・ノッチ・ブレーキ・ダッシュ・ブースト）で動かす。
## decide_every_s（cpu_brain.json）ごとに、見たもの（brain_observe.gd）から操作を決め、
## cpu_reaction_delay_s（local_race.json。人の反応に合わせる）たってから席に届ける。
## 席ごとに決める時をずらして、同じコマに計算が集まらないようにする。

const BrainNet := preload("res://scripts/cpu_brain/brain_net.gd")
const BrainObserve := preload("res://scripts/cpu_brain/brain_observe.gd")
const BrainSituation := preload("res://scripts/cpu_brain/brain_situation.gd")
const CpuBrainConfig := preload("res://scripts/config/cpu_brain_config.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")

static var _net: RefCounted

var _track: Path3D
var _race_distance_m := 0.0
var _inside := 0.0
## 走者 → {trainer_id, next_decide_s, queue, steer, brake}
var _seats := {}


func _init(track: Path3D, race_distance_m: float) -> void:
	_track = track
	_race_distance_m = race_distance_m
	_inside = BrainSituation.inside_sign(track.curve) if track != null and track.curve != null else 1.0
	if _net == null:
		_net = BrainNet.load_file(str(CpuBrainConfig.values().get("brain", "")))


## 走者を、育てたCPUで動かす（trainer_id＝性格の数字を読むトレーナー）。走者は、通信ごしの人と同じ扱いにしておくこと。
func add_seat(runner: Node3D, trainer_id: String) -> void:
	var decide := float(CpuBrainConfig.values()["decide_every_s"])
	_seats[runner] = {
		"trainer_id": trainer_id, "next_decide_s": decide * float(_seats.size() % 8) / 8.0,
		"queue": [], "steer": 0.0, "brake": false,
	}


func has_seat(runner: Node3D) -> bool:
	return _seats.has(runner)


## 1コマぶん進める。runners＝全員。elapsed_s＝レースの時計。started＝スタートしたか（止まっている間は呼ばない）。
func update(delta: float, runners: Array, elapsed_s: float, started: bool) -> void:
	if _net == null or _seats.is_empty():
		return
	var snapshots := {}
	var decide := float(CpuBrainConfig.values()["decide_every_s"])
	var delay := LocalRaceMath.Config.number("cpu_reaction_delay_s")
	for runner: Node3D in _seats:
		if not is_instance_valid(runner):
			continue
		var seat: Dictionary = _seats[runner]
		if not started or bool(runner.call("is_finished")):
			runner.call("set_remote_input", 0.0, 0.0)
			runner.call("set_braking", false)
			continue
		seat["next_decide_s"] = float(seat["next_decide_s"]) - delta
		if float(seat["next_decide_s"]) <= 0.0:
			seat["next_decide_s"] = decide
			if snapshots.is_empty():
				for r: Node3D in runners:
					snapshots[r] = r.call("get_telemetry_snapshot")
			var others: Array = []
			for r: Node3D in runners:
				if r != runner:
					others.append(snapshots[r])
			var me: Dictionary = snapshots[runner]
			var ctx := {
				"distance_m": _race_distance_m, "elapsed_s": elapsed_s, "curve": _track.curve, "route": runner.get("_race_route"),
				"inside": _inside, "field": int(CpuBrainConfig.values()["field"]), "trainer_id": str(seat["trainer_id"]),
			}
			var obs := BrainObserve.from_records(me, others, ctx)
			var mask := BrainObserve.mask_from(me, float(runner.call("get_drive_level")), _inside)
			(seat["queue"] as Array).append({"at": elapsed_s + delay, "action": _net.act(obs, mask)})
		# 決めた操作は、反応の遅れのあとに届く。ノッチは届いたコマにだけ1段押す。ラインとブレーキは、次が届くまで押し続ける。
		var notch_press := 0.0
		var queue: Array = seat["queue"]
		while not queue.is_empty() and float(queue[0]["at"]) <= elapsed_s + 0.0001:
			var action: Array = queue.pop_front()["action"]
			notch_press = float(int(action[0]) - 1)
			# ラインの「内」は、offset では _inside の向き。
			seat["steer"] = float(int(action[1]) - 1) * -_inside
			seat["brake"] = int(action[2]) == 1
			if int(action[3]) == 1:
				runner.call("trigger_dash")
			if int(action[4]) == 1:
				runner.call("trigger_boost")
		runner.call("set_remote_input", float(seat["steer"]), notch_press)
		runner.call("set_braking", bool(seat["brake"]))
