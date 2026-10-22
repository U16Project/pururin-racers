extends RefCounted
## CPU育成ラボ：頭が見る、今の状況（そのままの単位：m・bpm・km/h）。
## ラインは「内側がマイナス、外側がプラス」のm（コースの向きによらず同じ）。

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


static func read(runner: Node3D, runners: Array, curve: Curve3D, route: Dictionary, inside: float, now_s: float) -> Dictionary:
	var snap: Dictionary = runner.call("get_telemetry_snapshot")
	var distance_m := float(runner.call("get_race_distance"))
	var progress := float(snap["race_progress"])
	var s := {
		"now_s": now_s,
		"distance_m": distance_m,
		"progress_m": progress,
		"remaining_m": maxf(distance_m - progress, 0.0),
		"notch": int(round(float(runner.call("get_drive_level")))),
		"heart_bpm": float(snap["heart_rate_bpm"]),
		"stamina": float(snap["stamina_ratio"]),
		"speed_kmh": float(snap["speed"]),
		"actual_speed_kmh": float(snap["actual_speed"]),
		"line_m": -inside * float(snap["offset"]),
		"line_max_m": TrackMath.MAX_ABS_OFFSET_M,
		"corner_now": _is_corner(curve, route, progress),
		"corner_ahead": _is_corner(curve, route, progress + LOOK_AHEAD_M),
		"boost_left": int(snap["boost_uses_left"]),
		"dash_active": bool(runner.call("is_dash_active")),
	}
	# 順位と、前の走者：すぐ前（ラインに関係なく、いちばん近い前）と、同じラインのすぐ前。
	var line := float(s["line_m"])
	var better := 0
	var ahead: Node3D = null
	var ahead_gap := INF
	var lane: Node3D = null
	var lane_gap := INF
	for other: Node3D in runners:
		if other == runner:
			continue
		var gap := float(other.call("get_race_progress")) - progress
		if gap <= 0.001:
			continue
		better += 1
		if gap < ahead_gap:
			ahead_gap = gap
			ahead = other
		if absf(-inside * float(other.call("get_offset")) - line) < SAME_LINE_M and gap < lane_gap:
			lane_gap = gap
			lane = other
	s["place_ratio"] = float(better) / maxf(float(runners.size() - 1), 1.0)
	s["has_ahead"] = ahead != null
	s["ahead_gap_m"] = ahead_gap
	s["ahead_line_m"] = -inside * float(ahead.call("get_offset")) if ahead != null else 0.0
	s["has_lane_ahead"] = lane != null
	s["lane_ahead_gap_m"] = lane_gap
	s["lane_ahead_line_m"] = -inside * float(lane.call("get_offset")) if lane != null else 0.0
	return s


static func _is_corner(curve: Curve3D, route: Dictionary, progress: float) -> bool:
	var pose := CourseBuilder.route_pose(curve, route, progress, LocalRaceMath.lap_length_m())
	if pose.is_empty() or bool(pose.get("is_straight", false)):
		return false
	return absf(TrackMath.curvature_at(curve, float(pose["mainline_distance"]))) > 0.0005
