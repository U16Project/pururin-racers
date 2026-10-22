extends RefCounted
## CPU育成ラボ：つまみで走る頭。つまみの一覧は knobs.json。頭1つ＝ファイル1つ：
## {"kind": "knobs", "id", "pururin", "running_style", "generation", "knobs": {名前: 数字 か [短い距離用, 長い距離用]}}
## つまみを足すときは、knobs.json に足して、decide の中で使う（ここに使い方を書く）。

const LabScore := preload("lab_score.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const KIND := "knobs"
## 距離で2つの数字を持つつまみの、短い距離と長い距離（あいだは、中間の値）。
const SHORT_M := 1200.0
const LONG_M := 3000.0
## ノッチの範囲（ゲームの決まり：0〜6）。
const NOTCH_MAX := 6
## 心拍で下げたあと、心拍が「上限 − これ」を下回るまで上げない（bpm）。
const HEART_RETURN_MARGIN_BPM := 5.0
## ふさがれているとみなす、前との差（m）。
const BLOCKED_GAP_M := 3.0
## 横へ出るとき、前の走者から離す横の幅（m）。
const ESCAPE_SIDE_M := 2.0
## 横へ出ると決めたら、この秒数は、出る位置を変えない（左右に行ったり来たりしないように）。
const ESCAPE_HOLD_S := 2.0


## 頭のファイルを読む。読めなければ空。
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func knob_list() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LabScore.lab_dir().path_join("knobs.json")))
	return data["knobs"]


## 育てる数字の並び（つまみ1つにつき1つ、距離で2つ持つつまみは2つ）。[{name, slot（0＝短い距離用・1＝長い距離用・-1＝1つだけ）}]
static func slots(knobs: Array) -> Array:
	var out: Array = []
	for knob: Dictionary in knobs:
		if bool(knob["per_distance"]):
			out.append({"name": knob["name"], "slot": 0})
			out.append({"name": knob["name"], "slot": 1})
		else:
			out.append({"name": knob["name"], "slot": -1})
	return out


## 0〜1の数字の並びから、頭を作る（0＝範囲の下、1＝範囲の上）。
static func from_unit(unit: Array, knobs: Array, id: String, pururin_id: String, generation: int) -> Dictionary:
	var by_name := {}
	for knob: Dictionary in knobs:
		by_name[knob["name"]] = knob
	var values := {}
	var index := 0
	for slot: Dictionary in slots(knobs):
		var knob: Dictionary = by_name[slot["name"]]
		var u := clampf(float(unit[index]), 0.0, 1.0)
		var v := lerpf(float(knob["min"]), float(knob["max"]), u)
		if int(slot["slot"]) < 0:
			values[slot["name"]] = v
		else:
			if not values.has(slot["name"]):
				values[slot["name"]] = [0.0, 0.0]
			values[slot["name"]][int(slot["slot"])] = v
		index += 1
	return {
		"kind": KIND, "id": id, "pururin": pururin_id,
		"running_style": str(PururinRosterConfig.pururin_by_id(pururin_id)["running_style"]),
		"generation": generation, "knobs": values,
	}


## 頭から、0〜1の数字の並びに戻す。頭に無いつまみ（あとから足したもの）は、範囲のまん中にして、その名前を missing に入れる。
static func to_unit(brain: Dictionary, knobs: Array, missing: Array) -> Array:
	var by_name := {}
	for knob: Dictionary in knobs:
		by_name[knob["name"]] = knob
	var values: Dictionary = brain["knobs"]
	var unit: Array = []
	for slot: Dictionary in slots(knobs):
		var knob: Dictionary = by_name[slot["name"]]
		if not values.has(slot["name"]):
			if not missing.has(slot["name"]):
				missing.append(slot["name"])
			unit.append(0.5)
			continue
		var v: Variant = values[slot["name"]]
		var x := float(v[int(slot["slot"])]) if int(slot["slot"]) >= 0 else float(v)
		unit.append(inverse_lerp(float(knob["min"]), float(knob["max"]), x))
	return unit


## つまみの値（距離で2つ持つものは、その距離の値）。
static func value(brain: Dictionary, name: String, distance_m: float) -> float:
	var v: Variant = brain["knobs"][name]
	if v is Array:
		var t := clampf((distance_m - SHORT_M) / (LONG_M - SHORT_M), 0.0, 1.0)
		return lerpf(float(v[0]), float(v[1]), t)
	return float(v)


