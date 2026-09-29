extends RefCounted
## M5 wire 定義から描画用 Curve3D とルート変換を生成する。
## 判定の正本は shared/course_layout_m5.json の解析的な区間定義。

const COURSE_JSON := "res://data/course_layout_m5.json"
const QUARTER_CIRCLE_KAPPA := 0.5522847498
const REQUIRED_ROOT_KEYS := [
	"course_id", "track_length_m", "straight_length_m", "turn_radius_m",
	"turn_angle_rad", "goal_path_m", "goal_semantics", "routes",
]

static var _cached_result: Dictionary = {}
static var _attempted := false


## 互換用。既存呼び出しには検証済みのレイアウトだけを返す。
static func load_layout() -> Dictionary:
	var result := load_layout_result()
	return result.get("layout", {})


## 失敗を空の Dictionary と区別する。コントローラーは error を表示して開始を中止する。
static func load_layout_result() -> Dictionary:
	if not _attempted:
		_attempted = true
		_cached_result = load_file()
	return _cached_result


static func load_file(path: String = COURSE_JSON) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "%s: 読み込めません (%s)" % [path, FileAccess.get_open_error()]}
	return parse_text(file.get_as_text(), path)


static func parse_text(content: String, source: String = COURSE_JSON) -> Dictionary:
	var parser := JSON.new()
	if parser.parse(content) != OK:
		return {"error": "%s:%d: %s" % [source, parser.get_error_line(), parser.get_error_message()]}
	var errors := validate_layout(parser.data)
	if not errors.is_empty():
		return {"error": "%s: %s" % [source, "; ".join(errors)]}
	return {"layout": parser.data}


static func validate_layout(data: Variant) -> PackedStringArray:
	var errors := PackedStringArray()
	if not data is Dictionary:
		return PackedStringArray(["ルートはオブジェクトである必要があります"])
	for key in REQUIRED_ROOT_KEYS:
		if not data.has(key):
			errors.append("%s: 必須です" % key)
	if not errors.is_empty():
		return errors
	if not data.course_id is String or data.course_id.is_empty():
		errors.append("course_id: 空でない文字列が必要です")
	if not data.goal_semantics is String or data.goal_semantics.is_empty():
		errors.append("goal_semantics: 空でない文字列が必要です")
	for key in ["track_length_m", "straight_length_m", "turn_radius_m", "turn_angle_rad"]:
		var value: Variant = data.get(key)
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) <= 0.0:
			errors.append("%s: 正の有限数が必要です" % key)
	var goal: Variant = data.get("goal_path_m")
	if not (goal is float or goal is int) or not is_finite(float(goal)):
		errors.append("goal_path_m: 有限数が必要です")
	elif float(goal) < 0.0 or float(goal) >= float(data.track_length_m):
		errors.append("goal_path_m: 0 以上 track_length_m 未満にしてください")
	if data.routes is Array:
		_validate_routes(data.routes, float(data.track_length_m), errors)
	else:
		errors.append("routes: 配列が必要です")
	return errors


