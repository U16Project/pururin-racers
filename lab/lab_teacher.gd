extends SceneTree
## CPU育成ラボ：あなたの走り（ゲームの記録ファイル）を先生にして、そのぷるりんの頭に写す。レースは走らせない。
## 記録の0.5秒ごとの場面で、頭が「あなたと同じ操作」をするほど点が高い。性格の枠の中で、点がいちばん高くなる数字を探す（CMA-ES）。
## 使う記録：lab_settings.json の teacher_since より後に保存され、あなたがそのぷるりんを操作したレース。
## 比べる操作：ノッチの段、ライン、ダッシュとブーストを押した位置（くわしくは _agreement）。
## 起動（client/ で）：godot --headless --path . -s ../lab/lab_teacher.gd -- pururin=player-1
##   作りの確かめだけに、since=<日時>（記録の始まりを、その時だけ変える）と rounds=<回数> を付けられる。
## 結果：lab/brains/<ぷるりん>.json（写した頭。代を重ねる出発点）と、lab/runs/teacher/<ぷるりん>.json（どれだけ合ったか）。

const KnobBrain := preload("knob_brain.gd")
const LabSituation := preload("lab_situation.gd")
const LabScore := preload("lab_score.gd")
const LabBatch := preload("lab_batch.gd")
const Cma := preload("cma.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")

const LOG_DIR := "user://pururin_race_logs"
## ラインは、何コマ先（0.5秒ごと）のあなたのラインと比べるか。比べる差の目安（これだけずれたら0点）。
const LINE_LOOK_STEPS := 2
const LINE_ERROR_M := 3.0
## ノッチの上げ下げは、前後何コマ（0.5秒ごと）のずれまで、合ったと数えるか。ブースト・ダッシュは、押した位置が何mずれたら0点か。
const NOTCH_WINDOW_STEPS := 1
const PRESS_ERROR_M := 200.0
## 操作ごとの重さ（合わせて1）。
const WEIGHTS := {"notch": 0.4, "line": 0.3, "dash": 0.15, "boost": 0.15}
## 写すときの、候補の数と、くり返しの回数。
const CANDIDATES := 12
const ROUNDS := 100

var _knobs: Array
var _races: Array = []


func _initialize() -> void:
	var args := LabBatch.user_args()
	var pururin := str(args["pururin"])
	var settings := LabScore.load_settings()
	_knobs = KnobBrain.knob_list()
	var since := str(args.get("since", settings["teacher_since"]))
	var rounds := int(args.get("rounds", str(ROUNDS)))
	var files := _teacher_files(pururin, since)
	if files.is_empty():
		print("先生の記録がありません（%s を、%s より後に操作したレース）" % [pururin, since])
		quit()
		return
	for path: String in files:
		_races.append(_load_race(path, pururin))
	var steps := 0
	for race: Dictionary in _races:
		steps += (race["steps"] as Array).size()
	print("先生の記録：%d 本（%d 場面）" % [_races.size(), steps])
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var start: Array = []
	for i in KnobBrain.slots(_knobs).size():
		start.append(0.5)
	# ブースト・ダッシュの「使う残り距離」などは、あなたが押した位置から、そのまま決める（探さない）。
	var fixed := _fixed_knobs()
	print("押した位置から決めた数字：%s" % JSON.stringify(fixed))
	var cma := Cma.new(start, 0.3, CANDIDATES)
	var best_unit: Array = start
	var best_score := -INF
	for round_index in rounds:
		var candidates := cma.ask(rng)
		var costs: Array = []
		for unit: Array in candidates:
			var score := float(_agreement(_with_fixed(KnobBrain.from_unit(unit, _knobs, "", pururin, 0), fixed))["total"])
			costs.append(-score + Cma.outside(unit))
			if score > best_score:
				best_score = score
				best_unit = unit
		cma.tell(candidates, costs)
		if round_index % 10 == 0:
			print("  %d回目：いちばん合った %.1f%%" % [round_index, best_score * 100.0])
	var brain := _with_fixed(KnobBrain.from_unit(best_unit, _knobs, "%s-先生" % pururin, pururin, 0), fixed)
	var result := _agreement(brain)
	brain["teacher"] = {"races": files.map(func(p): return p.get_file()), "since": since, "agreement": result}
	LabBatch.save_json(LabScore.lab_dir().path_join("brains/%s.json" % pururin), brain)
	LabBatch.save_json(LabScore.lab_dir().path_join("runs/teacher/%s.json" % pururin), {"files": files, "agreement": result, "baseline": _agreement(KnobBrain.from_unit(start, _knobs, "", pururin, 0))})
	print("写した頭：lab/brains/%s.json" % pururin)
	print("合った割合：全体 %.1f%%（ノッチ %.1f%%、ライン %.1f%%、ダッシュ %.1f%%、ブースト %.1f%%）" % [
		float(result["total"]) * 100.0, float(result["notch"]) * 100.0, float(result["line"]) * 100.0, float(result["dash"]) * 100.0, float(result["boost"]) * 100.0])
	quit()


