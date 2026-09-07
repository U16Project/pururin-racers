extends GutTest

const M3Intro := preload("res://scripts/m3_intro.gd")


func test_intro_items_match_m3_guide() -> void:
	var intro := M3Intro.new()
	assert_eq(
		intro.get_intro_items(),
		PackedStringArray([
			"←→：ぷるりんの走る位置を調整",
			"C：カメラを切り替え",
			"控室：サーバーに接続して入室",
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
