extends RefCounted
## 育てたCPU（強化学習の頭）が見る、今の状況（そのままの単位：m・bpm・km/h）。brain_observe.gd が使う。
## ラインは「内側がマイナス、外側がプラス」のm（コースの向きによらず同じ）。
## 1体ぶん（record）は、走者の get_telemetry_snapshot() と同じ名前の項目を使う（記録ファイルの runners の1つも同じ形）。
## （CPU育成ラボの lab/lab_situation.gd から、頭が使う所だけを移したもの。計算は同じ。）

const TrackMath := preload("res://scripts/track_math.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const CourseBuilder := preload("res://scripts/course_builder.gd")

## 先を見る距離（m）。この先がコーナーかを見る。
const LOOK_AHEAD_M := 60.0
## 同じラインとみなす横の差（m・体の幅くらい）。
const SAME_LINE_M := 1.5


## コースの内側の向き（offset の符号）。楕円のコースなので、レースの最初に1回だけ調べる。
static func inside_sign(curve: Curve3D) -> float:
	var length := curve.get_baked_length()
	var best := 0.0
	var d := 0.0
	while d < length:
		var k := TrackMath.curvature_at(curve, d)
		if absf(k) > absf(best):
			best = k
		d += 5.0
	# offset を内側へ動かすと、進む距離が短くなる。
	return 1.0 if TrackMath.distance_multiplier(1.0, best) < TrackMath.distance_multiplier(-1.0, best) else -1.0


## me＝自分の1体ぶん、others＝ほかの全員の1体ぶん。
static func from_records(me: Dictionary, others: Array, distance_m: float, curve: Curve3D, route: Dictionary, inside: float, now_s: float) -> Dictionary:
	var progress := float(me["race_progress"])
	var line := -inside * float(me["offset"])
	var s := {
		"now_s": now_s,
		"distance_m": distance_m,
		"progress_m": progress,
		"remaining_m": maxf(distance_m - progress, 0.0),
		"notch": int(round(float(me["drive_level"]))),
		"heart_bpm": float(me["heart_rate_bpm"]),
		"stamina": float(me["stamina_ratio"]),
		"speed_kmh": float(me["speed"]),
		"actual_speed_kmh": float(me["actual_speed_kmh"]),
		"line_m": line,
		"line_max_m": TrackMath.MAX_ABS_OFFSET_M,
		"corner_now": _is_corner(curve, route, progress),
		"corner_ahead": _is_corner(curve, route, progress + LOOK_AHEAD_M),
		"boost_left": int(me["boost_uses_left"]),
		"dash_active": bool(me["dash_active"]),
	}
	# 順位と、前後の走者：すぐ前（ラインに関係なく、いちばん近い前）、同じラインのすぐ前、すぐ後ろ。
	var better := 0
	var ahead := {}
	var ahead_gap := INF
	var lane := {}
	var lane_gap := INF
	var behind_gap := INF
	for other: Dictionary in others:
		var gap := float(other["race_progress"]) - progress
		if gap <= 0.001:
			behind_gap = minf(behind_gap, -gap)
			continue
		better += 1
		if gap < ahead_gap:
			ahead_gap = gap
			ahead = other
		if absf(-inside * float(other["offset"]) - line) < SAME_LINE_M and gap < lane_gap:
			lane_gap = gap
			lane = other
	s["place"] = better + 1
	s["field"] = others.size() + 1
	s["place_ratio"] = float(better) / maxf(float(others.size()), 1.0)
	s["has_ahead"] = not ahead.is_empty()
	s["ahead_gap_m"] = ahead_gap
	s["ahead_line_m"] = -inside * float(ahead["offset"]) if not ahead.is_empty() else 0.0
	s["has_lane_ahead"] = not lane.is_empty()
	s["lane_ahead_gap_m"] = lane_gap
	s["lane_ahead_line_m"] = -inside * float(lane["offset"]) if not lane.is_empty() else 0.0
	s["behind_gap_m"] = behind_gap
	return s


static func _is_corner(curve: Curve3D, route: Dictionary, progress: float) -> bool:
	var pose := CourseBuilder.route_pose(curve, route, progress, LocalRaceMath.lap_length_m())
	if pose.is_empty() or bool(pose.get("is_straight", false)):
		return false
	return absf(TrackMath.curvature_at(curve, float(pose["mainline_distance"]))) > 0.0005
