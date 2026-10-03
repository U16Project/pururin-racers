extends GutTest

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")

func _state(heart: float = 150.0, fuel: float = 0.5) -> Dictionary:
	return {
		"heart_bpm": heart, "heart_min_bpm": 100.0, "heart_normal_max_bpm": 200.0, "heart_max_bpm": 230.0,
		"fuel_ratio": fuel,
	}


func test_heart_bar_spans_min_to_overheat_and_marks_the_normal_limit() -> void:
	assert_almost_eq(RaceHud.heart_fill_ratio(_state(100.0)), 0.0, 0.0001)
	assert_almost_eq(RaceHud.heart_fill_ratio(_state(230.0)), 1.0, 0.0001)
	assert_almost_eq(RaceHud.heart_fill_ratio(_state(300.0)), 1.0, 0.0001)
	assert_almost_eq(RaceHud.heart_limit_ratio(_state()), 100.0 / 130.0, 0.0001)


func test_heart_color_warns_before_the_limit_and_turns_red_above_it() -> void:
	assert_eq(RaceHud.heart_color(_state(150.0)), RaceHud.COLOR_COOL)
	assert_eq(RaceHud.heart_color(_state(190.0)), RaceHud.COLOR_WARN)
	assert_eq(RaceHud.heart_color(_state(201.0)), RaceHud.COLOR_DANGER)
	assert_true(RaceHud.heart_is_overheated(_state(201.0)))
	assert_false(RaceHud.heart_is_overheated(_state(200.0)))


func test_fuel_gauge_clamps_and_marks_debt() -> void:
	assert_eq(RaceHud.fuel_fill_ratio(-0.4), 0.0)
	assert_eq(RaceHud.fuel_fill_ratio(1.4), 1.0)
	assert_true(RaceHud.fuel_is_in_debt(_state(150.0, -0.1)))
	assert_false(RaceHud.fuel_is_in_debt(_state(150.0, 0.0)))
	assert_eq(RaceHud.fuel_color(0.8), RaceHud.COLOR_OK)
	assert_eq(RaceHud.fuel_color(0.3), RaceHud.COLOR_WARN)
	assert_eq(RaceHud.fuel_color(0.1), RaceHud.COLOR_DANGER)
	assert_eq(RaceHud.fuel_color(-0.1), RaceHud.COLOR_DANGER)


func test_local_race_shows_the_compact_hud_and_hides_debug_text_by_default() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	assert_not_null(race.get_node_or_null("UI/RaceHud"))
	assert_false(race.get_node("UI/HudLabel").visible)
	race.free()


func test_draft_gauge_has_ten_segments_and_lights_one_for_any_draft() -> void:
	var full := RaceHud.DRAFT_GAUGE_FULL_STRENGTH
	assert_eq(RaceHud.draft_segments(0.0), 0)
	assert_eq(RaceHud.draft_segments(0.001), 1)
	# 平方根の目盛り：満タンの25%の受取量で半分（5段）、100%で10段。
	assert_eq(RaceHud.draft_segments(full * 0.25), 5)
	assert_eq(RaceHud.draft_segments(full * 0.36), 6)
	assert_eq(RaceHud.draft_segments(full), 10)
	assert_eq(RaceHud.draft_segments(full * 3.0), 10)
	# 実測の受取量：前の走者2頭で約0.9、3頭で約1.8、6頭で約4.4、最後尾（11頭）で約9.5。
	assert_eq(RaceHud.draft_segments(0.9), 3)
	assert_eq(RaceHud.draft_segments(1.8), 4)
	assert_eq(RaceHud.draft_segments(4.4), 7)
	assert_lt(RaceHud.draft_segments(9.5), 10)
