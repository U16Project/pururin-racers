extends Control
## Codex案。単独のプレビューと、将来のレース接続の両方で使える表示部品。
## update_state のキーは local_race_controller のHUDデータと共通。

const Painter := preload("res://scripts/presentation/hud_painter.gd")
const Hud := preload("res://scripts/presentation/race_hud.gd")
const Detail := preload("res://scripts/menu/pururin_detail.gd")
const FitText := preload("res://scripts/presentation/fit_text.gd")
const BASE_SIZE := Vector2(698, 555)
# con2.pngと同じ座標。下書きと1:1で重ねて配置を確認できる。
const HEART_CENTER := Vector2(288, 322)
const RING_CENTER := Vector2(282, 305)
const RING_RADII := Vector2(110, 112)
const STAMINA_CENTER := Vector2(274, 302)
const STAMINA_RADII := Vector2(128, 128)
const SPEED_FULL_KMH := 110.0
const HEART_UNIT := 5.4
const WHITE := Color("f4fbff")
const YELLOW := Color("ffe435")
const CYAN := Color("39e7ff")
const PINK := Color("ff279a")
const DARK := Color(0.015, 0.035, 0.065, 0.92)
const TRACK := Color(0.09, 0.16, 0.22, 0.75)
const EDGE := Color(0.55, 0.73, 0.85, 0.44)
const NOTCH_COLORS := [Color("35e3fa"), Color("34eb80"), Color("b0f33c"), Color("ffe936"), Color("ff9b30"), Color("ff3c68")]

var _p := Painter.new()
var _bold: FontVariation
var _italic: FontFile
var _label_font: FontFile
var _scale_factor := 1.0
var _heart_shape := PackedVector2Array()
var _state: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bold = FontVariation.new()
	_bold.base_font = get_theme_default_font()
	_bold.variation_embolden = 0.35
	_italic = FontFile.new()
	_italic.data = FileAccess.get_file_as_bytes("res://test/manual/codex_hud/DejaVuSansCondensed-Oblique.ttf")
	_label_font = FontFile.new()
	_label_font.data = FileAccess.get_file_as_bytes("res://test/manual/codex_hud/DejaVuSansCondensed.ttf")
	for i in 128:
		var t := TAU * float(i) / 128.0
		_heart_shape.append(HEART_CENTER + Vector2(16.0 * pow(sin(t), 3), (-(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)) - 2.0) * 1.16) * HEART_UNIT)
	set_scale_factor(_scale_factor)


func set_scale_factor(value: float) -> void:
	_scale_factor = maxf(value, 0.1)
	custom_minimum_size = BASE_SIZE * _scale_factor
	size = custom_minimum_size
	queue_redraw()


func update_state(values: Dictionary) -> void:
	_state.merge(values, true)
	queue_redraw()


func _v(key: String) -> float:
	return float(_state.get(key, 0.0))


func _line(points: PackedVector2Array, color: Color, width: float) -> void:
	_p.draw_polyline(Transform2D(0, Vector2.ONE * _scale_factor, 0, Vector2.ZERO) * points, color, width * _scale_factor, true)


func _polygon(points: PackedVector2Array, color: Color) -> void:
	_p.draw_colored_polygon(Transform2D(0, Vector2.ONE * _scale_factor, 0, Vector2.ZERO) * points, color)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	result.append(points[0])
	return result


func _plate(rect: Rect2, slant: float = 16.0) -> void:
	# 文字の下には小さな札を並べない。BPMの帯だけに使う。
	var corners := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	_polygon(_rounded_polygon(corners, slant * 0.5), DARK)


