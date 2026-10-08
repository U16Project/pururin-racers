extends Control
## メニュー用の、名前を出す部品。自分の幅に合わせて、入りきらない名前を縮めて描く（縮め方は FitText の決まり）。
## ふつうの Label と違い、長い文字で周りの並びを押し広げない。

const FitText := preload("res://scripts/presentation/fit_text.gd")
const MenuStyle := preload("res://scripts/menu/menu_style.gd")

var text := ""
var font_size := 16
var color := MenuStyle.COLOR_TEXT
## 欄の中での寄せ方（0＝左寄せ、0.5＝中央）。
var align_ratio := 0.0
var _fitted: Dictionary = {}


func setup(label_font_size: int, label_align_ratio: float = 0.0) -> void:
	font_size = label_font_size
	align_ratio = label_align_ratio
	custom_minimum_size = Vector2(0.0, ceilf(label_font_size * 1.35))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_text(value: String) -> void:
	text = value
	queue_redraw()


func set_color(value: Color) -> void:
	color = value
	queue_redraw()


## 今の幅で収めた結果（text・font_size・x_scale・width）。
func fitted() -> Dictionary:
	var font := get_theme_default_font()
	return FitText.fit(font, text, size.x, font_size) if font != null else {}


func _draw() -> void:
	var font := get_theme_default_font()
	if font == null or text.is_empty():
		return
	FitText.draw(self, font, Vector2(0.0, size.y * 0.5 + font_size * 0.36), text, size.x, font_size, color, align_ratio, 6, MenuStyle.COLOR_OUTLINE)
