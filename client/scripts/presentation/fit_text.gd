extends RefCounted
## 名前などの文字を、決めた幅に収める。入るときは何もしない。
## 入りきらないときは、文字を少し小さくするのと、横に細くするのを、半分ずつ使って収める。
## 限度まで縮めても入らないときは、入る所まで削って、末尾を「…」にする。
## 操作盤・順位表・着順の板・メニューで、同じ決まりを使う。

## 文字の大きさは、元のこの割合まで。
const MIN_SIZE_SCALE := 0.8
## 横の細さは、元のこの割合まで。
const MIN_X_SCALE := 0.75
const ELLIPSIS := "…"


## 幅に収めた結果。text（出す文字。削ったときは末尾が「…」）、font_size、x_scale（横の細さ。1でそのまま）、width（出したときの幅）。
static func fit(font: Font, text: String, max_width: float, font_size: int) -> Dictionary:
	var natural := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if natural <= max_width or text.is_empty():
		return {"text": text, "font_size": font_size, "x_scale": 1.0, "width": natural}
	# 必要な縮みを、大きさと細さで半分ずつ受け持つ（掛け合わせると、必要な縮みになる）。
	var size_scale := clampf(sqrt(max_width / natural), MIN_SIZE_SCALE, 1.0)
	var size := maxi(roundi(font_size * size_scale), ceili(font_size * MIN_SIZE_SCALE))
	var shown := text
	var width := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x_scale := clampf(max_width / width, MIN_X_SCALE, 1.0)
	while width * x_scale > max_width + 0.01 and shown.length() > 1:
		shown = shown.substr(0, shown.length() - 1)
		width = font.get_string_size(shown + ELLIPSIS, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		x_scale = clampf(max_width / width, MIN_X_SCALE, 1.0)
	if shown != text:
		shown += ELLIPSIS
	return {"text": shown, "font_size": size, "x_scale": x_scale, "width": width * x_scale}


## 幅に収めて描く。position は、幅 max_width の欄の、左端・文字の下の線（ベースライン）。
## align_ratio は、欄の中での寄せ方（0＝左寄せ、0.5＝中央、1＝右寄せ）。outline_size が0より大きければ、縁取りを付ける。
## 収めた結果（fit と同じ）を返す。
static func draw(
	canvas: CanvasItem,
	font: Font,
	position: Vector2,
	text: String,
	max_width: float,
	font_size: int,
	color: Color,
	align_ratio: float = 0.0,
	outline_size: int = 0,
	outline_color: Color = Color.BLACK
) -> Dictionary:
	var fitted := fit(font, text, max_width, font_size)
	var origin := position + Vector2(maxf(max_width - float(fitted["width"]), 0.0) * align_ratio, 0.0)
	canvas.draw_set_transform(origin, 0.0, Vector2(float(fitted["x_scale"]), 1.0))
	if outline_size > 0:
		canvas.draw_string_outline(font, Vector2.ZERO, str(fitted["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(fitted["font_size"]), outline_size, outline_color)
	canvas.draw_string(font, Vector2.ZERO, str(fitted["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(fitted["font_size"]), color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return fitted
