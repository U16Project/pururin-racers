extends Control
## 右側にまとめる順位・距離・時計・順位表。試作専用、既存HUDと独立。

const Hud := preload("res://scripts/presentation/race_hud.gd")
const FitText := preload("res://scripts/presentation/fit_text.gd")
const BASE_SIZE := Vector2(320, 436)
const WHITE := Color("f1f8ff")
const DIM := Color("aec4d4")
const CYAN := Color("55dfff")
var _state: Dictionary = {}
var _bold: FontVariation


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE_SIZE
	size = BASE_SIZE
	_bold = FontVariation.new()
	_bold.base_font = get_theme_default_font()
	_bold.variation_embolden = 0.7


func update_state(values: Dictionary) -> void:
	_state.merge(values, true)
	queue_redraw()


func _box(rect: Rect2, color: Color, outline: Color = Color(0.6, 0.8, 1, 0.2)) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_border_width_all(1)
	box.border_color = outline
	draw_style_box(box, rect)


func _text(at: Vector2, value: String, px: int, color: Color = WHITE, max_width: float = 0) -> void:
	if max_width > 0:
		FitText.draw(self, _bold, at, value, max_width, px, color, 0, 2, Color(0.01, 0.03, 0.06, 0.9))
	else:
		draw_string_outline(_bold, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 2, Color(0.01, 0.03, 0.06, 0.9))
		draw_string(_bold, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)


func _draw() -> void:
	if _bold == null:
		return
	_box(Rect2(0, 0, 320, 126), Color(0.025, 0.055, 0.09, 0.68))
	_text(Vector2(15, 23), "POSITION", 11, DIM)
	_text(Vector2(15, 86), str(_state.get("place", 0)), 64)
	_text(Vector2(62, 85), "/ %d" % int(_state.get("field_size", 8)), 20, DIM)
	draw_line(Vector2(107, 17), Vector2(107, 106), Color(WHITE, 0.14))
	_text(Vector2(122, 25), "残り", 13, DIM)
	_text(Vector2(122, 58), "%d" % roundi(float(_state.get("remaining_m", 0))), 32)
	_text(Vector2(253, 58), "m", 17, DIM)
	_text(Vector2(122, 82), "TIME", 10, DIM)
	_text(Vector2(122, 110), str(_state.get("time_text", "0:00:00")), 27, CYAN)
	_box(Rect2(0, 136, 320, 300), Color(0.025, 0.055, 0.09, 0.65))
	_text(Vector2(14, 159), "順位", 12, DIM)
	_text(Vector2(65, 159), "プル", 12, DIM)
	_text(Vector2(202, 159), "BPM", 11, DIM)
	_text(Vector2(264, 159), "体力", 11, DIM)
	var runners: Array = _state.get("standings", [])
	for i in mini(runners.size(), 8):
		var runner: Dictionary = runners[i]
		var top := 169.0 + i * 32
		var is_player := bool(runner.get("is_player", false))
		if is_player:
			_box(Rect2(6, top, 308, 30), Color(0.12, 0.5, 0.66, 0.35), Color(CYAN, 0.5))
		else:
			draw_line(Vector2(13, top + 31), Vector2(307, top + 31), Color(WHITE, 0.06))
		var color := CYAN if is_player else WHITE
		_text(Vector2(16, top + 22), str(i + 1), 19, Hud.COLOR_GOLD if i == 0 else color)
		draw_circle(Vector2(47, top + 16), 5, runner.get("color", Color.WHITE), true, -1, true)
		_text(Vector2(62, top + 21), str(runner.get("name", "")), 16, color, 124)
		_text(Vector2(201, top + 20), "%d" % roundi(float(runner.get("heart_bpm", 0))), 15, Hud.heart_color(runner))
		var fuel := float(runner.get("fuel_ratio", 0))
		_text(Vector2(260, top + 20), "%d%%" % roundi(fuel * 100), 14, Hud.fuel_color(fuel))
