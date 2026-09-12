extends RefCounted
## M5 wire 定義から描画用 Curve3D とルート変換を生成する。
## 判定の正本は shared/course_layout_m5.json の解析的な区間定義。

const COURSE_JSON := "res://data/course_layout_m5.json"
const QUARTER_CIRCLE_KAPPA := 0.5522847498

static func load_layout() -> Dictionary:
	var file := FileAccess.open(COURSE_JSON, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func route_for_distance(layout: Dictionary, distance_m: float) -> Dictionary:
	for route in layout.get("routes", []):
		if is_equal_approx(float(route.get("distance_m", 0.0)), distance_m):
			return route
	return {}

static func make_racecourse_curve(
	straight_len: float,
	turn_radius: float,
	_bake_interval: float = 1.0
) -> Curve3D:
	var curve := Curve3D.new()
	var half_s := straight_len * 0.5
	var r := turn_radius
	var kappa := QUARTER_CIRCLE_KAPPA * r
	var third_s := straight_len / 3.0
	var br := Vector3(half_s, 0.0, -r)
	var bl := Vector3(-half_s, 0.0, -r)
	var lm := Vector3(-half_s - r, 0.0, 0.0)
	var tl := Vector3(-half_s, 0.0, r)
	var tr := Vector3(half_s, 0.0, r)
	var rm := Vector3(half_s + r, 0.0, 0.0)
	curve.add_point(br, -_arc_travel(-PI * 0.5) * kappa, Vector3(-third_s, 0.0, 0.0))
	curve.add_point(bl, Vector3(third_s, 0.0, 0.0), _arc_travel(-PI * 0.5) * kappa)
	curve.add_point(lm, -_arc_travel(-PI) * kappa, _arc_travel(-PI) * kappa)
	curve.add_point(tl, -_arc_travel(-PI * 1.5) * kappa, Vector3(third_s, 0.0, 0.0))
	curve.add_point(tr, Vector3(-third_s, 0.0, 0.0), _arc_travel(PI * 0.5) * kappa)
	curve.add_point(rm, -_arc_travel(0.0) * kappa, _arc_travel(0.0) * kappa)
	curve.closed = true
	curve.bake_interval = _bake_interval
	return curve

static func _arc_travel(theta: float) -> Vector3:
	return Vector3(sin(theta), 0.0, -cos(theta))

static func route_mainline_distance(
	route: Dictionary, route_distance_m: float, track_length_m: float
) -> float:
	var start := float(route.get("start_mainline_m", 0.0))
	var remaining := maxf(route_distance_m, 0.0)
	var segments: Array = route.get("segments", [])
	for segment in segments:
		var length := float(segment.get("distance_m", 0.0))
		var consumed := minf(remaining, length)
		if str(segment.get("type", "")) == "mainline":
			return fposmod(start + consumed, track_length_m)
		remaining -= consumed
		if remaining <= 0.0:
			return fposmod(start, track_length_m)
	return fposmod(start + route_distance_m, track_length_m)

static func route_offset_for_distance(
	route: Dictionary, route_distance_m: float, track_length_m: float
) -> float:
	var segments: Array = route.get("segments", [])
	var remaining := maxf(route_distance_m, 0.0)
	for segment in segments:
		var length := float(segment.get("distance_m", 0.0))
		if str(segment.get("type", "")) == "straight" and remaining < length:
			return remaining
		remaining -= minf(remaining, length)
		if remaining <= 0.0:
			break
	return route_mainline_distance(route, route_distance_m, track_length_m)
