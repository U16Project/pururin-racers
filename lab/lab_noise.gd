extends SceneTree
## CPU育成ラボ：確かめ方の確かめ。8席とも同じ頭（つまみが全部まん中の頭）で走らせ、点が「たまたま」でどれくらい動くかと、
## ぷるりんの能力の差がどれくらい点に出るかを測る。席の頭には A〜H の名前だけ付ける（中身は同じ）。
## ぷるりんは、席ごとにレースのたびに入れ替え、どの席もどのぷるりんにも同じ回数ずつ乗るようにする。
## 起動（client/ で）：godot --headless --path . -s ../lab/lab_noise.gd -- races=80 out=noise1 [seed=1]

const KnobBrain := preload("knob_brain.gd")
const LabScore := preload("lab_score.gd")
const LabBatch := preload("lab_batch.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const LABELS := ["A", "B", "C", "D", "E", "F", "G", "H"]
## 区切って見るときの、1区切りのレースの数（育成で1体が走る数と同じ）。
const CHUNK := 10

var _batch: LabBatch


func _initialize() -> void:
	var args := LabBatch.user_args()
	var settings := LabScore.load_settings()
	_batch = LabBatch.new(settings, LabScore.lab_dir().path_join("runs/%s" % str(args["out"])))
	var brains := {}
	var knobs := KnobBrain.knob_list()
	var middle: Array = []
	for i in KnobBrain.slots(knobs).size():
		middle.append(0.5)
	for label: String in LABELS:
		# 頭の pururin は名前だけ（この実験では、どのぷるりんにも乗る）。
		var brain := KnobBrain.from_unit(middle, knobs, "頭" + label, "player-1", 0)
		brains[str(brain["id"])] = brain
	var roster: Array = PururinRosterConfig.values()["roster"]
	var distances: Array = settings["distances_m"]
	var base_seed := int(args.get("seed", "1")) * 1000
	var jobs: Array = []
	for i in int(args["races"]):
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + i
		var seats: Array = []
		for k in LABELS.size():
			# 10体のぷるりんを、席ごとにずらして回す（10レースで、どの席も10体に1回ずつ）。
			seats.append({"brain": "頭" + LABELS[k], "pururin": str(roster[(k + i) % roster.size()]["id"])})
		LabBatch._shuffle(seats, rng)
		var lineup: Array = []
		var brain_gates := {}
		for gate in seats.size():
			lineup.append(seats[gate]["pururin"])
			brain_gates[str(gate)] = seats[gate]["brain"]
		jobs.append({
			"seed": base_seed + i, "distance_m": float(distances[i % distances.size()]),
			"lineup": lineup, "focus_gate": -1, "brain_gates": brain_gates,
		})
	_batch.launch(brains, jobs)
	print("レース %d 本を走らせます" % jobs.size())


func _process(_delta: float) -> bool:
	if _batch.is_running():
		return false
	var results := _batch.collect()
	var weights: Dictionary = _batch.settings["score"]
	var report := {"races": results.size(), "seconds": _batch.seconds(), "score_weights": weights}
	# 席（頭A〜H）ごとの、全部のレースでの点と、10レースずつに区切ったときの点。
	var by_label := LabScore.rows_by_name(results, func(_row): return "")
	var labels: Array = []
	var chunk_points: Array = []
	for label: String in LABELS:
		var entries: Array = by_label["頭" + label]
		var chunks: Array = []
		for c in range(0, entries.size(), CHUNK):
			var p := LabScore.points(LabScore.metrics(entries.slice(c, c + CHUNK)), weights)
			chunks.append(snappedf(p, 0.1))
			chunk_points.append(p)
		var m := LabScore.metrics(entries)
		labels.append({"name": "頭" + label, "points": LabScore.points(m, weights), "win_rate": m["win_rate"], "avg_place": m["avg_place"], "chunks": chunks})
	report["labels"] = labels
	report["chunk_points_min"] = chunk_points.min()
	report["chunk_points_max"] = chunk_points.max()
	# ぷるりんごとの点。
	var by_pururin := {}
	for result: Dictionary in results:
		for row: Dictionary in result["rows"]:
			var id := str(row["pururin"]).split("#")[0]
			if not by_pururin.has(id):
				by_pururin[id] = []
			by_pururin[id].append({"result": result, "row": row})
	var pururins: Array = []
	for id: String in by_pururin:
		var m := LabScore.metrics(by_pururin[id])
		var p := PururinRosterConfig.pururin_by_id(id)
		pururins.append({"id": id, "name": str(p["display_name"]), "style": str(p["running_style"]), "points": LabScore.points(m, weights), "win_rate": m["win_rate"], "avg_place": m["avg_place"], "races": m["races"]})
	pururins.sort_custom(func(a, b): return float(a["points"]) > float(b["points"]))
	report["pururins"] = pururins
	LabBatch.save_json(_batch.out_dir.path_join("results.json"), results)
	LabBatch.save_json(_batch.out_dir.path_join("report.json"), report)
	print("%d 本、%.0f 秒" % [results.size(), _batch.seconds()])
	print("席 | 全部の点 | 1位の割合 | 平均の着順 | 10レースずつの点")
	for row: Dictionary in labels:
		print("%s | %.1f | %.2f | %.2f | %s" % [row["name"], row["points"], row["win_rate"], row["avg_place"], str(row["chunks"])])
	print("10レースずつの点の幅：%.1f 〜 %.1f" % [report["chunk_points_min"], report["chunk_points_max"]])
	print("ぷるりん | 型 | 点 | 1位の割合 | 平均の着順 | 本数")
	for row: Dictionary in pururins:
		print("%s | %s | %.1f | %.2f | %.2f | %d" % [row["name"], row["style"], row["points"], row["win_rate"], row["avg_place"], row["races"]])
	return true
