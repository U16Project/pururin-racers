extends Control
## ローカルレースの常時表示HUD。数値の羅列ではなく、走りながら読める4つ
## （速度・ノッチ・心拍・体力）を画面下中央に大きく描く。詳細な診断はデバッグ表示（F3）へ分ける。
## 値は update_state() で受け取り、計算はここでは行わない（表示用の割合と色だけ）。

const PANEL_WIDTH := 440.0
const GAUGE_BAR_HEIGHT := 110.0
## 体力バーのうち、下から負債（マイナス）に使う割合。負債の全体（0〜限度）をこの長さで見せるので、プラス側より縮尺が小さい（減りが遅く見える）。
const FUEL_DEBT_ZONE_RATIO := 0.25
const PANEL_BODY_HEIGHT := 196.0
## 進行バー（文字の行とバー）の帯の高さ。
const PANEL_TOP_STRIP := 52.0
const PANEL_HEIGHT := PANEL_BODY_HEIGHT + PANEL_TOP_STRIP
const PROGRESS_BAR_HEIGHT := 10.0
const PROGRESS_SIDE_MARGIN := 24.0
## 画面下端からの余白。
const PANEL_BOTTOM_MARGIN := 20.0
const NOTCH_COUNT := 7
## 空気抵抗の減りのゲージ。30段で、満タン＝空気抵抗が60%減る（1段＝2%）。
const AIR_GAUGE_SEGMENTS := 30
const AIR_GAUGE_FULL := 0.60

const COLOR_PANEL := Color(0.05, 0.08, 0.14, 0.72)
const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.78, 1.0)
const COLOR_TRACK := Color(1.0, 1.0, 1.0, 0.16)
const COLOR_OK := Color(0.36, 0.86, 0.52, 1.0)
const COLOR_WARN := Color(1.0, 0.76, 0.25, 1.0)
const COLOR_DANGER := Color(1.0, 0.32, 0.28, 1.0)
const COLOR_FUEL_FULL := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_FUEL_LOW := Color(1.0, 0.55, 0.2, 1.0)
const COLOR_DEBT_DEEP := Color(0.72, 0.04, 0.06, 1.0)
const COLOR_PROGRESS := Color(0.3, 0.88, 1.0, 1.0)
const COLOR_COOL := Color(0.36, 0.72, 1.0, 1.0)
const COLOR_AERO := Color(0.36, 0.86, 0.52, 1.0)

var _state := {
	"place": 0,
	"field_size": 0,
	"remaining_m": 0.0,
	"race_distance_m": 0.0,
	"runners": [],
	"time_text": "",
	"speed_kmh": 0.0,
	"notch": 0,
	"notch_max": 6,
	"braking": false,
	"fuel_ratio": 1.0,
	"heart_bpm": 100.0,
	"heart_min_bpm": 100.0,
	"heart_normal_max_bpm": 200.0,
	"heart_max_bpm": 230.0,
	"air_green": 0.0,
	"air_blue": 0.0,
	"countdown": false,
}
var _blink := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.0)
	if heart_is_overheated(_state) or fuel_is_in_debt(_state) or bool(_state["braking"]):
		queue_redraw()


func update_state(values: Dictionary) -> void:
	for key in values:
		_state[key] = values[key]
	queue_redraw()


## 進行バー上の位置（0〜1）。
static func progress_ratio(progress_m: float, distance_m: float) -> float:
	if distance_m <= 0.0:
		return 0.0
	return clampf(progress_m / distance_m, 0.0, 1.0)


## 燃料バーのプラス側の表示割合（0〜1）。
static func fuel_fill_ratio(fuel_ratio: float) -> float:
	return clampf(fuel_ratio, 0.0, 1.0)


## 燃料バーのマイナス側（負債）の表示割合（0〜1。負債の限度で1）。
static func fuel_debt_ratio(fuel_ratio: float) -> float:
	return clampf(-fuel_ratio, 0.0, 1.0)


