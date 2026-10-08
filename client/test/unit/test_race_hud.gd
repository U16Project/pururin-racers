extends GutTest

const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")

const _RaceSessionForSetup := preload("res://scripts/race_session.gd")


## レースの場面は、ユーザーと相手が選ばれていないと走らないので、全員で出る状態にしておく。
func before_each() -> void:
	_RaceSessionForSetup.select_full_field(_RaceSessionForSetup.default_player_pururin_id())


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
	assert_almost_eq(RaceHud.fuel_debt_ratio(-0.4), 0.4, 0.0001)
	assert_eq(RaceHud.fuel_debt_ratio(0.4), 0.0)
	assert_eq(RaceHud.fuel_debt_ratio(-1.5), 1.0)
	assert_eq(RaceHud.fuel_fill_ratio(1.4), 1.0)
	assert_true(RaceHud.fuel_is_in_debt(_state(150.0, -0.1)))
	assert_false(RaceHud.fuel_is_in_debt(_state(150.0, 0.0)))


func test_local_race_shows_the_compact_hud_and_hides_debug_text_by_default() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	assert_not_null(race.get_node_or_null("UI/RaceHud"))
	assert_false(race.get_node("UI/HudLabel").visible)
	race.free()


func test_air_gauge_stacks_green_then_blue_in_twenty_segments() -> void:
	var step := RaceHud.AIR_GAUGE_FULL / float(RaceHud.AIR_GAUGE_SEGMENTS)
	assert_eq(RaceHud.air_gauge_segments(0.0, 0.0), {"green": 0, "blue": 0})
	# 緑だけ、青だけ、両方。
	assert_eq(RaceHud.air_gauge_segments(step * 3.0, 0.0), {"green": 3, "blue": 0})
	assert_eq(RaceHud.air_gauge_segments(0.0, step * 5.0), {"green": 0, "blue": 5})
	assert_eq(RaceHud.air_gauge_segments(step * 2.0, step * 6.0), {"green": 2, "blue": 6})
	# 少しでもあれば、その色は1段は点く。
	assert_eq(RaceHud.air_gauge_segments(0.001, 0.0)["green"], 1)
	assert_eq(RaceHud.air_gauge_segments(0.0, 0.001)["blue"], 1)
	assert_eq(RaceHud.air_gauge_segments(0.001, 0.001), {"green": 1, "blue": 1})
	# 満タンを超えても20段まで。
	var over := RaceHud.air_gauge_segments(RaceHud.AIR_GAUGE_FULL, RaceHud.AIR_GAUGE_FULL)
	assert_eq(int(over["green"]) + int(over["blue"]), RaceHud.AIR_GAUGE_SEGMENTS)
	assert_eq(RaceHud.air_gauge_segments(0.0, RaceHud.AIR_GAUGE_FULL), {"green": 0, "blue": RaceHud.AIR_GAUGE_SEGMENTS})


func test_fuel_color_is_a_smooth_gradient_from_blue_to_deep_red() -> void:
	var stops := RaceHud.fuel_gradient_stops()
	for stop: Array in stops:
		assert_true(RaceHud.fuel_color(float(stop[0])).is_equal_approx(stop[1]))
	# 範囲の外は両端の色。
	assert_true(RaceHud.fuel_color(2.0).is_equal_approx(RaceHud.COLOR_FUEL_FULL))
	assert_true(RaceHud.fuel_color(-2.0).is_equal_approx(RaceHud.COLOR_DEBT_DEEP))
	# 隣り合う段階の間は、両端の色の間にある（急に変わらない）。
	for index in stops.size() - 1:
		var mid := (float(stops[index][0]) + float(stops[index + 1][0])) * 0.5
		var expected: Color = (stops[index][1] as Color).lerp(stops[index + 1][1], 0.5)
		assert_true(RaceHud.fuel_color(mid).is_equal_approx(expected))
	# 位置: 満タンは上端、0は1/4の高さ、負債の限度は下端。負債側は縮尺が小さい。
	var zero_y := RaceHud.fuel_zero_y(0.0)
	assert_almost_eq(RaceHud.fuel_y(zero_y, 1.0), 0.0, 0.0001)
	assert_almost_eq(RaceHud.fuel_y(zero_y, 0.0), zero_y, 0.0001)
	assert_almost_eq(RaceHud.fuel_y(zero_y, -1.0), RaceHud.GAUGE_BAR_HEIGHT, 0.0001)
	assert_lt(absf(RaceHud.fuel_y(zero_y, -0.1) - zero_y), absf(RaceHud.fuel_y(zero_y, 0.1) - zero_y))

func test_style_state_color_follows_the_rank_bonus_sign() -> void:
	assert_eq(RaceHud.style_state_color(1), RaceHud.COLOR_STYLE_MATCH)
	assert_eq(RaceHud.style_state_color(0), RaceHud.COLOR_TEXT)
	assert_eq(RaceHud.style_state_color(-1), RaceHud.COLOR_STYLE_FAR)