func _rounded_polygon(corners: PackedVector2Array, radius: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in corners.size():
		var previous := corners[(i + corners.size() - 1) % corners.size()]
		var corner := corners[i]
		var next := corners[(i + 1) % corners.size()]
		var amount := minf(radius, minf(corner.distance_to(previous), corner.distance_to(next)) * 0.35)
		var enter := corner.move_toward(previous, amount)
		var leave := corner.move_toward(next, amount)
		for step in 9:
			var t := float(step) / 8
			result.append(enter * pow(1 - t, 2) + corner * (2 * t * (1 - t)) + leave * t * t)
	return result


func _text(at: Vector2, value: String, px: int, color: Color = WHITE, italic: bool = false) -> float:
	var font: Font = _italic if italic else _label_font
	var font_size := maxi(roundi(px * _scale_factor), 6)
	_p.glyphs.add(font, value, font_size, at * _scale_factor, color, maxi(roundi(_scale_factor * 2), 1), DARK)
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / _scale_factor


func _arc(from_deg: float, to_deg: float, center: Vector2 = RING_CENTER, radii: Vector2 = RING_RADII) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 101:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / 100.0) - 90.0)
		points.append(center + Vector2(cos(a), sin(a)) * radii)
	return points


func _track(points: PackedVector2Array, width: float) -> void:
	_polygon(_stroke(points, width + 5)[0], Color(0.01, 0.025, 0.04, 0.65))
	_polygon(_stroke(points, width + 1.2)[0], Color(EDGE, 0.30))
	_polygon(_stroke(points, width)[0], Color("1c3040"))


## 輪の端を、別の丸の重ね塗りではなく一続きの輪郭にする。
func _stroke(path: PackedVector2Array, width: float) -> Array:
	var shape := PackedVector2Array()
	var ratios := PackedFloat32Array()
	var normals := PackedVector2Array()
	for i in path.size():
		var tangent := path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
		normals.append(tangent.normalized().orthogonal())
	for i in path.size():
		shape.append(path[i] + normals[i] * width * 0.5)
		ratios.append(float(i) / maxf(path.size() - 1, 1))
	for i in range(1, 13):
		shape.append(path[-1] + normals[-1].rotated(PI * i / 12) * width * 0.5)
		ratios.append(1)
	for i in range(path.size() - 2, -1, -1):
		shape.append(path[i] - normals[i] * width * 0.5)
		ratios.append(float(i) / maxf(path.size() - 1, 1))
	for i in range(1, 12):
		shape.append(path[0] - normals[0].rotated(PI * i / 12) * width * 0.5)
		ratios.append(0)
	return [shape, ratios]


