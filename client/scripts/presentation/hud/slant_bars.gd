@tool
extends Control
## 斜めの棒の並び（ノッチ・ブースト）。下の棒から上の棒へ、ずらし（step）ずつ並べる。
## 棒の長さは、下の棒（first_length）から上の棒（last_length）へ、伸び方（grow）でだんだん変わる。
## 形・色・光り方は、エディタの右の欄で変えられ、エディタの中ですぐ見える（@tool）。
## この部品の四角は、描いている所（棒と、そのまわりの光）に自動で合わせる（エディタで、クリックしてつまみやすいように）。
## ゲームのコードが変えるのは、count（棒の数。設定の数）、lit_count（光らせる本数）、partial（次の1本を、下から光らせる割合）だけ。

## 棒の数と、下から光らせる本数。
@export_range(1, 12) var count := 6:
	set(next):
		count = maxi(next, 1)
		_refresh()
@export_range(0, 12) var lit_count := 6:
	set(next):
		lit_count = maxi(next, 0)
		_refresh()
## 次の1本（lit_count 本目の上）を、下からこの割合だけ光らせる（ブーストを使っている最中など）。
@export_range(0.0, 1.0, 0.01) var partial := 0.0:
	set(next):
		partial = clampf(next, 0.0, 1.0)
		_refresh()

@export_group("形")
## いちばん下の棒の、左下の角（この部品の左上から）。
@export var first_bottom_left := Vector2(0.0, 200.0):
	set(next):
		first_bottom_left = next
		_refresh()
## 次の棒への、左下の角のずらし。
@export var step := Vector2(0.0, -36.0):
	set(next):
		step = next
		_refresh()
## 棒の高さと、斜めのずれ（上の辺が、下の辺よりこれだけ右）。
@export var height := 30.0:
	set(next):
		height = next
		_refresh()
@export var slant := 14.0:
	set(next):
		slant = next
		_refresh()
## 下の棒と上の棒の、下の辺の長さ。間の棒は、伸び方（grow。1でまっすぐ、大きいほど上で急に伸びる）で決まる。
@export var first_length := 70.0:
	set(next):
		first_length = next
		_refresh()
@export var last_length := 190.0:
	set(next):
		last_length = next
		_refresh()
@export_range(0.2, 4.0, 0.05) var grow := 1.0:
	set(next):
		grow = next
		_refresh()
## 角の丸み（ピクセル）。
@export var corner := 2.0:
	set(next):
		corner = maxf(next, 0.0)
		_refresh()

@export_group("色")
## 下の棒（左はし）から、上の棒（右はし）への色。
@export var gradient: Gradient:
	set(next):
		if gradient != null and gradient.changed.is_connected(queue_redraw):
			gradient.changed.disconnect(queue_redraw)
		gradient = next
		if gradient != null and not gradient.changed.is_connected(queue_redraw):
			gradient.changed.connect(queue_redraw)
		_refresh()
## 消えている棒の色と、そのふちの線の色。
@export var empty_color := Color(1.0, 1.0, 1.0, 0.07):
	set(next):
		empty_color = next
		_refresh()
@export var empty_edge_color := Color(0.62, 0.8, 1.0, 0.35):
	set(next):
		empty_edge_color = next
		_refresh()

@export_group("光り方")
## 光っている棒のまわりの光の広がり（ピクセル）と濃さ。
@export var glow_width := 6.0:
	set(next):
		glow_width = maxf(next, 0.0)
		_refresh()
@export_range(0.0, 1.0, 0.01) var glow_strength := 0.35:
	set(next):
		glow_strength = next
		_refresh()
## 上へいくほど明るくする強さと、ふちの明るい線の強さ。
@export_range(0.0, 1.0, 0.01) var top_light := 0.2:
	set(next):
		top_light = next
		_refresh()
@export_range(0.0, 1.0, 0.01) var rim_light := 0.5:
	set(next):
		rim_light = next
		_refresh()


## 四角を合わせている最中か。
var _fitting := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _refresh() -> void:
	if is_inside_tree() and not _fitting:
		_fit_rect()
	queue_redraw()