## あなたが押した位置から、そのまま決めるつまみ：ブースト1〜3回目・ダッシュの使い始めの残り距離（距離ごとの平均から、
## 1200m用と3000m用を、距離に比例する線で出す）、ダッシュの間隔（押した間隔の平均）。
## 押す時を、残り距離だけで決めるように、体力・心拍の条件は、いちばんゆるくする。
func _fixed_knobs() -> Dictionary:
	var by_key := {}
	var gaps: Array = []
	for race: Dictionary in _races:
		var distance := float(race["distance_m"])
		var boosts: Array = []
		var dashes: Array = []
		for step: Dictionary in race["steps"]:
			var s: Dictionary = step["s"]
			if bool(step["boost"]):
				boosts.append(float(s["remaining_m"]))
			if bool(step["dash"]):
				dashes.append(s)
		for k in boosts.size():
			_add(by_key, "boost%d_remaining_m" % (k + 1), distance, boosts[k])
		if not dashes.is_empty():
			_add(by_key, "dash_remaining_m", distance, float(dashes[0]["remaining_m"]))
		for k in range(1, dashes.size()):
			gaps.append(float(dashes[k]["now_s"]) - float(dashes[k - 1]["now_s"]))
	var fixed := {"boost_stamina_at_least": -1.0, "dash_heart_below_bpm": 230.0}
	for key: String in by_key:
		fixed[key] = _distance_line(by_key[key])
	if not gaps.is_empty():
		var total := 0.0
		for g: float in gaps:
			total += g
		fixed["dash_interval_s"] = total / float(gaps.size())
	return fixed


static func _add(by_key: Dictionary, key: String, distance: float, value: float) -> void:
	if not by_key.has(key):
		by_key[key] = []
	(by_key[key] as Array).append(Vector2(distance, value))


## 距離と値の組から、1200m用と3000m用の値。まず距離ごとに、並べて真ん中の値を取り（1回だけの遠い値に引っぱられないように）、
## その距離ごとの値に、距離に比例する線を引く。距離が1つだけなら、その値を両方に。
static func _distance_line(raw: Array) -> Array:
	var groups := {}
	for p: Vector2 in raw:
		if not groups.has(p.x):
			groups[p.x] = []
		(groups[p.x] as Array).append(p.y)
	var points: Array = []
	for x: float in groups:
		var ys: Array = groups[x]
		ys.sort()
		var mid := ys.size() / 2
		points.append(Vector2(x, float(ys[mid]) if ys.size() % 2 == 1 else (float(ys[mid - 1]) + float(ys[mid])) * 0.5))
	var n := float(points.size())
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for p: Vector2 in points:
		sx += p.x
		sy += p.y
		sxx += p.x * p.x
		sxy += p.x * p.y
	var spread := n * sxx - sx * sx
	if spread < 1.0:
		return [maxf(sy / n, 0.0), maxf(sy / n, 0.0)]
	var slope := (n * sxy - sx * sy) / spread
	var base := (sy - slope * sx) / n
	return [maxf(base + slope * KnobBrain.SHORT_M, 0.0), maxf(base + slope * KnobBrain.LONG_M, 0.0)]


