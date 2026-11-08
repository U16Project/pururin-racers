@tool
extends Control
## 残り回数と、使用中の1回の残り時間を、切り分けた輪で描く。
@export_range(1, 24) var count := 3:
	set(next):
		count = maxi(next, 1)
		queue_redraw()
@export var lit_count := 3:
	set(next):
		lit_count = next
		queue_redraw()
@export_range(0.0, 1.0) var partial := 0.0:
	set(next):
		partial = next
		queue_redraw()
@export var center := Vector2(72, 72)
@export var radius := 40.0
@export var thickness := 10.0
## 各切れ目の片側の角度。参考ページと同じく両端を5度ずつ空ける。
@export var gap_deg := 5.0
@export var ring_color := Color(1, 0.47, 0.06)
@export var empty_color := Color(0.04, 0.06, 0.14, 0.45)
@export var edge_color := Color(0.6, 0.8, 1, 0.35)
@export var glow_width := 6.0
@export_range(0.0, 1.0) var glow_strength := 0.35

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func segment_fill(index: int) -> float:
	return 1.0 if index < lit_count else (partial if index == lit_count else 0.0)

func _draw() -> void:
	var span := TAU / float(count)
	var gap := minf(deg_to_rad(gap_deg), span * 0.49)
	for i in count:
		var start := float(i) * span + gap - PI * 0.5
		var end := float(i + 1) * span - gap - PI * 0.5
		draw_arc(center, radius, start, end, 64, edge_color, thickness + 2.0, true)
		draw_arc(center, radius, start, end, 64, empty_color, thickness, true)
		var fill := segment_fill(i)
		if fill <= 0.0:
			continue
		end = lerpf(start, end, fill)
		draw_arc(center, radius, start, end, 64, Color(ring_color, glow_strength * 0.35), thickness + glow_width * 2.0, true)
		draw_arc(center, radius, start, end, 64, Color(ring_color, glow_strength), thickness + glow_width, true)
		draw_arc(center, radius, start, end, 64, ring_color, thickness, true)
