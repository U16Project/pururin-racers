extends GutTest

const M3Intro := preload("res://scripts/m3_intro.gd")
const RaceSession := preload("res://scripts/race_session.gd")


func before_each() -> void:
	RaceSession.select_player_pururin(RaceSession.default_player_pururin_id())


func test_intro_items_match_m3_guide() -> void:
	var intro := M3Intro.new()
	assert_eq(
		intro.get_intro_items(),
		PackedStringArray([
			"←→／左スティック：走る位置　↑↓／十字キー：ローカルは出力、オンラインは目標スピード",
			"Y/C：カメラ切替　Start/Esc：メニュー（レース中）",
			"A：決定　B：キャンセル　X：ブースト（実装予定）",
			"レース開始＝ローカル　オンラインレース＝M5　控室＝接続",
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


func test_selected_pururin_preview_uses_attribute_adjusted_pre_race_stats() -> void:
	RaceSession.select_player_pururin("cpu-1")
	var intro := M3Intro.new()
	var preview := intro.selected_pururin_preview()
	assert_eq(preview["id"], "cpu-1")
	assert_eq(preview["display_name"], "アカネ")
	assert_eq(preview["attribute"], "火")
	assert_eq(preview["running_style"], "逃げ")
	assert_eq(preview["pre_race_stats"]["acceleration"], 9)
	assert_eq(preview["pre_race_stats"]["cardio"], 8)
	assert_eq(preview["pre_race_stats"]["top_speed"], 5)
	intro.free()
