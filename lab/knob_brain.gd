extends RefCounted
## CPU育成ラボ：性格の枠の中で、つまみで走る頭。つまみの一覧は knobs.json、性格の枠は trainer_styles.json の frame。
## 頭1つ＝ファイル1つ：{"kind": "persona", "id", "pururin", "trainer", "generation", "knobs": {名前: 数字 か [短い距離用, 長い距離用]}}
## 性格はトレーナーのもの（ぷるりんの一覧の trainer_id）。性格の枠は育成で変えない。
##
## ノッチの決め方（0.5秒ごと）：項目ごと（順位・体力・心拍・抜かれた／詰められた・温存・保ちたい心拍・スパート）に「上げたい（＋）・下げたい（−）」の気持ちを −1〜1 で出し、つまみの重さを掛けて足す。
## 合計が線（want_threshold）を超えたら1段上げ、マイナスで超えたら1段下げる。優先の順番は決めない（重さで決まる）。
## つまみを足すときは、knobs.json に足して、decide の中で使う（ここに使い方を書く）。

const LabScore := preload("lab_score.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")

const KIND := "persona"
## 距離で2つの数字を持つつまみの、短い距離と長い距離（あいだは、中間の値）。性格の枠の距離の基準は2000m。
const SHORT_M := 1200.0
const LONG_M := 3000.0
const FRAME_DISTANCE_M := 2000.0
## ノッチの範囲（ゲームの決まり：0〜6）。
const NOTCH_MAX := 6
## 心拍の気持ちが、下げたい気持ちの出はじめから −1 になるまでの幅（bpm）。
const HEART_SOFT_SPAN_BPM := 15.0
## 順位・体力の気持ちが −1〜1 になるまでの目安（順位2つぶん、体力25%ぶん）。
const PLACE_SPAN := 2.0
const STAMINA_SPAN := 0.25
## 保ちたい心拍から、これだけ離れたら、気持ちが −1〜1 になる（bpm）。
const CRUISE_SPAN_BPM := 20.0
## 抜かれたあと、取り返したい気持ちが続く秒数。
const PASSED_HOLD_S := 3.0
## ふさがれているとみなす、前との差（m）。横へ出るとき、前の走者から離す横の幅（m）と、その位置を保つ秒数。
const BLOCKED_GAP_M := 3.0
const ESCAPE_SIDE_M := 2.0
const ESCAPE_HOLD_S := 2.0

static var _styles := {}


## 頭のファイルを読む。読めなければ空。
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data if data is Dictionary else {}


static func knob_list() -> Array:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LabScore.lab_dir().path_join("knobs.json")))
	return data["knobs"]


## トレーナーの性格の枠。
static func frame_of(trainer_id: String) -> Dictionary:
	if _styles.is_empty():
		_styles = JSON.parse_string(FileAccess.get_file_as_string(LabScore.lab_dir().path_join("trainer_styles.json")))["trainers"]
	return _styles[trainer_id]["frame"]


static func trainer_of(pururin_id: String) -> String:
	return str(PururinRosterConfig.pururin_by_id(pururin_id)["trainer_id"])


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


## つまみの範囲（性格の枠から取るものは、その距離に合わせる）。slot は 0＝短い距離用・1＝長い距離用・-1＝1つだけ。
static func knob_range(knob: Dictionary, frame: Dictionary, slot: int) -> Vector2:
	if not knob.has("range_from"):
		return Vector2(float(knob["min"]), float(knob["max"]))
	var r: Array = frame[str(knob["range_from"])]
	var scale := 1.0
	if bool(knob.get("scale_with_distance", false)):
		scale = (SHORT_M if slot == 0 else LONG_M) / FRAME_DISTANCE_M
	return Vector2(float(r[0]) * scale, float(r[1]) * scale)


## 0〜1の数字の並びから、頭を作る（0＝範囲の下、1＝範囲の上）。
static func from_unit(unit: Array, knobs: Array, id: String, pururin_id: String, generation: int) -> Dictionary:
	var trainer := trainer_of(pururin_id)
	var frame := frame_of(trainer)
	var by_name := {}
	for knob: Dictionary in knobs:
		by_name[knob["name"]] = knob
	var values := {}
	var index := 0
	for slot: Dictionary in slots(knobs):
		var r := knob_range(by_name[slot["name"]], frame, int(slot["slot"]))
		var v := lerpf(r.x, r.y, clampf(float(unit[index]), 0.0, 1.0))
		if int(slot["slot"]) < 0:
			values[slot["name"]] = v
		else:
			if not values.has(slot["name"]):
				values[slot["name"]] = [0.0, 0.0]
			values[slot["name"]][int(slot["slot"])] = v
		index += 1
	return {
		"kind": KIND, "id": id, "pururin": pururin_id, "trainer": trainer,
		"running_style": str(PururinRosterConfig.pururin_by_id(pururin_id)["running_style"]),
		"generation": generation, "knobs": values,
	}


