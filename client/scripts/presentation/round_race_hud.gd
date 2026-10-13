extends Control
## 丸い操作盤。場所を取らないように、弧（ゲージ）の終わりを1本ずつずらして、空いた「弧の延長」に、
## その弧の名前と値を、弧に沿わせて書く（左の3本は上の延長、右の3本は下の延長）。
## 色は、四角い操作盤（RaceHud）と同じ。
## まん中にハート（心拍）、左に3本の弧（内から、空気抵抗の軽減・速さ・ノッチ）、
## 右に3本の弧（内から、体力・ブースト・ダッシュ）。
## 一番外の輪は、レースの道のり。Sから反時計まわりに、左・下を通って、3時のGまで。Gは固定で、
## レースの距離が長いほど、Sが右（時計まわり）へ動いて、道のりの弧が長くなる。
## 走り終えたぶんは水色、残りはうすい色。SとGの間の、使わない部分は、細かい刻み。
## 緑の印が自分、小さい点が、ほかのプル。
## 値を受け取って描くだけ（update_state）。角度は、12時を0として、時計まわりの度。

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const ButtonMark := preload("res://scripts/menu/button_mark.gd")
const GlyphBatch := preload("res://scripts/presentation/glyph_batch.gd")
## 大きさは、この半径（外の輪の外側）を基準にした寸法。set_radius で、全体を同じ比で変えられる。
const BASE_RADIUS := 175.0
const COURSE_RADIUS := 166.0
const COURSE_WIDTH := 13.0
## 弧の、まん中の半径（外・中・内）と、太さ。
const OUTER_RADIUS := 144.0
const MIDDLE_RADIUS := 120.0
const INNER_RADIUS := 96.0
const BAND_WIDTH := 20.0
## 色の付いたマスの下に敷く、うすい光の、はみ出し幅と濃さ。
const GLOW_EXTRA := 4.0
const GLOW_ALPHA := 0.25
## 左の3本（下から上へ、時計まわりに伸びる）。終わりの角度を1本ずつずらして、その先（延長）に文字を書く。
const LEFT_FROM_DEG := 200.0
const AERO_TO_DEG := 290.0
const SPEED_TO_DEG := 326.0
const NOTCH_TO_DEG := 338.0
## 左の3本の、文字のまん中の角度（弧の延長の上）。
const AERO_LABEL_DEG := 317.5
const SPEED_LABEL_DEG := 346.0
const NOTCH_LABEL_DEG := 355.5
## 右の、体力（上が満タン、下が0。0より下は、借り）・ブースト・ダッシュ。
## 下の終わりを1本ずつずらして、その先（延長）に、ボタンの印と文字を書く。
const STAMINA_FULL_DEG := 24.0
const STAMINA_ZERO_DEG := 78.0
const STAMINA_DEBT_DEG := 104.0
const BOOST_FROM_DEG := 84.0
const BOOST_TO_DEG := 2.0
const DASH_FROM_DEG := 96.0
const DASH_TO_DEG := 16.0
## 右の3本の、文字のまん中の角度と、ボタンの印の角度（弧の延長の上）。
const STAMINA_LABEL_DEG := 122.0
const BOOST_MARK_DEG := 93.0
const BOOST_LABEL_DEG := 121.0
const DASH_MARK_DEG := 104.0
const DASH_LABEL_DEG := 128.0
## レースの道のり：Gは3時で固定。Sから反時計まわりにGまで。3000mで、325度ぶん。
const DISTANCE_GOAL_DEG := 90.0
const DISTANCE_DEG_PER_M := 325.0 / 3000.0
## 使わない部分の、黒い刻み1つぶんの角度。
const UNUSED_TICK_DEG := 2.5
## 目盛りの数と、いっぱいのときの値。
const NOTCH_MAX := 6
const SPEED_FULL_KMH := 110.0
const SPEED_SEGMENTS := 66
const AERO_FULL := 1.0
const AERO_SEGMENTS := 48
const STAMINA_SEGMENTS := 40
const GAUGE_SEGMENTS := 38
## ノッチ1つぶんのマスの数（ほかのゲージと、マスの大きさをそろえる）。
## 一番下のノッチの段の数と、ノッチが1つ上がるごとに増える段の数。
const NOTCH_CELLS := 8
const NOTCH_CELLS_STEP := 2
## ブースト1回ぶんのマスの数。
const BOOST_CELLS := 12
const NOTCH_GAP_DEG := 2.0
## ハートの段の数と、段のすき間。
## ハートのまん中の高さ（盤のまん中から下へ）と、縦の縮め具合。
const HEART_DOWN := 5.0
const HEART_SQUASH := 0.86
const HEART_NARROW := 0.93
const HEART_STEPS := 24
const HEART_STEP_GAP := 1.5
const SEGMENT_GAP_DEG := 0.75
const HEART_SIZE := 76.0
## 名前の文字の大きさと、脚質の印の大きさ。
const NAME_SIZE := 24
const STYLE_SCALE := 1.7
## ゲージの文字：数値は大きく黄色、それ以外（名前・単位）は小さく白。
const VALUE_SIZE := 25
const WORD_SIZE := 16
const COLOR_VALUE := RaceHud.COLOR_GOLD
## S と G の茶色のバー（太さ、輪からのはみ出し、色）と、S・G の文字をバーから離す角度。
const GATE_BAR_WIDTH := 5.0
const GATE_BAR_OVER := 4.0
const COLOR_GATE_BAR := Color(0.62, 0.38, 0.18, 1.0)
const GATE_LETTER_DEG := 6.5
## タイムを書く場所（下の輪に沿わせる）。
const TIME_RADIUS := 142.0
const TIME_DEG := 174.0
## 名前を書く場所（輪の外。輪の外側から、どれだけ離すか）。
const NAME_OUTSIDE := 20.0
const NAME_DEG := 115.0
## 属性の印と、脚質の印を書く角度（輪の外の左下。名前が長くても重ならない）。属性の印の大きさ。
const ATTRIBUTE_DEG := 239.0
const ATTRIBUTE_SIZE := 30.0
const STYLE_DEG := 230.0
const COLOR_FACE := Color(0.02, 0.05, 0.11, 0.82)
const COLOR_RIM_LINE := Color(1.0, 1.0, 1.0, 0.22)
## 段の境目の線の太さ（ふつうの境目と、ノッチ・ブースト1回ごとの広い境目）。
const GAP_LINE_WIDTH := 1.4
const WIDE_GAP_LINE_WIDTH := 4.5
## 段の境目の線の色（盤の地と同じ色。細い線でも段が暗くなりすぎないよう、少し透かす）。
const COLOR_GAP := Color(0.02, 0.05, 0.11, 0.62)
const COLOR_SLOT := RaceHud.COLOR_TRACK
const COLOR_TEXT := Color(1.0, 1.0, 1.0, 0.97)
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const COLOR_NOTCH := RaceHud.COLOR_WARN
const COLOR_DISTANCE_DONE := RaceHud.COLOR_PROGRESS
## 速さは青系。遅い＝濃い青、速い＝明るい水色。
const COLOR_SPEED_LOW := Color(0.2, 0.42, 1.0, 1.0)
const COLOR_SPEED_HIGH := Color(0.62, 0.95, 1.0, 1.0)
const COLOR_AERO := RaceHud.COLOR_AERO
const COLOR_DRAFT := RaceHud.COLOR_COOL
const COLOR_BOOST := RaceHud.COLOR_BOOST
## ダッシュの色は、四角い操作盤と同じ。
const COLOR_DASH := RaceHud.COLOR_PROGRESS
const COLOR_COURSE := Color(1.0, 1.0, 1.0, 0.5)
const COLOR_SELF := RaceHud.COLOR_OK
const COLOR_HEART_EDGE := Color(1.0, 0.45, 0.6, 1.0)
const COLOR_HEART_EMPTY := Color(0.2, 0.25, 0.37, 0.9)
## 鼓動で光るときの色（空の段と、ふち）と、光っている長さ（鼓動1回のうち、最初のどれだけか）。
const COLOR_HEART_BEAT := Color(1.0, 0.62, 0.76, 1.0)
const HEART_BEAT_PART := 0.4
const HEART_BEAT_EMPTY_GLOW := 0.55
const HEART_BEAT_EDGE_GLOW := 0.7
const COLOR_HEART_BACK := Color(0.04, 0.06, 0.11, 1.0)

