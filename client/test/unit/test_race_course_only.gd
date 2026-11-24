extends GutTest
## ウェブ版オフラインテスト（コースだけ）と、景色ありのレースの作りの確認。

const RaceSession := preload("res://scripts/race_session.gd")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const SunShadow := preload("res://scripts/presentation/sun_shadow.gd")


func after_each() -> void:
	RaceSession.set_course_only(false)


func _race(course_only: bool) -> Node:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())
	RaceSession.set_course_only(course_only)
	var race: Node = LocalRaceScene.instantiate()
	add_child_autofree(race)
	return race


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
	# 太陽の影は、出してよい端末でだけ出す（ブラウザ版では、白っぽくなるので出さない）。
	assert_eq(SunShadow.allowed(), not OS.has_feature("web"))
	assert_eq((race.get_node("Sun") as DirectionalLight3D).shadow_enabled, SunShadow.allowed())
	# 重さを確かめる表示は、景色ありのレースにも置く。
	assert_not_null(race.get_node_or_null("UI/FpsLabel"))


func test_frame_counter_shows_only_with_the_detail_display_f3() -> void:
	var race := _race(false)
	var fps_label: Control = race.get_node("UI/FpsLabel")
	assert_false(fps_label.visible, "はじめは出さない")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F3
	key.pressed = true
	race._unhandled_input(key)
	assert_true(fps_label.visible, "F3で出す")
	race._unhandled_input(key)
	assert_false(fps_label.visible, "もう一度F3で消す")
