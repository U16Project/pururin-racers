extends Control
## レースの順位表（画面の左上、ハート型の操作盤の下）。
## 値は update_state() で受け取り、計算はここでは行わない（表示用の色だけ）。
## 色や印の描き方（脚質の印・王冠・メダル・体力の色）は、ほかの画面でも使う。

const FitText := preload("res://scripts/presentation/fit_text.gd")
const HudPainter := preload("res://scripts/presentation/hud_painter.gd")
## 体力の電池のうち、左から負債（マイナス）に使う割合。負債の全体（0〜限度）をこの長さで見せるので、プラス側より縮尺が小さい（減りが遅く見える）。
const FUEL_DEBT_ZONE_RATIO := 0.25
## 脚質の印「〈」の間隔。
const STYLE_CHEVRON_STEP := 10.0
## 脚質の印の、今いない所の色（明るい景色の上でも見えるよう、暗くする）。
## 光っていない脚質の「〈」：暗い地でも見えるように、うすい灰色（光っている方は、色と光で見分ける）。
const COLOR_STYLE_CHEVRON_OFF := Color(0.66, 0.72, 0.82, 0.6)
## 順位表（左上の操作盤の下に、台なしで出す）。行の高さは、確定した行も、まだの行も同じ。
## 置き場所（表の左上）は、standings_origin。local_race_controller が、操作盤の下に合わせて入れる。
## 自分の行の色の帯が、表の左はしから左へはみ出す幅。表の全体の幅は、STANDINGS_ROW_PAD + STANDINGS_WIDTH。
## オンラインで、走者を誰が動かしているかの札（KIND_PLAYER＝人、KIND_CPU＝CPU、KIND_CPU_SUB＝人が抜けて、CPUが代わりに走っている）。
## [札の文字, 色]。順位表は小さいので、短い文字（3つ目）を使う。
const KIND_PLAYER := "player"
const KIND_CPU := "cpu"
const KIND_CPU_SUB := "cpu_sub"
const CONTROL_TAGS := {
	KIND_PLAYER: ["プレイヤー", Color(0.24, 0.66, 0.4), ""],
	KIND_CPU: ["CPU", Color(0.42, 0.47, 0.56), "CPU"],
	KIND_CPU_SUB: ["CPU（代わり）", Color(0.9, 0.52, 0.18), "CPU"],
}
const STANDINGS_TAG_FONT_SIZE := 11
const STANDINGS_TAG_GAP := 4.0
const STANDINGS_ROW_PAD := 8.0
const STANDINGS_ROW_HEIGHT := 26.0
## 順位表の幅。体力の％の右はしまで（ゴールタイムの欄は置かない）。
const STANDINGS_WIDTH := 364.0
const STANDINGS_NAME_X := 50.0
const STANDINGS_NAME_WIDTH := 120.0
const STANDINGS_STYLE_X := 178.0
const STANDINGS_HEART_X := 224.0
const STANDINGS_FUEL_X := 278.0
const STANDINGS_BATTERY_SIZE := Vector2(36.0, 12.0)
const STANDINGS_FONT_SIZE := 16
const STANDINGS_CONFIRMED_FONT_SIZE := 20
const STANDINGS_VALUE_FONT_SIZE := 14

const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.78, 1.0)
const COLOR_OK := Color(0.36, 0.86, 0.52, 1.0)
const COLOR_WARN := Color(1.0, 0.76, 0.25, 1.0)
const COLOR_DANGER := Color(1.0, 0.32, 0.28, 1.0)
const COLOR_FUEL_FULL := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_FUEL_LOW := Color(1.0, 0.55, 0.2, 1.0)
const COLOR_DEBT_DEEP := Color(0.72, 0.04, 0.06, 1.0)
const COLOR_PROGRESS := Color(0.3, 0.88, 1.0, 1.0)
## 脚質と順位の関係の色。得意な順位にいる（補正がプラス）と青、普通は白、離れている（マイナス）と赤。
const COLOR_STYLE_MATCH := Color(0.35, 0.72, 1.0, 1.0)
const COLOR_STYLE_FAR := Color(1.0, 0.36, 0.32, 1.0)
const COLOR_GOLD := Color(1.0, 0.82, 0.22, 1.0)
const COLOR_SILVER := Color(0.82, 0.86, 0.92, 1.0)
const COLOR_BRONZE := Color(0.84, 0.54, 0.3, 1.0)
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const COLOR_COOL := Color(0.36, 0.72, 1.0, 1.0)

