extends PanelContainer
## 画面の右上の札。何のレースか（遊び方・ルームの札・区分と距離）と、レースの時計。
## 時計は、自分がゴールしたあとも、結果の板が出るまで進み続ける。

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const MARGIN := 14.0

var _kind := Label.new()
var _title := Label.new()
var _time := Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.09, 0.62)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	for label: Label in [_kind, _title, _time]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_color_override("font_outline_color", RaceHud.COLOR_OUTLINE)
		label.add_theme_constant_override("outline_size", 4)
		column.add_child(label)
	_kind.add_theme_font_size_override("font_size", 13)
	_title.add_theme_font_size_override("font_size", 18)
	_time.add_theme_font_size_override("font_size", 26)
	_time.add_theme_color_override("font_color", RaceHud.COLOR_GOLD)


## label は local_race_controller.race_label() の形。time_text はレースの時計の文字。
func show_race(label: Dictionary, time_text: String) -> void:
	var kind: Array = label["kind"]
	var parts := PackedStringArray([str(kind[0])])
	for tag: Array in label["tags"]:
		parts.append(str(tag[0]))
	_kind.text = "　".join(parts)
	_kind.add_theme_color_override("font_color", kind[1])
	_title.text = str(label["title"])
	_time.text = time_text
	reset_size()
	position = Vector2(get_viewport_rect().size.x - size.x - MARGIN, MARGIN)