## 頭から、0〜1の数字の並びに戻す。頭に無いつまみ（あとから足したもの）は、範囲のまん中にして、その名前を missing に入れる。
static func to_unit(brain: Dictionary, knobs: Array, missing: Array) -> Array:
	var frame := frame_of(str(brain["trainer"]))
	var values: Dictionary = brain["knobs"]
	var by_name := {}
	for knob: Dictionary in knobs:
		by_name[knob["name"]] = knob
	var unit: Array = []
	for slot: Dictionary in slots(knobs):
		if not values.has(slot["name"]):
			if not missing.has(slot["name"]):
				missing.append(slot["name"])
			unit.append(0.5)
			continue
		var r := knob_range(by_name[slot["name"]], frame, int(slot["slot"]))
		var v: Variant = values[slot["name"]]
		var x := float(v[int(slot["slot"])]) if int(slot["slot"]) >= 0 else float(v)
		unit.append(inverse_lerp(r.x, r.y, x) if r.y > r.x else 0.5)
	return unit


## つまみの値（距離で2つ持つものは、その距離の値）。
static func value(brain: Dictionary, name: String, distance_m: float) -> float:
	var v: Variant = brain["knobs"][name]
	if v is Array:
		var t := clampf((distance_m - SHORT_M) / (LONG_M - SHORT_M), 0.0, 1.0)
		return lerpf(float(v[0]), float(v[1]), t)
	return float(v)


## 今の状況（lab_situation.gd）から、操作を決める。memory は、その席だけの覚え書き。
## memory の last_dash_s は、ダッシュが効いたときに、走らせる側が入れる。
## 返すのは {notch: -1/0/1, target_line_m, brake, dash, boost, phase, target_notch, wants: {項目: 気持ち}}。
static func decide(brain: Dictionary, s: Dictionary, memory: Dictionary) -> Dictionary:
	var frame := frame_of(str(brain["trainer"]))
	var d := float(s["distance_m"])
	var now := float(s["now_s"])
	var step := clampf(now - float(memory.get("last_now_s", now)), 0.0, 1.0)
	memory["last_now_s"] = now
	var remaining := float(s["remaining_m"])
	var place := int(s["place"])
	var heart := float(s["heart_bpm"])
	# 場面：序盤・中盤・スパート。
	var phase := "mid"
	if float(s["progress_m"]) < value(brain, "start_length_m", d):
		phase = "start"
	elif remaining <= value(brain, "spurt_remaining_m", d):
		phase = "spurt"
	# いたい順位（終盤の枠があれば、残り3分の1から）。
	var wanted: Array = frame["place"]
	if frame.has("late_place") and remaining <= d / 3.0:
		wanted = frame["late_place"]
	var wants := {}
	# 順位：いたい順位より後ろなら上げたい、前すぎるなら下げたい。
	var place_want := 0.0
	if place > int(wanted[1]):
		place_want = minf(float(place - int(wanted[1])) / PLACE_SPAN, 1.0)
	elif place < int(wanted[0]):
		place_want = -minf(float(int(wanted[0]) - place) / PLACE_SPAN, 1.0)
	var place_weight := value(brain, "w_place", d) * (1.0 + (value(brain, "start_rush", d) if phase == "start" else 0.0))
	wants["place"] = place_want * place_weight
	# 体力：目安（スタートで100%、ゴールで finish_stamina_target まで、まっすぐ減る）より減っていたら、下げたい。
	var plan := 1.0 - (1.0 - value(brain, "finish_stamina_target", d)) * clampf(float(s["progress_m"]) / maxf(d, 1.0), 0.0, 1.0)
	var short := float(s["stamina"]) - plan
	wants["stamina"] = (maxf(short / STAMINA_SPAN, -1.0) if short < 0.0 and phase != "spurt" else 0.0) * value(brain, "w_stamina", d)
	# 抜かれた・詰められた：性格が取り返す・引かないなら、上げたい。
	var prev_place := int(memory.get("prev_place", place))
	memory["prev_place"] = place
	if place > prev_place and float(frame["retake"]) > 0.0:
		memory["passed_until_s"] = now + PASSED_HOLD_S
	var passed := now < float(memory.get("passed_until_s", -INF))
	var closed := float(s["behind_gap_m"]) <= value(brain, "closed_in_gap_m", d) and float(frame["hold"]) > 0.0
	var scene := (float(frame["retake"]) if passed else 0.0) + (float(frame["hold"]) if closed else 0.0)
	wants["scene"] = minf(scene, 1.0) * value(brain, "w_scene", d)
	# 心拍：高いほど、下げたい。上限（200）を超えても特別な決まりは置かない（ほかの気持ちが強ければ、そのまま上げる）。
	wants["heart"] = -clampf((heart - value(brain, "heart_soft_bpm", d)) / HEART_SOFT_SPAN_BPM, 0.0, 1.0) * value(brain, "w_heart", d)
	# 温存：いたい順位の中で、後ろと差がある時間が続いたら、下げたい。
	var in_range := place >= int(wanted[0]) and place <= int(wanted[1])
	if in_range and float(s["behind_gap_m"]) >= value(brain, "save_gap_m", d):
		memory["easy_s"] = float(memory.get("easy_s", 0.0)) + step
	else:
		memory["easy_s"] = 0.0
	wants["save"] = (-1.0 if float(memory["easy_s"]) >= value(brain, "save_after_s", d) and phase != "spurt" else 0.0) * value(brain, "w_save", d)
	# 保ちたい心拍：中盤（序盤とスパートは除く）、心拍がそれより高ければ下げたい、低ければ上げたい。
	var cruise := 0.0
	if phase == "mid":
		cruise = clampf((value(brain, "cruise_heart_bpm", d) - heart) / CRUISE_SPAN_BPM, -1.0, 1.0)
	wants["cruise"] = cruise * value(brain, "w_cruise", d)
	# スパート：スパートの区間では、上げたい。
	wants["spurt"] = (1.0 if phase == "spurt" else 0.0) * value(brain, "w_spurt", d)
	# 合計して、ノッチを決める。
	var total := 0.0
	for key: String in wants:
		total += float(wants[key])
	var notch := int(s["notch"])
	var command := 0
	var threshold := value(brain, "want_threshold", d)
	if total > threshold and notch < NOTCH_MAX:
		command = 1
	elif total < -threshold and notch > 0:
		command = -1
	# ライン。
	var target_line := _line(brain, frame, s, memory, phase, d)
	# ブースト：次が何回目かで、使う残り距離が決まる。
	var boost := false
	var used := 3 - int(s["boost_left"])
	if used < 3:
		boost = remaining <= value(brain, "boost%d_remaining_m" % (used + 1), d) and float(s["stamina"]) >= value(brain, "boost_stamina_at_least", d)
	# ダッシュ。
	var dash := false
	if not bool(s["dash_active"]) and now - float(memory.get("last_dash_s", -INF)) >= value(brain, "dash_interval_s", d):
		dash = remaining <= value(brain, "dash_remaining_m", d) and heart <= value(brain, "dash_heart_below_bpm", d)
	return {
		"notch": command, "target_line_m": target_line, "brake": false, "dash": dash, "boost": boost,
		"phase": phase, "target_notch": clampi(notch + command, 0, NOTCH_MAX), "wants": wants,
	}


