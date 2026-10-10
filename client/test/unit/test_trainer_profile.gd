extends GutTest
## トレーナー（ユーザー）の登録：名前と画像の保存、出走するプルのトレーナー名。

const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const RosterConfig := preload("res://scripts/config/pururin_roster_config.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const SAVE := "user://test_trainer_profile.json"
const ICON := "user://test_trainer_icon.png"
const ProfileScene := preload("res://scenes/trainer_profile.tscn")
const TitleScene := preload("res://scenes/title.tscn")

class ProfileWithoutNavigation extends "res://scripts/trainer_profile_screen.gd":
	var transitions := 0
	func go_to_race_select() -> void:
		transitions += 1


func test_start_uses_registration_validation_and_only_transitions_once() -> void:
	var screen := ProfileWithoutNavigation.new()
	add_child_autofree(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var start := InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	var edit: LineEdit = screen.find_child("NameEdit", true, false)
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-trainer-registration-start.png"))
	edit.text = ""
	screen._unhandled_input(start)
	assert_eq(screen.transitions, 0)
	edit.text = "テスト"
	screen.set("_file_dialog_open", true)
	screen._unhandled_input(start)
	assert_eq(screen.transitions, 0)
	screen.set("_file_dialog_open", false)
	screen._unhandled_input(start)
	screen._unhandled_input(start)
	assert_eq(screen.transitions, 1)
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.trainer_name(), "テスト")
	assert_eq(screen.find_child("RegisterButton", true, false).get_node("ButtonMark").get("kind"), "START")


## 本物の登録内容に触らないように、テスト用の保存場所を使う。
func before_each() -> void:
	_remove_files()
	TrainerProfile.use_paths(SAVE, ICON)


func after_each() -> void:
	_remove_files()
	TrainerProfile.use_paths(TrainerProfile.DEFAULT_SAVE_PATH, TrainerProfile.DEFAULT_ICON_PATH)


func _remove_files() -> void:
	for path: String in [SAVE, ICON]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_before_registering_the_name_is_the_default_and_there_is_no_icon() -> void:
	assert_eq(TrainerProfile.trainer_name(), str(TrainerProfile.config()["default_name"]))
	assert_eq(TrainerProfile.icon()["kind"], "none")
	assert_null(TrainerProfile.icon_texture())


func test_a_registered_name_is_kept_after_reloading() -> void:
	assert_eq(TrainerProfile.set_trainer_name("  ゆうじろう  "), "")
	assert_eq(TrainerProfile.trainer_name(), "ゆうじろう", "前後の空白は、取る")
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.trainer_name(), "ゆうじろう")


func test_names_outside_the_length_rules_are_refused_and_nothing_changes() -> void:
	var rules := TrainerProfile.config()
	var before := TrainerProfile.trainer_name()
	assert_ne(TrainerProfile.set_trainer_name("あ".repeat(int(rules["name_min_length"]) - 1)), "")
	assert_ne(TrainerProfile.set_trainer_name("あ".repeat(int(rules["name_max_length"]) + 1)), "")
	assert_ne(TrainerProfile.set_trainer_name("あい\nう"), "")
	assert_eq(TrainerProfile.trainer_name(), before)
	assert_eq(TrainerProfile.set_trainer_name("あ".repeat(int(rules["name_max_length"]))), "")


func test_the_icon_can_be_a_pururin_or_a_picture_file_or_nothing() -> void:
	var id := str(TrainerProfile.avatars()[2]["id"])
	TrainerProfile.set_icon_avatar(id)
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.icon(), {"kind": "avatar", "id": id})
	# 画像ファイル：まん中を正方形に切り取って、決まりの大きさで保存する。
	var source := Image.create(300, 120, false, Image.FORMAT_RGBA8)
	source.fill(Color.RED)
	var source_path := "user://test_trainer_source.png"
	source.save_png(source_path)
	assert_eq(TrainerProfile.set_icon_file(source_path), "")
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.icon()["kind"], "file")
	var size_px := int(TrainerProfile.config()["icon_size_px"])
	var texture := TrainerProfile.icon_texture()
	assert_eq(texture.get_size(), Vector2(size_px, size_px))
	# 読めないファイルは、理由を返して、今の画像を変えない。
	assert_ne(TrainerProfile.set_icon_file("user://no_such_picture.png"), "")
	assert_eq(TrainerProfile.icon()["kind"], "file")
	TrainerProfile.clear_icon()
	assert_eq(TrainerProfile.icon()["kind"], "none")
	assert_null(TrainerProfile.icon_texture())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))


