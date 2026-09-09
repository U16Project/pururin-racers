extends GutTest

const M3Intro := preload("res://scripts/m3_intro.gd")


func test_intro_items_match_m3_guide() -> void:
	var intro := M3Intro.new()
	assert_eq(
		intro.get_intro_items(),
		PackedStringArray([
			"←→：走る位置　↑↓：目標スピード",
			"C：カメラ切替　Esc：メニュー（レース中）",
			"レース開始＝ローカル　集団プロトタイプ＝M4　控室へ進む＝接続",
		])
	)
	intro.free()


func test_connection_statuses_are_distinct_and_user_facing() -> void:
	var intro := M3Intro.new()
	assert_eq(intro.get_connection_status(M3Intro.ConnectionStage.CONNECTING), "接続しています…")
	assert_eq(intro.get_connection_status(M3Intro.ConnectionStage.CONNECTED), "接続できました")
	assert_eq(
		intro.get_connection_status(M3Intro.ConnectionStage.FAILED),
		"接続できませんでした。サーバーを起動してください"
	)
	intro.free()


func test_next_scene_is_existing_m2_room_scene() -> void:
	var intro := M3Intro.new()
	assert_eq(intro.next_scene_path(), "res://scenes/m2_run.tscn")
	assert_true(ResourceLoader.exists(intro.next_scene_path()))
	intro.free()


func test_race_scene_exists() -> void:
	var intro := M3Intro.new()
	assert_eq(intro.race_scene_path(), "res://scenes/local_race.tscn")
	assert_true(ResourceLoader.exists(intro.race_scene_path()))
	intro.free()


func test_m4_scene_exists() -> void:
	var intro := M3Intro.new()
	assert_eq(intro.m4_scene_path(), "res://scenes/m4_group_race.tscn")
	assert_true(ResourceLoader.exists(intro.m4_scene_path()))
	intro.free()
