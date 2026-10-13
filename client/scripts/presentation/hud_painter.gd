extends RefCounted
## 操作盤・順位表の絵を、少ない「描く命令」でまとめて描く。
## CanvasItem の draw_circle・draw_line などは、1回ごとに命令が1つ出る。丸・線・面が数百あると、
## スマホのブラウザで重い。ここでは、同じ名前の命令で受けて、三角形にして1つの並びにため、
## 最後に flush で、1回の命令で描く。文字は、文字の絵ごとにまとめて、図形の手前に描く。
## 呼んだ順に重なる（あとに呼んだものが手前）。なめらかな線は、ふちを透明へぼかして作る。
## 使い方：begin(描く先) → draw_... → flush()。

const GlyphBatch := preload("res://scripts/presentation/glyph_batch.gd")

## なめらかな線の、ふちをぼかす幅（ピクセル）。
const FEATHER_PX := 1.25
## なめらかな線の、色の濃い芯を、片側でこれだけ細くする（ピクセル）。
const AA_CORE_SHRINK_PX := 0.5
## 丸を、何角形で描くか（小さい丸は少なく、大きい丸は多く）。
const CIRCLE_SEGMENTS_MIN := 12
const CIRCLE_SEGMENTS_MAX := 64
## 折れ線の角を、とがらせる限度（線の太さの半分の、この倍まで）。
const MITER_LIMIT := 2.0

var glyphs := GlyphBatch.new()
var _canvas: CanvasItem
var _points := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _xform := Transform2D.IDENTITY
## 覚えておいた絵（名前 → [位置, 色, 三角形の番号]）。同じ絵を、作り直さずに、そのまま描くため。
var _blocks := {}
## 覚えておく絵の数の上限（超えたら、いったん全部忘れる）。
const BLOCK_CACHE_LIMIT := 2000
## 絵を組み立てるのに使った時間の合計（マイクロ秒。全部のペインターの合計）。重さを確かめる表示（FpsLabel）が読む。
static var build_usec_total := 0
var _began_usec := 0


func begin(canvas: CanvasItem) -> void:
	_canvas = canvas
	_began_usec = Time.get_ticks_usec()
	_xform = Transform2D.IDENTITY
	_points.clear()
	_colors.clear()
	_indices.clear()
	glyphs.clear()


## ためた図形と文字を描く。図形が先、文字が手前。
func flush() -> void:
	_flush_shapes()
	glyphs.flush(_canvas)
	build_usec_total += Time.get_ticks_usec() - _began_usec


## 図形の、三角形の数（テスト用）。
func triangle_count() -> int:
	return _indices.size() / 3


func _flush_shapes() -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(_canvas.get_canvas_item(), _indices, _points, _colors)
	_points.clear()
	_colors.clear()
	_indices.clear()


## 図形のかたまりを、覚えておいて描く。key が同じなら、builder を呼ばずに、前に作った三角形をそのまま描く
## （毎回作ると、計算が重い。スマホのブラウザでは、ここが一番効く）。
## builder の中では、このペインターの図形の命令だけを使う（文字は入れない。文字は、覚えた絵に含まれない）。
## at を変えれば、同じ絵を、別の場所に描ける。重なる順は、呼んだ順のまま。
func draw_block(key: Variant, builder: Callable, at: Vector2 = Vector2.ZERO) -> void:
	_flush_shapes()
	if not _blocks.has(key):
		if _blocks.size() >= BLOCK_CACHE_LIMIT:
			_blocks.clear()
		builder.call()
		_blocks[key] = [_points.duplicate(), _colors.duplicate(), _indices.duplicate()]
		_points.clear()
		_colors.clear()
		_indices.clear()
	var block: Array = _blocks[key]
	if (block[2] as PackedInt32Array).is_empty():
		return
	var item := _canvas.get_canvas_item()
	if at != Vector2.ZERO:
		RenderingServer.canvas_item_add_set_transform(item, Transform2D(0.0, at))
	RenderingServer.canvas_item_add_triangle_array(item, block[2], block[0], block[1])
	if at != Vector2.ZERO:
		RenderingServer.canvas_item_add_set_transform(item, Transform2D.IDENTITY)


## 覚えている絵の数（テスト用）。
func block_count() -> int:
	return _blocks.size()


func draw_set_transform(position: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
	_xform = Transform2D(rotation, scale, 0.0, position)


func _vertex(point: Vector2, color: Color) -> int:
	_points.append(_xform * point)
	_colors.append(color)
	return _points.size() - 1


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color_a: Color, color_b: Color, color_c: Color, color_d: Color) -> void:
	var first := _vertex(a, color_a)
	_vertex(b, color_b)
	_vertex(c, color_c)
	_vertex(d, color_d)
	_indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
	var triangles := Geometry2D.triangulate_polygon(points)
	if triangles.is_empty():
		return
	var first := _points.size()
	for point in points:
		_vertex(point, color)
	for index in triangles:
		_indices.append(first + index)


func draw_polygon(points: PackedVector2Array, colors: PackedColorArray) -> void:
	var triangles := Geometry2D.triangulate_polygon(points)
	if triangles.is_empty():
		return
	var first := _points.size()
	for index in points.size():
		_vertex(points[index], colors[index] if colors.size() == points.size() else colors[0])
	for index in triangles:
		_indices.append(first + index)


static func circle_segments(radius: float) -> int:
	return clampi(int(radius * 2.0) + 8, CIRCLE_SEGMENTS_MIN, CIRCLE_SEGMENTS_MAX)


