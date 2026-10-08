extends Control
## スタートの枠の番号の札。競馬の枠の色（1白・2黒・3赤・4青・5黄・6緑・7だいだい・8桃）で塗った四角に、数字を太く入れる。

const GATE_COLORS := [
	Color(0.96, 0.96, 0.96, 1.0),
	Color(0.12, 0.12, 0.14, 1.0),
	Color(0.88, 0.2, 0.2, 1.0),
	Color(0.2, 0.45, 0.9, 1.0),
	Color(0.98, 0.84, 0.2, 1.0),
	Color(0.22, 0.68, 0.36, 1.0),
	Color(0.96, 0.55, 0.16, 1.0),
	Color(0.96, 0.56, 0.72, 1.0),
]
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.55)
const COLOR_DARK_TEXT := Color(0.06, 0.08, 0.12, 1.0)
const COLOR_LIGHT_TEXT := Color(0.97, 0.98, 1.0, 1.0)

var gate_number := 0
var _bold_font: FontVariation


## gate_index は 0〜7（1枠〜8枠）。
func setup(gate_index: int, side: float) -> void:
	assert(gate_index >= 0 and gate_index < GATE_COLORS.size(), "枠の色がありません: %d" % gate_index)
	gate_number = gate_index + 1
	custom_minimum_size = Vector2(side, side)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 枠の色の上で読みやすい、数字の色。
static func text_color_for(gate_index: int) -> Color:
	return COLOR_DARK_TEXT if (GATE_COLORS[gate_index] as Color).get_luminance() > 0.5 else COLOR_LIGHT_TEXT


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null or gate_number <= 0:
		return
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.variation_embolden = 0.9
	_bold_font.base_font = font
	var box := StyleBoxFlat.new()
	box.bg_color = GATE_COLORS[gate_number - 1]
	box.border_color = COLOR_BORDER
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.skew = Vector2(0.18, 0.0)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var text := "%d" % gate_number
	var font_size := int(roundf(size.y * 0.66))
	var width := _bold_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_bold_font, Vector2((size.x - width) * 0.5, size.y * 0.5 + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, text_color_for(gate_number - 1))