func _portion(path: PackedVector2Array, from_ratio: float, to_ratio: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var start := clampf(from_ratio, 0, 1) * (path.size() - 1)
	var end := clampf(to_ratio, 0, 1) * (path.size() - 1)
	if end <= start:
		return points
	points.append(path[floori(start)].lerp(path[mini(floori(start) + 1, path.size() - 1)], fposmod(start, 1.0)))
	for i in range(floori(start) + 1, ceili(end)):
		points.append(path[i])
	points.append(path[floori(end)].lerp(path[mini(floori(end) + 1, path.size() - 1)], fposmod(end, 1.0)))
	return points


func _lit(path: PackedVector2Array, color: Color, width: float) -> void:
	_gradient(path, width, func(_t: float) -> Color: return color)


func _gradient(path: PackedVector2Array, width: float, color_at: Callable) -> void:
	if path.size() < 2:
		return
	_polygon(_stroke(path, width + 6)[0], Color(color_at.call(0.5), 0.07))
	var normals := PackedVector2Array()
	for i in path.size():
		normals.append((path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized().orthogonal() * width * 0.5)
	var transform := Transform2D(0, Vector2.ONE * _scale_factor, 0, Vector2.ZERO)
	for i in path.size() - 1:
		var first: Color = color_at.call(float(i) / (path.size() - 1))
		var next: Color = color_at.call(float(i + 1) / (path.size() - 1))
		_p.draw_polygon(transform * PackedVector2Array([path[i] + normals[i], path[i + 1] + normals[i + 1], path[i + 1] - normals[i + 1], path[i] - normals[i]]), PackedColorArray([first, next, next, first]))
	for end in [0, path.size() - 1]:
		var cap := PackedVector2Array([path[end]])
		for i in 17:
			cap.append(path[end] + normals[end].rotated(PI * float(i) / 16 + (PI if end == 0 else 0.0)))
		_polygon(cap, color_at.call(0.0 if end == 0 else 1.0))
	# 片側だけの細いハイライト。厚みを加えすぎず線を滑らかにする。
	var shine := PackedVector2Array()
	for i in path.size():
		var tangent := path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]
		shine.append(path[i] + tangent.normalized().orthogonal() * (width * 0.5 - 3.0))
	_line(shine, Color(WHITE, 0.3), 1.2)


func _draw() -> void:
	if _bold == null:
		return
	_p.begin(self)
	_p.glyphs.oversampling = get_viewport().get_oversampling()
	# 明るい芝・砂の上でも読める一枚の薄い地。文字別の札は置かない。
	var backing := PackedVector2Array([Vector2(28, 45), Vector2(642, 45), Vector2(642, 526), Vector2(28, 526)])
	_polygon(_rounded_polygon(backing, 16), Color(0.025, 0.055, 0.085, 0.54))
	_draw_header()
	_draw_speed()
	_draw_aero()
	_draw_stamina()
	_draw_notch()
	_draw_boost()
	_draw_dash()
	_draw_heart()
	_p.flush()
	# 属性と脚質はゲーム内の正式な図形を使う。
	if not str(_state.get("attribute_id", "")).is_empty():
		Detail.draw_attribute_mark(self, Vector2(445, 88) * _scale_factor, 28.0 * _scale_factor, str(_state["attribute_id"]), _state.get("attribute_color", Color("ff3769")))
	Hud.draw_style_chevrons(self, Vector2(486, 88) * _scale_factor, Hud.style_state_color(int(_state.get("style_rank_bonus", 0))), int(_state.get("style_group_count", 3)), int(_state.get("style_group_index", 0)), 2.0 * _scale_factor)


func _draw_header() -> void:
	# 下書きの上の行。区切り線や枠は加えない。
	var name_text := str(_state.get("player_name", "")) + "（%s）" % str(_state.get("trainer_name", ""))
	var fitted := FitText.fit(_bold, name_text, 249, 26)
	# 文字の幅が変わっても、固定幅の名札と属性は動かさない。
	_p.glyphs.add(_bold, fitted.text, maxi(roundi(float(fitted.font_size) * _scale_factor), 6), Vector2.ZERO, WHITE, 1, DARK, Transform2D(0, Vector2(fitted.x_scale, 1), 0, Vector2(172, 101) * _scale_factor))


func _draw_speed() -> void:
	var path := _arc(226, 341)
	_track(path, 17)
	var ratio := clampf(_v("speed_kmh") / SPEED_FULL_KMH, 0, 1)
	_gradient(_portion(path, 0, ratio), 17, func(t: float) -> Color: return Color("4b77df").lerp(CYAN, t * ratio))
	_text(Vector2(268, 151), "Speed", 24, WHITE, true)
	var width := _text(Vector2(257, 207), str(roundi(_v("speed_kmh"))), 49, YELLOW, true)
	_text(Vector2(263 + width, 205), "km/h", 18)


func _draw_aero() -> void:
	var path := PackedVector2Array()
	for i in 81:
		var t := float(i) / 80
		path.append(Vector2(150, 394).bezier_interpolate(Vector2(121, 356), Vector2(107, 291), Vector2(100, 258), t))
	_track(path, 22)
	var green := maxf(_v("air_green"), 0.0)
	var blue := maxf(_v("air_blue"), 0.0)
	var total := green + blue
	var scale_max := maxf(total, 1.0)
	_gradient(_portion(path, 0, total / scale_max), 22, func(t: float) -> Color: return Color("46ebad") if t * total <= green else Color("3ba5ff"))
	# 100%を超えても数字を丸め込まない。
	_text(Vector2(66, 196), "aero", 24, WHITE, true)
	var width := _text(Vector2(70, 246), str(roundi(total * 100)), 45 if total < 1 else 38, YELLOW, true)
	_text(Vector2(75 + width, 244), "%", 19)


func _draw_stamina() -> void:
	var path := _arc(160, 62, STAMINA_CENTER, STAMINA_RADII)
	_track(path, 20)
	var fuel := clampf(_v("fuel_ratio"), -1, 1)
	_gradient(_portion(path, 0, maxf(fuel, 0)), 20, func(t: float) -> Color: return Hud.fuel_color(t * maxf(fuel, 0)))
	var debt := _arc(172, 163, STAMINA_CENTER, STAMINA_RADII)
	_track(debt, 20)
	if fuel < 0:
		_lit(_portion(debt, 1.0 + fuel, 1.0), Hud.COLOR_DANGER, 20)
	var at := path[0]
	var direction := (at - STAMINA_CENTER).normalized()
	_line(PackedVector2Array([at - direction * 16, at + direction * 16]), WHITE, 3)
	_text(at + Vector2(15, 20), "0", 14, WHITE, false)
	_text(Vector2(202, 454), "Stamina", 24, WHITE, true)
	var width := _text(Vector2(211, 494), str(roundi(fuel * 100)), 44, YELLOW if fuel >= 0 else Hud.COLOR_DANGER, true)
	_text(Vector2(217 + width, 492), "%", 18)


func notch_shape(level: int, maximum: int) -> PackedVector2Array:
	var t := float(level - 1) / maxf(maximum - 1, 1)
	var left := lerpf(354, 428, pow(t, 0.65))
	var top := lerpf(394, 194, t)
	var width := lerpf(53, 145, pow(t, 1.3))
	var height := minf(29, 200.0 / maxf(maximum - 1, 1) - 7)
	var left_top := left + 16.0
	var left_bottom := left
	# 体力の弧の外周から12px離す。下書きの配置を保ち、塗り同士の重なりを避ける。
	for edge in [0, 1]:
		var y := top + (height if edge == 1 else 0.0)
		if y >= 240 and y <= 424:
			var delta_y := y - STAMINA_CENTER.y
			var boundary := STAMINA_CENTER.x + sqrt(maxf(pow(STAMINA_RADII.x, 2) - delta_y * delta_y, 0)) + 22.0
			if edge == 0:
				left_top = maxf(left_top, boundary)
			else:
				left_bottom = maxf(left_bottom, boundary)
	# 棒の左辺の傾きも揃える。個別の角だけを押すと、不規則な台形になるため。
	left_bottom = maxf(left_bottom, left_top - 16)
	left_top = left_bottom + 16
	return _rounded_polygon(PackedVector2Array([Vector2(left_top, top), Vector2(left + width + 16, top), Vector2(left + width, top + height), Vector2(left_bottom, top + height)]), 4)


func _draw_notch() -> void:
	var maximum := maxi(int(_state.get("notch_max", 6)), 1)
	var notch := clampi(int(_state.get("notch", 1)), 1, maximum)
	for level in range(1, maximum + 1):
		var shape := notch_shape(level, maximum)
		var color: Color = NOTCH_COLORS[clampi(roundi(float(level - 1) / maxf(maximum - 1, 1) * 5), 0, 5)]
		_polygon(shape, color if level <= notch else TRACK)
		_line(_closed(shape), Color(color.lightened(0.6), 0.7) if level <= notch else EDGE, 1.5)
		if level <= notch:
			var shine := _portion(shape.slice(0, 13), 0, 1)
			_line(shine, Color(WHITE, 0.35), 1.5)
		if level == notch:
			_line(_closed(shape), Color(WHITE, 0.65), 2)
	_text(Vector2(436, 181), "Notch", 24, WHITE, true)
	_text(Vector2(526, 182), str(notch), 49, YELLOW, true)
	if bool(_state.get("braking", false)):
		_text(Vector2(434, 240), "BRAKE", 17, Hud.COLOR_DANGER)


func _draw_boost() -> void:
	var maximum := maxi(int(_state.get("boost_max_uses", 3)), 1)
	var left := clampi(int(_state.get("boost_uses_left", 0)), 0, maximum)
	var active := clampf(_v("boost_ratio"), 0, 1)
	for i in maximum:
		var at := Vector2(453, 429) + Vector2(43, -67) * float(i) * 3.0 / maximum
		var shape := _rounded_polygon(PackedVector2Array([at, at + Vector2(19, 0), at + Vector2(48, -53), at + Vector2(29, -53)]), 3)
		var fill := 1.0 if i < left else (active if i == left else 0.0)
		_polygon(shape, TRACK)
		if fill > 0:
			var end := at + Vector2(29, -53) * fill
			_polygon(_rounded_polygon(PackedVector2Array([at, at + Vector2(19, 0), end + Vector2(19, 0), end]), minf(3, fill * 3)), Hud.COLOR_BOOST)
		_line(_closed(shape), Hud.COLOR_BOOST.lightened(0.3) if fill > 0 else EDGE, 2)
	_text(Vector2(416, 464), "Boost", 24, WHITE, true)
	_text(Vector2(422, 505), "(%d)" % left, 25)
	_button(Vector2(488, 496), "X", Color("55aaff"))


func _draw_dash() -> void:
	var path := PackedVector2Array()
	for i in 65:
		var t := float(i) / 64
		path.append(Vector2(548, 391).bezier_interpolate(Vector2(560, 360), Vector2(577, 305), Vector2(584, 287), t))
	_track(path, 22)
	_lit(_portion(path, 0, clampf(_v("dash_ratio"), 0, 1)), CYAN, 22)
	_text(Vector2(538, 428), "Dash", 24, WHITE, true)
	_text(Vector2(538, 464), "(∞)", 25)
	_button(Vector2(613, 455), "B", Color("ff5e67"))


func _button(at: Vector2, label: String, color: Color) -> void:
	var path := PackedVector2Array()
	for i in 33:
		path.append(at + Vector2.RIGHT.rotated(TAU * i / 32) * 12)
	_polygon(path, DARK)
	_line(path, color, 2)
	_text(at + Vector2(-6, 6), label, 16, color, false)


func _clip_heart(from_y: float, to_y: float, color: Color) -> void:
	var rectangle := PackedVector2Array([Vector2(195, from_y), Vector2(380, from_y), Vector2(380, to_y), Vector2(195, to_y)])
	for polygon: PackedVector2Array in Geometry2D.intersect_polygons(_heart_shape, rectangle):
		if polygon.size() >= 3:
			_polygon(polygon, color)


func _draw_heart() -> void:
	var outline := _closed(_heart_shape)
	_line(outline, Color(PINK, 0.06), 19)
	_line(outline, Color(PINK, 0.14), 11)
	_polygon(_heart_shape, Color(0.025, 0.065, 0.12, 0.80))
	var low := float(_state.get("heart_min_bpm", 100))
	var high := float(_state.get("heart_max_bpm", 230))
	var normal := float(_state.get("heart_normal_max_bpm", 200))
	var fill := clampf((_v("heart_bpm") - low) / maxf(high - low, 1), 0, 1)
	var bounds := Rect2(_heart_shape[0], Vector2.ZERO)
	for point in _heart_shape:
		bounds = bounds.expand(point)
	var level := lerpf(bounds.end.y, bounds.position.y, fill)
	var water := CYAN if _v("heart_bpm") <= normal - 20 else Hud.COLOR_WARN.lerp(Hud.COLOR_DANGER, clampf((_v("heart_bpm") - normal + 20) / maxf(high - normal + 20, 1), 0, 1))
	_clip_heart(level, bounds.end.y + 1, water)
	for i in 30:
		var y := lerpf(bounds.position.y, bounds.end.y, float(i) / 30)
		_clip_heart(y, y + 1, Color(WHITE, 0.23) if y >= level else Color(WHITE, 0.035))
	_clip_heart(level, minf(level + 2, bounds.end.y), water.lightened(0.65))
	_line(outline, PINK, 4)
	var beat := clampf(1.0 - float(_state.get("heart_beat_phase", 1)) / 0.4, 0, 1)
	_line(outline, Color(WHITE, beat * 0.6), 1.3)
	# BPM帯も角を丸め、数字の幅に合わせてハート内に収める。
	_plate(Rect2(229, 297, 123, 38), 8)
	var width := _text(Vector2(236, 329), str(roundi(_v("heart_bpm"))), 39, WHITE, true)
	_text(Vector2(238 + width, 327), "bpm", 13)
