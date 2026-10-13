extends RefCounted
## たくさんの文字を、少ない「描く命令」でまとめて描く。
## draw_string は、置き方（回転など）が違う文字ごとに命令が1つずつ出るので、輪に沿わせた文字や、
## 行の多い表では、数百回になる（スマホのブラウザで重い）。ここでは、文字の四角を自分で並べて、
## 文字の絵（テクスチャ）ごとに、1回の命令で描く。見た目は draw_string と同じ。
## 使い方：add で文字をためて、最後に flush（ふちを全部描いてから、中身を全部描く）。

## 文字の絵を、何倍の細かさで作るか。画面を拡大して出す所（引き伸ばす小画面）では、その倍率を入れると、ぼやけない。
var oversampling := 1.0
## 文字の絵 → {points, uvs, colors, indices}。ふち用と、中身用。
var _outline := {}
var _fill := {}


func clear() -> void:
	_outline.clear()
	_fill.clear()


## 文字を、ためる。origin は、書き出しの位置（文字の下の線の左端）。xform は、その文字の置き方（回転・移動）。
## outline_size が 0 より大きければ、ふちも付ける。
func add(font: Font, text: String, font_size: int, origin: Vector2, color: Color, outline_size: int = 0, outline_color: Color = Color.BLACK, xform: Transform2D = Transform2D.IDENTITY) -> void:
	if text.is_empty():
		return
	var server := TextServerManager.get_primary_interface()
	var shaped := server.create_shaped_text()
	# 文字の絵は、細かさの倍率ぶん大きく作り、置くときに、その倍率で割って元の大きさに戻す。
	var drawn_size := maxi(roundi(float(font_size) * oversampling), 1)
	var unit := float(font_size) / float(drawn_size)
	var drawn_outline := roundi(float(outline_size) / unit)
	server.shaped_text_add_string(shaped, text, font.get_rids(), drawn_size, font.get_opentype_features())
	server.shaped_text_shape(shaped)
	var pen := origin
	for glyph: Dictionary in server.shaped_text_get_glyphs(shaped):
		var font_rid: RID = glyph["font_rid"]
		if font_rid.is_valid():
			var at := pen + (glyph["offset"] as Vector2) * unit
			if drawn_outline > 0:
				_add_quad(server, _outline, font_rid, Vector2i(drawn_size, drawn_outline), int(glyph["index"]), at, unit, outline_color, xform)
			_add_quad(server, _fill, font_rid, Vector2i(drawn_size, 0), int(glyph["index"]), at, unit, color, xform)
		pen.x += float(glyph["advance"]) * float(glyph.get("repeat", 1)) * unit
	server.free_rid(shaped)


func _add_quad(server: TextServer, store: Dictionary, font_rid: RID, size: Vector2i, index: int, at: Vector2, unit: float, color: Color, xform: Transform2D) -> void:
	var texture := server.font_get_glyph_texture_rid(font_rid, size, index)
	if not texture.is_valid():
		return
	var rect := Rect2(at + server.font_get_glyph_offset(font_rid, size, index) * unit, server.font_get_glyph_size(font_rid, size, index) * unit)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var uv := server.font_get_glyph_uv_rect(font_rid, size, index)
	var texture_size := server.font_get_glyph_texture_size(font_rid, size, index)
	if not store.has(texture):
		store[texture] = {"points": PackedVector2Array(), "uvs": PackedVector2Array(), "colors": PackedColorArray(), "indices": PackedInt32Array()}
	var batch: Dictionary = store[texture]
	var points: PackedVector2Array = batch["points"]
	var uvs: PackedVector2Array = batch["uvs"]
	var colors: PackedColorArray = batch["colors"]
	var indices: PackedInt32Array = batch["indices"]
	var first := points.size()
	for corner: Vector2 in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
		points.append(xform * (rect.position + rect.size * corner))
		uvs.append((uv.position + uv.size * corner) / texture_size)
		colors.append(color)
	for offset: int in [0, 1, 2, 0, 2, 3]:
		indices.append(first + offset)
	batch["points"] = points
	batch["uvs"] = uvs
	batch["colors"] = colors
	batch["indices"] = indices


## ためた文字が、何回の命令になるか（文字の絵の数。ふちと中身の合計）。
func draw_call_count() -> int:
	return _outline.size() + _fill.size()


## ためた文字を、item（CanvasItem）に描く。ふちを全部描いてから、中身を全部描く。
func flush(item: CanvasItem) -> void:
	for store: Dictionary in [_outline, _fill]:
		for texture: RID in store:
			var batch: Dictionary = store[texture]
			RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), batch["indices"], batch["points"], batch["colors"], batch["uvs"], PackedInt32Array(), PackedFloat32Array(), texture)
	clear()
