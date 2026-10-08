extends Control
## ぷるりんの画像（今は仮）。個体の色で塗った、丸いぷるりんを描く。
## 小さい画像（スロット）も、大きい画像（詳細）も、この部品の大きさ違い。
## 本物の画像に差し替えるときは、この部品だけを直す。

const PururinVisualStyle := preload("res://scripts/pururin_visual_style.gd")
const COLOR_OUTLINE := Color(0.03, 0.05, 0.1, 0.9)
const BODY_POINTS := 40

var _pururin: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 表示する個体。空なら、何も描かない。
func set_pururin(pururin: Dictionary) -> void:
	_pururin = pururin
	queue_redraw()


func _draw() -> void:
	if _pururin.is_empty():
		return
	var side := minf(size.x, size.y)
	var center := size * 0.5 + Vector2(0.0, side * 0.06)
	var radius := side * 0.44
	var color := PururinVisualStyle.color_for_pururin(_pururin)
	# 下が少しつぶれた、丸い体。
	var body := PackedVector2Array()
	var outline := PackedVector2Array()
	for index in BODY_POINTS:
		var angle := TAU * float(index) / float(BODY_POINTS)
		var squash := 0.84 if sin(angle) > 0.0 else 1.0
		var point := Vector2(cos(angle), sin(angle) * squash)
		body.append(center + point * radius)
		outline.append(center + point * (radius + maxf(side * 0.035, 1.5)))
	draw_colored_polygon(outline, COLOR_OUTLINE)
	draw_colored_polygon(body, color)
	# つや。
	draw_circle(center + Vector2(-radius * 0.38, -radius * 0.42), radius * 0.2, Color(1.0, 1.0, 1.0, 0.55))
	# 目。
	for direction: float in [-1.0, 1.0]:
		var eye := center + Vector2(direction * radius * 0.32, radius * 0.02)
		draw_circle(eye, radius * 0.12, COLOR_OUTLINE)
		draw_circle(eye + Vector2(-radius * 0.035, -radius * 0.04), radius * 0.045, Color.WHITE)