static func _with_fixed(brain: Dictionary, fixed: Dictionary) -> Dictionary:
	for key: String in fixed:
		brain["knobs"][key] = fixed[key]
	return brain


## 先生の記録のファイル（決めた日時より後に保存され、そのぷるりんを人が操作したもの）。古い順。
func _teacher_files(pururin: String, since: String) -> Array:
	# teacher_since は、このPCの時刻で書いてある。ファイルの時刻（世界共通の秒）と比べるため、時差を引く。
	var since_unix := Time.get_unix_time_from_datetime_string(since) - int(Time.get_time_zone_from_system()["bias"]) * 60
	var dir := ProjectSettings.globalize_path(LOG_DIR)
	var out: Array = []
	for name in DirAccess.get_files_at(dir):
		var path := dir.path_join(name)
		if not name.ends_with(".json") or FileAccess.get_modified_time(path) < since_unix:
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or (data["samples"] as Array).is_empty():
			continue
		for record: Dictionary in data["samples"][0]["runners"]:
			if bool(record["player"]) and str(record["id"]).split("#")[0] == pururin:
				out.append(path)
	out.sort_custom(func(a, b): return FileAccess.get_modified_time(a) < FileAccess.get_modified_time(b))
	return out


## 1本の記録から、場面（状況）と、そのあとのあなたの操作の並びを作る。
func _load_race(path: String, pururin: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var distance := float(data["race_distance_m"])
	var path3d := Path3D.new()
	LocalRaceMath.apply_course_to_path(path3d)
	var route := CourseBuilder.route_for_distance(LocalRaceMath.course_layout(), distance)
	var inside := LabSituation.inside_sign(path3d.curve)
	var samples: Array = data["samples"]
	var steps: Array = []
	for i in range(samples.size() - 1):
		var me := _player(samples[i], pururin)
		var next := _player(samples[i + 1], pururin)
		if bool(me["finished"]):
			break
		var later := _player(samples[mini(i + LINE_LOOK_STEPS, samples.size() - 1)], pururin)
		var others: Array = (samples[i]["runners"] as Array).filter(func(r): return not bool(r["player"]))
		var situation := LabSituation.from_records(me, others, distance, path3d.curve, route, inside, float(samples[i]["elapsed_s"]))
		steps.append({
			"s": situation,
			"notch_change": signi(roundi(float(next["drive_level"])) - roundi(float(me["drive_level"]))),
			"line_later": -inside * float(later["offset"]),
			"dash": bool(next["dash_active"]) and not bool(me["dash_active"]),
			"boost": int(next["boost_uses_left"]) < int(me["boost_uses_left"]),
		})
	path3d.free()
	return {"path": path, "distance_m": distance, "steps": steps}


static func _player(sample: Dictionary, pururin: String) -> Dictionary:
	for record: Dictionary in sample["runners"]:
		if bool(record["player"]) and str(record["id"]).split("#")[0] == pururin:
			return record
	return {}


## 頭が、あなたとどれだけ同じに走るか（0〜1。操作ごとに出し、重さで合わせる）。
## 場面の状況は、記録のまま（あなたのノッチ・心拍のまま。頭の操作で場面は変えない）。
## ノッチ：「上げる・そのまま・下げる」が、あなたと同じか。0.5秒前後のずれは合ったと数える。
##   あなたがした操作の種類ごとに合った割合を出して平均する（「そのまま」がほとんどなので、ふつうに数えると、何もしない頭が高くなるため）。
## ライン：頭が行きたいラインと、1秒後のあなたのラインの差（3mずれたら0点）。
## ブースト・ダッシュ：あなたが押した位置（残り距離）と、頭が押す位置の差（200mずれたら0点。頭が押さなければ0点）。
## ダッシュの間隔も、あなたが押した時で数える。
func _agreement(brain: Dictionary) -> Dictionary:
	var notch_hits := {}
	var notch_totals := {}
	var line_err := 0.0
	var count := 0
	var press_scores := {"dash": [], "boost": []}
	for race: Dictionary in _races:
		var memory := {}
		var steps: Array = race["steps"]
		var commands: Array = []
		var user_boost := {}
		var dash_guess := -1.0
		for step: Dictionary in steps:
			var s: Dictionary = step["s"]
			var command := KnobBrain.decide(brain, s, memory)
			commands.append(int(command["notch"]))
			line_err += minf(absf(float(command["target_line_m"]) - float(step["line_later"])) / LINE_ERROR_M, 1.0)
			count += 1
			var remaining := float(s["remaining_m"])
			var left := int(s["boost_left"])
			if bool(step["boost"]):
				user_boost[left] = remaining
			if bool(command["dash"]) and dash_guess < 0.0:
				dash_guess = remaining
			if bool(step["dash"]):
				(press_scores["dash"] as Array).append(_press_score(dash_guess, remaining))
				dash_guess = -1.0
				memory["last_dash_s"] = float(s["now_s"])
		for i in steps.size():
			var actual := int(steps[i]["notch_change"])
			notch_totals[actual] = int(notch_totals.get(actual, 0)) + 1
			var hit := false
			for j in range(maxi(i - NOTCH_WINDOW_STEPS, 0), mini(i + NOTCH_WINDOW_STEPS, steps.size() - 1) + 1):
				if int(commands[j]) == actual:
					hit = true
					break
			if actual == 0:
				# 「そのまま」は、その場で頭も動かさなかったときだけ合ったと数える（いつも動く頭を、高く数えないため）。
				hit = int(commands[i]) == 0
			if hit:
				notch_hits[actual] = int(notch_hits.get(actual, 0)) + 1
		# ブースト：あなたが先に押すと、記録の上では頭に押す機会が来ないので、頭が押すはずの位置を、
		# その回数目のまま、レースの初めから探す。
		for left: int in user_boost:
			(press_scores["boost"] as Array).append(_press_score(_brain_boost_at(brain, steps, left), float(user_boost[left])))
	var notch_sum := 0.0
	for kind in notch_totals:
		notch_sum += float(notch_hits.get(kind, 0)) / float(notch_totals[kind])
	var result := {
		"notch": notch_sum / maxf(float(notch_totals.size()), 1.0),
		"line": clampf(1.0 - line_err / maxf(float(count), 1.0), 0.0, 1.0),
	}
	for key: String in press_scores:
		var list: Array = press_scores[key]
		var total := 0.0
		for v: float in list:
			total += v
		result[key] = total / float(list.size()) if not list.is_empty() else 1.0
	var weighted := 0.0
	for key: String in WEIGHTS:
		weighted += float(WEIGHTS[key]) * float(result[key])
	result["total"] = weighted
	return result


## ブーストの残り回数が left のとき、頭が初めて押す残り距離（押さなければ -1）。ブーストの判断は、残り距離・体力・残り回数だけで決まる。
static func _brain_boost_at(brain: Dictionary, steps: Array, left: int) -> float:
	var memory := {}
	for step: Dictionary in steps:
		var s: Dictionary = (step["s"] as Dictionary).duplicate()
		s["boost_left"] = left
		if bool(KnobBrain.decide(brain, s, memory)["boost"]):
			return float(s["remaining_m"])
	return -1.0


## 押した位置の点：頭の位置（押さなければ -1）と、あなたの位置の差から。
static func _press_score(brain_at: float, user_at: float) -> float:
	if brain_at < 0.0:
		return 0.0
	return clampf(1.0 - absf(brain_at - user_at) / PRESS_ERROR_M, 0.0, 1.0)
