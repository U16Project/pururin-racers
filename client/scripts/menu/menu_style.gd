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
## 「選択済み」（他のスロットで使っている）の色。
const COLOR_TAKEN := Color(1.0, 0.6, 0.2, 1.0)
const ButtonMark := preload("res://scripts/menu/button_mark.gd")
const FONT_PATH := "res://fonts/NotoSansJP-Regular.otf"

# ---- オンラインフリー対戦の画面と同じ組み立て（上の帯・カード・下の帯）の色。
## 上の帯・下の帯の地。
const COLOR_BAR := Color(0.04, 0.07, 0.13, 0.92)
## 上の帯の下の線・選んでいる札などの水色。
const COLOR_ACCENT := Color(0.35, 0.86, 1.0, 1.0)
## 帯の中の、小さく暗めの文字。
const COLOR_BAR_DIM := Color(0.74, 0.8, 0.9, 1.0)
## カード・箱の地と縁。
const COLOR_CARD := Color(0.08, 0.12, 0.2, 0.86)
const COLOR_CARD_BORDER := Color(0.45, 0.78, 1.0, 0.55)
## 背景の絵の暗さ（上に乗せる文字や箱が読めるように）。
const COLOR_BACKGROUND_DIM := Color(0.42, 0.45, 0.55, 1.0)
## いちばんの操作のボタン（黄色）と、その文字。
const COLOR_PRIMARY := Color(1.0, 0.8, 0.28, 1.0)
const COLOR_PRIMARY_TEXT := Color(0.12, 0.07, 0.0, 1.0)
const BAR_HEIGHT := 64.0
const GUIDE_HEIGHT := 40.0
const SCREEN_MARGIN := 28.0

static var _bold_font: FontVariation


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
	# 押せないときは、暗くする。
	button.add_theme_color_override("font_disabled_color", Color(COLOR_TEXT, 0.4))
	button.add_theme_stylebox_override("disabled", box(Color(color.darkened(0.45), 0.8)))
	button.add_theme_stylebox_override("focus", focus_box())


static func button(text: String, font_size: int, color: Color = COLOR_BUTTON) -> Button:
	var node := Button.new()
	node.text = text
	style_button(node, font_size, color)
	return node


## ゲームパッドのボタンのマークを作る（文字の横に並べる用）。
static func mark(kind: String, diameter: float) -> Control:
	var node: Control = ButtonMark.new()
	node.call("setup", kind, diameter)
	return node


## ボタンの左端に、ゲームパッドのボタンのマークを付ける（そのボタンを押すと、この動きになる、の印）。
static func add_mark(target: Button, kind: String, diameter: float = 26.0) -> Control:
	var node := mark(kind, diameter)
	node.name = "ButtonMark"
	target.add_child(node)
	node.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	node.offset_left = 14.0
	node.offset_right = 14.0 + ButtonMark.mark_width(kind, diameter)
	node.offset_top = -diameter * 0.5
	node.offset_bottom = diameter * 0.5
	return node


## 太字（見出し・大きな数字）。
static func bold_font() -> FontVariation:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = load(FONT_PATH)
		_bold_font.variation_embolden = 0.85
	return _bold_font


static func bold_label(text: String, font_size: int, color: Color = COLOR_TEXT, outline: int = 6) -> Label:
	var node := label(text, font_size, color)
	node.add_theme_font_override("font", bold_font())
	node.add_theme_constant_override("outline_size", outline)
	return node


## カード・箱の地（縁つき、丸い角）。border は縁の色。
static func card_box(color: Color = COLOR_CARD, border: Color = COLOR_CARD_BORDER, radius: int = 14) -> StyleBoxFlat:
	var style := box(color, radius, 0.0, 0.0)
	style.border_color = border
	style.set_border_width_all(2)
	return style


