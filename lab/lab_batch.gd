extends RefCounted
## CPU育成ラボ：レースのまとまり（バッチ）を作って、画面なしのゴドーを何本か同時に起こし、結果を集めて点を付ける。
## 試し走り（lab_trial.gd）も、代を重ねる育成（lab_evolve.gd）も、これを使う。

const LabScore := preload("lab_score.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const BASELINE := "今までのCPU"
## 1レースに出る数。
const FIELD := 8

var settings: Dictionary
var out_dir := ""
var _pids: Array = []
var _outs: Array = []
var _started_msec := 0
var _job_count := 0


func _init(lab_settings: Dictionary, dir: String) -> void:
	settings = lab_settings
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)


## 試し走り：頭ごとに、その頭のぷるりんの席に頭が乗り、ほかの7席は今までのCPU。
## 同じレース（くじ・距離・相手・枠）で、頭の代わりに今までのCPUが乗ったときの行も、1回ずつ作る（比べる目安）。
func make_trial_jobs(brains: Dictionary, races: int, base_seed: int) -> Array:
	var jobs: Array = []
	var pururins := {}
	for id: String in brains:
		pururins[str(brains[id]["pururin"])] = true
	for pururin_id: String in pururins:
		for i in races:
			var spec := _trial_spec(pururin_id, base_seed + i, i)
			jobs.append(_with_brain(spec, ""))
			for id: String in brains:
				if str(brains[id]["pururin"]) == pururin_id:
					jobs.append(_with_brain(spec, id))
	return jobs


## 試し走りの1レース：距離は順番に回す。ほかの7体と枠順は、くじ。
func _trial_spec(pururin_id: String, race_seed: int, index: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = race_seed
	var others: Array = (PururinRosterConfig.values()["roster"] as Array).filter(func(p): return str(p["id"]) != pururin_id)
	_shuffle(others, rng)
	var lineup: Array = [pururin_id]
	for p: Dictionary in others.slice(0, FIELD - 1):
		lineup.append(str(p["id"]))
	_shuffle(lineup, rng)
	var distances: Array = settings["distances_m"]
	return {
		"seed": race_seed, "distance_m": float(distances[index % distances.size()]),
		"lineup": lineup, "focus_gate": lineup.find(pururin_id),
	}


static func _with_brain(spec: Dictionary, brain_id: String) -> Dictionary:
	var job: Dictionary = spec.duplicate(true)
	job["brain_gates"] = {} if brain_id.is_empty() else {str(spec["focus_gate"]): brain_id}
	return job


## 育成のレースの一覧：count 本。距離は順番に回す。8席に出るぷるりんは、休む子を順番に回して、どの子も同じ回数ずつ出る
## （10体なら、1本で2体が休み、10本でどの子も2回休む）。枠順は、くじ。
func make_race_list(pururin_ids: Array, count: int, base_seed: int) -> Array:
	var list: Array = []
	var distances: Array = settings["distances_m"]
	var rest := pururin_ids.size() - FIELD
	var cursor := 0
	for r in count:
		var rng := RandomNumberGenerator.new()
		rng.seed = base_seed + r
		var resting := {}
		for j in rest:
			resting[pururin_ids[cursor % pururin_ids.size()]] = true
			cursor += 1
		var lineup: Array = pururin_ids.filter(func(id): return not resting.has(id))
		_shuffle(lineup, rng)
		list.append({"seed": base_seed + r, "distance_m": float(distances[r % distances.size()]), "lineup": lineup})
	return list


## レースの一覧から、仕事を作る。各席の頭は brain_for（ぷるりんの番号 → 頭の名前）で決める。
static func jobs_for(race_list: Array, brain_for: Callable) -> Array:
	var jobs: Array = []
	for race: Dictionary in race_list:
		var job: Dictionary = race.duplicate(true)
		var gates := {}
		for gate in (race["lineup"] as Array).size():
			gates[str(gate)] = str(brain_for.call(str(race["lineup"][gate])))
		job["brain_gates"] = gates
		job["focus_gate"] = -1
		jobs.append(job)
	return jobs


static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = list[i]
		list[i] = list[j]
		list[j] = t


## 仕事を、同時に走らせる数に分けて、画面なしのゴドーを、その数だけ起こす。
func launch(brains: Dictionary, jobs: Array) -> void:
	var workers := mini(int(settings["workers"]), jobs.size())
	var parts: Array = []
	for w in workers:
		parts.append([])
	# 長いレースが1つの仕事に偏らないよう、順に配る。
	for i in jobs.size():
		parts[i % workers].append(jobs[i])
	_started_msec = Time.get_ticks_msec()
	_job_count = jobs.size()
	_pids.clear()
	_outs.clear()
	for w in workers:
		var job_path := out_dir.path_join("job_%d.json" % w)
		var out_path := out_dir.path_join("out_%d.json" % w)
		DirAccess.remove_absolute(out_path)
		DirAccess.remove_absolute(out_path + ".part")
		var file := FileAccess.open(job_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"settings": settings, "brains": brains, "races": parts[w]}))
		file.close()
		var pid := OS.create_process(OS.get_executable_path(), [
			"--headless", "--fixed-fps", str(int(settings["fixed_fps"])), "--path", ProjectSettings.globalize_path("res://"),
			"-s", LabScore.lab_dir().path_join("lab_worker.gd"), "--", "job=" + job_path, "out=" + out_path,
		])
		_pids.append(pid)
		_outs.append(out_path)


