extends Control
## スタート前のカウントダウン（3・2・1・START!）と、スタートのノッチを選ぶ案内。
## 数字は、出た瞬間に大きく弾んで、まわりの輪が1秒かけて減っていく。START! は金色で弾けて消える。
## ノッチの案内は、カウントダウンの間だけ、画面の下に出す（今のノッチを、段の並びで見せる）。

const MenuStyle := preload("res://scripts/menu/menu_style.gd")

const NUMBER_SIZE := 150
const NUMBER_CENTER := Vector2(0.5, 0.34)
const RING_RADIUS := 98.0
const RING_WIDTH := 10.0
const POP_SECONDS := 0.22
const POP_SCALE := 1.45
const START_SECONDS := 0.9
const START_SIZE := 120
const COLOR_OUTLINE := Color(0.05, 0.09, 0.17, 1.0)
const COLOR_NUMBER := Color(1.0, 1.0, 1.0, 1.0)
## 数字ごとの輪の色（3・2・1）。
const RING_COLORS := {3: Color(0.35, 0.86, 1.0), 2: Color(1.0, 0.82, 0.3), 1: Color(1.0, 0.45, 0.3)}
const COLOR_START := Color(1.0, 0.84, 0.2)
const NOTCH_PANEL_SIZE := Vector2(460.0, 92.0)
const NOTCH_PANEL_BOTTOM := 96.0
const COLOR_PANEL := Color(0.06, 0.1, 0.18, 0.86)
const COLOR_PANEL_BORDER := Color(0.35, 0.86, 1.0, 0.9)
const COLOR_SEGMENT_ON := Color(0.35, 0.86, 1.0)
const COLOR_SEGMENT_OFF := Color(1.0, 1.0, 1.0, 0.16)

var _count := 0
## 今の数字が出てからの秒数（輪の減り方と、弾み方に使う）。
var _count_time := 0.0
var _count_seconds := 1.0
var _start_time := -1.0
var _notch_shown := false
var _notch := 0
var _notch_min := 1
var _notch_max := 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 数字を出す。seconds_left は、スタートまでの残りの秒数（小数のまま）。数字が変わったときだけ、弾ませる。
func show_count(seconds_left: float) -> void:
	var number := ceili(seconds_left)
	if number != _count:
		_count = number
		_count_time = 0.0
	else:
		_count_time = float(number) - seconds_left
	_start_time = -1.0
	visible = true
	queue_redraw()


func show_start() -> void:
	_count = 0
	_start_time = 0.0
	_notch_shown = false
	visible = true
	queue_redraw()


func hide_all() -> void:
	_count = 0
	_start_time = -1.0
	_notch_shown = false
	queue_redraw()


func is_counting() -> bool:
	return _count > 0


## ノッチの案内を出す・隠す。level は今のノッチ。
func set_notch(shown: bool, level: int, level_min: int, level_max: int) -> void:
	if shown == _notch_shown and level == _notch and level_min == _notch_min and level_max == _notch_max:
		return
	_notch_shown = shown
	_notch = level
	_notch_min = level_min
	_notch_max = level_max
	queue_redraw()


func _process(delta: float) -> void:
	if _start_time >= 0.0:
		_start_time += delta
		if _start_time >= START_SECONDS:
			_start_time = -1.0
		queue_redraw()


func _draw() -> void:
	var font := MenuStyle.bold_font()
	var center := size * NUMBER_CENTER
	if _count > 0:
		_draw_number(font, center)
	elif _start_time >= 0.0:
		_draw_start(font, center)
	if _notch_shown:
		_draw_notch_panel(font)


func _draw_number(font: Font, center: Vector2) -> void:
	var ring_color: Color = RING_COLORS.get(_count, RING_COLORS[1])
	var pop := clampf(_count_time / POP_SECONDS, 0.0, 1.0)
	var scale_now := lerpf(POP_SCALE, 1.0, ease(pop, 0.4))
	var alpha := clampf(pop * 2.0, 0.0, 1.0)
	# 輪：うすい地の輪の上に、残りの分だけ色の輪（上から時計回りに減る）。
	draw_arc(center, RING_RADIUS, 0.0, TAU, 64, Color(COLOR_OUTLINE, 0.6), RING_WIDTH + 6.0, true)
	var left := clampf(1.0 - _count_time / _count_seconds, 0.0, 1.0)
	if left > 0.0:
		draw_arc(center, RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * left, 64, Color(ring_color, alpha), RING_WIDTH, true)
	draw_circle(center, RING_RADIUS - RING_WIDTH, Color(COLOR_OUTLINE, 0.45 * alpha))
	var caption := "スタートまで"
	_draw_centered(font, caption, center + Vector2(0.0, -RING_RADIUS - 22.0), 26, Color(1, 1, 1, alpha), 8)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_now)
	_draw_centered(font, str(_count), Vector2(0.0, NUMBER_SIZE * 0.36), NUMBER_SIZE, Color(COLOR_NUMBER, alpha), 16, ring_color.darkened(0.55))
	draw_set_transform(Vector2.ZERO)