## カードの形のボタン：ふだんは水色の薄い縁、乗せる・押すと明るい水色の縁、選んでいると黄色の枠。
static func style_card_button(button: BaseButton) -> void:
	button.add_theme_stylebox_override("normal", card_box())
	button.add_theme_stylebox_override("hover", card_box(COLOR_CARD.lightened(0.08), COLOR_ACCENT))
	button.add_theme_stylebox_override("pressed", card_box(COLOR_CARD.darkened(0.1), COLOR_ACCENT))
	button.add_theme_stylebox_override("hover_pressed", card_box(COLOR_CARD.darkened(0.1), COLOR_ACCENT))
	var focus := box(Color(0.0, 0.0, 0.0, 0.0), 15, 0.0, 0.0)
	focus.border_color = COLOR_FOCUS
	focus.set_border_width_all(3)
	button.add_theme_stylebox_override("focus", focus)


## 丸い札（「いつもの」など）。地の色に、暗い文字。
static func tag(text: String, color: Color, font_size: int = 13) -> PanelContainer:
	var node := PanelContainer.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", box(color, 13, 10.0, 2.0))
	var text_label := bold_label(text, font_size, COLOR_BAR, 0)
	text_label.name = "Text"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(text_label)
	return node


## 画面の上の帯：左に画面の名前、右にトレーナーの札。右の並び（HBoxContainer）を返す（札の前に足せる）。
static func top_bar(parent: Control, title: String, trainer_name: String) -> HBoxContainer:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", box(COLOR_BAR, 0, 0.0, 0.0))
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = BAR_HEIGHT
	parent.add_child(bar)
	var line := Panel.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_stylebox_override("panel", box(Color(COLOR_ACCENT, 0.6), 0, 0.0, 0.0))
	line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	line.offset_top = -2.0
	bar.add_child(line)
	var heading := bold_label(title, 28)
	heading.name = "Title"
	heading.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	heading.offset_left = SCREEN_MARGIN
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(heading)
	var right := HBoxContainer.new()
	right.name = "RightRow"
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 18)
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -600.0
	right.offset_right = -SCREEN_MARGIN
	bar.add_child(right)
	var chip := PanelContainer.new()
	chip.name = "TrainerChip"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := card_box(Color(0.13, 0.18, 0.27, 0.92), COLOR_CARD_BORDER, 20)
	chip_style.content_margin_left = 16.0
	chip_style.content_margin_right = 16.0
	chip_style.content_margin_top = 6.0
	chip_style.content_margin_bottom = 6.0
	chip.add_theme_stylebox_override("panel", chip_style)
	right.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var caption := label("トレーナー", 13, COLOR_BAR_DIM)
	caption.add_theme_constant_override("outline_size", 0)
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(caption)
	var name_label := bold_label(trainer_name, 18, COLOR_TEXT, 0)
	name_label.name = "TrainerName"
	row.add_child(name_label)
	return right


## 画面の下の帯（操作の案内）。案内を並べる横の並びを返す（guide_item で足す）。
static func guide_bar(parent: Control) -> HBoxContainer:
	var bar := Panel.new()
	bar.name = "GuideBar"
	bar.add_theme_stylebox_override("panel", box(COLOR_BAR, 0, 0.0, 0.0))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -GUIDE_HEIGHT
	parent.add_child(bar)
	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 34)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = SCREEN_MARGIN
	row.offset_right = -SCREEN_MARGIN
	bar.add_child(row)
	return row


## 下の帯の案内を1つ：ボタンの印と、その動き。
static func guide_item(row: HBoxContainer, kind: String, text: String) -> Label:
	var item := HBoxContainer.new()
	item.add_theme_constant_override("separation", 8)
	row.add_child(item)
	var item_mark := mark(kind, 24.0)
	item_mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(item_mark)
	var text_label := label(text, 16, COLOR_BAR_DIM)
	text_label.add_theme_constant_override("outline_size", 0)
	text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(text_label)
	return text_label


