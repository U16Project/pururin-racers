extends GutTest

const HudPainter := preload("res://scripts/presentation/hud_painter.gd")

var _builds := 0


func _painter() -> HudPainter:
	var canvas := Control.new()
	add_child_autofree(canvas)
	var painter := HudPainter.new()
	painter.begin(canvas)
	return painter


func test_shapes_are_collected_as_triangles_and_emptied_by_flush() -> void:
	var painter := _painter()
	painter.draw_rect(Rect2(0.0, 0.0, 10.0, 10.0), Color.WHITE)
	assert_eq(painter.triangle_count(), 2)
	painter.draw_circle(Vector2.ZERO, 5.0, Color.WHITE)
	assert_eq(painter.triangle_count(), 2 + HudPainter.circle_segments(5.0))
	painter.flush()
	assert_eq(painter.triangle_count(), 0)


func test_a_smooth_line_adds_a_soft_edge_on_both_sides() -> void:
	var painter := _painter()
	painter.draw_line(Vector2.ZERO, Vector2(10.0, 0.0), Color.WHITE, 3.0)
	var plain := painter.triangle_count()
	painter.draw_line(Vector2.ZERO, Vector2(10.0, 0.0), Color.WHITE, 3.0, true)
	# 芯の2枚に、両側のぼかしが2枚ずつ足される。
	assert_eq(painter.triangle_count() - plain, plain * 3)


func test_a_block_is_built_once_and_reused_for_the_same_key() -> void:
	var painter := _painter()
	_builds = 0
	var builder := func() -> void:
		_builds += 1
		painter.draw_rect(Rect2(0.0, 0.0, 4.0, 4.0), Color.WHITE)
	painter.draw_block(["a", 1], builder)
	painter.draw_block(["a", 1], builder, Vector2(20.0, 0.0))
	assert_eq(_builds, 1, "同じ名前なら、作り直さない")
	painter.draw_block(["a", 2], builder)
	assert_eq(_builds, 2, "名前が変われば、作る")
	assert_eq(painter.block_count(), 2)
	assert_eq(painter.triangle_count(), 0, "かたまりは、その場で描くので、ためた図形には残らない")


func test_a_corner_is_sharpened_only_up_to_the_limit() -> void:
	# まっすぐな所では、横向きの長さは1。
	assert_almost_eq(HudPainter.strip_side(Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(2.0, 0.0)).length(), 1.0, 0.0001)
	# するどく折り返す所でも、限度より長くならない。
	var sharp := HudPainter.strip_side(Vector2(0.0, 0.0), Vector2(10.0, 0.0), Vector2(0.0, 0.5))
	assert_almost_eq(sharp.length(), HudPainter.MITER_LIMIT, 0.0001)