func _draw_start(font: Font, center: Vector2) -> void:
	var t := _start_time / START_SECONDS
	var scale_now := lerpf(0.6, 1.15, ease(clampf(t * 3.0, 0.0, 1.0), 0.3))
	var alpha := 1.0 - clampf((t - 0.6) / 0.4, 0.0, 1.0)
	# 弾ける線：真ん中から外へ、16本。
	for index in 16:
		var angle := TAU * float(index) / 16.0
		var direction := Vector2(cos(angle), sin(angle))
		var inner := lerpf(60.0, 180.0, t)
		var outer := inner + lerpf(80.0, 20.0, t)
		draw_line(center + direction * inner, center + direction * outer, Color(COLOR_START, alpha * 0.8), 5.0, true)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_now)
	_draw_centered(font, "START!", Vector2(0.0, START_SIZE * 0.36), START_SIZE, Color(COLOR_START, alpha), 18, Color(0.45, 0.2, 0.0, alpha))
	draw_set_transform(Vector2.ZERO)


## 下の案内：左に「スタートのノッチ」と上下のマーク、右に今のノッチと、段の並び。
func _draw_notch_panel(font: Font) -> void:
	var rect := Rect2(Vector2((size.x - NOTCH_PANEL_SIZE.x) * 0.5, size.y - NOTCH_PANEL_BOTTOM - NOTCH_PANEL_SIZE.y), NOTCH_PANEL_SIZE)
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL
	box.border_color = COLOR_PANEL_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(16)
	draw_style_box(box, rect)
	var left := rect.position + Vector2(22.0, 34.0)
	draw_string_outline(font, left, "スタートのノッチ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, COLOR_OUTLINE)
	draw_string(font, left, "スタートのノッチ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	# 上下の矢印（十字キー・↑↓）と、その説明。
	var arrow_center := rect.position + Vector2(36.0, 64.0)
	draw_colored_polygon(PackedVector2Array([arrow_center + Vector2(0, -12), arrow_center + Vector2(-9, -3), arrow_center + Vector2(9, -3)]), COLOR_SEGMENT_ON)
	draw_colored_polygon(PackedVector2Array([arrow_center + Vector2(0, 12), arrow_center + Vector2(-9, 3), arrow_center + Vector2(9, 3)]), COLOR_SEGMENT_ON)
	draw_string(font, rect.position + Vector2(54.0, 71.0), "十字キー・↑↓ で選ぶ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, 0.75))
	# 今のノッチ（大きな数字）と、段の並び（今の段まで光る）。
	var value_x := rect.position.x + 250.0
	draw_string_outline(font, Vector2(value_x, rect.position.y + 66.0), str(_notch), HORIZONTAL_ALIGNMENT_CENTER, 50, 48, 10, COLOR_OUTLINE)
	draw_string(font, Vector2(value_x, rect.position.y + 66.0), str(_notch), HORIZONTAL_ALIGNMENT_CENTER, 50, 48, COLOR_SEGMENT_ON)
	var count := maxi(_notch_max - _notch_min + 1, 1)
	var bars_left := value_x + 66.0
	var bars_width := rect.end.x - 20.0 - bars_left
	var step := bars_width / float(count)
	for index in count:
		var level := _notch_min + index
		var height := lerpf(16.0, 52.0, float(index) / maxf(float(count - 1), 1.0))
		var bar := Rect2(Vector2(bars_left + step * index + 2.0, rect.position.y + 74.0 - height), Vector2(step - 4.0, height))
		draw_rect(bar, COLOR_SEGMENT_ON if level <= _notch else COLOR_SEGMENT_OFF)


func _draw_centered(font: Font, text: String, baseline_center: Vector2, font_size: int, color: Color, outline: int, outline_color: Color = COLOR_OUTLINE) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var position := baseline_center - Vector2(width * 0.5, 0.0)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(outline_color, color.a))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