var _state := {
	"speed_kmh": 0.0, "notch": 1, "heart_bpm": 100.0, "heart_beat_phase": 1.0, "heart_min_bpm": 100.0, "heart_normal_max_bpm": 200.0, "heart_max_bpm": 230.0,
	"fuel_ratio": 1.0, "air_green": 0.0, "air_blue": 0.0, "place": 0, "field_size": 0, "time_s": 0.0,
	"remaining_m": 0.0, "race_distance_m": 2000.0, "boost_ratio": 0.0, "dash_ratio": 0.0, "boost_uses_left": 0, "boost_max_uses": 0,
	"runners": [], "player_name": "", "trainer_name": "",
	"attribute_id": "", "attribute_color": Color.WHITE, "style_group_count": 0, "style_group_index": 0, "style_rank_bonus": 0,
}
var _radius := BASE_RADIUS
var _thin_gaps := PackedVector2Array()
## ためておいた文字（[置く場所, 回す角度, 書き出しの位置, 文字, 大きさ, 色] の並び）。
var _glyphs: Array = []
var _glyph_batch := GlyphBatch.new()
var _wide_gaps := PackedVector2Array()
var _center := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		set_radius(BASE_RADIUS)


## 全体の大きさ（外の輪の外側の半径。ピクセル）。
func set_radius(radius: float) -> void:
	_radius = radius
	custom_minimum_size = Vector2(radius + _s(NAME_OUTSIDE + 22.0), radius + _s(NAME_OUTSIDE + 22.0)) * 2.0
	queue_redraw()


