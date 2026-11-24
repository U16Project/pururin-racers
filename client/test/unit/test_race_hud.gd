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


func test_heart_color_warns_before_the_limit_and_turns_red_above_it() -> void:
	assert_eq(RaceHud.heart_color(_state(150.0)), RaceHud.COLOR_COOL)
	assert_eq(RaceHud.heart_color(_state(190.0)), RaceHud.COLOR_WARN)
	assert_eq(RaceHud.heart_color(_state(201.0)), RaceHud.COLOR_DANGER)


func test_local_race_shows_the_compact_hud_and_hides_debug_text_by_default() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	assert_not_null(race.get_node_or_null("UI/RaceHud"))
	assert_false(race.get_node("UI/HudLabel").visible)
	race.free()


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

func test_style_state_color_follows_the_rank_bonus_sign() -> void:
	assert_eq(RaceHud.style_state_color(1), RaceHud.COLOR_STYLE_MATCH)
	assert_eq(RaceHud.style_state_color(0), RaceHud.COLOR_TEXT)
	assert_eq(RaceHud.style_state_color(-1), RaceHud.COLOR_STYLE_FAR)


func test_confirmed_count_counts_the_finished_rows_at_the_top() -> void:
	assert_eq(RaceHud.confirmed_count([]), 0)
	assert_eq(RaceHud.confirmed_count([{"finished": false}, {"finished": false}]), 0)
	assert_eq(RaceHud.confirmed_count([{"finished": true}, {"finished": true}, {"finished": false}]), 2)
	assert_eq(RaceHud.confirmed_count([{"finished": true}, {"finished": true}]), 2)


func test_standings_scale_changes_the_width() -> void:
	var hud := RaceHud.new()
	add_child_autofree(hud)
	assert_eq(hud.standings_scale, 1.0)
	hud.standings_panel_width = 240.0
	for factor in [0.5, 1.0, 1.5]:
		hud.standings_scale = factor
		var width: float = (RaceHud.STANDINGS_ROW_PAD + RaceHud.STANDINGS_WIDTH) * hud.standings_draw_scale()
		assert_almost_eq(width, hud.standings_panel_width * factor, 0.001)


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


func test_standings_are_not_redrawn_every_frame() -> void:
	var hud := RaceHud.new()
	add_child_autofree(hud)
	# 心拍が上限を超えていても、値が変わらなければ、毎コマの描き直しを頼まない。
	hud.update_state({"heart_bpm": float(hud.get("_state")["heart_normal_max_bpm"]) + 20.0})
	await get_tree().process_frame
	await get_tree().process_frame
	var draws := [0]
	hud.draw.connect(func() -> void: draws[0] += 1)
	for index in 5:
		await get_tree().process_frame
	assert_eq(draws[0], 0)
