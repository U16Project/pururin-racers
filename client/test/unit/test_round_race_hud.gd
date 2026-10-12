extends GutTest
## 丸い操作盤、足元の文字、ウェブ版オフラインテストの確認。期待値は、定数や式から作る。

const RoundRaceHud := preload("res://scripts/presentation/round_race_hud.gd")
const RaceHud := preload("res://scripts/presentation/race_hud.gd")
const PlayerGroundMarker := preload("res://scripts/presentation/player_ground_marker.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const ModeSelectScene := preload("res://scenes/mode_select.tscn")


func after_each() -> void:
	RaceSession.set_course_only(false)


func _race(course_only: bool) -> Node:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	RaceSession.set_course_only(course_only)
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	return race


func test_clock_text_is_minutes_seconds_hundredths() -> void:
	assert_eq(RoundRaceHud.clock_text(0.0), "0:00:00")
	assert_eq(RoundRaceHud.clock_text(35.0), "0:35:00")
	assert_eq(RoundRaceHud.clock_text(95.07), "1:35:07")
	assert_eq(RoundRaceHud.clock_text(-3.0), "0:00:00")


func test_goal_is_fixed_and_start_moves_with_the_distance() -> void:
	var goal := float(RoundRaceHud.DISTANCE_GOAL_DEG)
	for distance: float in RaceSession.supported_distances_m():
		# 走り終えた所は、どの距離でも、Gの角度。
		assert_almost_eq(RoundRaceHud.distance_deg(distance, distance), goal, 0.0001)
		# 走り始めは、Sの角度。
		assert_almost_eq(RoundRaceHud.distance_deg(distance, 0.0), RoundRaceHud.distance_start_deg(distance), 0.0001)
	# 距離が長いほど、SはGから遠い。
	var distances: Array = RaceSession.supported_distances_m()
	for index in range(1, distances.size()):
		assert_gt(RoundRaceHud.distance_start_deg(float(distances[index])), RoundRaceHud.distance_start_deg(float(distances[index - 1])))


func test_stamina_gauge_has_full_zero_and_debt_ends() -> void:
	assert_almost_eq(RoundRaceHud.stamina_deg(1.0), float(RoundRaceHud.STAMINA_FULL_DEG), 0.0001)
	assert_almost_eq(RoundRaceHud.stamina_deg(0.0), float(RoundRaceHud.STAMINA_ZERO_DEG), 0.0001)
	assert_almost_eq(RoundRaceHud.stamina_deg(-1.0), float(RoundRaceHud.STAMINA_DEBT_DEG), 0.0001)
	# 0%の線は、満タンと借りの端のあいだにある。
	assert_between(float(RoundRaceHud.STAMINA_ZERO_DEG), float(RoundRaceHud.STAMINA_FULL_DEG), float(RoundRaceHud.STAMINA_DEBT_DEG))


func test_higher_notches_have_longer_gauge_parts() -> void:
	var total := 0
	for level in range(1, RoundRaceHud.NOTCH_MAX + 1):
		if level > 1:
			assert_gt(RoundRaceHud.notch_cells(level), RoundRaceHud.notch_cells(level - 1))
		assert_eq(RoundRaceHud.notch_cells_before(level), total)
		total += RoundRaceHud.notch_cells(level)
	assert_eq(RoundRaceHud.notch_cells_before(RoundRaceHud.NOTCH_MAX + 1), total)


func test_notch_gauge_color_runs_from_green_through_yellow_to_red() -> void:
	assert_eq(RoundRaceHud.notch_gradient(0.0), RaceHud.COLOR_OK)
	assert_eq(RoundRaceHud.notch_gradient(0.5), RoundRaceHud.COLOR_NOTCH)
	assert_eq(RoundRaceHud.notch_gradient(1.0), RaceHud.COLOR_DANGER)


func test_place_color_marks_the_top_three() -> void:
	assert_eq(RoundRaceHud.place_color(1), RaceHud.COLOR_GOLD)
	assert_eq(RoundRaceHud.place_color(2), RaceHud.COLOR_SILVER)
	assert_eq(RoundRaceHud.place_color(3), RaceHud.COLOR_BRONZE)
	assert_eq(RoundRaceHud.place_color(4), RoundRaceHud.COLOR_TEXT)


func test_heart_glows_at_the_beat_and_fades_out() -> void:
	assert_almost_eq(RoundRaceHud.beat_glow(0.0), 1.0, 0.0001)
	assert_almost_eq(RoundRaceHud.beat_glow(float(RoundRaceHud.HEART_BEAT_PART)), 0.0, 0.0001)
	assert_almost_eq(RoundRaceHud.beat_glow(1.0), 0.0, 0.0001)
	assert_gt(RoundRaceHud.beat_glow(0.0), RoundRaceHud.beat_glow(float(RoundRaceHud.HEART_BEAT_PART) * 0.5))


func test_curved_text_is_never_upside_down() -> void:
	# 上半分（9時〜12時〜3時）は「上向き」、下半分は「下向き」として並べる。
	for degrees: float in [0.0, 45.0, 90.0, 270.0, 315.0, 360.0]:
		assert_true(RoundRaceHud.arc_text_is_upper(degrees), "%.0f度は上半分" % degrees)
	for degrees: float in [91.0, 135.0, 180.0, 225.0, 269.0]:
		assert_false(RoundRaceHud.arc_text_is_upper(degrees), "%.0f度は下半分" % degrees)


func test_race_shows_the_round_hud_and_hides_the_old_bottom_panel() -> void:
	var race := _race(false)
	var round_hud: Control = race.get("_round_hud")
	assert_not_null(round_hud)
	assert_not_null(race.get_node_or_null("UI/RoundRaceHudView"))
	# 前の操作盤は、残してあるが、下の盤は描かない。順位表は、画面にそのまま出す。
	var race_hud: Control = race.get_node("UI/RaceHud")
	assert_false(bool(race_hud.get("main_panel_visible")))
	assert_null(race.get_node_or_null("UI/RaceHudView"))
	# 丸い操作盤は、仮想パッドのラインのボタンのすぐ右、画面の下。
	var view: Control = race.get_node("UI/RoundRaceHudView")
	var radius := float(race.ROUND_HUD_RADIUS)
	var center := view.position + view.size * 0.5
	assert_almost_eq(center.x - radius, float(race.TouchControls.LINE_BUTTONS_RIGHT) + float(race.ROUND_HUD_STICK_GAP), 0.5)


func test_ground_text_shows_notch_then_speed_then_heart_rate() -> void:
	assert_eq(PlayerGroundMarker.info_parts(0, 4, 55.4, 148.2), ["4", "ノッチ", true])
	assert_eq(PlayerGroundMarker.info_parts(1, 4, 55.4, 148.2), ["55", "km/h", false])
	assert_eq(PlayerGroundMarker.info_parts(2, 4, 55.4, 148.2), ["148", "bpm", false])
	# ノッチは、0を出さない（一番下は1）。
	assert_eq(PlayerGroundMarker.info_parts(0, 0, 0.0, 100.0)[0], "1")


func test_ground_text_fades_in_and_out() -> void:
	var step := float(PlayerGroundMarker.INFO_STEP_S)
	assert_almost_eq(PlayerGroundMarker.info_alpha_at(0.0), 0.0, 0.0001)
	assert_almost_eq(PlayerGroundMarker.info_alpha_at(step * 0.5), float(PlayerGroundMarker.INFO_ALPHA_MAX), 0.0001)
	assert_almost_eq(PlayerGroundMarker.info_alpha_at(step), 0.0, 0.0001)


func test_ground_text_returns_to_the_notch_when_the_notch_changes() -> void:
	var marker := MeshInstance3D.new()
	marker.set_script(PlayerGroundMarker)
	add_child_autofree(marker)
	var step := float(PlayerGroundMarker.INFO_STEP_S)
	marker.call("show_info", 3, 50.0, 150.0, 0.0)
	assert_eq(int(marker.get("_info_index")), 0)
	# 1つぶんの時間が過ぎると、次（速さ）へ進む。
	marker.call("show_info", 3, 50.0, 150.0, step * 1.1)
	assert_eq(int(marker.get("_info_index")), 1)
	assert_eq((marker.get_node(PlayerGroundMarker.INFO_WORD_NAME) as Label3D).text, "km/h")
	# ノッチが変わったら、ノッチの表示に戻る。
	marker.call("show_info", 4, 50.0, 150.0, 0.1)
	assert_eq(int(marker.get("_info_index")), 0)
	assert_eq((marker.get_node(PlayerGroundMarker.INFO_VALUE_NAME) as Label3D).text, "4")


func test_mode_select_has_the_web_offline_test_button() -> void:
	var screen: Node = ModeSelectScene.instantiate()
	add_child_autofree(screen)
	var button := screen.find_child("WebOfflineTestButton", true, false) as Button
	assert_not_null(button)
	assert_eq(button.text, "ウェブ版オフラインテスト")


func test_web_offline_test_builds_only_the_course_and_turns_shadows_off() -> void:
	var race := _race(true)
	# コースまわり（柵）はある。観客席・旗の柱などは作らない。
	assert_not_null(race.get_node_or_null("TrackPath/RaceVenue/FencePosts"))
	assert_null(race.get_node_or_null("TrackPath/RaceVenue/Poles"))
	assert_eq(race.get_node("TrackPath/RaceVenue/HomeStraight").get_child_count(), 0)
	assert_eq(race.get_node("TrackPath/RaceVenue/Field").get_child_count(), 0)
	assert_false((race.get_node("Sun") as DirectionalLight3D).shadow_enabled)
	assert_not_null(race.get_node_or_null("UI/FpsLabel"))
	# 順位表は、別の絵に描いて貼る。
	assert_not_null(race.get_node_or_null("UI/RaceHudView"))


func test_normal_race_keeps_the_full_venue_and_shadows() -> void:
	var race := _race(false)
	assert_not_null(race.get_node_or_null("TrackPath/RaceVenue/Poles"))
	assert_gt(race.get_node("TrackPath/RaceVenue/HomeStraight").get_child_count(), 0)
	assert_true((race.get_node("Sun") as DirectionalLight3D).shadow_enabled)
	assert_null(race.get_node_or_null("UI/FpsLabel"))
