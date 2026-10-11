extends Label
## 1秒あたりのコマ数を、画面の上のまん中に小さく出す（ウェブ版オフラインテストのレースだけ。重さを確かめるため）。

const FONT_SIZE := 16
const TOP_MARGIN := 4.0


func _ready() -> void:
	name = "FpsLabel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = TOP_MARGIN
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_outline_color", Color(0.03, 0.05, 0.1, 0.9))
	add_theme_constant_override("outline_size", 5)


func _process(_delta: float) -> void:
	text = "%d コマ/秒" % int(Engine.get_frames_per_second())
