extends GutTest
## レースの左上の操作盤（場面 race_control_panel.tscn）と、右上へ移した順位表の確認。期待値は、設定や式から作る。

const RaceControlPanel := preload("res://scripts/presentation/hud/race_control_panel.gd")
const PanelScene := preload("res://scenes/hud/race_control_panel.tscn")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceMath := preload("res://scripts/local_race_math.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func _panel() -> Control:
	var panel: Control = PanelScene.instantiate()
	add_child_autofree(panel)
	return panel


func test_race_shows_the_panel_at_the_top_left_and_hides_the_old_bottom_panel() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var hud: Control = race.get("_heart_hud")
	assert_eq(hud.get_script(), RaceControlPanel)
	var view: Control = race.get_node("UI/HeartRaceHudView")
	assert_eq(view.position, race.HEART_HUD_MARGIN)
	var board: Control = hud.get_node("Board")
	assert_almost_eq(view.size.x, board.size.x * float(race.HEART_HUD_SCALE), 1.0)
	assert_false(bool(race.get_node("UI/RaceHud").get("main_panel_visible")))


func test_board_top_left_sits_at_the_panel_origin() -> void:
	var panel := _panel()
	var factor := 0.5
	panel.set_scale_factor(factor)
	var board: Control = panel.get_node("Board")
	assert_almost_eq(panel.position + board.position * factor, Vector2.ZERO, Vector2(0.001, 0.001))
	assert_almost_eq(panel.custom_minimum_size, board.size * factor, Vector2(0.001, 0.001))


func test_values_reach_the_parts() -> void:
	var panel := _panel()
	var notch_max := int(LocalRaceMath.DRIVE_LEVEL_MAX)
	var boost_max := int(LocalRaceMath.Config.number("boost_max_uses"))
	panel.update_state({
		"speed_kmh": RaceControlPanel.SPEED_FULL_KMH * 0.5, "fuel_ratio": -0.4, "air_base": 0.05, "air_rear": 0.1, "air_blue": 0.2,
		"notch": 2, "notch_max": notch_max, "boost_uses_left": 1, "boost_max_uses": boost_max, "boost_ratio": 0.6,
		"dash_ratio": 0.3, "heart_bpm": 165.0, "heart_min_bpm": 100.0, "heart_max_bpm": 230.0, "heart_normal_max_bpm": 200.0,
		"player_name": "アカネ", "trainer_name": "U16",
	})
	assert_almost_eq(float(panel.get_node("Gauges/Speed").get("value")), 0.5, 0.0001)
	assert_eq(panel.get_node("SpeedText/SpeedValue").text, "%d" % int(round(RaceControlPanel.SPEED_FULL_KMH * 0.5)))
	assert_almost_eq(float(panel.get_node("Gauges/Stamina").get("value")), RaceControlPanel.stamina_value(-0.4), 0.0001)
	assert_eq(panel.get_node("StaminaText/StaminaValue").text, "-40")
	# 空力のゲージは、根本から 黄（空力の能力）・緑（後方支援）・青（ドラフト）を積み上げる。
	# 弧は AERO_FULL で満タン。数字は本当の割合。
	assert_almost_eq(float(panel.get_node("Aero/AeroBlue").get("value")), 0.35 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_almost_eq(float(panel.get_node("Aero/AeroGreen").get("value")), 0.15 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_almost_eq(float(panel.get_node("Aero/AeroBase").get("value")), 0.05 / RaceControlPanel.AERO_FULL, 0.0001)
	assert_eq(panel.get_node("Aero/AeroValue").text, "35")
	assert_eq(int(panel.get_node("Notch/NotchBars").get("count")), notch_max)
	assert_eq(int(panel.get_node("Notch/NotchBars").get("lit_count")), 2)
	assert_eq(int(panel.get_node("Boost/BoostBars").get("count")), boost_max)
	assert_eq(int(panel.get_node("Boost/BoostBars").get("lit_count")), 1)
	assert_almost_eq(float(panel.get_node("Boost/BoostBars").get("partial")), 0.6, 0.0001)
	assert_almost_eq(float(panel.get_node("Dash/DashBar").get("value")), 0.3, 0.0001)
	assert_almost_eq(float(panel.get_node("Heart").get("value")), 0.5, 0.0001)
	assert_eq(panel.get_node("NameRow/Name").text, "アカネ（U16）")


func test_stamina_zero_is_the_middle_of_the_arc() -> void:
	assert_almost_eq(RaceControlPanel.stamina_value(1.0), 1.0, 0.0001)
	assert_almost_eq(RaceControlPanel.stamina_value(0.0), 0.5, 0.0001)
	assert_almost_eq(RaceControlPanel.stamina_value(-1.0), 0.0, 0.0001)


func test_long_name_is_squeezed_before_the_attribute_mark() -> void:
	var panel := _panel()
	panel.update_state({"player_name": "ア".repeat(12), "trainer_name": "ト".repeat(12)})
	var name: Label = panel.get_node("NameRow/Name")
	var attribute: Control = panel.get_node("NameRow/Attribute")
	assert_lt(name.position.x + name.get_minimum_size().x * name.scale.x, attribute.position.x)


func test_heart_water_turns_from_cyan_to_red_near_the_limit() -> void:
	var normal_max := 200.0
	assert_eq(RaceControlPanel.heart_water_color(normal_max - RaceControlPanel.HEART_WARN_FROM_BPM, normal_max, 230.0), RaceControlPanel.COLOR_HEART_LOW)
	assert_eq(RaceControlPanel.heart_water_color(230.0, normal_max, 230.0), RaceControlPanel.COLOR_HEART_HIGH)


func test_standings_sit_under_the_panel_within_its_width() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var view: Control = race.get_node("UI/HeartRaceHudView")
	var origin: Vector2 = race.get_node("UI/RaceHud").get("standings_origin")
	# 操作盤のすぐ下、左はしは操作盤にそろえる。幅は、操作盤からはみ出さない。
	assert_almost_eq(origin.y, view.position.y + view.size.y + float(race.STANDINGS_GAP), 0.001)
	assert_almost_eq(origin.x - RaceHud.STANDINGS_ROW_PAD, view.position.x, 0.001)
	assert_lte(RaceHud.STANDINGS_ROW_PAD + RaceHud.STANDINGS_WIDTH, view.size.x)


func test_stamina_lost_in_a_push_stays_red_and_then_fades() -> void:
	var panel := _panel()
	var stamina_hit := panel.get_node("Gauges/StaminaHit")
	panel.call("_update_stamina_hit", 0.8, true, 0)
	panel.call("_update_stamina_hit", 0.6, true, 100)
	# 押し合いのあいだは、始まったときの体力で、赤い帯の上のはしを止める。
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.8, 0.0001)
	# 終わったら、だんだん今の値へ戻り、決めた秒数で消える。
	panel.call("_update_stamina_hit", 0.6, false, 200)
	panel.call("_update_stamina_hit", 0.6, false, 200 + int(RaceControlPanel.STAMINA_HIT_FADE_S * 500.0))
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.7, 0.0001)
	panel.call("_update_stamina_hit", 0.6, false, 200 + int(RaceControlPanel.STAMINA_HIT_FADE_S * 1000.0))
	assert_almost_eq(float(panel.get("_stamina_hit_ratio")), 0.6, 0.0001)
	assert_not_null(stamina_hit)


func test_losing_a_push_flashes_and_shakes_the_heart_and_then_restores_it() -> void:
	var panel := _panel()
	var heart: Control = panel.get_node("Heart")
	var edge: Color = heart.get("edge_color")
	var position: Vector2 = heart.position
	# 点滅のいちばん赤い瞬間（1回の点滅の4分の1）。
	panel.call("_update_heart_hit", true, int(1000.0 / RaceControlPanel.HEART_HIT_FLASH_PER_S / 4.0))
	assert_true((heart.get("edge_color") as Color).is_equal_approx(RaceControlPanel.HEART_HIT_EDGE_COLOR))
	panel.call("_update_heart_hit", false, 0)
	assert_true((heart.get("edge_color") as Color).is_equal_approx(edge))
	assert_eq(heart.position, position)