func update_state(values: Dictionary) -> void:
	for key in values:
		_state[key] = values[key]
	queue_redraw()


## 12時を0として時計まわりの度を、画面の角度（ラジアン）にする。
static func angle_of(degrees: float) -> float:
	return deg_to_rad(degrees - 90.0)


## 道のりの、Sの角度（Gから、時計まわりに数えた度。360を超えない）。レースの距離が長いほど、大きい。
static func distance_start_deg(race_distance_m: float) -> float:
	return DISTANCE_GOAL_DEG + minf(race_distance_m * DISTANCE_DEG_PER_M, 350.0)


## 道のりの上の場所（スタートから done_m 進んだ所）の角度。Sから、反時計まわりにGへ向かう。
static func distance_deg(race_distance_m: float, done_m: float) -> float:
	var start := distance_start_deg(race_distance_m)
	return lerpf(start, DISTANCE_GOAL_DEG, clampf(done_m / maxf(race_distance_m, 0.001), 0.0, 1.0))


## 体力の割合（1＝満タン、0＝空、マイナス＝借り。−1まで）の、弧の上の角度。
static func stamina_deg(fuel_ratio: float) -> float:
	if fuel_ratio >= 0.0:
		return lerpf(STAMINA_ZERO_DEG, STAMINA_FULL_DEG, clampf(fuel_ratio, 0.0, 1.0))
	return lerpf(STAMINA_ZERO_DEG, STAMINA_DEBT_DEG, clampf(-fuel_ratio, 0.0, 1.0))


func _s(value: float) -> float:
	return value * _radius / BASE_RADIUS


func _draw() -> void:
	_center = size * 0.5
	_thin_gaps.clear()
	_wide_gaps.clear()
	_glyphs.clear()
	var font := get_theme_default_font()
	draw_circle(_center, _radius, COLOR_FACE)
	draw_arc(_center, _radius + _s(1.5), 0.0, TAU, 96, COLOR_RIM_LINE, _s(1.2), true)
	_draw_course_ring()
	_draw_heart(font)
	_draw_left_gauges()
	_draw_right_gauges()
	_draw_gap_lines()
	_draw_heart_value(font)
	_draw_texts(font)
	_draw_glyphs(font)


func _arc(radius: float, width: float, from_deg: float, to_deg: float, color: Color) -> void:
	if is_equal_approx(from_deg, to_deg):
		return
	var points := maxi(int(absf(to_deg - from_deg)) + 2, 3)
	draw_arc(_center, _s(radius), angle_of(from_deg), angle_of(to_deg), points, color, _s(width), true)


## 段々のゲージを1本描く。count 段のうち、lit_from 〜 lit_to の段に色を付ける。
## color_at は、ゲージの中の位置（0＝始まり、1＝終わり）から色を決める。wide_gaps は、すき間を広くする境目の番号。
## 軽く描くために、色の付いた部分は1本の帯で描き、その上に、段の境目の線を引く。
func _gauge(radius: float, from_deg: float, to_deg: float, count: int, lit_from: int, lit_to: int, color_at: Callable, wide_gaps: Array = []) -> void:
	if count <= 0:
		return
	_arc(radius, BAND_WIDTH, from_deg, to_deg, COLOR_SLOT)
	var cell := (to_deg - from_deg) / float(count)
	lit_from = clampi(lit_from, 0, count)
	lit_to = clampi(lit_to, 0, count)
	if lit_to > lit_from:
		var a0 := from_deg + cell * float(lit_from)
		var a1 := from_deg + cell * float(lit_to)
		var steps := maxi(int(absf(a1 - a0) / 1.5) + 1, 2)
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		var glow := PackedColorArray()
		for step in steps + 1:
			var deg := lerpf(a0, a1, float(step) / float(steps))
			var color: Color = color_at.call((deg - from_deg) / (to_deg - from_deg))
			points.append(_center + Vector2.RIGHT.rotated(angle_of(deg)) * _s(radius))
			colors.append(color)
			glow.append(Color(color, GLOW_ALPHA))
		draw_polyline_colors(points, glow, _s(BAND_WIDTH + GLOW_EXTRA), true)
		draw_polyline_colors(points, colors, _s(BAND_WIDTH), true)
	var half := (BAND_WIDTH + GLOW_EXTRA) * 0.5 + 1.0
	for index in range(1, count):
		_add_gap_line(radius, half, from_deg + cell * float(index), index in wide_gaps)