## 下の帯の、押せる案内（マウスでも押せる「戻る」など）。ゲームパッドでは、印のボタンで押す。
static func guide_button(row: HBoxContainer, kind: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_font_override("font", bold_font())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, COLOR_TEXT if state != "font_color" else COLOR_BAR_DIM)
	var mark_width := ButtonMark.mark_width(kind, 24.0)
	var padding := box(Color(0.0, 0.0, 0.0, 0.0), 0, 0.0, 0.0)
	padding.content_margin_left = mark_width + 8.0
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state, padding)
	row.add_child(button)
	var node := mark(kind, 24.0)
	node.name = "ButtonMark"
	button.add_child(node)
	node.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	node.offset_right = mark_width
	node.offset_top = -12.0
	node.offset_bottom = 12.0
	return button


## 背景の絵（暗くして敷く）。
static func background(parent: Control, path: String) -> TextureRect:
	var node := TextureRect.new()
	node.name = "Background"
	node.texture = load(path)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	node.modulate = COLOR_BACKGROUND_DIM
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


## フリー対戦の画面と同じ、丸いボタン。kind：
## "primary"（黄色の地に暗い文字。いちばんの操作）、"secondary"（暗い地に水色の文字）、"quiet"（暗い地に白い文字）、
## "tab"（暗い地に白い文字。選んでいる＝押してある間は、水色の地に暗い文字）。
static func style_pill_button(button: BaseButton, kind: String, font_size: int, radius: int = 22) -> void:
	var base := Color(0.13, 0.18, 0.27, 0.92)
	var text := COLOR_TEXT
	var down_text := COLOR_TEXT
	var normal := base
	var down := base.darkened(0.15)
	match kind:
		"primary":
			normal = COLOR_PRIMARY
			down = COLOR_PRIMARY.darkened(0.1)
			text = COLOR_PRIMARY_TEXT
			down_text = COLOR_PRIMARY_TEXT
		"secondary":
			text = COLOR_ACCENT
			down_text = COLOR_ACCENT
		"tab":
			down = COLOR_ACCENT
			down_text = COLOR_BAR
	button.add_theme_font_size_override("font_size", font_size)
	if button is Button:
		(button as Button).add_theme_font_override("font", bold_font())
	for state in ["font_color", "font_hover_color", "font_focus_color"]:
		button.add_theme_color_override(state, text)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, down_text)
	button.add_theme_color_override("font_disabled_color", Color(text, 0.35))
	button.add_theme_stylebox_override("normal", _pill(normal, Color(1, 1, 1, 0.18), radius))
	button.add_theme_stylebox_override("hover", _pill(normal.lightened(0.12), Color(1, 1, 1, 0.35), radius))
	button.add_theme_stylebox_override("pressed", _pill(down, Color(1, 1, 1, 0.35), radius))
	button.add_theme_stylebox_override("hover_pressed", _pill(down.lightened(0.08), Color(1, 1, 1, 0.45), radius))
	button.add_theme_stylebox_override("disabled", _pill(Color(normal, normal.a * 0.35), Color(1, 1, 1, 0.08), radius))
	var focus := box(Color(0.0, 0.0, 0.0, 0.0), radius + 2, 0.0, 0.0)
	focus.border_color = COLOR_FOCUS
	focus.set_border_width_all(3)
	focus.set_expand_margin_all(2.0)
	button.add_theme_stylebox_override("focus", focus)


static func pill_button(text: String, kind: String, font_size: int = 20) -> Button:
	var node := Button.new()
	node.text = text
	style_pill_button(node, kind, font_size)
	return node


static func _pill(color: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := box(color, radius, 18.0, 6.0)
	style.border_color = border
	style.set_border_width_all(2)
	return style


## 中身を入れる箱（カードと同じ地と縁）。
static func panel_box(margin_x: float = 20.0, margin_y: float = 16.0) -> StyleBoxFlat:
	var style := card_box()
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style


## 箱の見出し（太字、下に水色の線）。見出しと線を縦に並べたものを返す。
static func section_title(text: String, font_size: int = 18) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", 6)
	var heading := bold_label(text, font_size, COLOR_TEXT, 0)
	heading.name = "Heading"
	node.add_child(heading)
	var rule := ColorRect.new()
	rule.color = Color(COLOR_ACCENT, 0.35)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(rule)
	return node
