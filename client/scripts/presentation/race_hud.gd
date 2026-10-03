extends Control
## ローカルレースの常時表示HUD。数値の羅列ではなく、走りながら読める4つ
## （速度・ノッチ・心拍・体力）を画面下中央に大きく描く。詳細な診断はデバッグ表示（F3）へ分ける。
## 値は update_state() で受け取り、計算はここでは行わない（表示用の割合と色だけ）。

const PANEL_WIDTH := 440.0
const PANEL_HEIGHT := 196.0
## 画面下端からの余白。
const PANEL_BOTTOM_MARGIN := 20.0
const NOTCH_COUNT := 7
const DRAFT_SEGMENTS := 10
## ドラフトゲージの満タン。「前の走者1頭が真後ろにぴったりいる強さ」の何倍で10段になるか。
## 走行に効く実効率は頭打ちになるため、ゲージは頭打ちにならない受取量（基準比）で表し、集団が大きいほど伸びる。
const DRAFT_GAUGE_FULL_STRENGTH := 5.0

const COLOR_PANEL := Color(0.05, 0.08, 0.14, 0.72)
const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.62, 0.68, 0.78, 1.0)
const COLOR_TRACK := Color(1.0, 1.0, 1.0, 0.16)
const COLOR_OK := Color(0.36, 0.86, 0.52, 1.0)
const COLOR_WARN := Color(1.0, 0.76, 0.25, 1.0)
const COLOR_DANGER := Color(1.0, 0.32, 0.28, 1.0)
const COLOR_COOL := Color(0.36, 0.72, 1.0, 1.0)

var _state := {
	"place": 0,
	"field_size": 0,
	"remaining_m": 0.0,
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
	"draft_strength": 0.0,
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


## 燃料の表示割合。0未満（負債）は0として、負債は色と文字で伝える。
static func fuel_fill_ratio(fuel_ratio: float) -> float:
	return clampf(fuel_ratio, 0.0, 1.0)


static func fuel_is_in_debt(state: Dictionary) -> bool:
	return float(state.get("fuel_ratio", 1.0)) < 0.0


static func fuel_color(fuel_ratio: float) -> Color:
	if fuel_ratio < 0.0:
		return COLOR_DANGER
	if fuel_ratio < 0.2:
		return COLOR_DANGER
	if fuel_ratio < 0.45:
		return COLOR_WARN
	return COLOR_OK


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


## ドラフトの受取量（基準比）を10段階の点灯数へ。少しでも受けていれば1つは点く。
static func draft_segments(strength: float) -> int:
	if strength <= 0.0:
		return 0
	return clampi(ceili(strength / DRAFT_GAUGE_FULL_STRENGTH * DRAFT_SEGMENTS - 0.0001), 1, DRAFT_SEGMENTS)


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
	var speed_origin := panel.position + Vector2(24.0, 96.0)
	_draw_text(font, "%d" % int(roundf(float(_state["speed_kmh"]))), speed_origin, 76, COLOR_TEXT)
	_draw_text(font, "km/h", speed_origin + Vector2(0.0, 30.0), 22, COLOR_DIM)
	_draw_draft_gauge(font, panel.position + Vector2(24.0, 168.0))
	# 右：縦ゲージ3本（ノッチ・心拍・体力）
	var gauge_top := panel.position.y + 18.0
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
	_draw_vertical_gauge(
		font, "体力", Vector2(left + column * 2.0, gauge_top), fuel_fill_ratio(fuel), fuel_color(fuel),
		-1.0, "負債" if fuel_is_in_debt(_state) else "%d%%" % int(roundf(fuel * 100.0))
	)
	if bool(_state["countdown"]):
		_draw_text(font, "↑↓で開始ノッチを選択", Vector2(panel.position.x + 24.0, panel.position.y - 10.0), 20, COLOR_TEXT)


func _draw_draft_gauge(font: Font, origin: Vector2) -> void:
	var lit := draft_segments(float(_state["draft_strength"]))
	_draw_text(font, "ドラフト", origin + Vector2(0.0, -6.0), 16, COLOR_DIM)
	var segment_width := 14.0
	var gap := 3.0
	for index in DRAFT_SEGMENTS:
		var rect := Rect2(origin + Vector2(index * (segment_width + gap), 0.0), Vector2(segment_width, 14.0))
		draw_rect(rect, COLOR_COOL if index < lit else COLOR_TRACK)


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


func _draw_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	# 背景に溶けないよう、暗い縁取りを付ける。
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Color(0.03, 0.05, 0.1, 0.9))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