## 段の境目の線を、1本ためる。線は、あとでまとめて描く（1本ずつ描くと、数が多くて重いため）。
func _add_gap_line(radius: float, half: float, deg: float, wide: bool) -> void:
	var direction := Vector2.RIGHT.rotated(angle_of(deg))
	var points := _wide_gaps if wide else _thin_gaps
	points.append(_center + direction * _s(radius - half))
	points.append(_center + direction * _s(radius + half))
	if wide:
		_wide_gaps = points
	else:
		_thin_gaps = points


## ためておいた段の境目の線を、太さごとに、まとめて描く。
func _draw_gap_lines() -> void:
	if not _thin_gaps.is_empty():
		draw_multiline(_thin_gaps, COLOR_GAP, maxf(_s(GAP_LINE_WIDTH), 1.0))
	if not _wide_gaps.is_empty():
		draw_multiline(_wide_gaps, COLOR_GAP, maxf(_s(WIDE_GAP_LINE_WIDTH), 1.0))


func _lit_course(from_deg: float, to_deg: float) -> void:
	_arc(COURSE_RADIUS, COURSE_WIDTH + GLOW_EXTRA, from_deg, to_deg, Color(COLOR_DISTANCE_DONE, GLOW_ALPHA))
	_arc(COURSE_RADIUS, COURSE_WIDTH, from_deg, to_deg, COLOR_DISTANCE_DONE)


## 一番外：レースの道のり。走り終えたぶん（水色）、残り（うすい黄色）、使わない部分（黒い刻み）、自分の印と、ほかのプルの点。
func _draw_course_ring() -> void:
	var font := get_theme_default_font()
	var distance := float(_state["race_distance_m"])
	var done := clampf(distance - float(_state["remaining_m"]), 0.0, distance)
	var start_deg := distance_start_deg(distance)
	var own_deg := distance_deg(distance, done)
	_arc(COURSE_RADIUS, COURSE_WIDTH, DISTANCE_GOAL_DEG, own_deg, COLOR_COURSE)
	_lit_course(own_deg, start_deg)
	# 使わない部分（Sから時計まわりに、Gまで）は、黒い刻み。
	var unused_from := start_deg
	var unused_to := DISTANCE_GOAL_DEG + 360.0
	var ticks := maxi(int((unused_to - unused_from) / UNUSED_TICK_DEG), 1)
	var step := (unused_to - unused_from) / float(ticks)
	_arc(COURSE_RADIUS, COURSE_WIDTH, unused_from, unused_to, COLOR_SLOT)
	for index in range(1, ticks):
		_add_gap_line(COURSE_RADIUS, COURSE_WIDTH * 0.5, unused_from + step * float(index), false)
	for runner: Dictionary in _state["runners"]:
		if bool(runner.get("player", false)):
			continue
		var at := _center + Vector2.RIGHT.rotated(angle_of(distance_deg(distance, float(runner.get("ratio", 0.0)) * distance))) * _s(COURSE_RADIUS)
		draw_circle(at, _s(4.2), COLOR_OUTLINE)
		draw_circle(at, _s(3.2), runner.get("color", Color.WHITE))
	var own := _center + Vector2.RIGHT.rotated(angle_of(own_deg)) * _s(COURSE_RADIUS)
	draw_circle(own, _s(11.0), Color(COLOR_SELF, 0.3))
	draw_circle(own, _s(7.5), Color.WHITE)
	draw_circle(own, _s(5.5), COLOR_SELF)
	# S・G と、進んだ距離は、輪の上に、輪に沿わせて書く。
	# S と G の位置には、輪を横切る茶色のバー。
	for bar_deg: float in [start_deg, DISTANCE_GOAL_DEG]:
		var direction := Vector2.RIGHT.rotated(angle_of(bar_deg))
		draw_line(_center + direction * _s(COURSE_RADIUS - COURSE_WIDTH * 0.5 - GATE_BAR_OVER), _center + direction * _s(COURSE_RADIUS + COURSE_WIDTH * 0.5 + GATE_BAR_OVER), COLOR_OUTLINE, _s(GATE_BAR_WIDTH + 2.0), true)
		draw_line(_center + direction * _s(COURSE_RADIUS - COURSE_WIDTH * 0.5 - GATE_BAR_OVER), _center + direction * _s(COURSE_RADIUS + COURSE_WIDTH * 0.5 + GATE_BAR_OVER), COLOR_GATE_BAR, _s(GATE_BAR_WIDTH), true)
	_arc_text(font, COURSE_RADIUS, start_deg + GATE_LETTER_DEG, "S", 20, COLOR_TEXT)
	_arc_text(font, COURSE_RADIUS, DISTANCE_GOAL_DEG + 360.0 - GATE_LETTER_DEG, "G", 20, RaceHud.COLOR_GOLD)
	var distance_text := "%dm / %dm" % [int(round(done)), int(round(distance))]
	if DISTANCE_GOAL_DEG + 360.0 - start_deg >= 50.0:
		_arc_text(font, COURSE_RADIUS, DISTANCE_GOAL_DEG + 360.0 - 36.0, distance_text, 16, COLOR_TEXT)