func test_a_broken_save_file_is_reported_and_the_default_is_used() -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string("{\"name\": \"\"}")
	file.close()
	TrainerProfile.last_error = ""
	TrainerProfile.reload_profile()
	assert_ne(TrainerProfile.last_error, "")
	assert_eq(TrainerProfile.trainer_name(), str(TrainerProfile.config()["default_name"]))
	assert_push_error_count(1)


func test_config_rules_are_checked() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TrainerProfile.CONFIG_PATH))
	assert_eq(TrainerProfile.validate_config(good).size(), 0)
	var no_default := good.duplicate()
	no_default["default_name"] = ""
	assert_gt(TrainerProfile.validate_config(no_default).size(), 0)
	var reversed := good.duplicate()
	reversed["name_min_length"] = int(good["name_max_length"]) + 1
	assert_gt(TrainerProfile.validate_config(reversed).size(), 0)


func test_the_user_pururin_carries_the_user_name_and_cpu_pururins_their_own_trainer() -> void:
	TrainerProfile.set_trainer_name("ゆうじろう")
	var seen := {}
	for pururin: Dictionary in RosterConfig.values()["roster"]:
		var id := str(pururin["id"])
		assert_eq(RaceSession.trainer_name_for(id, true), "ゆうじろう")
		var cpu_name := RaceSession.trainer_name_for(id, false)
		assert_eq(cpu_name, str(pururin["trainer_name"]))
		assert_false(seen.has(cpu_name), "CPUのトレーナー名は、重ならない")
		seen[cpu_name] = true


func _screen() -> Control:
	var screen: Control = ProfileScene.instantiate()
	add_child_autofree(screen)
	return screen


func test_the_screen_starts_from_what_is_registered() -> void:
	TrainerProfile.set_trainer_name("ゆうじろう")
	var id := str(TrainerProfile.avatars()[1]["id"])
	TrainerProfile.set_icon_avatar(id)
	var screen := _screen()
	assert_eq((screen.find_child("NameEdit", true, false) as LineEdit).text, "ゆうじろう")
	assert_eq(screen.call("pending_icon")["kind"], "avatar")
	assert_eq(screen.call("pending_icon")["id"], id)
	assert_true(bool((screen.find_child("Choice_avatar_%s" % id, true, false) as Button).get_meta("selected")))
	assert_false(bool((screen.find_child("Choice_none", true, false) as Button).get_meta("selected")))
	# 選択肢は、なし＋用意してある人の絵の全部。
	assert_not_null(screen.find_child("Choice_none", true, false))
	for avatar: Dictionary in TrainerProfile.avatars():
		assert_not_null(screen.find_child("Choice_avatar_%s" % avatar["id"], true, false))


func test_nothing_is_saved_until_register_and_a_bad_name_is_refused() -> void:
	TrainerProfile.set_trainer_name("ゆうじろう")
	var screen := _screen()
	var id := str(TrainerProfile.avatars()[3]["id"])
	screen.call("choose_icon", "avatar", id)
	(screen.find_child("NameEdit", true, false) as LineEdit).text = "あ"
	# 選んだだけでは、保存しない。
	assert_eq(TrainerProfile.icon()["kind"], "none")
	# 短すぎる名前では、登録できない。理由を出して、何も変えない。
	screen.call("register")
	assert_ne((screen.find_child("ProblemLabel", true, false) as Label).text, "")
	assert_eq(TrainerProfile.trainer_name(), "ゆうじろう")
	assert_eq(TrainerProfile.icon()["kind"], "none")


func test_register_saves_the_name_and_the_chosen_icon() -> void:
	var screen := _screen()
	var id := str(TrainerProfile.avatars()[3]["id"])
	screen.call("choose_icon", "avatar", id)
	(screen.find_child("NameEdit", true, false) as LineEdit).text = "あたらしい"
	# 場面の切り替えはさせずに、保存だけを確かめる。
	var problem := TrainerProfile.name_problem("あたらしい")
	assert_eq(problem, "")
	TrainerProfile.set_trainer_name((screen.find_child("NameEdit", true, false) as LineEdit).text)
	TrainerProfile.set_icon_avatar(str(screen.call("pending_icon")["id"]))
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.trainer_name(), "あたらしい")
	assert_eq(TrainerProfile.icon(), {"kind": "avatar", "id": id})


func test_a_picture_file_can_be_chosen_and_an_unreadable_one_is_refused() -> void:
	var screen := _screen()
	var source := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	source.fill(Color.BLUE)
	var source_path := "user://test_trainer_source.png"
	source.save_png(source_path)
	screen.call("choose_file", source_path)
	assert_eq(screen.call("pending_icon")["kind"], "file")
	assert_eq(screen.call("pending_icon")["path"], source_path)
	assert_eq(TrainerProfile.icon()["kind"], "none", "選んだだけでは、保存しない")
	screen.call("choose_file", "user://no_such_picture.png")
	assert_ne((screen.find_child("ProblemLabel", true, false) as Label).text, "")
	assert_eq(screen.call("pending_icon")["path"], source_path, "読めないファイルでは、選びかけを変えない")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))