static func fuel_is_in_debt(state: Dictionary) -> bool:
	return float(state.get("fuel_ratio", 1.0)) < 0.0


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


## 心拍バーの表示割合（最低〜過熱上限）。
static func heart_fill_ratio(state: Dictionary) -> float:
	var low := float(state.get("heart_min_bpm", 100.0))
	var high := float(state.get("heart_max_bpm", 230.0))
	return clampf((float(state.get("heart_bpm", low)) - low) / maxf(high - low, 0.001), 0.0, 1.0)


## 通常上限（200）の位置。バー上の目印に使う。
static func heart_limit_ratio(state: Dictionary) -> float:
	var low := float(state.get("heart_min_bpm", 100.0))
	var high := float(state.get("heart_max_bpm", 230.0))
	return clampf((float(state.get("heart_normal_max_bpm", 200.0)) - low) / maxf(high - low, 0.001), 0.0, 1.0)


## 空気抵抗の減り（緑＝空力と後方支援、青＝ドラフト）を、20段の点灯数へ。
## 緑を先に積み、続けて青を積む。少しでもあれば、その色は最低1段は点く。合計は20段を超えない。
static func air_gauge_segments(green: float, blue: float) -> Dictionary:
	var step := AIR_GAUGE_FULL / float(AIR_GAUGE_SEGMENTS)
	var green_value := maxf(green, 0.0)
	var blue_value := maxf(blue, 0.0)
	var green_count := 0
	if green_value > 0.0:
		green_count = clampi(maxi(roundi(green_value / step), 1), 1, AIR_GAUGE_SEGMENTS)
	var total_count := clampi(ceili((green_value + blue_value) / step - 0.0001), 0, AIR_GAUGE_SEGMENTS)
	if blue_value > 0.0:
		total_count = maxi(total_count, green_count + 1)
	total_count = clampi(total_count, green_count, AIR_GAUGE_SEGMENTS)
	green_count = mini(green_count, total_count)
	return {"green": green_count, "blue": total_count - green_count}


static func heart_is_overheated(state: Dictionary) -> bool:
	return float(state.get("heart_bpm", 0.0)) > float(state.get("heart_normal_max_bpm", 200.0))


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
	_draw_race_info(font)
	_draw_main_panel(font)


func _draw_race_info(font: Font) -> void:
	var place := int(_state["place"])
	if place <= 0:
		return
	var origin := Vector2(24.0, 24.0)
	_draw_text(font, "%d" % place, origin + Vector2(0.0, 52.0), 64, COLOR_TEXT)
	_draw_text(font, "/ %d 位" % int(_state["field_size"]), origin + Vector2(54.0 if place < 10 else 80.0, 52.0), 24, COLOR_DIM)
	_draw_text(font, "残り %.0f m" % float(_state["remaining_m"]), origin + Vector2(0.0, 88.0), 26, COLOR_TEXT)
	_draw_text(font, str(_state["time_text"]), origin + Vector2(0.0, 120.0), 26, COLOR_TEXT)