func draw_circle(center: Vector2, radius: float, color: Color) -> void:
	var segments := circle_segments(radius)
	var first := _vertex(center, color)
	for index in segments:
		_vertex(center + Vector2.RIGHT.rotated(TAU * float(index) / float(segments)) * radius, color)
	for index in segments:
		_indices.append_array([first, first + 1 + index, first + 1 + (index + 1) % segments])


func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, _antialiased: bool = false) -> void:
	var a := rect.position
	var c := rect.end
	var b := Vector2(c.x, a.y)
	var d := Vector2(a.x, c.y)
	if filled:
		_quad(a, b, c, d, color, color, color, color)
		return
	# 枠だけ。角がつながるように、線の太さの半分だけ、両端を伸ばす。
	var half := maxf(width, 1.0) * 0.5
	draw_line(a - Vector2(half, 0.0), b + Vector2(half, 0.0), color, width)
	draw_line(d - Vector2(half, 0.0), c + Vector2(half, 0.0), color, width)
	draw_line(a, d, color, width)
	draw_line(b, c, color, width)


func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	_strip(PackedVector2Array([from, to]), PackedColorArray([color]), width, antialiased)


func draw_multiline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var colors := PackedColorArray([color])
	for index in range(0, points.size() - 1, 2):
		_strip(PackedVector2Array([points[index], points[index + 1]]), colors, width, antialiased)


func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	_strip(points, PackedColorArray([color]), width, antialiased)


func draw_polyline_colors(points: PackedVector2Array, colors: PackedColorArray, width: float = -1.0, antialiased: bool = false) -> void:
	_strip(points, colors, width, antialiased)


func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var points := PackedVector2Array()
	var count := maxi(point_count, 2)
	for index in count:
		points.append(center + Vector2.RIGHT.rotated(lerpf(start_angle, end_angle, float(index) / float(count - 1))) * radius)
	_strip(points, PackedColorArray([color]), width, antialiased)


## 折れ線を、太さのある帯にして、ためる。colors が1つなら、全部その色。
func _strip(points: PackedVector2Array, colors: PackedColorArray, width: float, antialiased: bool) -> void:
	var count := points.size()
	if count < 2:
		return
	var half := maxf(width, 1.0) * 0.5
	var feather := 0.0
	if antialiased:
		# 色の濃い芯を少し細くして、その外をぼかす（CanvasItem のなめらかな線と、同じ太さに見える合わせ方。撮った画面で合わせた）。
		half = maxf(half - AA_CORE_SHRINK_PX, 0.05)
		feather = FEATHER_PX
	# 最初と最後が同じ点なら、輪（つなぎ目も、角として扱う）。
	var closed := count > 2 and points[0].is_equal_approx(points[count - 1])
	var previous_first := -1
	for index in count:
		var before := points[index - 1] if index > 0 else (points[count - 2] if closed else points[index])
		var after := points[index + 1] if index < count - 1 else (points[1] if closed else points[index])
		var side := strip_side(before, points[index], after)
		var color := colors[index] if colors.size() == count else colors[0]
		var first := _vertex(points[index] + side * half, color)
		_vertex(points[index] - side * half, color)
		if antialiased:
			var clear := Color(color, 0.0)
			_vertex(points[index] + side * (half + feather), clear)
			_vertex(points[index] - side * (half + feather), clear)
		if previous_first >= 0:
			_indices.append_array([previous_first, first, first + 1, previous_first, first + 1, previous_first + 1])
			if antialiased:
				_indices.append_array([previous_first + 2, first + 2, first, previous_first + 2, first, previous_first])
				_indices.append_array([previous_first + 1, first + 1, first + 3, previous_first + 1, first + 3, previous_first + 3])
		previous_first = first


## 折れ線の、その点での「横向き」（長さは、角でとがらせるぶん、1より長くなる。限度は MITER_LIMIT）。
static func strip_side(before: Vector2, point: Vector2, after: Vector2) -> Vector2:
	var into := (point - before).normalized() if not point.is_equal_approx(before) else Vector2.ZERO
	var out := (after - point).normalized() if not after.is_equal_approx(point) else Vector2.ZERO
	if into == Vector2.ZERO:
		into = out
	if out == Vector2.ZERO:
		out = into
	var normal_in := Vector2(-into.y, into.x)
	var normal_out := Vector2(-out.y, out.x)
	var middle := normal_in + normal_out
	if middle.length_squared() < 0.000001:
		return normal_in
	middle = middle.normalized()
	return middle * minf(1.0 / maxf(middle.dot(normal_in), 1.0 / MITER_LIMIT), MITER_LIMIT)


func draw_string(font: Font, position: Vector2, text: String, _alignment: int = HORIZONTAL_ALIGNMENT_LEFT, _width: float = -1.0, font_size: int = 16, color: Color = Color.WHITE) -> void:
	glyphs.add(font, text, font_size, position, color, 0, Color.BLACK, _xform)


func draw_string_outline(font: Font, position: Vector2, text: String, _alignment: int = HORIZONTAL_ALIGNMENT_LEFT, _width: float = -1.0, font_size: int = 16, outline_size: int = 1, color: Color = Color.WHITE) -> void:
	glyphs.add(font, text, font_size, position, color, outline_size, color, _xform, false)


## 角の丸い板など、ここでまとめられない絵。ためた図形を先に描いてから、そのまま描く（重なる順を守る）。
func draw_style_box(style_box: StyleBox, rect: Rect2) -> void:
	_flush_shapes()
	_canvas.draw_style_box(style_box, rect)