## 左の3本：内から、空気抵抗の軽減（緑＝空力、青＝集団）、速さ、ノッチ。
func _draw_left_gauges() -> void:
	var aero := float(_state["air_green"]) / AERO_FULL
	var total := aero + float(_state["air_blue"]) / AERO_FULL
	_gauge(INNER_RADIUS, LEFT_FROM_DEG, AERO_TO_DEG, AERO_SEGMENTS, 0, roundi(total * float(AERO_SEGMENTS)), func(ratio: float) -> Color:
		return COLOR_AERO if ratio < aero else COLOR_DRAFT)
	_gauge(MIDDLE_RADIUS, LEFT_FROM_DEG, SPEED_TO_DEG, SPEED_SEGMENTS, 0, roundi(float(_state["speed_kmh"]) / SPEED_FULL_KMH * float(SPEED_SEGMENTS)), func(ratio: float) -> Color:
		return COLOR_SPEED_LOW.lerp(COLOR_SPEED_HIGH, ratio))
	# ノッチは、上のノッチほど段の数が多い（＝長い）。ノッチの境目は、すき間を広くする。色は、位置で少しずつ変わる。
	var notch := clampi(int(_state["notch"]), 1, NOTCH_MAX)
	var borders: Array = []
	for level in range(2, NOTCH_MAX + 1):
		borders.append(notch_cells_before(level))
	_gauge(OUTER_RADIUS, LEFT_FROM_DEG, NOTCH_TO_DEG, notch_cells_before(NOTCH_MAX + 1), 0, notch_cells_before(notch + 1), notch_gradient, borders)


## 右の3本：内から、ブースト、ダッシュ、体力（色は位置で決まる。白い線が0%）。
func _draw_right_gauges() -> void:
	var fuel := float(_state["fuel_ratio"])
	var span := STAMINA_DEBT_DEG - STAMINA_FULL_DEG
	var zero_cell := roundi((STAMINA_ZERO_DEG - STAMINA_FULL_DEG) / span * float(STAMINA_SEGMENTS))
	var level_cell := roundi((stamina_deg(fuel) - STAMINA_FULL_DEG) / span * float(STAMINA_SEGMENTS))
	# 0より上は、今の体力から0まで。借りのあいだは、0から今の位置まで。
	_gauge(OUTER_RADIUS, STAMINA_FULL_DEG, STAMINA_DEBT_DEG, STAMINA_SEGMENTS, mini(level_cell, zero_cell), maxi(level_cell, zero_cell), func(ratio: float) -> Color:
		var deg := lerpf(STAMINA_FULL_DEG, STAMINA_DEBT_DEG, ratio)
		return RaceHud.fuel_color(inverse_lerp(STAMINA_ZERO_DEG, STAMINA_FULL_DEG, deg) if deg <= STAMINA_ZERO_DEG else -inverse_lerp(STAMINA_ZERO_DEG, STAMINA_DEBT_DEG, deg)))
	_arc(OUTER_RADIUS, BAND_WIDTH + 4.0, STAMINA_ZERO_DEG - 0.9, STAMINA_ZERO_DEG + 0.9, Color.WHITE)
	# ブーストは、1回ぶんを BOOST_CELLS 段で描く。回の境目は、すき間を広くする。
	# 残っている回数ぶんに色を付ける。使っている最中の1回は、残り時間ぶんだけ、明るい色を付ける。
	var uses := int(_state["boost_max_uses"])
	var left := clampi(int(_state["boost_uses_left"]), 0, uses)
	var boost_borders: Array = []
	for index in range(1, uses):
		boost_borders.append(index * BOOST_CELLS)
	var boost_lit := left * BOOST_CELLS + (roundi(float(_state["boost_ratio"]) * float(BOOST_CELLS)) if left < uses else 0)
	var left_ratio := float(left) / float(maxi(uses, 1))
	_gauge(INNER_RADIUS, BOOST_FROM_DEG, BOOST_TO_DEG, uses * BOOST_CELLS, 0, boost_lit, func(ratio: float) -> Color:
		return COLOR_BOOST if ratio <= left_ratio else COLOR_BOOST.lerp(Color.WHITE, 0.35), boost_borders)
	_gauge(MIDDLE_RADIUS, DASH_FROM_DEG, DASH_TO_DEG, GAUGE_SEGMENTS, 0, roundi(float(_state["dash_ratio"]) * float(GAUGE_SEGMENTS)), func(_ratio: float) -> Color: return COLOR_DASH)


