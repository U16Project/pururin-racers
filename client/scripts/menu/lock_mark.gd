extends Control
## 施錠の印（閉じた金色の南京錠）。パスワードの要る部屋などに付ける。

const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const COLOR_LOCK := Color(1.0, 0.82, 0.3)
## 印の、もとの大きさ（この大きさのとき、倍率1）。
const BASE_SIZE := Vector2(18.0, 22.0)

## 大きさの倍率。
@export var mark_scale := 1.0:
	set(value):
		mark_scale = value
		custom_minimum_size = BASE_SIZE * mark_scale
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BASE_SIZE * mark_scale


func _draw() -> void:
	draw_lock(self, size * 0.5 + Vector2(0.0, 1.5 * mark_scale), mark_scale)


## 南京錠を、指定の描画先に描く。center は、箱の上の辺のまん中あたり。
static func draw_lock(canvas: CanvasItem, center: Vector2, lock_scale: float = 1.0) -> void:
	var shackle := PackedVector2Array([center + Vector2(-4.0, 0.0) * lock_scale])
	for index in 9:
		var angle := PI + PI * float(index) / 8.0
		shackle.append(center + Vector2(cos(angle) * 4.0, -1.5 + sin(angle) * 4.5) * lock_scale)
	shackle.append(center + Vector2(4.0, 0.0) * lock_scale)
	canvas.draw_polyline(shackle, MenuStyle.COLOR_OUTLINE, 4.0 * lock_scale, true)
	canvas.draw_polyline(shackle, COLOR_LOCK, 2.0 * lock_scale, true)
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_LOCK
	box.set_corner_radius_all(int(3.0 * lock_scale))
	box.border_color = MenuStyle.COLOR_OUTLINE
	box.set_border_width_all(1)
	canvas.draw_style_box(box, Rect2(center + Vector2(-6.0, -1.0) * lock_scale, Vector2(12.0, 10.0) * lock_scale))
