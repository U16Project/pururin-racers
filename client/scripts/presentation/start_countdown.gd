extends Control
## スタート前のカウントダウン（3・2・1・START!）。
## 数字は、出た瞬間に大きく弾んで、まわりの輪が1秒かけて減っていく。START! は金色で弾けて消える。
## スタートのノッチを選ぶ案内は、start_notch_hint.gd が出す（カウントダウンの前まで）。

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

var _count := 0
## 今の数字が出てからの秒数（輪の減り方と、弾み方に使う）。
var _count_time := 0.0
var _count_seconds := 1.0
var _start_time := -1.0


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
	visible = true
	queue_redraw()


func hide_all() -> void:
	_count = 0
	_start_time = -1.0
	queue_redraw()


func is_counting() -> bool:
	return _count > 0


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


func _draw_centered(font: Font, text: String, baseline_center: Vector2, font_size: int, color: Color, outline: int, outline_color: Color = COLOR_OUTLINE) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var position := baseline_center - Vector2(width * 0.5, 0.0)
	draw_string_outline(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color(outline_color, color.a))
	draw_string(font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
