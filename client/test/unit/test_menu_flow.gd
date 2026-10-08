extends GutTest
## 起動からレースまでの画面の流れ：ロゴ → タイトル → レース選択 → レース。

const Logo := preload("res://scripts/logo.gd")
const LogoScene := preload("res://scenes/logo.tscn")
const TitleScene := preload("res://scenes/title.tscn")
const RaceSelect := preload("res://scripts/race_select.gd")
const RaceSelectScene := preload("res://scenes/race_select.tscn")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)
	RaceSession.select_player_pururin(RaceSession.default_player_pururin_id())
	RaceSession.select_all_opponents()


func test_game_starts_with_the_logo_and_the_logo_leads_to_the_title() -> void:
	assert_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/logo.tscn")
	var logo := LogoScene.instantiate()
	add_child(logo)
	assert_true(ResourceLoader.exists(Logo.LOGO_IMAGE_PATH))
	assert_true(ResourceLoader.exists(logo.next_scene_path()))
	assert_eq(logo.next_scene_path(), "res://scenes/title.tscn")
	logo.free()


func test_logo_is_skipped_by_pressing_any_key_or_button_but_not_by_releasing() -> void:
	var key := InputEventKey.new()
	key.pressed = true
	assert_true(Logo.is_skip_event(key))
	key.pressed = false
	assert_false(Logo.is_skip_event(key))
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	assert_true(Logo.is_skip_event(pad))
	assert_false(Logo.is_skip_event(InputEventJoypadMotion.new()))


func test_title_shows_a_background_image_and_only_the_free_race_button() -> void:
	var title := TitleScene.instantiate()
	add_child(title)
	assert_not_null((title.get_node("Background") as TextureRect).texture)
	assert_eq(title.find_children("*", "BaseButton", true, false).size(), 1)
	assert_not_null(title.get_node_or_null("FreeRaceButton"))
	assert_eq(title.next_scene_path(), "res://scenes/race_select.tscn")
	assert_true(ResourceLoader.exists(title.next_scene_path()))
	title.free()


func test_race_select_offers_every_supported_distance_and_remembers_the_choice() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var buttons: Array = screen.get("_distance_buttons")
	var distances := RaceSession.supported_distances_m()
	assert_eq(buttons.size(), distances.size())
	for index in buttons.size():
		assert_eq(buttons[index].button_pressed, is_equal_approx(float(distances[index]), RaceSession.selected_distance_m()))
	(buttons[0] as Button).pressed.emit()
	assert_eq(RaceSession.selected_distance_m(), float(distances[0]))
	screen.free()


func test_race_select_lists_the_whole_roster_and_remembers_the_chosen_pururin() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var option: OptionButton = screen.get_node("Panel/Content/PururinOption")
	var roster: Array = PururinRosterConfig.values()["roster"]
	assert_eq(option.item_count, roster.size())
	var last := roster.size() - 1
	option.item_selected.emit(last)
	assert_eq(RaceSession.selected_player_pururin_id(), str(roster[last]["id"]))
	assert_true(ResourceLoader.exists(RaceSelect.RACE_SCENE_PATH))
	assert_true(ResourceLoader.exists(RaceSelect.TITLE_SCENE_PATH))
	screen.free()


func test_selected_pururin_preview_uses_attribute_adjusted_pre_race_stats() -> void:
	RaceSession.select_player_pururin("cpu-1")
	var preview := RaceSelect.selected_pururin_preview()
	assert_eq(preview["id"], "cpu-1")
	assert_eq(preview["display_name"], "アカネ")
	assert_eq(preview["attribute"], "火")
	assert_eq(preview["running_style"], "逃げ")
	assert_eq(preview["pre_race_stats"]["acceleration"], 9)
	assert_eq(preview["pre_race_stats"]["cardio"], 8)
	assert_eq(preview["pre_race_stats"]["top_speed"], 5)


func test_race_select_lists_the_opponents_and_keeps_at_least_one() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var boxes: Dictionary = screen.get("_opponent_boxes")
	var candidates := RaceSession.opponent_candidate_ids()
	assert_eq(boxes.size(), candidates.size())
	for identifier in candidates:
		assert_true((boxes[identifier] as Button).button_pressed)
	# 1体だけ残して外す。最後の1体は、外そうとしても選ばれたまま。
	for index in range(1, candidates.size()):
		(boxes[candidates[index]] as Button).button_pressed = false
	assert_eq(RaceSession.selected_opponent_ids(), [candidates[0]] as Array[String])
	(boxes[candidates[0]] as Button).button_pressed = false
	assert_true((boxes[candidates[0]] as Button).button_pressed)
	assert_eq(RaceSession.selected_opponent_ids(), [candidates[0]] as Array[String])
	screen.free()


func test_race_select_swaps_the_opponent_candidates_when_the_player_changes() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var first_player := RaceSession.selected_player_pururin_id()
	var option: OptionButton = screen.get_node("Panel/Content/PururinOption")
	var roster: Array = PururinRosterConfig.values()["roster"]
	var last := roster.size() - 1
	option.item_selected.emit(last)
	var boxes: Dictionary = screen.get("_opponent_boxes")
	assert_true(boxes.has(first_player))
	assert_false(boxes.has(str(roster[last]["id"])))
	assert_eq(boxes.size(), roster.size() - 1)
	screen.free()