func test_game_start_goes_to_the_trainer_screen_and_ok_goes_to_race_select() -> void:
	var title: Control = TitleScene.instantiate()
	add_child_autofree(title)
	assert_eq((title.find_child("FreeRaceButton", true, false) as Button).text, "ゲーム開始")
	assert_eq(title.call("next_scene_path"), "res://scenes/trainer_profile.tscn")
	var screen := _screen()
	assert_eq(screen.get("RACE_SELECT_SCENE_PATH"), "res://scenes/race_select.tscn")
	assert_true(ResourceLoader.exists(screen.get("RACE_SELECT_SCENE_PATH")))


func test_a_saved_avatar_that_no_longer_exists_is_reported() -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"name": "ゆうじろう", "icon": {"kind": "avatar", "id": "no-such-avatar"}}))
	file.close()
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.icon()["kind"], "none")
	assert_push_error_count(1)


func test_the_gamepad_accept_button_chooses_the_focused_picture() -> void:
	var screen := _screen()
	var avatars := TrainerProfile.avatars()
	# ゲームパッドのAは、選んでいるボタンを「押す」。画像のボタンでも、押した画像に切り替わる。
	for index in [2, 5, 2]:
		var id := str(avatars[index]["id"])
		var button := screen.find_child("Choice_avatar_%s" % id, true, false) as Button
		assert_true(RaceControllerInput.activate_control(button))
		assert_eq(screen.call("pending_icon"), {"kind": "avatar", "id": id, "path": ""})
		assert_true(bool(button.get_meta("selected")))
		# 緑になるのは、選んでいる1つだけ。
		var selected_count := 0
		for other in screen.find_children("Choice_*", "Button", true, false):
			selected_count += 1 if bool(other.get_meta("selected")) else 0
		assert_eq(selected_count, 1)
	assert_true(RaceControllerInput.activate_control(screen.find_child("Choice_none", true, false)))
	assert_eq(screen.call("pending_icon")["kind"], "none")


func test_the_introduction_is_saved_and_a_too_long_one_is_refused() -> void:
	var limit := int(TrainerProfile.config()["introduction_max_length"])
	assert_eq(TrainerProfile.introduction(), str(TrainerProfile.config()["default_introduction"]))
	# 改行は空白に直し、前後の空白は取る。空でもよい。
	assert_eq(TrainerProfile.set_introduction("  ぷるりんが\n大好き。  "), "")
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.introduction(), "ぷるりんが 大好き。")
	assert_ne(TrainerProfile.set_introduction("あ".repeat(limit + 1)), "")
	assert_eq(TrainerProfile.introduction(), "ぷるりんが 大好き。", "長すぎるものは、登録しない")
	assert_eq(TrainerProfile.set_introduction("あ".repeat(limit)), "")
	assert_eq(TrainerProfile.set_introduction(""), "")
	assert_eq(TrainerProfile.introduction(), "")


func test_a_profile_saved_before_the_introduction_existed_still_loads() -> void:
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify({"name": "ゆうじろう", "icon": {"kind": "none", "id": ""}}))
	file.close()
	TrainerProfile.reload_profile()
	assert_eq(TrainerProfile.trainer_name(), "ゆうじろう")
	assert_eq(TrainerProfile.introduction(), str(TrainerProfile.config()["default_introduction"]))


func test_the_screen_edits_the_introduction_and_refuses_a_too_long_one() -> void:
	TrainerProfile.set_introduction("はじめまして。")
	var screen := _screen()
	var edit := screen.find_child("IntroductionEdit", true, false) as TextEdit
	var count := screen.find_child("IntroductionCount", true, false) as Label
	var limit := int(TrainerProfile.config()["introduction_max_length"])
	assert_eq(edit.text, "はじめまして。")
	assert_eq(count.text, "%d／%d" % ["はじめまして。".length(), limit])
	# 長すぎる紹介文では、登録できない。理由を出して、何も変えない。
	edit.text = "あ".repeat(limit + 5)
	screen.call("_refresh_introduction_count")
	assert_eq(count.text, "%d／%d" % [limit + 5, limit])
	screen.call("register")
	assert_ne((screen.find_child("ProblemLabel", true, false) as Label).text, "")
	assert_eq(TrainerProfile.introduction(), "はじめまして。")