## そのノッチの段の数（上のノッチほど多い）。
static func notch_cells(level: int) -> int:
	return NOTCH_CELLS + NOTCH_CELLS_STEP * (level - 1)


## そのノッチより下のノッチの、段の数の合計。
static func notch_cells_before(level: int) -> int:
	var total := 0
	for lower in range(1, level):
		total += notch_cells(lower)
	return total


## ノッチのゲージの色。位置（0＝一番下、1＝一番上）で、緑→黄→赤へ変わる。
static func notch_gradient(position: float) -> Color:
	if position < 0.5:
		return RaceHud.COLOR_OK.lerp(COLOR_NOTCH, position * 2.0)
	return COLOR_NOTCH.lerp(RaceHud.COLOR_DANGER, (position - 0.5) * 2.0)


## タイムの書き方（分:秒:100分の1秒）。
static func clock_text(seconds: float) -> String:
	var hundredths := int(floor(maxf(seconds, 0.0) * 100.0))
	return "%d:%02d:%02d" % [hundredths / 6000, (hundredths / 100) % 60, hundredths % 100]


## 順位の色。1〜3位は、金・銀・銅。
static func place_color(place: int) -> Color:
	match place:
		1: return RaceHud.COLOR_GOLD
		2: return RaceHud.COLOR_SILVER
		3: return RaceHud.COLOR_BRONZE
	return COLOR_TEXT


## まん中：ハート。下から、心拍の高さまで色を塗る。まん中に、心拍数。
func _draw_heart(font: Font) -> void:
	var heart_state := {"heart_bpm": _state["heart_bpm"], "heart_min_bpm": _state["heart_min_bpm"], "heart_normal_max_bpm": _state["heart_normal_max_bpm"], "heart_max_bpm": _state["heart_max_bpm"]}
	var fill := clampf(inverse_lerp(float(_state["heart_min_bpm"]), float(_state["heart_max_bpm"]), float(_state["heart_bpm"])), 0.0, 1.0)
	var shape := _heart_points(HEART_SIZE)
	# 鼓動の強さ（音が鳴った瞬間が1、そこからすっと消える）。空の段と、外のピンクのふちを、これで光らせる。
	var beat := beat_glow(float(_state["heart_beat_phase"]))
	draw_colored_polygon(_heart_points(HEART_SIZE + 9.0 + 5.0 * beat), Color(COLOR_HEART_EDGE, 0.22 + 0.5 * beat))
	draw_colored_polygon(_heart_points(HEART_SIZE + 2.5 + 1.5 * beat), COLOR_HEART_EDGE.lerp(Color.WHITE, HEART_BEAT_EDGE_GLOW * beat))
	draw_colored_polygon(shape, COLOR_HEART_BACK)
	# 下から段々に、心拍の高さまで色を付ける（形を、段ごとに切る）。
	var top := INF
	var bottom := -INF
	for point in shape:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var step := (bottom - top) / float(HEART_STEPS)
	for index in HEART_STEPS:
		var y1 := bottom - step * float(index)
		var y0 := y1 - step + _s(HEART_STEP_GAP)
		var lit := (float(index) + 0.5) / float(HEART_STEPS) < fill
		for part: PackedVector2Array in Geometry2D.intersect_polygons(shape, PackedVector2Array([Vector2(-1e4, y0), Vector2(1e4, y0), Vector2(1e4, y1), Vector2(-1e4, y1)])):
			# 細すぎて面にできない切れはしは、描かない。
			if part.size() >= 3 and not Geometry2D.triangulate_polygon(part).is_empty():
				draw_colored_polygon(part, RaceHud.heart_color(heart_state) if lit else COLOR_HEART_EMPTY.lerp(COLOR_HEART_BEAT, HEART_BEAT_EMPTY_GLOW * beat))


## 鼓動の光の強さ。phase は、鼓動の進み具合（0＝音が鳴った瞬間、1＝次の音の直前）。
static func beat_glow(phase: float) -> float:
	var fade := clampf(1.0 - phase / HEART_BEAT_PART, 0.0, 1.0)
	return fade * fade


