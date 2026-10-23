extends RefCounted
## 強化学習：頭が見るもの（数字の並び）と、選べる操作。
## 走っているレースからも、ゲームの記録ファイルの1コマ（あなたの走り＝お手本）からも、同じ形で作る。
## 1体ぶんの値は、走者の get_telemetry_snapshot() と同じ形（記録ファイルの runners の1つも同じ形）。
## 並びの長さは、いつも同じ（size()）。値は、だいたい -1〜1 に収める。「いない」「とても遠い」は、決めた上限の数字に置きかえる。

const LabSituation := preload("../lab_situation.gd")
const RlCourse := preload("rl_course.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const StatsMath := preload("res://scripts/pururin_stats_math.gd")
const StatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const TrackMath := preload("res://scripts/track_math.gd")

## 操作の並び：ノッチ（下げる・そのまま・上げる）、ライン（内へ・そのまま・外へ）、ブレーキ、ダッシュ、ブースト。
const ACTION_SIZES := [3, 3, 2, 2, 2]
## 距離・時間の目安。値を -1〜1 くらいにするために割る。
const DISTANCE_SCALE_M := 3000.0
const COURSE_LOOK_M := 300.0
const FINAL_STRAIGHT_SCALE_M := 500.0
const SECONDS_SCALE := 20.0
## トレーナーの性格の数字（trainer_styles.json の frame）。並べる順と、割る数。範囲の数字は [下, 上] の2つ。
const FRAME_KEYS := [["place", 8.0], ["late_place", 8.0], ["retake", 1.0], ["hold", 1.0], ["save_after_s", SECONDS_SCALE],
	["follow_m", SECONDS_SCALE], ["follow_only_within_place", 8.0], ["spurt_m_2000", 2000.0]]
const TRAINER_STYLES_PATH := "../lab/trainer_styles.json"
## 集団の位置：前・中・後ろ・ひとり。
const GROUP_SLOTS := 4

static var _runner_info := {}
static var _frames := {}


## 並びの長さ。
static func size(field: int) -> int:
	var stats := (StatsConfig.values()["stat_ids"] as Array).size()
	var attrs := (StatsConfig.values()["attributes"] as Dictionary).size()
	var styles := StatsMath.rank_group_count()
	var race := 12 + 5 + 3 + GROUP_SLOTS
	var me := 17 + stats * 2 + attrs + styles + _frame_size()
	return race + me + (field - 1) * _other_size()


static func _other_size() -> int:
	var stats := (StatsConfig.values()["stat_ids"] as Array).size()
	return 14 + stats * 2 + (StatsConfig.values()["attributes"] as Dictionary).size() + StatsMath.rank_group_count()


static func _frame_size() -> int:
	var n := 0
	for key: Array in FRAME_KEYS:
		n += 1 if str(key[0]) in ["retake", "hold", "follow_only_within_place"] else 2
	return n


## ctx：{distance_m, elapsed_s, curve, route, inside, field, scales（rl_settings の observe）}
## me＝学ぶ席の1体ぶん、others＝ほかの全員の1体ぶん。
static func from_records(me: Dictionary, others: Array, ctx: Dictionary) -> PackedFloat32Array:
	var scales: Dictionary = ctx["scales"]
	var gap_scale := float(scales["gap_scale_m"])
	var speed_scale := float(scales["speed_scale_kmh"])
	var field := int(ctx["field"])
	var distance := maxf(float(ctx["distance_m"]), 1.0)
	var elapsed := float(ctx["elapsed_s"])
	var inside := float(ctx["inside"])
	var s := LabSituation.from_records(_situation_record(me), others.map(_situation_record), distance, ctx["curve"], ctx["route"], inside, elapsed)
	var progress := float(s["progress_m"])
	var typical_s := typical_finish_s(distance, scales)
	var out := PackedFloat32Array()
	# レース
	out.append(distance / DISTANCE_SCALE_M)
	out.append(progress / distance)
	out.append(clampf(float(s["remaining_m"]) / DISTANCE_SCALE_M, 0.0, 1.0))
	out.append(clampf(elapsed / typical_s, 0.0, 2.0))
	out.append(float(me["gate"]) / maxf(float(field - 1), 1.0))
	out.append(float(s["place_ratio"]))
	out.append(1.0 if bool(s["has_lane_ahead"]) else 0.0)
	out.append(_gap(float(s["lane_ahead_gap_m"]), gap_scale))
	out.append(_gap(float(s["ahead_gap_m"]), gap_scale))
	out.append(_gap(float(s["behind_gap_m"]), gap_scale))
	out.append(1.0 if bool(s["corner_now"]) else 0.0)
	out.append(1.0 if bool(s["corner_ahead"]) else 0.0)
	# コースの先の形
	var profile := RlCourse.profile(ctx["curve"], ctx["route"], distance)
	var ahead := RlCourse.ahead(profile, progress, COURSE_LOOK_M)
	out.append(float(ahead["to_corner_m"]) / COURSE_LOOK_M)
	out.append(float(ahead["corner_bend"]))
	out.append(float(ahead["corner_left_m"]) / COURSE_LOOK_M)
	out.append(float(profile["final_straight_m"]) / FINAL_STRAIGHT_SCALE_M)
	out.append(1.0 if bool(ahead["on_final_straight"]) else 0.0)
	# レース全体の流れ：先頭の組の速さ（その距離のふつうのペースと比べて）、隊列の長さ、自分が集団のどこか
	var everyone: Array = others.duplicate()
	everyone.append(me)
	everyone.sort_custom(func(a, b): return float(a["race_progress"]) > float(b["race_progress"]))
	var groups := _groups(everyone, float(scales["group_gap_m"]))
	var leader_progress := float(everyone[0]["race_progress"])
	var usual_progress := elapsed * distance / typical_s
	out.append(clampf((leader_progress / maxf(usual_progress, 1.0) - 1.0) * 5.0, -1.0, 1.0) if elapsed > 5.0 else 0.0)
	var front_speed := 0.0
	for r: Dictionary in groups[0]:
		front_speed += float(r["speed"])
	out.append(front_speed / float((groups[0] as Array).size()) / speed_scale)
	out.append(clampf((leader_progress - float(everyone[everyone.size() - 1]["race_progress"])) / gap_scale, 0.0, 1.0))
	out.append_array(_group_slot(me, groups))
	# 自分の値
	var heart_min := LocalRaceMath.Config.number("heart_rate_min_bpm")
	var heart_max := LocalRaceMath.Config.number("heart_rate_overheat_max_bpm")
	var draft: Dictionary = me["draft"]
	out.append(float(me["drive_level"]) / LocalRaceMath.DRIVE_LEVEL_MAX)
	out.append(_heart(float(me["heart_rate_bpm"]), heart_min, heart_max))
	out.append(float(me["stamina_ratio"]))
	out.append(float(me["speed"]) / speed_scale)
	out.append(float(me["actual_speed_kmh"]) / speed_scale)
	out.append(float(s["line_m"]) / TrackMath.MAX_ABS_OFFSET_M)
	out.append(float(me["boost_uses_left"]) / LocalRaceMath.Config.number("boost_max_uses"))
	out.append(1.0 if bool(me["dash_active"]) else 0.0)
	out.append(1.0 if float(me["boost_points"]) > 0.0 else 0.0)
	out.append(float(draft["received_draft_p"]))
	out.append(float(draft["effective_draft_ratio"]))
	out.append(1.0 if bool(me["in_push_contest"]) else 0.0)
	out.append(1.0 if float(me["contact_heart_load_bpm_per_s"]) > 0.0 else 0.0)
	out.append(float(me["overheat_ratio"]))
	out.append(float(me["overheat_propulsion_efficiency"]))
	out.append(float(me["propulsion_efficiency"]))
	out.append(1.0 if bool(me["braking"]) else 0.0)
	# 自分の能力（レース前の値と、順位と区間で変わる実際の値）、属性、脚質、トレーナーの性格
	out.append_array(_runner_block(me))
	out.append_array(_frame(str(me["id"])))
	# ほかの走者：前を走る順に。
	var my_id := str(me["id"])
	var sorted_others: Array = others.duplicate()
	sorted_others.sort_custom(func(a, b): return float(a["race_progress"]) > float(b["race_progress"]))
	for i in field - 1:
		if i >= sorted_others.size():
			out.append(0.0)
			out.append(1.0)
			for k in _other_size() - 2:
				out.append(0.0)
			continue
		var o: Dictionary = sorted_others[i]
		var od: Dictionary = o["draft"]
		out.append(1.0)
		out.append(_gap(float(o["race_progress"]) - progress, gap_scale))
		out.append(-inside * float(o["offset"]) / TrackMath.MAX_ABS_OFFSET_M)
		out.append(float(o["speed"]) / speed_scale)
		out.append(float(o["stamina_ratio"]))
		out.append(_heart(float(o["heart_rate_bpm"]), heart_min, heart_max))
		out.append(float(o["boost_uses_left"]) / LocalRaceMath.Config.number("boost_max_uses"))
		out.append(1.0 if bool(o["dash_active"]) else 0.0)
		out.append(1.0 if float(o["boost_points"]) > 0.0 else 0.0)
		out.append(float(od["received_draft_p"]))
		out.append(float(od["effective_draft_ratio"]))
		# 自分の後ろについているか。
		out.append(1.0 if str(od.get("primary_source_id", "")) == my_id else 0.0)
		out.append(1.0 if bool(o["in_push_contest"]) else 0.0)
		out.append(1.0 if float(o["contact_heart_load_bpm_per_s"]) > 0.0 else 0.0)
		out.append_array(_runner_block(o))
	return out


## 選べる操作（ACTION_SIZES の順に並べた、選べる＝1・選べない＝0）。ゲームが受け付けない操作だけを外す。
## level＝今のノッチの段（ブレーキ中の記録では分からないので -1 を渡すと、ノッチはどれも選べる）。
static func mask_from(me: Dictionary, level: float, inside: float) -> PackedByteArray:
	var line := -inside * float(me["offset"])
	var limit := TrackMath.MAX_ABS_OFFSET_M - 0.01
	var braking := bool(me["braking"])
	# ダッシュ・ブーストは、ノッチが0・ブレーキ中は受け付けない（ゲームの決まり）。
	var can_act := level != 0.0 and not braking
	var out := PackedByteArray()
	if level < 0.0:
		out.append_array([1, 1, 1])
	else:
		out.append_array([1 if level > LocalRaceMath.DRIVE_LEVEL_MIN else 0, 1, 1 if level < LocalRaceMath.DRIVE_LEVEL_MAX else 0])
	out.append_array([1 if line > -limit else 0, 1, 1 if line < limit else 0])
	out.append_array([1, 1])
	out.append_array([1, 1 if can_act else 0])
	out.append_array([1, 1 if can_act and int(me["boost_uses_left"]) > 0 else 0])
	return out


## その距離の、ふつうのゴールのタイム（rl_settings の observe.typical_finish_s から、距離で直線に引いて出す）。
static func typical_finish_s(distance_m: float, scales: Dictionary) -> float:
	var table: Dictionary = scales["typical_finish_s"]
	var points: Array = []
	for key: String in table:
		points.append(Vector2(float(key), float(table[key])))
	points.sort_custom(func(a, b): return a.x < b.x)
	if distance_m <= points[0].x:
		return points[0].y * distance_m / points[0].x
	for i in range(1, points.size()):
		if distance_m <= points[i].x:
			var t: float = (distance_m - points[i - 1].x) / (points[i].x - points[i - 1].x)
			return lerpf(points[i - 1].y, points[i].y, t)
	var last: Vector2 = points[points.size() - 1]
	return last.y * distance_m / last.x


## 記録の1体ぶんを、lab_situation が読む名前にそろえる（記録と走っている走者で、ドライブの段の名前が同じ）。
static func _situation_record(r: Dictionary) -> Dictionary:
	return {
		"race_progress": r["race_progress"], "offset": r["offset"], "speed": r["speed"], "actual_speed_kmh": r["actual_speed_kmh"],
		"heart_rate_bpm": r["heart_rate_bpm"], "stamina_ratio": r["stamina_ratio"], "drive_level": r["drive_level"],
		"boost_uses_left": r["boost_uses_left"], "dash_active": r["dash_active"],
	}


## 前から順に並んだ全員を、間が group_gap_m より開いた所で組に分ける。
static func _groups(everyone: Array, group_gap_m: float) -> Array:
	var groups: Array = [[everyone[0]]]
	for i in range(1, everyone.size()):
		if float(everyone[i - 1]["race_progress"]) - float(everyone[i]["race_progress"]) > group_gap_m:
			groups.append([])
		(groups[groups.size() - 1] as Array).append(everyone[i])
	return groups


## 自分が、組の前・中・後ろ・ひとりのどこか。
static func _group_slot(me: Dictionary, groups: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(GROUP_SLOTS)
	out.fill(0.0)
	for group: Array in groups:
		var index := group.find(me)
		if index < 0:
			continue
		if group.size() == 1:
			out[3] = 1.0
		elif index == 0:
			out[0] = 1.0
		elif index == group.size() - 1:
			out[2] = 1.0
		else:
			out[1] = 1.0
	return out


## 1体の、レース前の能力（パドックで見える値）・実際の能力・属性・脚質。
static func _runner_block(r: Dictionary) -> PackedFloat32Array:
	var info := _info(str(r["id"]))
	var stat_max := float(StatsConfig.values()["race_effective_max"])
	var out := PackedFloat32Array()
	var live: Dictionary = r["effective_stats"]
	for id: String in StatsConfig.values()["stat_ids"]:
		out.append(float((info["stats"] as Dictionary)[id]) / stat_max)
	for id: String in StatsConfig.values()["stat_ids"]:
		out.append(float(live.get(id, 0)) / stat_max)
	out.append_array(info["attribute"])
	out.append_array(info["style"])
	return out


static func _info(runner_id: String) -> Dictionary:
	var id := runner_id.split("#")[0]
	if _runner_info.has(id):
		return _runner_info[id]
	var pururin := PururinRosterConfig.pururin_by_id(id)
	var attrs: Array = (StatsConfig.values()["attributes"] as Dictionary).keys()
	var attribute := PackedFloat32Array()
	attribute.resize(attrs.size())
	attribute.fill(0.0)
	attribute[attrs.find(str(pururin["attribute"]))] = 1.0
	var style := PackedFloat32Array()
	style.resize(StatsMath.rank_group_count())
	style.fill(0.0)
	style[StatsMath.style_rank_group_index(str(pururin["running_style"]))] = 1.0
	var info := {
		"stats": StatsMath.pre_race_stats(str(pururin["attribute"]), pururin["allocation"]),
		"attribute": attribute, "style": style, "trainer_id": str(pururin.get("trainer_id", "")),
	}
	_runner_info[id] = info
	return info


## そのぷるりんのトレーナーの性格の数字（lab/trainer_styles.json の frame）。無ければ空。
static func trainer_frame(runner_id: String) -> Dictionary:
	var trainer_id := str(_info(runner_id)["trainer_id"])
	var text := FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join(TRAINER_STYLES_PATH))
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if data is Dictionary and (data["trainers"] as Dictionary).has(trainer_id):
		return data["trainers"][trainer_id].get("frame", {})
	return {}


## トレーナーの性格の数字を、並びにしたもの。無ければ0を並べる。
static func _frame(runner_id: String) -> PackedFloat32Array:
	var trainer_id := str(_info(runner_id)["trainer_id"])
	if _frames.has(trainer_id):
		return _frames[trainer_id]
	var frame := trainer_frame(runner_id)
	var out := PackedFloat32Array()
	for key: Array in FRAME_KEYS:
		var name := str(key[0])
		var scale := float(key[1])
		var value: Variant = frame.get(name, frame.get("place", [0, 0]) if name == "late_place" else null)
		if name in ["retake", "hold", "follow_only_within_place"]:
			out.append(float(value) / scale if value != null else 0.0)
		else:
			var pair: Array = value if value is Array else [0, 0]
			out.append(float(pair[0]) / scale)
			out.append(float(pair[1]) / scale)
	_frames[trainer_id] = out
	return out


static func _gap(gap_m: float, scale: float) -> float:
	if is_inf(gap_m):
		return 1.0 if gap_m > 0.0 else -1.0
	return clampf(gap_m / scale, -1.0, 1.0)


static func _heart(bpm: float, low: float, high: float) -> float:
	return clampf((bpm - low) / maxf(high - low, 1.0), 0.0, 1.0)