func _draw_main_panel(font: Font) -> void:
	# 親が CanvasLayer の場合は Control の size が当てにならないため、ビューポートの大きさを使う。
	var screen := get_viewport_rect().size
	var panel := Rect2(
		Vector2((screen.x - PANEL_WIDTH) * 0.5, screen.y - PANEL_BOTTOM_MARGIN - PANEL_HEIGHT),
		Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	)
	draw_rect(panel, COLOR_PANEL)
	var braking := bool(_state["braking"])
	# 左：速度とドラフト
	_draw_progress_bar(font, panel)
	var body_top := panel.position.y + PANEL_TOP_STRIP
	var speed_origin := Vector2(panel.position.x + 24.0, body_top + 96.0)
	_draw_text(font, "%d" % int(roundf(float(_state["speed_kmh"]))), speed_origin, 76, COLOR_TEXT)
	_draw_text(font, "km/h", speed_origin + Vector2(0.0, 30.0), 22, COLOR_DIM)
	_draw_draft_gauge(font, Vector2(panel.position.x + 24.0, body_top + 160.0))
	# 右：縦ゲージ3本（ノッチ・心拍・体力）
	var gauge_top := body_top + 18.0
	var left := panel.position.x + 224.0
	var column := 68.0
	_draw_notch_gauge(font, Vector2(left, gauge_top), braking)
	var heart_color_now := heart_color(_state)
	if heart_is_overheated(_state) and _blink > 0.5:
		heart_color_now = heart_color_now.lightened(0.35)
	_draw_vertical_gauge(
		font, "心拍", Vector2(left + column, gauge_top), heart_fill_ratio(_state), heart_color_now,
		heart_limit_ratio(_state), "%d" % int(roundf(float(_state["heart_bpm"])))
	)
	var fuel := float(_state["fuel_ratio"])
	_draw_fuel_gauge(font, Vector2(left + column * 2.0, gauge_top), fuel)
	if bool(_state["countdown"]):
		_draw_text(font, "↑↓で開始ノッチを選択", Vector2(panel.position.x + 24.0, panel.position.y - 10.0), 20, COLOR_TEXT)


