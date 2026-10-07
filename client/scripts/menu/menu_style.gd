extends RefCounted
## メニュー画面（タイトル・レース選択）で共通の見た目。ボタンと文字の作り方をそろえる。

const COLOR_TEXT := Color(0.97, 0.98, 1.0, 1.0)
const COLOR_DIM := Color(0.78, 0.83, 0.9, 1.0)
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const COLOR_PANEL := Color(0.05, 0.08, 0.14, 0.78)
const COLOR_BUTTON := Color(0.18, 0.42, 0.58, 1.0)
const COLOR_BUTTON_QUIET := Color(0.2, 0.25, 0.33, 1.0)
const COLOR_BUTTON_ON := Color(0.2, 0.62, 0.42, 1.0)
const COLOR_FOCUS := Color(1.0, 0.86, 0.3, 1.0)


static func box(color: Color, radius: int = 10, margin_x: float = 22.0, margin_y: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


## 選んでいる部品が分かるように、黄色い枠を付ける（ゲームパッドとキーボードの操作用）。
static func focus_box(radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_FOCUS
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.set_expand_margin_all(3.0)
	return style


static func label(text: String, font_size: int, color: Color = COLOR_TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	node.add_theme_constant_override("outline_size", 6)
	return node


static func style_button(button: BaseButton, font_size: int, color: Color = COLOR_BUTTON) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, COLOR_TEXT)
	button.add_theme_stylebox_override("normal", box(color))
	button.add_theme_stylebox_override("hover", box(color.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", box(COLOR_BUTTON_ON))
	button.add_theme_stylebox_override("hover_pressed", box(COLOR_BUTTON_ON.lightened(0.12)))
	button.add_theme_stylebox_override("focus", focus_box())


static func button(text: String, font_size: int, color: Color = COLOR_BUTTON) -> Button:
	var node := Button.new()
	node.text = text
	style_button(node, font_size, color)
	return node
