extends GutTest
const Session := preload("res://scripts/race_session.gd")
const EntriesScene := preload("res://scenes/race_entries.tscn")
const Select := preload("res://scripts/race_select.gd")
class WithoutNavigation extends "res://scripts/race_entries.gd":
	var paths: Array[String] = []
	func _navigate(path: String) -> void:
		paths.append(path)

func before_each() -> void:
	Session.clear_slots()
	Session.set_slot(0, "player-1")
	Session.set_slot(4, "cpu-1")
	Session.set_slot_trainer(4, "kaede")

func after_each() -> void:
	Session.clear_slots()

func test_entries_preserve_gate_and_show_selected_trainer_and_player() -> void:
	var before := Session.slots_snapshot()
	var screen: Control = EntriesScene.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen.get("_rows").size(), 2)
	assert_eq(screen.get("_entries")[1]["gate"], 4)
	assert_eq(screen.get("_favorite").text, "プレイヤー操作")
	screen.get("_rows")[1].grab_focus()
	assert_eq(screen.get("shown_gate"), 4)
	assert_eq(screen.get("_trainer_name").text, "カエデ")
	assert_eq(screen.get("_detail").call("shown_pururin_id"), "cpu-1")
	assert_eq(Session.slots_snapshot(), before)
	assert_eq(Select.RACE_SCENE_PATH, "res://scenes/race_entries.tscn")

func test_start_and_back_are_guarded_and_never_change_selection() -> void:
	var screen := WithoutNavigation.new()
	add_child_autofree(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var before := Session.slots_snapshot()
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_START
	event.pressed = true
	screen._unhandled_input(event)
	screen._unhandled_input(event)
	assert_eq(screen.paths, ["res://scenes/local_race.tscn"])
	assert_eq(Session.slots_snapshot(), before)
	var returning := WithoutNavigation.new()
	add_child_autofree(returning)
	returning.back()
	returning.back()
	assert_eq(returning.paths, ["res://scenes/race_select.tscn"])
	Session.clear_slots()
	var invalid := WithoutNavigation.new()
	add_child_autofree(invalid)
	invalid.start()
	assert_true(invalid.paths.is_empty())

func test_full_field_fits_viewport_with_readable_details() -> void:
	Session.select_full_field("player-1")
	var screen: Control = EntriesScene.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var panel: Control = screen.find_child("Panel", true, false)
	assert_true(screen.get_viewport_rect().encloses(panel.get_global_rect()))
	for row: Button in screen.get("_rows"):
		row.grab_focus()
		assert_true(panel.get_global_rect().encloses(row.get_global_rect()))
	assert_eq(screen.get("_rows").size(), 8)
	assert_lte((screen.get("_start") as Control).get_global_rect().end.y, screen.get_viewport_rect().size.y - 16)
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-race-entries-full.png"))
