extends GutTest

const GlyphBatch := preload("res://scripts/presentation/glyph_batch.gd")


func test_many_texts_of_one_size_become_a_few_draw_calls() -> void:
	var font := ThemeDB.fallback_font
	var batch := GlyphBatch.new()
	var texts := 40
	for index in texts:
		batch.add(font, "12", 20, Vector2(0.0, 20.0 * index), Color.WHITE, 4, Color.BLACK, Transform2D(0.1 * index, Vector2.ZERO))
	# 1つずつ描けば、ふちと中身で texts × 2 回。まとめると、文字の絵の数（ふち・中身）だけで済む。
	assert_gt(batch.draw_call_count(), 0)
	assert_lt(batch.draw_call_count(), texts)


func test_flush_draws_and_empties_the_batch() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	var batch := GlyphBatch.new()
	batch.add(ThemeDB.fallback_font, "A", 16, Vector2.ZERO, Color.WHITE)
	batch.flush(canvas)
	assert_eq(batch.draw_call_count(), 0)


func test_empty_text_adds_nothing() -> void:
	var batch := GlyphBatch.new()
	batch.add(ThemeDB.fallback_font, "", 16, Vector2.ZERO, Color.WHITE, 4)
	assert_eq(batch.draw_call_count(), 0)