## 描いている所の四角（この部品の左上から）。全部の棒と、まわりの光のはみ出しを含む。
func drawn_rect() -> Rect2:
	var box := Rect2(first_bottom_left, Vector2.ZERO)
	for index in count:
		for point in bar_shape(index):
			box = box.expand(point)
	return box.grow(glow_width + 3.0)


## この部品の四角を、描いている所に合わせる（見た目の位置は変えない）。回したり縮めたりしているときは、合わせない。
func _fit_rect() -> void:
	if rotation != 0.0 or scale != Vector2.ONE:
		return
	var box := drawn_rect()
	if box.position.distance_to(Vector2.ZERO) < 0.5 and box.size.distance_to(size) < 0.5:
		return
	_fitting = true
	position += box.position
	first_bottom_left -= box.position
	size = box.size
	_fitting = false


## index 本目（0が下）の棒の形（左下・右下・右上・左上）。
func bar_shape(index: int) -> PackedVector2Array:
	var bottom_left := first_bottom_left + step * float(index)
	var ratio := pow(float(index) / float(maxi(count - 1, 1)), grow)
	var length := lerpf(first_length, last_length, ratio)
	return PackedVector2Array([
		bottom_left, bottom_left + Vector2(length, 0.0),
		bottom_left + Vector2(length + slant, -height), bottom_left + Vector2(slant, -height),
	])


## index 本目の色。
func bar_color(index: int) -> Color:
	if gradient == null:
		return Color.WHITE
	return gradient.sample(float(index) / float(maxi(count - 1, 1)))


## 角を丸めた形。
static func rounded(shape: PackedVector2Array, radius: float) -> PackedVector2Array:
	if radius <= 0.0:
		return shape
	var inner := Geometry2D.offset_polygon(shape, -radius, Geometry2D.JOIN_MITER)
	if inner.is_empty():
		return shape
	var result := Geometry2D.offset_polygon(inner[0], radius, Geometry2D.JOIN_ROUND)
	return result[0] if not result.is_empty() else shape


static func grown(shape: PackedVector2Array, amount: float) -> PackedVector2Array:
	var result := Geometry2D.offset_polygon(shape, amount, Geometry2D.JOIN_ROUND)
	return result[0] if not result.is_empty() else shape


func _draw() -> void:
	# 消えている棒を、先に全部描く。
	for index in count:
		var shape := rounded(bar_shape(index), corner)
		draw_colored_polygon(shape, empty_color)
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, empty_edge_color, 1.0, true)
	# 光っている棒のまわりの光（となりの棒にかぶらないよう、棒より先に）。
	for index in mini(lit_count, count):
		_glow(rounded(bar_shape(index), corner), bar_color(index))
	if lit_count < count and partial > 0.0:
		_glow(rounded(_partial_shape(lit_count), corner), bar_color(lit_count))
	for index in mini(lit_count, count):
		_lit(rounded(bar_shape(index), corner), bar_color(index))
	if lit_count < count and partial > 0.0:
		_lit(rounded(_partial_shape(lit_count), corner), bar_color(lit_count).lerp(Color.WHITE, 0.25))


func _partial_shape(index: int) -> PackedVector2Array:
	var shape := bar_shape(index)
	return PackedVector2Array([shape[0], shape[1], shape[1].lerp(shape[2], partial), shape[0].lerp(shape[3], partial)])


func _glow(shape: PackedVector2Array, color: Color) -> void:
	if glow_width <= 0.0 or glow_strength <= 0.0:
		return
	draw_colored_polygon(grown(shape, glow_width), Color(color, glow_strength * 0.4))
	draw_colored_polygon(grown(shape, glow_width * 0.45), Color(color, glow_strength))


func _lit(shape: PackedVector2Array, color: Color) -> void:
	var top := INF
	var bottom := -INF
	for point in shape:
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var colors := PackedColorArray()
	for point in shape:
		colors.append(color.lerp(color.lerp(Color.WHITE, top_light), inverse_lerp(bottom, top, point.y)))
	draw_polygon(shape, colors)
	if rim_light > 0.0:
		var edge := shape.duplicate()
		edge.append(shape[0])
		draw_polyline(edge, Color(color.lerp(Color.WHITE, 0.6), rim_light), 1.5, true)
