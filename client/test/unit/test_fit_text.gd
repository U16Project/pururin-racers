extends GutTest
## 名前を幅に収める決まり：入るときはそのまま。入りきらないときは、大きさと横の細さを半分ずつ縮める。
## 限度まで縮めても入らないときは、末尾を「…」にする。

const FitText := preload("res://scripts/presentation/fit_text.gd")
const FONT_SIZE := 20


func _font() -> Font:
	return ThemeDB.fallback_font


func _width(text: String, font_size: int = FONT_SIZE) -> float:
	return _font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func test_text_that_fits_is_left_exactly_as_it_is() -> void:
	var text := "Abc"
	var fitted := FitText.fit(_font(), text, _width(text) + 1.0, FONT_SIZE)
	assert_eq(fitted["text"], text)
	assert_eq(fitted["font_size"], FONT_SIZE)
	assert_eq(fitted["x_scale"], 1.0)
	assert_almost_eq(float(fitted["width"]), _width(text), 0.001)


func test_text_that_is_a_little_too_long_shrinks_in_size_and_in_width_together() -> void:
	var text := "Abcdefghi"
	var max_width := _width(text) * 0.7
	var fitted := FitText.fit(_font(), text, max_width, FONT_SIZE)
	assert_eq(fitted["text"], text, "削らずに入る")
	assert_lt(int(fitted["font_size"]), FONT_SIZE, "文字が小さくなる")
	assert_gte(int(fitted["font_size"]), ceili(FONT_SIZE * FitText.MIN_SIZE_SCALE))
	assert_lt(float(fitted["x_scale"]), 1.0, "横も細くなる")
	assert_gte(float(fitted["x_scale"]), FitText.MIN_X_SCALE)
	assert_lte(float(fitted["width"]), max_width + 0.01)
	# 片方だけを大きく効かせない：大きさの縮みと、横の縮みが、近い割合になる。
	var size_scale := float(fitted["font_size"]) / float(FONT_SIZE)
	assert_almost_eq(size_scale, float(fitted["x_scale"]), 0.12)


func test_text_far_too_long_is_cut_and_ends_with_an_ellipsis() -> void:
	var text := "Abcdefghijklmnopqrstuvwxyz"
	var max_width := _width(text) * 0.3
	var fitted := FitText.fit(_font(), text, max_width, FONT_SIZE)
	assert_true(str(fitted["text"]).ends_with(FitText.ELLIPSIS))
	assert_lt(str(fitted["text"]).length(), text.length())
	assert_true(text.begins_with(str(fitted["text"]).trim_suffix(FitText.ELLIPSIS)))
	assert_eq(fitted["font_size"], ceili(FONT_SIZE * FitText.MIN_SIZE_SCALE), "大きさは、限度まで")
	assert_gte(float(fitted["x_scale"]), FitText.MIN_X_SCALE, "横の細さは、限度より細くしない")
	assert_lte(float(fitted["width"]), max_width + 0.01)


func test_the_limit_is_reached_just_before_cutting() -> void:
	# 元の幅の「大きさの限度 × 細さの限度」より少し広い幅なら、削らずに入る。
	var text := "Abcdefghi"
	var limit := FitText.MIN_SIZE_SCALE * FitText.MIN_X_SCALE
	var fitted := FitText.fit(_font(), text, _width(text) * (limit + 0.04), FONT_SIZE)
	assert_eq(fitted["text"], text)
