extends GutTest
## レースの左上の操作盤（ハート型。絵の部品で組み立てる PartsRaceHud）と、右上へ移した順位表の確認。期待値は、設定や式から作る。

const PartsRaceHud := preload("res://scripts/presentation/parts_race_hud.gd")
const PartsConfig := preload("res://scripts/config/heart_hud_parts_config.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")


func test_race_shows_the_parts_hud_at_the_top_left_and_hides_the_old_bottom_panel() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	var hud: Control = race.get("_heart_hud")
	assert_eq(hud.get_script(), PartsRaceHud)
	assert_null(race.get_node_or_null("UI/RoundRaceHudView"))
	var view: Control = race.get_node("UI/HeartRaceHudView")
	assert_eq(view.position, race.HEART_HUD_MARGIN)
	var canvas_width := float(PartsConfig.config()["canvas"][0])
	assert_almost_eq(view.size.x, canvas_width * 0.5 * float(race.HEART_HUD_SCALE), 1.0)
	var race_hud: Control = race.get_node("UI/RaceHud")
	assert_false(bool(race_hud.get("main_panel_visible")))


func test_all_parts_images_are_in_place() -> void:
	var notch_count := int(preload("res://scripts/local_race_math.gd").DRIVE_LEVEL_MAX)
	var boost_count := int(preload("res://scripts/local_race_math.gd").Config.number("boost_max_uses"))
	assert_eq(PartsConfig.missing_images(PartsConfig.config(), notch_count, boost_count), PackedStringArray())


func test_standings_sit_at_the_right_edge() -> void:
	for width: float in [1152.0, 1600.0]:
		assert_almost_eq(RaceHud.side_left(width) + RaceHud.STANDINGS_WIDTH + RaceHud.SIDE_RIGHT_MARGIN, width, 0.0001)


func test_heart_water_rises_from_the_lowest_to_the_overheat_limit() -> void:
	assert_almost_eq(PartsRaceHud.heart_fill(100.0, 100.0, 230.0), 0.0, 0.0001)
	assert_almost_eq(PartsRaceHud.heart_fill(165.0, 100.0, 230.0), 0.5, 0.0001)
	assert_almost_eq(PartsRaceHud.heart_fill(300.0, 100.0, 230.0), 1.0, 0.0001)


func test_heart_water_turns_from_cyan_to_red_near_the_limit() -> void:
	var normal_max := 200.0
	assert_eq(PartsRaceHud.heart_water_color(normal_max - PartsRaceHud.HEART_WARN_FROM_BPM, normal_max, 230.0), PartsRaceHud.COLOR_HEART_LOW)
	assert_eq(PartsRaceHud.heart_water_color(230.0, normal_max, 230.0), PartsRaceHud.COLOR_HEART_HIGH)