var _state := {
	"place": 0,
	"standings": [],
	"heart_normal_max_bpm": 200.0,
	"countdown": false,
}
## 操作盤の幅に対する順位表の幅。
@export_range(0.01, 5.0, 0.01, "or_greater") var standings_scale := 1.0:
	set(next):
		standings_scale = next
		queue_redraw()
## 操作盤の画面上の幅。
var standings_panel_width := STANDINGS_ROW_PAD + STANDINGS_WIDTH:
	set(next):
		standings_panel_width = next
		queue_redraw()
## 順位表の左上（行の左のはし）。自分の行の色の帯は、ここから STANDINGS_ROW_PAD だけ左へはみ出す。
var standings_origin := Vector2(54.0, 120.0):
	set(next):
		standings_origin = next
		queue_redraw()
## 確定した行に使う太字。
var _bold_font: FontVariation
## 丸・線・面・文字は、ここにためて、最後にまとめて描く（1つずつ描くと、描く命令が多くて重いため）。文字は、ほかの絵より手前に出る。
var _painter := HudPainter.new()


func standings_draw_scale() -> float:
	return standings_panel_width * standings_scale / (STANDINGS_ROW_PAD + STANDINGS_WIDTH)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func update_state(values: Dictionary) -> void:
	for key in values:
		_state[key] = values[key]
	queue_redraw()


## 脚質と今の順位の関係の色（順位の補正がプラスなら青、0なら白、マイナスなら赤）。
static func style_state_color(rank_bonus: int) -> Color:
	if rank_bonus > 0:
		return COLOR_STYLE_MATCH
	if rank_bonus < 0:
		return COLOR_STYLE_FAR
	return COLOR_TEXT


## 順位表のうち、順位が確定した（ゴールした）行の数。確定した行は、上から続けて並ぶ。
static func confirmed_count(standings: Array) -> int:
	var count := 0
	for row in standings:
		if not bool(row["finished"]):
			break
		count += 1
	return count


## 体力バーの色の段階（体力の割合, 色）。満タンの青から、0の赤、負債の濃い赤へ、なめらかにつなぐ。
## 負債の限度（-1）は、バーの下端の濃い赤。
static func fuel_gradient_stops() -> Array:
	return [
		[1.0, COLOR_FUEL_FULL],
		[0.65, COLOR_OK],
		[0.35, COLOR_WARN],
		[0.12, COLOR_FUEL_LOW],
		[0.0, COLOR_DANGER],
		[-1.0, COLOR_DEBT_DEEP],
	]


## その体力の割合での色。バーの位置に対応するなめらかな色。範囲の外は両端の色。
static func fuel_color(fuel_ratio: float) -> Color:
	var stops := fuel_gradient_stops()
	if fuel_ratio >= float(stops[0][0]):
		return stops[0][1]
	for index in stops.size() - 1:
		var upper: Array = stops[index]
		var lower: Array = stops[index + 1]
		if fuel_ratio >= float(lower[0]):
			var span := float(upper[0]) - float(lower[0])
			var t := (float(upper[0]) - fuel_ratio) / span
			return (upper[1] as Color).lerp(lower[1], t)
	return stops[stops.size() - 1][1]


static func heart_color(state: Dictionary) -> Color:
	var bpm := float(state.get("heart_bpm", 0.0))
	var normal_max := float(state.get("heart_normal_max_bpm", 200.0))
	if bpm > normal_max:
		return COLOR_DANGER
	if bpm > normal_max - 20.0:
		return COLOR_WARN
	return COLOR_COOL


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	_painter.begin(self)
	_painter.glyphs.oversampling = get_viewport().get_oversampling()
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.variation_embolden = 0.8
	_bold_font.base_font = font
	var factor := standings_draw_scale()
	var anchor := standings_origin - Vector2(STANDINGS_ROW_PAD, 0.0)
	draw_set_transform(anchor * (1.0 - factor), 0.0, Vector2.ONE * factor)
	_draw_standings(font)
	_painter.flush()
	draw_set_transform(Vector2.ZERO)


## 脚質の印。順位の組の数だけ「〈」を並べ、左が先頭の組。得意な組だけ、はっきり太く描く。
## center_left は、印の並びの左端・縦の中央。色は、今の順位との関係（青・白・赤）。
func _draw_style_chevrons(center_left: Vector2, color: Color, count: int, own: int, size_scale: float = 1.0) -> void:
	draw_style_chevrons(_painter, center_left, color, count, own, size_scale)


