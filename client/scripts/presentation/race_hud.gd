extends Control
## ローカルレースの常時表示HUD。数値の羅列ではなく、走りながら読める4つ
## （速度・ノッチ・燃料・心拍）を画面下中央に大きく描く。詳細な診断はデバッグ表示（F3）へ分ける。
## 値は update_state() で受け取り、計算はここでは行わない（表示用の割合と色だけ）。

const PANEL_WIDTH := 600.0
const PANEL_HEIGHT := 164.0
## 下端のガイド文（GuideLabel）の上に置く余白。
const PANEL_BOTTOM_MARGIN := 84.0
const NOTCH_COUNT := 7

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
	"drafting": false,
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
	if bool(_state["drafting"]):
		_draw_text(font, "ドラフト", origin + Vector2(0.0, 154.0), 22, COLOR_COOL)


func _draw_main_panel(font: Font) -> void:
	# 親が CanvasLayer の場合は Control の size が当てにならないため、ビューポートの大きさを使う。
	var screen := get_viewport_rect().size
	var panel := Rect2(
		Vector2((screen.x - PANEL_WIDTH) * 0.5, screen.y - PANEL_BOTTOM_MARGIN - PANEL_HEIGHT),
		Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	)
	draw_rect(panel, COLOR_PANEL)
	var braking := bool(_state["braking"])
	# 左：速度
	var speed_origin := panel.position + Vector2(24.0, 92.0)
	_draw_text(font, "%d" % int(roundf(float(_state["speed_kmh"]))), speed_origin, 76, COLOR_TEXT)
	_draw_text(font, "km/h", speed_origin + Vector2(0.0, 30.0), 22, COLOR_DIM)
	# 右：ノッチ・燃料・心拍
	var bars_left := panel.position.x + 230.0
	var bars_width := PANEL_WIDTH - 230.0 - 24.0
	_draw_notch(font, Vector2(bars_left, panel.position.y + 18.0), bars_width, braking)
	_draw_gauge(
		font, "燃料", Vector2(bars_left, panel.position.y + 90.0), bars_width,
		fuel_fill_ratio(float(_state["fuel_ratio"])), fuel_color(float(_state["fuel_ratio"])),
		-1.0, "負債" if fuel_is_in_debt(_state) else ""
	)
	var heart_color_now := heart_color(_state)
	if heart_is_overheated(_state) and _blink > 0.5:
		heart_color_now = heart_color_now.lightened(0.35)
	_draw_gauge(
		font, "心拍", Vector2(bars_left, panel.position.y + 126.0), bars_width,
		heart_fill_ratio(_state), heart_color_now, heart_limit_ratio(_state),
		"%d" % int(roundf(float(_state["heart_bpm"])))
	)
	if bool(_state["countdown"]):
		_draw_text(font, "↑↓で開始ノッチを選択", Vector2(panel.position.x + 24.0, panel.position.y - 10.0), 20, COLOR_TEXT)


func _draw_notch(font: Font, origin: Vector2, width: float, braking: bool) -> void:
	var notch := int(_state["notch"])
	var gap := 6.0
	var segment_width := (width - gap * (NOTCH_COUNT - 1)) / NOTCH_COUNT
	for index in NOTCH_COUNT:
		var rect := Rect2(origin + Vector2(index * (segment_width + gap), 0.0), Vector2(segment_width, 24.0))
		var active := index <= notch and index > 0
		var color := COLOR_TRACK
		if active:
			color = COLOR_DIM if braking else COLOR_OK.lerp(COLOR_WARN, float(index) / float(NOTCH_COUNT - 1))
		draw_rect(rect, color)
		if index == notch:
			draw_rect(rect.grow(2.0), COLOR_TEXT, false, 2.0)
	var label := "ブレーキ" if braking else "ノッチ %d" % notch
	_draw_text(font, label, origin + Vector2(0.0, 52.0), 22, COLOR_DANGER if braking else COLOR_TEXT)


func _draw_gauge(font: Font, title: String, origin: Vector2, width: float, ratio: float, color: Color, mark_ratio: float, value_text: String) -> void:
	var label_width := 56.0
	_draw_text(font, title, origin + Vector2(0.0, 16.0), 20, COLOR_DIM)
	var track := Rect2(origin + Vector2(label_width, 2.0), Vector2(width - label_width - 52.0, 16.0))
	draw_rect(track, COLOR_TRACK)
	draw_rect(Rect2(track.position, Vector2(track.size.x * ratio, track.size.y)), color)
	if mark_ratio >= 0.0:
		var x := track.position.x + track.size.x * mark_ratio
		draw_line(Vector2(x, track.position.y - 3.0), Vector2(x, track.end.y + 3.0), COLOR_TEXT, 2.0)
	if not value_text.is_empty():
		_draw_text(font, value_text, Vector2(track.end.x + 8.0, origin.y + 16.0), 20, color)


func _draw_text(font: Font, text: String, position: Vector2, font_size: int, color: Color) -> void:
	# 背景に溶けないよう、暗い縁取りを付ける。
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 6, Color(0.03, 0.05, 0.1, 0.9))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