func test_confirmed_count_counts_the_finished_rows_at_the_top() -> void:
	assert_eq(RaceHud.confirmed_count([]), 0)
	assert_eq(RaceHud.confirmed_count([{"finished": false}, {"finished": false}]), 0)
	assert_eq(RaceHud.confirmed_count([{"finished": true}, {"finished": true}, {"finished": false}]), 2)
	assert_eq(RaceHud.confirmed_count([{"finished": true}, {"finished": true}]), 2)


func test_standings_time_text_shows_minutes_seconds_and_hundredths() -> void:
	assert_eq(RaceHud.standings_time_text(118.32), "1:58:32")
	assert_eq(RaceHud.standings_time_text(9.05), "0:09:05")


func test_standings_sit_midway_between_the_race_info_and_the_panel() -> void:
	var screen_height := 648.0
	var rows := 8
	var top := RaceHud.standings_top(screen_height, rows)
	var gap_above := top - (RaceHud.RACE_INFO_ORIGIN.y + RaceHud.RACE_INFO_HEIGHT)
	var gap_below := screen_height - RaceHud.PANEL_BOTTOM_MARGIN - RaceHud.PANEL_HEIGHT - (top + rows * RaceHud.STANDINGS_ROW_HEIGHT)
	assert_almost_eq(gap_above, gap_below, 0.0001)
	assert_gt(gap_above, 0.0)


func test_standings_start_at_the_same_height_whatever_the_field_size() -> void:
	# 表の位置は、満員の行の数で決める。人数が少ないレースでも、上から詰めて並ぶ。
	assert_eq(RaceHud.STANDINGS_FULL_ROWS, preload("res://scripts/local_race_math.gd").FIELD_SIZE)


## 全角9文字の名前。
func _nine_characters() -> String:
	return "ア".repeat(9)


func test_a_nine_character_name_is_never_cut_in_the_race_hud_or_the_result_board() -> void:
	var FitText := preload("res://scripts/presentation/fit_text.gd")
	var Board := preload("res://scripts/presentation/race_result_board.gd")
	var probe := Control.new()
	add_child_autofree(probe)
	var font := probe.get_theme_default_font()
	var bold := FontVariation.new()
	bold.base_font = font
	bold.variation_embolden = 0.8
	var name := _nine_characters()
	# 操作盤の名札：そのままの大きさで入る。
	var tab := FitText.fit(font, name, RaceHud.NAME_TAB_MAX_TEXT_WIDTH, RaceHud.NAME_TAB_FONT_SIZE)
	assert_eq(tab["text"], name)
	assert_eq(tab["x_scale"], 1.0)
	assert_eq(tab["font_size"], RaceHud.NAME_TAB_FONT_SIZE)
	# 順位表：ふつうの行も、確定した行（太字で大きい）も、削られない。
	var normal := FitText.fit(font, name, RaceHud.STANDINGS_NAME_WIDTH, RaceHud.STANDINGS_FONT_SIZE)
	assert_eq(normal["text"], name)
	var confirmed := FitText.fit(bold, name, RaceHud.STANDINGS_NAME_WIDTH, RaceHud.STANDINGS_CONFIRMED_FONT_SIZE)
	assert_eq(confirmed["text"], name)
	# 着順の板：ユーザーの行（太字）でも、そのままの大きさで入る。
	var time_width := font.get_string_size("9分59秒99", HORIZONTAL_ALIGNMENT_LEFT, -1, Board.FONT_SIZE).x
	var board_width: float = Board.BOARD_WIDTH - Board.TIME_RIGHT_MARGIN - time_width - Board.NAME_TIME_GAP - Board.NAME_X
	var board := FitText.fit(bold, name, board_width, Board.FONT_SIZE)
	assert_eq(board["text"], name)
	assert_eq(board["x_scale"], 1.0)


func test_the_name_tab_sits_between_the_standings_and_the_panel() -> void:
	var screen_height := 648.0
	var panel_top := screen_height - RaceHud.PANEL_BOTTOM_MARGIN - RaceHud.PANEL_HEIGHT
	var standings_bottom := RaceHud.standings_top(screen_height, RaceHud.STANDINGS_FULL_ROWS) + RaceHud.STANDINGS_FULL_ROWS * RaceHud.STANDINGS_ROW_HEIGHT
	assert_gte(panel_top - RaceHud.NAME_TAB_HEIGHT, standings_bottom, "名札は、順位表の一番下の行に重ならない")
	# 順位表の右端は、操作盤の右端までに収まる。
	assert_lte(RaceHud.STANDINGS_LEFT + RaceHud.STANDINGS_WIDTH, RaceHud.PANEL_LEFT_MARGIN + RaceHud.PANEL_WIDTH)