## 脚質の印を、指定の描画先に描く（順位表・レース選択などで共通）。
static func draw_style_chevrons(canvas: Object, center_left: Vector2, color: Color, count: int, own: int, size_scale: float = 1.0) -> void:
	var step := STYLE_CHEVRON_STEP * size_scale
	var half_height := 6.5 * size_scale
	var depth := 5.0 * size_scale
	for index in count:
		var tip := Vector2(center_left.x + index * step, center_left.y)
		var points := PackedVector2Array([
			tip + Vector2(depth, -half_height), tip, tip + Vector2(depth, half_height),
		])
		if index == own:
			# 光っているように、外側を薄く太く、内側を濃く描く。
			canvas.draw_polyline(points, Color(color, 0.28), 6.0 * size_scale, true)
			canvas.draw_polyline(points, color, 2.6 * size_scale, true)
		else:
			canvas.draw_polyline(points, COLOR_STYLE_CHEVRON_OFF, 2.0 * size_scale, true)


## 順位表（左上の操作盤の下）。上から今の順位の順。ゴールして確定した行は、太く・大きく・明るくし、印を王冠・メダルにする。
## カメラで見ている子の行の色（頭の上の目印 watch_marker.gd と同じ黄色）。
const COLOR_WATCH := Color(1.0, 0.86, 0.25)