## ハートの形を、決めた位置・縦の縮め具合で作る。
func _heart_points(size_units: float) -> PackedVector2Array:
	var center := _center + Vector2(0.0, _s(HEART_DOWN))
	var points := heart_shape(center, _s(size_units))
	for index in points.size():
		points[index].x = center.x + (points[index].x - center.x) * HEART_NARROW
		points[index].y = center.y + (points[index].y - center.y) * HEART_SQUASH
	return points


## 心拍数は、ゲージより手前に書く。
func _draw_heart_value(font: Font) -> void:
	var center := _center + Vector2(0.0, _s(HEART_DOWN))
	var text := "%d" % int(round(float(_state["heart_bpm"])))
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_s(52.0)))
	_text(font, center + Vector2(-_s(12.0), _s(6.0)), text, 52, COLOR_TEXT)
	_text(font, center + Vector2(text_size.x * 0.5 + _s(6.0), _s(6.0)), "bpm", 15, COLOR_TEXT)


## ハートの形（数式で作った点の並び）。size は、まん中から横の端までの、おおよその長さ。
static func heart_shape(center: Vector2, size_px: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 60:
		var t := TAU * float(index) / 60.0
		points.append(center + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)) - 2.0) * size_px / 16.0)
	return points


func _draw_texts(font: Font) -> void:
	# 左の3本：それぞれの弧の、上の延長に、名前と値を書く。
	_arc_label(font, INNER_RADIUS, AERO_LABEL_DEG, "aero ", "%d" % int(round((float(_state["air_green"]) + float(_state["air_blue"])) * 100.0)), "%")
	_arc_label(font, MIDDLE_RADIUS, SPEED_LABEL_DEG, "", "%d" % int(round(float(_state["speed_kmh"]))), " km/h")
	_arc_label(font, OUTER_RADIUS, NOTCH_LABEL_DEG, "Notch ", "%d" % clampi(int(_state["notch"]), 1, NOTCH_MAX), "")
	# 右の3本：それぞれの弧の、下の延長に、（ボタンの印と）名前と値を書く。
	_arc_label(font, OUTER_RADIUS, STAMINA_LABEL_DEG, "Stam. ", "%d" % int(round(float(_state["fuel_ratio"]) * 100.0)), "%")
	ButtonMark.draw_mark(self, font, _center + Vector2.RIGHT.rotated(angle_of(BOOST_MARK_DEG)) * _s(INNER_RADIUS), "X", _s(18.0))
	_arc_label(font, INNER_RADIUS, BOOST_LABEL_DEG, "Boost(", "%d" % int(_state["boost_uses_left"]), ")")
	ButtonMark.draw_mark(self, font, _center + Vector2.RIGHT.rotated(angle_of(DASH_MARK_DEG)) * _s(MIDDLE_RADIUS), "B", _s(18.0))
	_arc_label(font, MIDDLE_RADIUS, DASH_LABEL_DEG, "Dash(", "∞", ")")
	# 下のすき間：順位とタイム。
	# 順位は大きく（1〜3位は、金・銀・銅）。「/8」は小さく、右下に添える。
	if int(_state["place"]) > 0:
		var place_text := "%d" % int(_state["place"])
		var place_px := maxi(int(round(_s(54.0))), 6)
		var place_width := font.get_string_size(place_text, HORIZONTAL_ALIGNMENT_LEFT, -1, place_px).x
		_text(font, _center + Vector2(_s(-6.0), _s(119.0)), place_text, 54, place_color(int(_state["place"])))
		_text(font, _center + Vector2(_s(-6.0) + place_width * 0.5 + _s(17.0), _s(119.0)), "/%d" % int(_state["field_size"]), 21, RaceHud.COLOR_DIM)
	_arc_text(font, TIME_RADIUS, TIME_DEG, clock_text(float(_state["time_s"])), 24, COLOR_TEXT)
	# 名前（とトレーナー名）は、輪の外の右下に、輪に沿わせて書く。
	var name_text := str(_state["player_name"])
	if not str(_state["trainer_name"]).is_empty():
		name_text += "（%s）" % _state["trainer_name"]
	_arc_text(font, BASE_RADIUS + NAME_OUTSIDE, NAME_DEG, name_text, NAME_SIZE, COLOR_TEXT)
	# 属性の印と、脚質の印は、輪の外の左下に、輪に沿わせて並べる。
	if not str(_state["attribute_id"]).is_empty():
		var mark_at := _center + Vector2.RIGHT.rotated(angle_of(ATTRIBUTE_DEG)) * _s(BASE_RADIUS + NAME_OUTSIDE)
		draw_circle(mark_at, _s(ATTRIBUTE_SIZE * 0.5 + 3.0), COLOR_OUTLINE)
		PururinDetail.draw_attribute_mark(self, mark_at, _s(ATTRIBUTE_SIZE), str(_state["attribute_id"]), _state["attribute_color"])
	if int(_state["style_group_count"]) > 0:
		var style_angle := angle_of(STYLE_DEG)
		draw_set_transform(_center + Vector2.RIGHT.rotated(style_angle) * _s(BASE_RADIUS + NAME_OUTSIDE), style_angle - PI * 0.5, Vector2.ONE)
		# 名前の文字と同じように、暗いふちを先に描く（輪の外でも読めるように）。
		var chevron_scale := _s(STYLE_SCALE)
		for index in int(_state["style_group_count"]):
			var tip := Vector2(index * RaceHud.STYLE_CHEVRON_STEP * chevron_scale, 0.0)
			var own := index == int(_state["style_group_index"])
			draw_polyline(PackedVector2Array([tip + Vector2(5.0, -6.5) * chevron_scale, tip, tip + Vector2(5.0, 6.5) * chevron_scale]), COLOR_OUTLINE, (5.6 if own else 3.6) * chevron_scale, true)
		RaceHud.draw_style_chevrons(self, Vector2.ZERO, RaceHud.style_state_color(int(_state["style_rank_bonus"])), int(_state["style_group_count"]), int(_state["style_group_index"]), chevron_scale)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## ゲージの文字（名前・数値・単位）を、輪に沿わせて書く。数値だけ、大きく黄色。
