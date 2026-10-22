extends SceneTree
## CPU育成ラボ：つまみで走る頭を、ぷるりん1体ごとに育てる（育て方は CMA-ES、cma.gd）。
## 1代：
##   1. ぷるりんごとに、候補を candidates 個作る。
##   2. レースの一覧（races 本。距離は順番、出るぷるりんは休みを順番に回す、枠順はくじ）を決める。
##   3. 候補の番号ごとに、その一覧を走る（k 番目の候補どうしで races 本）。どの候補も、同じ一覧を走る。
##   4. 点（lab_score.gd）で候補を並べ、ぷるりんごとに CMA-ES を次へ進める。
##   5. 確かめ：次の代の「中心」の頭と、殿堂（前の代までの中心）を混ぜて check_races 本走り、どちらが前か見る。
## 起動（client/ で）：godot --headless --path . -s ../lab/lab_evolve.gd -- generations=3 out=<名前> [seed=1]
## 結果：lab/runs/<名前>/gen_000/（中心の頭、まとめ、育て方の状態）… と、progress.json（全部の代のまとめ）。

const KnobBrain := preload("knob_brain.gd")
const Cma := preload("cma.gd")
const LabScore := preload("lab_score.gd")
const LabBatch := preload("lab_batch.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const CENTER := "中心"

var _batch: LabBatch
var _evolve: Dictionary
var _knobs: Array
var _pururins: Array = []
var _generations := 0
var _generation := 0
var _seed := 1
var _rng := RandomNumberGenerator.new()
## ぷるりん → 育て方（CMA-ES）。
var _cma := {}
## ぷるりん → この代の候補（0〜1の数字の並び）。
var _candidates := {}
## ぷるりん → 殿堂の頭（古い順）。
var _hall := {}
var _brains := {}
var _progress: Array = []
## 今どちらを走らせているか："train"（候補）か "check"（確かめ）。
var _stage := ""
var _train_results: Array = []


func _initialize() -> void:
	var args := LabBatch.user_args()
	var settings := LabScore.load_settings()
	_evolve = settings["evolve"]
	_knobs = KnobBrain.knob_list()
	_generations = int(args["generations"])
	_seed = int(args.get("seed", "1"))
	_rng.seed = _seed
	_batch = LabBatch.new(settings, LabScore.lab_dir().path_join("runs/%s" % str(args["out"])))
	var start: Array = []
	for i in KnobBrain.slots(_knobs).size():
		# 最初は、どのつまみも範囲のまん中。
		start.append(0.5)
	for p: Dictionary in PururinRosterConfig.values()["roster"]:
		var id := str(p["id"])
		_pururins.append(id)
		_cma[id] = Cma.new(start, float(_evolve["start_sigma"]), int(_evolve["candidates"]))
		_hall[id] = []
	_start_training()


func _brain_name(pururin_id: String, generation: int, label: String) -> String:
	return "%s-g%03d-%s" % [pururin_id, generation, label]


func _start_training() -> void:
	_brains = {}
	for id: String in _pururins:
		_candidates[id] = (_cma[id] as Cma).ask(_rng)
		for k in (_candidates[id] as Array).size():
			var brain := KnobBrain.from_unit(_candidates[id][k], _knobs, _brain_name(id, _generation, "c%02d" % k), id, _generation)
			_brains[str(brain["id"])] = brain
	var race_list := _batch.make_race_list(_pururins, int(_evolve["races"]), _seed * 1000000 + _generation * 1000)
	var jobs: Array = []
	for k in int(_evolve["candidates"]):
		jobs.append_array(LabBatch.jobs_for(race_list, func(id): return _brain_name(id, _generation, "c%02d" % k)))
	_stage = "train"
	_batch.launch(_brains, jobs)
	print("%d代目：ぷるりん %d 体 × 候補 %d 個、レースの一覧 %d 本 ＝ %d 本" % [_generation, _pururins.size(), int(_evolve["candidates"]), race_list.size(), jobs.size()])


## 確かめ：各席に、次の代の中心か、殿堂の頭（くじで半々）を乗せる。殿堂が空（0代目）なら、やらない。
func _start_check() -> bool:
	if (_hall[_pururins[0]] as Array).is_empty():
		return false
	_brains = {}
	for id: String in _pururins:
		var center := _center(id)
		_brains[str(center["id"])] = center
		for brain: Dictionary in _hall[id]:
			_brains[str(brain["id"])] = brain
	var race_list := _batch.make_race_list(_pururins, int(_evolve["check_races"]), _seed * 1000000 + _generation * 1000 + 500)
	var jobs := LabBatch.jobs_for(race_list, func(id):
		var hall: Array = _hall[id]
		if _rng.randf() < 0.5:
			return _brain_name(id, _generation + 1, CENTER)
		return str(hall[_rng.randi_range(0, hall.size() - 1)]["id"]))
	_stage = "check"
	_batch.launch(_brains, jobs)
	print("  確かめ：次の代の中心と、殿堂で %d 本" % jobs.size())
	return true


## 次の代の中心（育て方が、今いちばん良いと見ている頭）。
func _center(id: String) -> Dictionary:
	return KnobBrain.from_unit((_cma[id] as Cma).mean, _knobs, _brain_name(id, _generation + 1, CENTER), id, _generation + 1)


func _process(_delta: float) -> bool:
	if _batch.is_running():
		return false
	var results := _batch.collect()
	if _stage == "train":
		_train_results = results
		_tell(results)
		if _start_check():
			return false
		_finish_generation([])
	else:
		_finish_generation(results)
	_generation += 1
	if _generation >= _generations:
		print("おわり：%s" % _batch.out_dir)
		return true
	_start_training()
	return false


## 候補の点から、ぷるりんごとに育て方を進める。
func _tell(results: Array) -> void:
	var points := {}
	for row: Dictionary in _batch.score_table(results):
		points[str(row["name"])] = float(row["points"])
	for id: String in _pururins:
		var costs: Array = []
		for k in (_candidates[id] as Array).size():
			# 点が高いほど良い。範囲の外へ出た候補は、少し損をさせる。
			costs.append(-float(points[_brain_name(id, _generation, "c%02d" % k)]) + 100.0 * Cma.outside(_candidates[id][k]))
		(_cma[id] as Cma).tell(_candidates[id], costs)


func _finish_generation(check_results: Array) -> void:
	var dir := _batch.out_dir.path_join("gen_%03d" % _generation)
	var by_name := {}
	for row: Dictionary in _batch.score_table(_train_results):
		by_name[str(row["name"])] = row
	var per_pururin := {}
	for id: String in _pururins:
		var rows: Array = []
		for k in int(_evolve["candidates"]):
			rows.append(by_name[_brain_name(id, _generation, "c%02d" % k)])
		rows.sort_custom(func(a, b): return float(a["points"]) > float(b["points"]))
		var average := 0.0
		for row: Dictionary in rows:
			average += float(row["points"])
		average /= float(rows.size())
		var center := _center(id)
		LabBatch.save_json(dir.path_join("brains/%s.json" % str(center["id"])), center)
		# 候補も残す（点を付けて）。どんな値の候補が良かったかを、あとで見られるように。
		for k in int(_evolve["candidates"]):
			var name := _brain_name(id, _generation, "c%02d" % k)
			var candidate := KnobBrain.from_unit(_candidates[id][k], _knobs, name, id, _generation)
			candidate["score"] = {"points": by_name[name]["points"], "metrics": by_name[name]["metrics"]}
			LabBatch.save_json(dir.path_join("candidates/%s.json" % name), candidate)
		LabBatch.save_json(dir.path_join("cma/%s.json" % id), (_cma[id] as Cma).to_dict())
		per_pururin[id] = {
			"name": str(PururinRosterConfig.pururin_by_id(id)["display_name"]),
			"best": str(rows[0]["name"]), "best_points": float(rows[0]["points"]), "best_metrics": rows[0]["metrics"],
			"average_points": average, "sigma": (_cma[id] as Cma).sigma, "next_center": str(center["id"]),
		}
		(_hall[id] as Array).append(center)
		while (_hall[id] as Array).size() > int(_evolve["hall_of_fame"]):
			(_hall[id] as Array).pop_front()
	var check := {}
	if not check_results.is_empty():
		var check_table := _batch.score_table(check_results)
		check = {
			"center": _sum_rows(check_table.filter(func(r): return str(r["name"]).ends_with(CENTER) and str(r["name"]).contains("-g%03d-" % (_generation + 1)))),
			"hall": _sum_rows(check_table.filter(func(r): return not str(r["name"]).contains("-g%03d-" % (_generation + 1)))),
			"table": check_table,
		}
	var summary := {
		"generation": _generation, "candidates": int(_evolve["candidates"]), "races": int(_evolve["races"]),
		"train_races": _train_results.size(), "check_races": check_results.size(), "seconds": _batch.seconds(),
		"score_weights": _batch.settings["score"], "pururins": per_pururin, "check": check,
	}
	_progress.append(summary)
	LabBatch.save_json(dir.path_join("summary.json"), summary)
	LabBatch.save_json(dir.path_join("results.json"), _train_results)
	LabBatch.save_json(_batch.out_dir.path_join("progress.json"), _progress)
	print("%d代目のまとめ" % _generation)
	for id: String in _pururins:
		var s: Dictionary = per_pururin[id]
		print("  %s：候補のいちばん %.1f、候補の平均 %.1f、広がり %.3f" % [s["name"], s["best_points"], s["average_points"], s["sigma"]])
	if not check.is_empty():
		print("  確かめ：次の中心 平均の着順 %.2f（1位 %.2f）／殿堂 平均の着順 %.2f（1位 %.2f）" % [check["center"]["avg_place"], check["center"]["win_rate"], check["hall"]["avg_place"], check["hall"]["win_rate"]])


## いくつかの行の、平均の着順と1位の割合（レースの数で重みを付ける）。
static func _sum_rows(rows: Array) -> Dictionary:
	var races := 0.0
	var place := 0.0
	var wins := 0.0
	for row: Dictionary in rows:
		var m: Dictionary = row["metrics"]
		races += float(m["races"])
		place += float(m["avg_place"]) * float(m["races"])
		wins += float(m["win_rate"]) * float(m["races"])
	return {"races": races, "avg_place": place / maxf(races, 1.0), "win_rate": wins / maxf(races, 1.0)}