func _draw_standings(font: Font) -> void:
	var standings: Array = _state["standings"]
	# カウントダウン中（順位がまだ0）も出す。並びは controller が枠順にして渡す。
	if (int(_state["place"]) <= 0 and not bool(_state.get("countdown", false))) or standings.is_empty():
		return
	var confirmed := confirmed_count(standings)
	var table_top := standings_origin.y
	for index in standings.size():
		var row: Dictionary = standings[index]
		var top := table_top + index * STANDINGS_ROW_HEIGHT
		var center_y := top + STANDINGS_ROW_HEIGHT * 0.5
		var x := standings_origin.x
		var is_confirmed := index < confirmed
		if bool(row["player"]):
			_draw_rounded_rect(Rect2(Vector2(x - STANDINGS_ROW_PAD, top + 1.0), Vector2(STANDINGS_WIDTH + STANDINGS_ROW_PAD, STANDINGS_ROW_HEIGHT - 2.0)), Color(COLOR_PROGRESS, 0.22), 6.0)
		if bool(row.get("watched", false)):
			var watch_rect := Rect2(Vector2(x - STANDINGS_ROW_PAD, top + 1.0), Vector2(STANDINGS_WIDTH + STANDINGS_ROW_PAD, STANDINGS_ROW_HEIGHT - 2.0))
			_draw_rounded_rect(watch_rect, Color(COLOR_WATCH, 0.22), 6.0)
			_painter.draw_rect(watch_rect, COLOR_WATCH, false, 2.0)
		var row_font: Font = _bold_font if is_confirmed else font
		var text_color := COLOR_TEXT if is_confirmed else COLOR_DIM.lerp(COLOR_TEXT, 0.45)
		var text_size := STANDINGS_CONFIRMED_FONT_SIZE if is_confirmed else STANDINGS_FONT_SIZE
		var baseline := center_y + text_size * 0.36
		_draw_standings_rank(row_font, Vector2(x + 12.0, center_y), index + 1, is_confirmed, text_size, text_color)
		_painter.draw_circle(Vector2(x + 36.0, center_y), 6.5, COLOR_OUTLINE)
		_painter.draw_circle(Vector2(x + 36.0, center_y), 5.0, row["color"])
		# 長い名前は、欄の幅に収める（少し小さく・少し細く。それでも入らなければ末尾を「…」に）。
		# オンラインのCPUの行は、名前の欄の右端に、小さく「CPU」の札（代わりに走っているときは、だいだい色）。
		var name_width := STANDINGS_NAME_WIDTH
		var tag: Array = CONTROL_TAGS.get(str(row.get("kind", "")), [])
		if not tag.is_empty() and not str(tag[2]).is_empty():
			var tag_size := Vector2(font.get_string_size(str(tag[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, STANDINGS_TAG_FONT_SIZE).x + 8.0, STANDINGS_TAG_FONT_SIZE + 4.0)
			var tag_rect := Rect2(Vector2(x + STANDINGS_NAME_X + STANDINGS_NAME_WIDTH - tag_size.x, center_y - tag_size.y * 0.5), tag_size)
			_draw_rounded_rect(tag_rect, tag[1], 4.0)
			_painter.glyphs.add(_bold_font, str(tag[2]), STANDINGS_TAG_FONT_SIZE, Vector2(tag_rect.position.x + 4.0, center_y + STANDINGS_TAG_FONT_SIZE * 0.36), Color.WHITE, 0, Color.TRANSPARENT)
			name_width -= tag_size.x + STANDINGS_TAG_GAP
		var fitted := FitText.fit(row_font, str(row["name"]), name_width, text_size)
		_painter.glyphs.add(row_font, str(fitted["text"]), int(fitted["font_size"]), Vector2.ZERO, text_color, 6, COLOR_OUTLINE, Transform2D(0.0, Vector2(float(fitted["x_scale"]), 1.0), 0.0, Vector2(x + STANDINGS_NAME_X, baseline)))
		_draw_style_chevrons(Vector2(x + STANDINGS_STYLE_X, center_y), style_state_color(int(row["style_rank_bonus"])), int(row["style_group_count"]), int(row["style_group_index"]), 0.85)
		var value_baseline := center_y + STANDINGS_VALUE_FONT_SIZE * 0.36
		_draw_heart(Vector2(x + STANDINGS_HEART_X + 7.0, center_y), COLOR_DANGER)
		# 心拍の数字の色は、操作盤の心拍と同じ決め方。
		var heart_text_color := heart_color({"heart_bpm": row["heart_bpm"], "heart_normal_max_bpm": _state["heart_normal_max_bpm"]})
		_draw_text(font, "%d" % int(roundf(float(row["heart_bpm"]))), Vector2(x + STANDINGS_HEART_X + 18.0, value_baseline), STANDINGS_VALUE_FONT_SIZE, heart_text_color)
		var fuel := float(row["fuel_ratio"])
		_draw_battery(Vector2(x + STANDINGS_FUEL_X, center_y - STANDINGS_BATTERY_SIZE.y * 0.5), fuel)
		_draw_text(font, "%d%%" % int(roundf(fuel * 100.0)), Vector2(x + STANDINGS_FUEL_X + STANDINGS_BATTERY_SIZE.x + 8.0, value_baseline), STANDINGS_VALUE_FONT_SIZE, COLOR_DANGER if fuel < 0.0 else text_color)
	if confirmed > 0 and confirmed < standings.size():
		# 確定した行と、まだの行の境目。行の境目に引くので、行の高さは変わらない。
		var line_y := table_top + confirmed * STANDINGS_ROW_HEIGHT
		var left := standings_origin.x
		var from := Vector2(left - STANDINGS_ROW_PAD, line_y)
		var to := Vector2(left + STANDINGS_WIDTH, line_y)
		_painter.draw_line(from, to, COLOR_OUTLINE, 4.0)
		_painter.draw_line(from, to, COLOR_TEXT, 1.5)


## 順位の印。確定したら、1位は金の王冠、2位は銀メダル、3位は銅メダル、4位からは太い数字。
func _draw_standings_rank(font: Font, center: Vector2, place: int, is_confirmed: bool, font_size: int, color: Color) -> void:
	if is_confirmed and place == 1:
		_draw_crown(center)
		return
	if is_confirmed and place <= 3:
		_draw_medal(font, center, place, COLOR_SILVER if place == 2 else COLOR_BRONZE)
		return
	var text := "%d" % place
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_draw_text(font, text, Vector2(center.x - width * 0.5, center.y + font_size * 0.36), font_size, color)


func _draw_crown(center: Vector2) -> void:
	draw_crown(_painter, center)


func _draw_medal(font: Font, center: Vector2, place: int, color: Color) -> void:
	draw_medal(_painter, font, center, place, color)


## 金の王冠を、指定の描画先に描く（順位表と、着順の板で共通）。
static func draw_crown(canvas: Object, center: Vector2, size_scale: float = 1.0) -> void:
	var shape := PackedVector2Array([
		Vector2(-11.0, 8.0), Vector2(-11.0, -5.0), Vector2(-5.0, 1.0), Vector2(0.0, -9.0),
		Vector2(5.0, 1.0), Vector2(11.0, -5.0), Vector2(11.0, 8.0),
	])
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point * size_scale)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, COLOR_OUTLINE, 4.0 * size_scale, true)
	canvas.draw_colored_polygon(points, COLOR_GOLD)
	canvas.draw_line(center + Vector2(-11.0, 4.5) * size_scale, center + Vector2(11.0, 4.5) * size_scale, Color(0.72, 0.46, 0.05), 1.5 * size_scale)
	for tip: Vector2 in [Vector2(-11.0, -5.0), Vector2(0.0, -9.0), Vector2(11.0, -5.0)]:
		canvas.draw_circle(center + tip * size_scale, 2.2 * size_scale, COLOR_GOLD)