## パネル上部の進行バー。上にレース距離（左）と残り距離（右）、下に全走者の位置。
func _draw_progress_bar(font: Font, panel: Rect2) -> void:
	var left := panel.position.x + PROGRESS_SIDE_MARGIN
	var width := PANEL_WIDTH - PROGRESS_SIDE_MARGIN * 2.0
	var text_y := panel.position.y + 28.0
	_draw_text(font, "%d m" % int(roundf(float(_state["race_distance_m"]))), Vector2(left, text_y), 14, COLOR_DIM)
	var time_text := str(_state["time_text"])
	var time_width := font.get_string_size(time_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_draw_text(font, time_text, Vector2(left + (width - time_width) * 0.5, text_y), 16, COLOR_TEXT)
	var remaining_text := "残り %d m" % int(roundf(float(_state["remaining_m"])))
	var remaining_width := font.get_string_size(remaining_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_draw_text(font, remaining_text, Vector2(left + width - remaining_width, text_y), 16, COLOR_TEXT)
	var bar_y := panel.position.y + 38.0
	var rail := Rect2(Vector2(left, bar_y), Vector2(width, PROGRESS_BAR_HEIGHT))
	_draw_rounded_rect(rail, COLOR_TRACK, PROGRESS_BAR_HEIGHT * 0.5)
	var runners: Array = _state["runners"]
	var player_ratio := 0.0
	for mark in runners:
		if bool(mark["player"]):
			player_ratio = float(mark["ratio"])
	if player_ratio > 0.0:
		_draw_rounded_rect(Rect2(rail.position, Vector2(maxf(width * player_ratio, PROGRESS_BAR_HEIGHT), PROGRESS_BAR_HEIGHT)), COLOR_PROGRESS, PROGRESS_BAR_HEIGHT * 0.5)
	for quarter: float in [0.25, 0.5, 0.75]:
		var x: float = left + width * quarter
		draw_line(Vector2(x, bar_y - 2.0), Vector2(x, bar_y + PROGRESS_BAR_HEIGHT + 2.0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
	_draw_goal_checker(Vector2(left + width, bar_y + PROGRESS_BAR_HEIGHT * 0.5))
	var center_y := bar_y + PROGRESS_BAR_HEIGHT * 0.5
	for mark in runners:
		if not bool(mark["player"]):
			draw_circle(Vector2(left + width * float(mark["ratio"]), center_y), 4.5, mark["color"])
	for mark in runners:
		if bool(mark["player"]):
			var center := Vector2(left + width * float(mark["ratio"]), center_y)
			draw_circle(center, 8.5, COLOR_TEXT)
			draw_circle(center, 6.0, mark["color"])


func _draw_goal_checker(center: Vector2) -> void:
	var cell := 4.0
	for row in 4:
		for column in 2:
			var color := Color(0.97, 0.98, 1.0, 1.0) if (row + column) % 2 == 0 else Color(0.08, 0.1, 0.16, 1.0)
			draw_rect(Rect2(Vector2(center.x - cell + column * cell, center.y - cell * 2.0 + row * cell), Vector2(cell, cell)), color)


func _draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)


func _draw_draft_gauge(font: Font, origin: Vector2) -> void:
	var green_value := float(_state["air_green"])
	var blue_value := float(_state["air_blue"])
	var counts := air_gauge_segments(green_value, blue_value)
	_draw_text(font, "空気抵抗 −%d%%" % int(roundf((green_value + blue_value) * 100.0)), origin + Vector2(0.0, -8.0), 16, COLOR_DIM)
	var segment_width := 4.5
	var gap := 1.2
	for index in AIR_GAUGE_SEGMENTS:
		var rect := Rect2(origin + Vector2(index * (segment_width + gap), 0.0), Vector2(segment_width, 14.0))
		var color := COLOR_TRACK
		if index < int(counts["green"]):
			color = COLOR_AERO
		elif index < int(counts["green"]) + int(counts["blue"]):
			color = COLOR_COOL
		draw_rect(rect, color)
	# 凡例
	var legend_y := origin.y + 28.0
	draw_rect(Rect2(Vector2(origin.x, legend_y - 9.0), Vector2(9.0, 9.0)), COLOR_AERO)
	_draw_text(font, "空力", Vector2(origin.x + 13.0, legend_y), 14, COLOR_DIM)
	draw_rect(Rect2(Vector2(origin.x + 56.0, legend_y - 9.0), Vector2(9.0, 9.0)), COLOR_COOL)
	_draw_text(font, "集団", Vector2(origin.x + 69.0, legend_y), 14, COLOR_DIM)


func _draw_notch_gauge(font: Font, origin: Vector2, braking: bool) -> void:
	var notch := int(_state["notch"])
	var bar_width := 34.0
	var bar_height := 110.0
	var gap := 3.0
	var segment_height := (bar_height - gap * (NOTCH_COUNT - 1)) / NOTCH_COUNT
	for index in NOTCH_COUNT:
		# 下がノッチ0、上へ積み上げる。
		var y := origin.y + bar_height - (index + 1) * segment_height - index * gap
		var rect := Rect2(Vector2(origin.x, y), Vector2(bar_width, segment_height))
		var color := COLOR_TRACK
		if index > 0 and index <= notch:
			color = COLOR_DIM if braking else COLOR_OK.lerp(COLOR_WARN, float(index) / float(NOTCH_COUNT - 1))
		draw_rect(rect, color)
		if index == notch:
			draw_rect(rect.grow(2.0), COLOR_TEXT, false, 2.0)
	_draw_text(font, "ノッチ", Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, "ブレーキ" if braking else "%d" % notch, Vector2(origin.x - (6.0 if braking else -8.0), origin.y + bar_height + 54.0), 20 if braking else 26, COLOR_DANGER if braking else COLOR_TEXT)


func _draw_vertical_gauge(font: Font, title: String, origin: Vector2, ratio: float, color: Color, mark_ratio: float, value_text: String) -> void:
	var bar_width := 34.0
	var bar_height := 110.0
	var track := Rect2(origin, Vector2(bar_width, bar_height))
	draw_rect(track, COLOR_TRACK)
	var fill_height := bar_height * ratio
	draw_rect(Rect2(Vector2(origin.x, origin.y + bar_height - fill_height), Vector2(bar_width, fill_height)), color)
	if mark_ratio >= 0.0:
		var y := origin.y + bar_height - bar_height * mark_ratio
		draw_line(Vector2(origin.x - 4.0, y), Vector2(origin.x + bar_width + 4.0, y), COLOR_TEXT, 2.0)
	_draw_text(font, title, Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, value_text, Vector2(origin.x - 6.0, origin.y + bar_height + 54.0), 20, color)


## 体力バー。1本の目盛りで、上が満タン、下から1/4が負債。今の体力の高さまで、下から明るく塗る。
## 色は位置で決まり、満タンの青から、緑・黄・橙・0の赤、負債の濃い赤まで、常に全体を薄く見せる。
## 負債の全体（0〜限度）は下の1/4に収まるので、プラスより縮尺が小さく、減る速さは遅く見える。
func _draw_fuel_gauge(font: Font, origin: Vector2, fuel: float) -> void:
	var bar_width := 34.0
	var bar_height := GAUGE_BAR_HEIGHT
	var zero_y := fuel_zero_y(origin.y)
	var bottom_y := origin.y + bar_height
	draw_rect(Rect2(origin, Vector2(bar_width, bar_height)), COLOR_TRACK)
	_draw_fuel_gradient(origin.x, bar_width, zero_y, origin.y, bottom_y, 0.22)
	_draw_fuel_gradient(origin.x, bar_width, zero_y, fuel_y(zero_y, fuel), bottom_y, 1.0)
	# 体力0の境目。ここより下が負債（マイナス）。
	draw_line(Vector2(origin.x, zero_y), Vector2(origin.x + bar_width, zero_y), COLOR_TEXT, 1.0)
	var debt := fuel_debt_ratio(fuel)
	var value_text := "-%d%%" % int(roundf(debt * 100.0)) if debt > 0.0 else "%d%%" % int(roundf(fuel * 100.0))
	_draw_text(font, "体力", Vector2(origin.x - 6.0, origin.y + bar_height + 28.0), 17, COLOR_DIM)
	_draw_text(font, value_text, Vector2(origin.x - 6.0, origin.y + bar_height + 54.0), 20, fuel_color(fuel))


## バーの上端が origin_y のとき、体力0の線の縦の位置。
static func fuel_zero_y(origin_y: float) -> float:
	return origin_y + GAUGE_BAR_HEIGHT * (1.0 - FUEL_DEBT_ZONE_RATIO)


## 体力の割合に対応する、バー上の縦の位置。0が zero_y、プラスは上へ（満タンで上端）、負債は下へ（限度で下端）。
static func fuel_y(zero_y: float, fuel_ratio: float) -> float:
	if fuel_ratio >= 0.0:
		return zero_y - GAUGE_BAR_HEIGHT * (1.0 - FUEL_DEBT_ZONE_RATIO) * minf(fuel_ratio, 1.0)
	return zero_y + GAUGE_BAR_HEIGHT * FUEL_DEBT_ZONE_RATIO * minf(-fuel_ratio, 1.0)


## 体力バーの色を、縦の範囲 [from_y, to_y]（from_y が上）だけ、なめらかに描く。
func _draw_fuel_gradient(x: float, width: float, zero_y: float, from_y: float, to_y: float, alpha: float) -> void:
	if to_y <= from_y:
		return
	var stops := fuel_gradient_stops()
	for index in stops.size() - 1:
		var upper: Array = stops[index]
		var lower: Array = stops[index + 1]
		var upper_y := fuel_y(zero_y, float(upper[0]))
		var lower_y := fuel_y(zero_y, float(lower[0]))
		var y0 := maxf(upper_y, from_y)
		var y1 := minf(lower_y, to_y)
		if y1 <= y0 or lower_y <= upper_y:
			continue
		var c0 := (upper[1] as Color).lerp(lower[1], (y0 - upper_y) / (lower_y - upper_y))
		var c1 := (upper[1] as Color).lerp(lower[1], (y1 - upper_y) / (lower_y - upper_y))
		c0.a = alpha
		c1.a = alpha
		draw_polygon(
			PackedVector2Array([Vector2(x, y0), Vector2(x + width, y0), Vector2(x + width, y1), Vector2(x, y1)]),
			PackedColorArray([c0, c0, c1, c1])
		)


func _draw_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	# 背景に溶けないよう、暗い縁取りを付ける。
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Color(0.03, 0.05, 0.1, 0.9))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
