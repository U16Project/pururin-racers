@tool
extends Control
## 操作盤の小さな印：属性の印・脚質の印・ボタンの印（輪に文字）。この部品のまん中（脚質は左はし）に描く。
## 大きさと色は、エディタの右の欄で変えられ、エディタの中ですぐ見える（@tool）。
## ゲームのコードが変えるのは、属性（attribute_id・attribute_color）と脚質（style_count・style_index・style_rank_bonus）だけ。

const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")

@export_enum("attribute", "style", "button") var kind := "button":
	set(next):
		kind = next
		queue_redraw()
## 印の大きさ（ピクセル。脚質は高さ）。
@export var mark_size := 30.0:
	set(next):
		mark_size = next
		queue_redraw()

@export_group("属性")
@export var attribute_id := "fire":
	set(next):
		attribute_id = next
		queue_redraw()
@export var attribute_color := Color("ff3b6b"):
	set(next):
		attribute_color = next
		queue_redraw()

@export_group("脚質")
@export_range(0, 6) var style_count := 4:
	set(next):
		style_count = next
		queue_redraw()
@export_range(0, 6) var style_index := 1:
	set(next):
		style_index = next
		queue_redraw()
## 脚質と今の順位の関係（プラスなら青、0なら白、マイナスなら赤）。
@export_range(-1, 1) var style_rank_bonus := 0:
	set(next):
		style_rank_bonus = next
		queue_redraw()

@export_group("ボタン")
@export var letter := "X":
	set(next):
		letter = next
		queue_redraw()
@export var ring_color := Color(1.0, 0.47, 0.06, 1.0):
	set(next):
		ring_color = next
		queue_redraw()
@export var ring_width := 2.0:
	set(next):
		ring_width = next
		queue_redraw()
@export var letter_font: Font:
	set(next):
		letter_font = next
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var middle := size * 0.5
	match kind:
		"attribute":
			if not attribute_id.is_empty():
				PururinDetail.draw_attribute_mark(self, middle, mark_size, attribute_id, attribute_color)
		"style":
			if style_count > 0:
				RaceHud.draw_style_chevrons(self, Vector2(0.0, middle.y), RaceHud.style_state_color(style_rank_bonus), style_count, style_index, mark_size / 13.0)
		"button":
			var radius := mark_size * 0.5
			draw_arc(middle, radius - ring_width * 0.5, 0.0, TAU, 48, Color(0.02, 0.03, 0.06, 0.9), ring_width + 3.0, true)
			draw_arc(middle, radius - ring_width * 0.5, 0.0, TAU, 48, ring_color, ring_width, true)
			var font := letter_font if letter_font != null else get_theme_default_font()
			var font_size := int(round(mark_size * 0.62))
			var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			draw_string(font, middle + Vector2(-text_size.x * 0.5, font_size * 0.36), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ring_color.lerp(Color.WHITE, 0.25))