## メダル（リボンと丸）を、指定の描画先に描く。
static func draw_medal(canvas: Object, font: Font, center: Vector2, place: int, color: Color, size_scale: float = 1.0) -> void:
	var ribbon := PackedVector2Array([
		center + Vector2(-7.0, -12.0) * size_scale, center + Vector2(7.0, -12.0) * size_scale,
		center + Vector2(3.0, -3.0) * size_scale, center + Vector2(-3.0, -3.0) * size_scale,
	])
	canvas.draw_colored_polygon(ribbon, COLOR_COOL)
	var medal_center := center + Vector2(0.0, 2.5) * size_scale
	canvas.draw_circle(medal_center, 9.5 * size_scale, COLOR_OUTLINE)
	canvas.draw_circle(medal_center, 8.0 * size_scale, color)
	canvas.draw_arc(medal_center, 5.8 * size_scale, 0.0, TAU, 24, color.darkened(0.3), 1.0 * size_scale, true)
	var text := "%d" % place
	var font_size := int(roundf(11.0 * size_scale))
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(font, medal_center + Vector2(-width * 0.5, 4.0 * size_scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color.darkened(0.6))


func _draw_heart(center: Vector2, color: Color) -> void:
	for pass_index in 2:
		var grow := 1.5 if pass_index == 0 else 0.0
		var pass_color := COLOR_OUTLINE if pass_index == 0 else color
		_painter.draw_circle(center + Vector2(-3.0, -2.0), 3.4 + grow, pass_color)
		_painter.draw_circle(center + Vector2(3.0, -2.0), 3.4 + grow, pass_color)
		_painter.draw_colored_polygon(PackedVector2Array([
			center + Vector2(-6.2 - grow, -0.4), center + Vector2(6.2 + grow, -0.4), center + Vector2(0.0, 6.6 + grow * 1.4),
		]), pass_color)


## 体力の電池：左の4分の1が負債（マイナス）、その右がプラス。
## 今の体力の位置まで、左から色を塗る。
func _draw_battery(top_left: Vector2, fuel_ratio: float) -> void:
	var body := Rect2(top_left, STANDINGS_BATTERY_SIZE)
	_painter.draw_rect(body.grow(1.5), COLOR_OUTLINE)
	var cap := Rect2(Vector2(body.end.x, body.position.y + 3.0), Vector2(3.0, body.size.y - 6.0))
	_painter.draw_rect(cap.grow(1.0), COLOR_OUTLINE)
	_painter.draw_rect(cap, COLOR_TEXT)
	var inner := body.grow(-2.0)
	_draw_battery_gradient(inner, -1.0, 1.0, 0.25)
	_draw_battery_gradient(inner, -1.0, clampf(fuel_ratio, -1.0, 1.0), 1.0)
	_painter.draw_rect(body, COLOR_TEXT, false, 1.5)


## 電池の中での、体力の割合の横の位置。負債の限度（-1）が左端、0が左から4分の1、満タン（1）が右端。
static func battery_x(inner: Rect2, fuel_ratio: float) -> float:
	var zero_x := inner.position.x + inner.size.x * FUEL_DEBT_ZONE_RATIO
	if fuel_ratio >= 0.0:
		return zero_x + inner.size.x * (1.0 - FUEL_DEBT_ZONE_RATIO) * minf(fuel_ratio, 1.0)
	return zero_x - inner.size.x * FUEL_DEBT_ZONE_RATIO * minf(-fuel_ratio, 1.0)


## 電池の中身を、体力の割合 [from_ratio, to_ratio] の範囲だけ、体力の色で描く。
func _draw_battery_gradient(inner: Rect2, from_ratio: float, to_ratio: float, alpha: float) -> void:
	var stops := fuel_gradient_stops()
	for index in stops.size() - 1:
		var high: Array = stops[index]
		var low: Array = stops[index + 1]
		var r0 := maxf(float(low[0]), from_ratio)
		var r1 := minf(float(high[0]), to_ratio)
		if r1 <= r0:
			continue
		var c0 := fuel_color(r0)
		var c1 := fuel_color(r1)
		c0.a = alpha
		c1.a = alpha
		var x0 := battery_x(inner, r0)
		var x1 := battery_x(inner, r1)
		_painter.draw_polygon(
			PackedVector2Array([Vector2(x0, inner.position.y), Vector2(x1, inner.position.y), Vector2(x1, inner.end.y), Vector2(x0, inner.end.y)]),
			PackedColorArray([c0, c1, c1, c0])
		)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	_painter.draw_style_box(style, rect)


func _draw_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	# 背景に溶けないよう、暗い縁取りを付ける。
	_painter.glyphs.add(font, text, font_size, position, color, 6, Color(0.03, 0.05, 0.1, 0.9))