## 行きたいライン（内がマイナスのm）。性格のラインの癖も、ここで入れる。
static func _line(brain: Dictionary, frame: Dictionary, s: Dictionary, memory: Dictionary, phase: String, d: float) -> float:
	var now := float(s["now_s"])
	var line: float = s["line_m"]
	var line_max := float(s["line_max_m"])
	var remaining := float(s["remaining_m"])
	var habit := str(frame["line"])
	var leaving := remaining <= value(brain, "leave_follow_remaining_m", d)
	var lane_gap := float(s["lane_ahead_gap_m"])
	var has_lane := bool(s["has_lane_ahead"])
	# 「隙間」の癖の子は、速さが落ちるのを待たずに、ふさがれたらすぐ横へ出る。
	var loss_needed := 0.0 if habit == "gap" else value(brain, "blocked_speed_loss_kmh", d)
	var blocked := has_lane and lane_gap < BLOCKED_GAP_M and float(s["speed_kmh"]) - float(s["actual_speed_kmh"]) >= loss_needed
	var follow_ok := float(frame["follow_m"][1]) > 0.0 and (int(frame["follow_only_within_place"]) == 0 or int(s["place"]) <= int(frame["follow_only_within_place"]))
	if now < float(memory.get("escape_until_s", -INF)):
		return float(memory["escape_line_m"])
	if habit == "outside_late" and phase == "spurt" and has_lane and lane_gap <= value(brain, "follow_within_m", d) + BLOCKED_GAP_M:
		# 直線・スパートで外へ出る癖：前の走者より外へ。
		return _escape(memory, now, minf(float(s["lane_ahead_line_m"]) + ESCAPE_SIDE_M, line_max))
	if blocked or (leaving and has_lane and lane_gap <= value(brain, "follow_within_m", d)):
		# 広い側（コースのまん中寄り）へ出る。
		var lane_line := float(s["lane_ahead_line_m"])
		var side := -1.0 if lane_line > 0.0 else 1.0
		return _escape(memory, now, clampf(lane_line + side * ESCAPE_SIDE_M, -line_max, line_max))
	if follow_ok and not leaving and bool(s["has_ahead"]) and float(s["ahead_gap_m"]) <= value(brain, "follow_within_m", d):
		# 前の真後ろにつく（風よけ）。
		return float(s["ahead_line_m"])
	if bool(s["corner_now"]) or bool(s["corner_ahead"]):
		return lerpf(line, -line_max, value(brain, "corner_inside", d))
	return line


static func _escape(memory: Dictionary, now: float, target: float) -> float:
	memory["escape_line_m"] = target
	memory["escape_until_s"] = now + ESCAPE_HOLD_S
	return target
