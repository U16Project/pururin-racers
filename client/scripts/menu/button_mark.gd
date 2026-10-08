extends Control
## ゲームパッドのボタンのマーク。丸の中に文字（A・B・X・Y）、START・SELECT・L1・R1・L2・R2 は横長の丸。
## 色は、ゲームパッドのボタンの色に合わせる。絵文字ではなく、図形で描く。
## 文字の横に置く部品としても、ほかの描画（操作盤など）から draw_mark で直接描くこともできる。

const KIND_START := "START"
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const COLOR_LETTER := Color(0.06, 0.08, 0.12, 1.0)
const COLOR_GOLD := Color(1.0, 0.82, 0.3, 1.0)
const COLOR_DARK := Color(0.09, 0.1, 0.13, 1.0)
## マークの地の色。
const COLORS := {
	"A": Color(0.45, 0.82, 0.38, 1.0),
	"B": Color(0.95, 0.36, 0.33, 1.0),
	"X": Color(0.38, 0.62, 1.0, 1.0),
	"Y": Color(1.0, 0.82, 0.25, 1.0),
	KIND_START: Color(0.82, 0.86, 0.92, 1.0),
	"SELECT": Color(0.82, 0.86, 0.92, 1.0),
	"L1": COLOR_DARK,
	"R1": COLOR_DARK,
	"L2": COLOR_DARK,
	"R2": COLOR_DARK,
}
## 肩のボタンと引き金（L1・R1・L2・R2）は、暗い地に金色の文字と枠。それ以外は、暗い文字。
const GOLD_KINDS := ["L1", "R1", "L2", "R2"]
## 横長の丸で描くマークの横幅（丸の直径の何倍か）。ここに無いマークは、丸。
const PILL_WIDTH_RATIOS := {KIND_START: 2.7, "SELECT": 3.0, "L1": 1.7, "R1": 1.7, "L2": 1.7, "R2": 1.7}

var kind := ""
var diameter := 0.0


func setup(mark_kind: String, mark_diameter: float) -> void:
	assert(COLORS.has(mark_kind), "ボタンのマークがありません: %s" % mark_kind)
	kind = mark_kind
	diameter = mark_diameter
	custom_minimum_size = Vector2(mark_width(kind, diameter), diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	queue_redraw()


static func mark_width(mark_kind: String, mark_diameter: float) -> float:
	return mark_diameter * float(PILL_WIDTH_RATIOS[mark_kind]) if PILL_WIDTH_RATIOS.has(mark_kind) else mark_diameter


func _draw() -> void:
	if not kind.is_empty():
		draw_mark(self, get_theme_default_font(), size * 0.5, kind, diameter)


## マークを、指定の描画先に描く。center は、マークの中心。
static func draw_mark(canvas: CanvasItem, font: Font, center: Vector2, mark_kind: String, mark_diameter: float) -> void:
	var color: Color = COLORS[mark_kind]
	var radius := mark_diameter * 0.5
	var is_pill := PILL_WIDTH_RATIOS.has(mark_kind)
	var is_gold := mark_kind in GOLD_KINDS
	var font_size := int(roundf(mark_diameter * (0.42 if mark_kind.length() > 2 else (0.58 if is_pill else 0.66))))
	if is_pill:
		var half_width := mark_width(mark_kind, mark_diameter) * 0.5
		var pill := StyleBoxFlat.new()
		pill.bg_color = color
		pill.set_corner_radius_all(int(radius))
		pill.border_color = COLOR_GOLD if is_gold else COLOR_OUTLINE
		pill.set_border_width_all(maxi(int(roundf(mark_diameter * 0.07)), 1))
		canvas.draw_style_box(pill, Rect2(center - Vector2(half_width, radius), Vector2(half_width * 2.0, mark_diameter)))
	else:
		canvas.draw_circle(center, radius, COLOR_OUTLINE)
		canvas.draw_circle(center, radius - maxf(mark_diameter * 0.07, 1.0), color)
	var text_size := font.get_string_size(mark_kind, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	canvas.draw_string(font, center + Vector2(-text_size.x * 0.5, font_size * 0.36), mark_kind, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, COLOR_GOLD if is_gold else COLOR_LETTER)