func _arc_label(font: Font, radius: float, center_deg: float, word: String, value: String, unit: String) -> void:
	_arc_runs(font, radius, center_deg, [[word, WORD_SIZE, COLOR_TEXT], [value, VALUE_SIZE, COLOR_VALUE], [unit, WORD_SIZE, COLOR_TEXT]])


## 文字を、輪に沿わせて書く。center_deg が、文字のまん中の角度。
func _arc_text(font: Font, radius: float, center_deg: float, text: String, font_size: int, color: Color) -> void:
	_arc_runs(font, radius, center_deg, [[text, font_size, color]])


## 大きさ・色の違う文字のならび（runs＝[文字, 大きさ, 色] の並び）を、輪に沿わせて書く。
## 上半分では、文字の頭を外へ向けて、時計まわりに並べる。下半分では、頭を内へ向けて、反時計まわりに並べる（さかさまにしない）。
func _arc_runs(font: Font, radius: float, center_deg: float, runs: Array) -> void:
	var glyphs: Array = []
	var total := 0.0
	var biggest := 0
	for run: Array in runs:
		var px := maxi(int(round(_s(float(run[1])))), 6)
		biggest = maxi(biggest, px)
		for index in str(run[0]).length():
			var character := str(run[0])[index]
			var width := font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			glyphs.append([character, px, run[2], width])
			total += width
	var direction := 1.0 if arc_text_is_upper(center_deg) else -1.0
	# 文字の下の線（ベースライン）が通る半径。一番大きい文字のまん中が、指定の半径に来るようにずらす。
	var baseline_radius := _s(radius) - direction * float(biggest) * 0.36
	var cursor_deg := center_deg - direction * rad_to_deg(total / baseline_radius) * 0.5
	for glyph: Array in glyphs:
		var width := float(glyph[3])
		var angle := angle_of(cursor_deg + direction * rad_to_deg(width / baseline_radius) * 0.5)
		_glyphs.append([_center + Vector2.RIGHT.rotated(angle) * baseline_radius, angle + direction * PI * 0.5, Vector2(-width * 0.5, 0.0), glyph[0], glyph[1], glyph[2]])
		cursor_deg += direction * rad_to_deg(width / baseline_radius)


## その角度（12時を0として時計まわり）が、輪の上半分か。
static func arc_text_is_upper(degrees: float) -> bool:
	var wrapped := fposmod(degrees, 360.0)
	return wrapped <= 90.0 or wrapped >= 270.0


## 文字を、まん中ぞろえで、ふち付きで出す。
func _text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var px := maxi(int(round(_s(float(font_size)))), 6)
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_glyphs.append([Vector2.ZERO, 0.0, at - Vector2(width * 0.5, 0.0), text, px, color])


## ためておいた文字を、まとめて描く（1文字ずつ描くと、命令の数が多くて重いため）。文字は、ほかの絵より手前に出る。
func _draw_glyphs(font: Font) -> void:
	var outline := maxi(int(_s(4.0)), 2)
	for glyph: Array in _glyphs:
		_glyph_batch.add(font, glyph[3], glyph[4], glyph[2], glyph[5], outline, COLOR_OUTLINE, Transform2D(float(glyph[1]), glyph[0]))
	_glyph_batch.flush(self)
