extends RefCounted
## たくさんの文字を、少ない「描く命令」でまとめて描く。
## draw_string は、置き方（回転など）が違う文字ごとに命令が1つずつ出るので、輪に沿わせた文字や、
## 行の多い表では、数百回になる（スマホのブラウザで重い）。ここでは、文字の四角を自分で並べて、
## 文字の絵（テクスチャ）ごとに、1回の命令で描く。見た目は draw_string と同じ。
## 使い方：add で文字をためて、最後に flush（ふちを全部描いてから、中身を全部描く）。

## 文字の絵を、何倍の細かさで作るか。画面を拡大して出す所（引き伸ばす小画面）では、その倍率を入れると、ぼやけない。
var oversampling := 1.0
## 覚えておく文字の種類の上限（超えたら、いったん全部忘れる。数字が次々変わる所でも、増え続けないように）。
const QUAD_CACHE_LIMIT := 2000
## [フォント, 文字, 大きさ, ふちの太さ, 細かさ] → その文字の四角の並び。
var _quad_cache := {}
## 文字の絵 → その絵で描く四角の並び（Batch）。ふち用と、中身用。
var _outline := {}
var _fill := {}


## 1つの文字の絵で描く、四角の並び。
class Batch:
	var points := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


func clear() -> void:
	_outline.clear()
	_fill.clear()


## 文字を、ためる。origin は、書き出しの位置（文字の下の線の左端）。xform は、その文字の置き方（回転・移動）。
## outline_size が 0 より大きければ、ふちも付ける。fill が false なら、ふちだけ。
func add(font: Font, text: String, font_size: int, origin: Vector2, color: Color, outline_size: int = 0, outline_color: Color = Color.BLACK, xform: Transform2D = Transform2D.IDENTITY, fill: bool = true) -> void:
	if text.is_empty():
		return
	var placed := xform * Transform2D(0.0, origin)
	if outline_size > 0:
		_add_quads(_outline, _quads(font, text, font_size, outline_size), placed, outline_color)
	if fill:
		_add_quads(_fill, _quads(font, text, font_size, 0), placed, color)


## その文字の、四角の並び（[文字の絵, 四隅の位置4つ, 四隅の絵の中の位置4つ] の並び）。書き出しの位置を原点として作る。
## 同じ文字・大きさは、作ったものを覚えておいて使い回す（毎回作ると、計算が重い）。
func _quads(font: Font, text: String, font_size: int, outline_size: int) -> Array:
	var key := [font.get_rid(), text, font_size, outline_size, oversampling]
	if _quad_cache.has(key):
		return _quad_cache[key]
	if _quad_cache.size() >= QUAD_CACHE_LIMIT:
		_quad_cache.clear()
	var server := TextServerManager.get_primary_interface()
	# 文字の絵は、細かさの倍率ぶん大きく作り、置くときに、その倍率で割って元の大きさに戻す。
	var drawn_size := maxi(roundi(float(font_size) * oversampling), 1)
	var unit := float(font_size) / float(drawn_size)
	var size := Vector2i(drawn_size, roundi(float(outline_size) / unit))
	var shaped := server.create_shaped_text()
	server.shaped_text_add_string(shaped, text, font.get_rids(), drawn_size, font.get_opentype_features())
	server.shaped_text_shape(shaped)
	var quads: Array = []
	var pen := Vector2.ZERO
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		var font_rid: RID = glyph["font_rid"]
		var index := int(glyph["index"])
		if font_rid.is_valid():
			var texture := server.font_get_glyph_texture_rid(font_rid, size, index)
			var rect := Rect2(pen + ((glyph["offset"] as Vector2) + server.font_get_glyph_offset(font_rid, size, index)) * unit, server.font_get_glyph_size(font_rid, size, index) * unit)
			if texture.is_valid() and rect.size.x > 0.0 and rect.size.y > 0.0:
				var uv := server.font_get_glyph_uv_rect(font_rid, size, index)
				var texture_size := server.font_get_glyph_texture_size(font_rid, size, index)
				var corners := PackedVector2Array()
				var uvs := PackedVector2Array()
				for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
					corners.append(rect.position + rect.size * corner)
					uvs.append((uv.position + uv.size * corner) / texture_size)
				quads.append([texture, corners, uvs])
		pen.x += float(glyph["advance"]) * float(glyph.get("repeat", 1)) * unit
	server.free_rid(shaped)
	_quad_cache[key] = quads
	return quads


func _add_quads(store: Dictionary, quads: Array, placed: Transform2D, color: Color) -> void:
	for quad: Array in quads:
		var texture: RID = quad[0]
		if not store.has(texture):
			store[texture] = Batch.new()
		var batch: Batch = store[texture]
		var first := batch.points.size()
		batch.points.append_array(placed * (quad[1] as PackedVector2Array))
		batch.uvs.append_array(quad[2])
		batch.colors.append_array([color, color, color, color])
		batch.indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


## ためた文字が、何回の命令になるか（文字の絵の数。ふちと中身の合計）。
func draw_call_count() -> int:
	return _outline.size() + _fill.size()


## ためた文字を、item（CanvasItem）に描く。ふちを全部描いてから、中身を全部描く。
func flush(item: CanvasItem) -> void:
	for store: Dictionary in [_outline, _fill]:
		for texture: RID in store:
			var batch: Batch = store[texture]
			RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), batch.indices, batch.points, batch.colors, batch.uvs, PackedInt32Array(), PackedFloat32Array(), texture)
	clear()
