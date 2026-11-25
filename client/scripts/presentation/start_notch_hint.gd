extends Control
## スタートのノッチを選ぶ案内。後ろからの画面に替わってから、カウントダウンが始まるまで出す。
## 画面のまん中より少し上に文字の箱、左上の操作盤のノッチのゲージを黄色い枠で囲み、指差しのマークでつつく。
## 箱の枠とゲージの枠は点滅し、文字は点滅しない。

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const POINTER_TEXTURE := preload("res://assets/ui/notch_pointer.png")

## 文字の箱：幅、上の端（画面の高さに対する割合）、内側の余白、角の丸み、枠の太さ。
const BOX_WIDTH := 380.0
const BOX_TOP_RATIO := 0.26
const BOX_PADDING := Vector2(28.0, 16.0)
const BOX_RADIUS := 18
const BOX_BORDER := 3
const TITLE_SIZE := 34
const SUB_SIZE := 22
const LINE_GAP := 6.0
## ゲージの囲み：角の丸み、黄色い線と、その外の紺の線の太さ。
const GAUGE_RADIUS := 14.0
const GAUGE_LINE := 4.0
const GAUGE_OUTLINE := 9.0
## 指差しのマーク：囲みの高さに対する、絵の大きさと、置く所（囲みの左上から）。
const POINTER_SIZE_RATIO := 1.07
const POINTER_OFFSET_RATIO := Vector2(0.497, 0.173)
## つつく動き：1往復の秒数と、いちばん前へ出たときのずれ（左上へ）。
const POKE_SECONDS := 0.7
const POKE_OFFSET := Vector2(-18.0, -7.0)
## 点滅：1往復の秒数と、いちばん暗いときの濃さ。
const BLINK_SECONDS := 1.2
const BLINK_MIN_ALPHA := 0.35
const COLOR_BOX := Color(20.0 / 255.0, 30.0 / 255.0, 52.0 / 255.0, 0.88)
const COLOR_YELLOW := Color("#ffd23f")
const COLOR_NAVY := Color("#0b1424")
const COLOR_ARROW := Color("#4cc9ff")
const COLOR_SUB := Color("#dfe8f5")
const TITLE_TEXT := "スタートのノッチ"
const SUB_TEXT := "十字キー・↑↓ で選ぶ"

var _gauge_rect := Rect2()
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## 出す・隠す。gauge_rect は、画面の上のノッチのゲージを囲む四角。
func set_shown(shown: bool, gauge_rect: Rect2 = Rect2()) -> void:
	if shown and not visible:
		_time = 0.0
	visible = shown
	_gauge_rect = gauge_rect


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


## 点滅の濃さ（1 から BLINK_MIN_ALPHA の間を、なめらかに行き来する）。
static func blink_alpha(seconds: float) -> float:
	var wave := 0.5 + 0.5 * cos(TAU * seconds / BLINK_SECONDS)
	return lerpf(BLINK_MIN_ALPHA, 1.0, wave)


## つつく動きのずれ（はじめは0、半分の時にいちばん前）。
static func poke_offset(seconds: float) -> Vector2:
	var wave := 0.5 - 0.5 * cos(TAU * seconds / POKE_SECONDS)
	return POKE_OFFSET * wave


## 文字の箱の四角。
func box_rect() -> Rect2:
	var font := MenuStyle.bold_font()
	var height := BOX_PADDING.y * 2.0 + float(BOX_BORDER) * 2.0 + font.get_height(TITLE_SIZE) + LINE_GAP + font.get_height(SUB_SIZE)
	return Rect2(Vector2((size.x - BOX_WIDTH) * 0.5, size.y * BOX_TOP_RATIO), Vector2(BOX_WIDTH, height))


func _draw() -> void:
	var alpha := blink_alpha(_time)
	if _gauge_rect.size.y > 0.0:
		_draw_gauge_frame(alpha)
	_draw_box(alpha)
	if _gauge_rect.size.y > 0.0:
		var side := _gauge_rect.size.y * POINTER_SIZE_RATIO
		var top_left := _gauge_rect.position + _gauge_rect.size.y * POINTER_OFFSET_RATIO + poke_offset(_time)
		draw_texture_rect(POINTER_TEXTURE, Rect2(top_left, Vector2(side, side)), false)


func _draw_gauge_frame(alpha: float) -> void:
	_draw_round_frame(_gauge_rect, GAUGE_RADIUS, GAUGE_OUTLINE, Color(COLOR_NAVY, alpha))
	_draw_round_frame(_gauge_rect, GAUGE_RADIUS, GAUGE_LINE, Color(COLOR_YELLOW, alpha))


func _draw_round_frame(rect: Rect2, radius: float, width: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(int(round(width)))
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	var half := width * 0.5
	draw_style_box(box, rect.grow(half))


func _draw_box(alpha: float) -> void:
	var rect := box_rect()
	var back := StyleBoxFlat.new()
	back.bg_color = COLOR_BOX
	back.set_corner_radius_all(BOX_RADIUS)
	back.anti_aliasing = true
	draw_style_box(back, rect)
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = Color(COLOR_YELLOW, alpha)
	frame.set_border_width_all(BOX_BORDER)
	frame.set_corner_radius_all(BOX_RADIUS)
	frame.anti_aliasing = true
	draw_style_box(frame, rect)
	var font := MenuStyle.bold_font()
	var top := rect.position.y + float(BOX_BORDER) + BOX_PADDING.y
	var title_width := font.get_string_size(TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x
	draw_string(font, Vector2(rect.get_center().x - title_width * 0.5, top + font.get_ascent(TITLE_SIZE)), TITLE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, Color.WHITE)
	# 2行目：上下の三角と「十字キー・↑↓ で選ぶ」を、まとめて真ん中にそろえる。
	var sub_top := top + font.get_height(TITLE_SIZE) + LINE_GAP
	var arrows_width := 22.0
	var gap := 10.0
	var sub_width := font.get_string_size(SUB_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE).x
	var left := rect.get_center().x - (arrows_width + gap + sub_width) * 0.5
	var arrow_center := Vector2(left + arrows_width * 0.5, sub_top + font.get_height(SUB_SIZE) * 0.5)
	draw_colored_polygon(PackedVector2Array([arrow_center + Vector2(0, -13), arrow_center + Vector2(9, -3), arrow_center + Vector2(-9, -3)]), COLOR_ARROW)
	draw_colored_polygon(PackedVector2Array([arrow_center + Vector2(0, 13), arrow_center + Vector2(9, 3), arrow_center + Vector2(-9, 3)]), COLOR_ARROW)
	draw_string(font, Vector2(left + arrows_width + gap, sub_top + font.get_ascent(SUB_SIZE)), SUB_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE, COLOR_SUB)
