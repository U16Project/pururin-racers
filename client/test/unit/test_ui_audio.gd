extends GutTest

const UIAudio := preload("res://scripts/ui_audio.gd")
const RaceSelect := preload("res://scripts/race_select.gd")
const Title := preload("res://scripts/title.gd")
const Runner := preload("res://scripts/runner_local_race.gd")


class AudioProbe extends "res://scripts/ui_audio.gd":
	var play_count := 0
	var played_keys: Array[String] = []

	func _play_focus_click() -> void:
		play_count += 1

	func _play_sound(key: String) -> void:
		played_keys.append(key)


func test_ui_sounds_exist_and_load_as_ogg_streams() -> void:
	for key: String in UIAudio.SOUND_PATHS:
		var path := str(UIAudio.SOUND_PATHS[key])
		assert_true(ResourceLoader.exists(path), key)
		var stream := load(path)
		assert_not_null(stream, key)
		assert_true(stream is AudioStreamOggVorbis, key)


func test_ui_sound_methods_use_the_approved_sound_keys() -> void:
	var audio := AudioProbe.new()
	add_child(audio)
	audio.play_selection_cycle()
	audio.play_arrow_click()
	audio.play_back()
	audio.play_confirmation()
	audio.play_clear_selection()
	audio.play_checkbox_toggle()
	audio.play_notch_up()
	audio.play_notch_down()
	audio.play_error()
	assert_eq(audio.played_keys, [
		"selection_cycle", "arrow_click", "back", "confirmation",
		"clear_selection", "checkbox_toggle", "notch_up", "notch_down", "error",
	])
	audio.free()


func test_change_sounds_require_the_right_input_and_an_actual_change() -> void:
	assert_eq(RaceSelect.cycle_sound_key("gamepad", true), "selection_cycle")
	assert_eq(RaceSelect.cycle_sound_key("mouse", true), "arrow_click")
	assert_eq(RaceSelect.cycle_sound_key("keyboard", true), "")
	assert_eq(RaceSelect.cycle_sound_key("gamepad", false), "")
	assert_eq(Title.screen_mode_sound_key(true, true), "selection_cycle")
	assert_eq(Title.screen_mode_sound_key(false, true), "")
	assert_eq(Title.screen_mode_sound_key(true, false), "")
	assert_eq(Runner.notch_sound_key(2.0, 3.0), "notch_up")
	assert_eq(Runner.notch_sound_key(3.0, 2.0), "notch_down")
	assert_eq(Runner.notch_sound_key(3.0, 3.0), "")


func test_focus_move_click_is_only_allowed_when_focus_owner_changes() -> void:
	var audio := UIAudio.new()
	var first := Control.new()
	var second := Control.new()
	add_child(first)
	add_child(second)
	assert_true(audio.should_play_focus_move(first, second))
	assert_false(audio.should_play_focus_move(first, first))
	assert_false(audio.should_play_focus_move(first, null))
	assert_false(audio.should_play_focus_move(null, second))
	audio.free()
	first.free()
	second.free()


func test_corrected_gamepad_navigation_plays_once_only_after_focus_moves() -> void:
	var audio := AudioProbe.new()
	add_child(audio)
	var holder := Control.new()
	add_child(holder)
	var first := Button.new()
	var second := Button.new()
	holder.add_child(first)
	holder.add_child(second)
	first.focus_mode = Control.FOCUS_ALL
	second.focus_mode = Control.FOCUS_ALL
	first.focus_neighbor_right = first.get_path_to(second)
	second.focus_neighbor_right = second.get_path_to(second)
	first.grab_focus()
	await get_tree().process_frame

	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	pad.device = 15
	pad.set_meta("pad_corrected", true)
	get_viewport().push_input(pad)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_focus_owner(), second)
	assert_eq(audio.play_count, 1)

	get_viewport().push_input(pad)
	await get_tree().process_frame
	assert_eq(audio.play_count, 1)
	audio.free()
	holder.free()