static func _validate_routes(routes: Array, track_length_m: float, errors: PackedStringArray) -> void:
	if routes.is_empty():
		errors.append("routes: 少なくとも 1 つ必要です")
		return
	var route_ids := {}
	var distances := {}
	for index in routes.size():
		var route: Variant = routes[index]
		var prefix := "routes[%d]" % index
		if not route is Dictionary:
			errors.append("%s: オブジェクトが必要です" % prefix)
			continue
		for key in ["route_id", "distance_m", "start_mainline_m", "segments"]:
			if not route.has(key):
				errors.append("%s.%s: 必須です" % [prefix, key])
		if not route.has("route_id") or not route.has("distance_m") or not route.has("start_mainline_m") or not route.has("segments"):
			continue
		if not route.route_id is String or route.route_id.is_empty():
			errors.append("%s.route_id: 空でない文字列が必要です" % prefix)
		elif route_ids.has(route.route_id):
			errors.append("%s.route_id: 重複しています" % prefix)
		else:
			route_ids[route.route_id] = true
		var distance: Variant = route.distance_m
		var start: Variant = route.start_mainline_m
		if not (distance is float or distance is int) or not is_finite(float(distance)) or float(distance) <= 0.0:
			errors.append("%s.distance_m: 正の有限数が必要です" % prefix)
		elif distances.has(float(distance)):
			errors.append("%s.distance_m: 重複しています" % prefix)
		else:
			distances[float(distance)] = true
		if not (start is float or start is int) or not is_finite(float(start)) or float(start) < 0.0 or float(start) >= track_length_m:
			errors.append("%s.start_mainline_m: 0 以上 track_length_m 未満の有限数が必要です" % prefix)
		if not route.segments is Array or route.segments.is_empty():
			errors.append("%s.segments: 空でない配列が必要です" % prefix)
			continue
		var segment_total := 0.0
		for segment_index in route.segments.size():
			var segment: Variant = route.segments[segment_index]
			var segment_prefix := "%s.segments[%d]" % [prefix, segment_index]
			if not segment is Dictionary:
				errors.append("%s: オブジェクトが必要です" % segment_prefix)
				continue
			var segment_type: Variant = segment.get("type")
			var segment_distance: Variant = segment.get("distance_m")
			if not segment_type is String or not segment_type in ["mainline", "straight"]:
				errors.append("%s.type: mainline または straight が必要です" % segment_prefix)
			if not (segment_distance is float or segment_distance is int) or not is_finite(float(segment_distance)) or float(segment_distance) <= 0.0:
				errors.append("%s.distance_m: 正の有限数が必要です" % segment_prefix)
			else:
				segment_total += float(segment_distance)
		if distance is float or distance is int:
			if is_finite(float(distance)) and not is_equal_approx(segment_total, float(distance)):
				errors.append("%s.segments: distance_m の合計と一致しません" % prefix)

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
		if remaining <= length:
			if str(segment.get("type", "")) == "mainline":
				return fposmod(start + remaining, track_length_m)
			return fposmod(start, track_length_m)
		if str(segment.get("type", "")) == "mainline":
			start = fposmod(start + length, track_length_m)
		remaining -= length
	# ゴール後の表示継続では route distance が定義長を超える。
	# その場合はルート終端から本線をそのまま進め、専用区間を再走しない。
	return fposmod(start + remaining, track_length_m)

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


## ルートの進行距離を描画用の位置へ変換する共通入口。
## 専用の直線区間も本線と同じ route distance 軸で扱い、物理式は呼び出し側で共通化する。
static func route_pose(
	curve: Curve3D,
	route: Dictionary,
	route_distance_m: float,
	track_length_m: float
) -> Dictionary:
	if curve == null or route.is_empty():
		return {}
	var progress := maxf(route_distance_m, 0.0)
	var segments: Array = route.get("segments", [])
	if not segments.is_empty() and str(segments[0].get("type", "")) == "straight":
		var launch_length := float(segments[0].get("distance_m", 0.0))
		if progress < launch_length:
			var start_distance := fposmod(float(route.get("start_mainline_m", 0.0)), track_length_m)
			var start_xf := curve.sample_baked_with_rotation(start_distance)
			# 専用スタート直線は本線の接続点から外側へ延ばす。
			# 外側方向は本線接線の逆側、進行方向は接続点へ向かう本線接線と同じにする。
			var outward_travel := start_xf.basis.z
			var travel := -outward_travel
			travel.y = 0.0
			if travel.length_squared() < 0.0001:
				travel = Vector3(0.0, 0.0, -1.0)
			else:
				travel = travel.normalized()
			var lateral := Vector3(-travel.z, 0.0, travel.x)
			var join_outward := lateral.normalized() if lateral.length_squared() >= 0.0001 else Vector3(0.0, 0.0, 1.0)
			return {
				"position": start_xf.origin + outward_travel * (launch_length - progress),
				"travel": travel,
				"outward": join_outward,
				"mainline_distance": start_distance,
				"curvature": 0.0,
				"is_straight": true,
			}
	var mainline_distance := route_mainline_distance(route, progress, track_length_m)
	var mainline_xf := curve.sample_baked_with_rotation(mainline_distance)
	var mainline_travel := -mainline_xf.basis.z
	mainline_travel.y = 0.0
	if mainline_travel.length_squared() < 0.0001:
		mainline_travel = Vector3(0.0, 0.0, -1.0)
	else:
		mainline_travel = mainline_travel.normalized()
	var mainline_lateral := Vector3(-mainline_travel.z, 0.0, mainline_travel.x)
	return {
		"position": mainline_xf.origin,
		"travel": mainline_travel,
		"outward": mainline_lateral.normalized() if mainline_lateral.length_squared() >= 0.0001 else Vector3(0.0, 0.0, 1.0),
		"mainline_distance": mainline_distance,
		"curvature": 0.0,
		"is_straight": false,
	}