## 今の状況（lab_situation.gd）から、操作を決める。memory は、その席だけの覚え書き（最後にダッシュした時間など）。
## 返すのは {notch: -1/0/1, target_line_m: 行きたいライン（内がマイナスのm）, brake, dash, boost, phase, target_notch}。
static func decide(brain: Dictionary, s: Dictionary, memory: Dictionary) -> Dictionary:
	var d := float(s["distance_m"])
	var remaining := float(s["remaining_m"])
	var notch := int(s["notch"])
	# ノッチ：序盤・中盤・スパート。
	var phase := "mid"
	var target := 0
	if float(s["progress_m"]) < value(brain, "start_length_m", d):
		phase = "start"
		target = roundi(value(brain, "start_notch", d))
	elif remaining <= value(brain, "spurt_remaining_m", d):
		phase = "spurt"
		target = roundi(value(brain, "spurt_notch", d))
	else:
		# 中盤：いたい順位より後ろならノッチを足し、前なら引く。
		var diff := float(s["place_ratio"]) - value(brain, "wanted_place", d)
		target = roundi(value(brain, "mid_notch", d) + clampf(diff * 4.0, -1.0, 1.0) * value(brain, "place_notch_range", d))
	if phase != "spurt" and float(s["stamina"]) < value(brain, "save_stamina_below", d):
		target -= 1
	var heart_limit: float = value(brain, "spurt_heart_limit_bpm", d) if phase == "spurt" else value(brain, "mid_heart_limit_bpm", d)
	var heart := float(s["heart_bpm"])
	# 心拍が上限を超えたら、そのときの段から1段だけ下げる。下げたあとは、心拍が少し下がるまで上げない
	# （上げ下げをくり返すと、それだけで心拍が上がるため）。
	if heart > heart_limit:
		if not memory.has("heart_cap"):
			memory["heart_cap"] = target - 1
		target = mini(target, int(memory["heart_cap"]))
	elif memory.has("heart_cap"):
		if heart > heart_limit - HEART_RETURN_MARGIN_BPM:
			target = mini(target, int(memory["heart_cap"]))
		else:
			memory.erase("heart_cap")
	target = clampi(target, 0, NOTCH_MAX)
	# ライン。
	var now := float(s["now_s"])
	var line: float = s["line_m"]
	var line_max := float(s["line_max_m"])
	var target_line := line
	var start_escape := false
	var leaving := remaining <= value(brain, "leave_follow_remaining_m", d)
	var follow_within := value(brain, "follow_within_m", d)
	var lane_gap := float(s["lane_ahead_gap_m"])
	var blocked := bool(s["has_lane_ahead"]) and lane_gap < BLOCKED_GAP_M \
		and float(s["speed_kmh"]) - float(s["actual_speed_kmh"]) >= value(brain, "blocked_speed_loss_kmh", d)
	if now < float(memory.get("escape_until_s", -INF)):
		# 横へ出ている途中：決めた位置のまま。
		target_line = float(memory["escape_line_m"])
	elif blocked or (leaving and bool(s["has_lane_ahead"]) and lane_gap <= follow_within):
		# 同じラインの前にふさがれた、または、後ろにつくのをやめる所：広い側（コースのまん中寄り）へ出る。
		var lane_line := float(s["lane_ahead_line_m"])
		var side := -1.0 if lane_line > 0.0 else 1.0
		target_line = clampf(lane_line + side * ESCAPE_SIDE_M, -line_max, line_max)
		memory["escape_line_m"] = target_line
		memory["escape_until_s"] = now + ESCAPE_HOLD_S
		start_escape = true
	elif not leaving and bool(s["has_ahead"]) and float(s["ahead_gap_m"]) <= follow_within:
		# 前の真後ろにつく（風よけ）。
		target_line = float(s["ahead_line_m"])
	elif bool(s["corner_now"]) or bool(s["corner_ahead"]):
		target_line = lerpf(line, -line_max, value(brain, "corner_inside", d))
	# ブースト：次が何回目かで、使う残り距離が決まる。
	var boost := false
	var used := 3 - int(s["boost_left"])
	if used < 3:
		var at: float = value(brain, "boost%d_remaining_m" % (used + 1), d)
		boost = remaining <= at and float(s["stamina"]) >= value(brain, "boost_stamina_at_least", d)
	# ダッシュ。
	var since_dash := now - float(memory.get("last_dash_s", -INF))
	var dash := false
	if not bool(s["dash_active"]) and since_dash >= value(brain, "dash_interval_s", d):
		dash = remaining <= value(brain, "dash_remaining_m", d) and float(s["heart_bpm"]) <= value(brain, "dash_heart_below_bpm", d)
		if start_escape and value(brain, "dash_on_escape", d) >= 0.5:
			dash = true
	return {
		"notch": signi(target - notch), "target_line_m": target_line, "brake": false, "dash": dash, "boost": boost,
		"phase": phase, "target_notch": target,
	}