func is_running() -> bool:
	for pid: int in _pids:
		if OS.is_process_running(pid):
			return true
	return false


## 走り終わったレースの数（途中の結果のファイルから数える）。
func done_count() -> int:
	var n := 0
	for out_path: String in _outs:
		for path in [out_path, out_path + ".part"]:
			var file := FileAccess.open(path, FileAccess.READ)
			if file != null:
				n += (JSON.parse_string(file.get_as_text()) as Array).size()
				break
	return n


func job_count() -> int:
	return _job_count


func seconds() -> float:
	return (Time.get_ticks_msec() - _started_msec) / 1000.0


## 集めた結果。仕事のファイルは、もう要らないので消す。
func collect() -> Array:
	var results: Array = []
	for w in _outs.size():
		var file := FileAccess.open(_outs[w], FileAccess.READ)
		if file == null:
			push_error("結果がありません: " + str(_outs[w]))
			continue
		results.append_array(JSON.parse_string(file.get_as_text()))
		file.close()
		DirAccess.remove_absolute(_outs[w])
		DirAccess.remove_absolute(str(_outs[w]) + ".part")
		DirAccess.remove_absolute(out_dir.path_join("job_%d.json" % w))
	return results


## 結果を、頭ごと（と今までのCPU）に分けて、点の高い順の表にする。
func score_table(results: Array) -> Array:
	var by_name := LabScore.rows_by_name(results, func(row): return baseline_name(str(row["pururin"])))
	var weights: Dictionary = settings["score"]
	var table: Array = []
	for key: String in by_name:
		var m := LabScore.metrics(by_name[key])
		table.append({"name": key, "points": LabScore.points(m, weights), "metrics": m})
	table.sort_custom(func(a, b): return float(a["points"]) > float(b["points"]))
	return table


## 今までのCPUの行の名前（ぷるりんごと）。runner_id（「番号#2」）でも、元のぷるりんで見る。
static func baseline_name(runner_id: String) -> String:
	var pururin := PururinRosterConfig.pururin_by_id(runner_id.split("#")[0])
	return "%s（%s）" % [BASELINE, str(pururin["display_name"])]


static func print_table(table: Array) -> void:
	print("名前 | 点 | 1位の割合 | 1位との差(秒) | 平均の着順 | 残った体力 | 本数")
	for row: Dictionary in table:
		var m: Dictionary = row["metrics"]
		print("%s | %.1f | %.2f | %.2f | %.2f | %.2f | %d" % [row["name"], row["points"], m["win_rate"], m["gap_to_winner_s"], m["avg_place"], m["stamina_left"], m["races"]])


static func save_json(path: String, data: Variant) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", false))
	file.close()


static func user_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	return args
