extends GutTest
const Session := preload("res://scripts/race_session.gd")
const Trainers := preload("res://scripts/config/cpu_trainers_config.gd")
const Looks := preload("res://scripts/config/pururin_look_config.gd")
const Controller := preload("res://scenes/local_race.tscn")
const Slot := preload("res://scripts/menu/pururin_slot.gd")

func before_each() -> void:
	Session.clear_slots()
	Session.set_slot(0, "player-1")
	Session.set_slot(1, "cpu-1")

func after_each() -> void:
	Session.clear_slots()

func test_trainer_choices_and_new_pururins() -> void:
	assert_eq(Trainers.values().size(), 13)
	assert_eq(Session.roster_ids().size(), 10)
	assert_false(Looks.look_for("cpu-8").is_empty())
	assert_false(Looks.look_for("cpu-9").is_empty())
	var invalid := {"schema_version": 1, "trainers": [{"id": "invalid", "name": "試験", "profile_id": "missing"}]}
	assert_false(Trainers.validate(invalid).is_empty())
	for trainer: Dictionary in Trainers.values():
		assert_true(ResourceLoader.exists(str(trainer["portrait_path"])))
		assert_false(str(trainer["introduction"]).is_empty())
		assert_true(trainer["favorite_running_style"] in ["escape", "pace", "stalk", "closer"])


func test_empty_cpu_slot_accepts_trainer_and_keeps_it_when_character_changes() -> void:
	Session.set_slot(1, "")
	assert_true(Session.set_slot_trainer(1, "kaede"))
	assert_eq(Session.field_entries().size(), 1)
	Session.set_slot(1, "cpu-8")
	assert_eq(Session.slot_trainer_id(1), "kaede")
	Session.set_slot(1, "")
	assert_eq(Session.slot_trainer_id(1), "kaede")
	Session.randomize_unlocked(true)
	assert_eq(Session.slot_trainer_id(1), "kaede")
	Session.clear_slots()
	Session.set_slot(0, "player-1")
	Session.set_slot_trainer(1, "kaede")
	Session.randomize_trainers_unlocked(true)
	assert_eq(Session.slot_trainer_id(1), "kaede")
	for slot in range(2, Session.SLOT_COUNT):
		assert_false(Session.slot_trainer_id(slot).is_empty())
	assert_eq(Session.field_entries().size(), 1)
	var screen: Control = load("res://scenes/race_select.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var row: Control = screen.find_child("Slot1", true, false)
	assert_eq(row.call("trainer_text"), "カエデ")
	row.get("_trainer_button").pressed.emit()
	assert_true(screen.get("_trainer_picker").visible)
	screen.get("_trainer_picker").hide()
	screen.call("_on_slot_force_requested", 1)
	assert_true(screen.get("_trainer_picker").visible)


func test_clear_all_removes_unlocked_characters_and_trainers_only() -> void:
	var profile := preload("res://scripts/config/trainer_profile.gd")
	var saved_name: String = profile.trainer_name()
	var saved_icon: Dictionary = profile.icon().duplicate(true)
	Session.set_slot_trainer(1, "kaede")
	Session.toggle_lock(1)
	Session.set_slot_trainer(2, "ren")
	Session.clear_unlocked()
	assert_eq(Session.slot_pururin_id(1), "cpu-1")
	assert_eq(Session.slot_trainer_id(1), "kaede")
	assert_true(Session.is_locked(1))
	assert_eq(Session.slot_pururin_id(0), "")
	assert_eq(Session.slot_trainer_id(2), "")
	assert_eq(profile.trainer_name(), saved_name)
	assert_eq(profile.icon(), saved_icon)
	Session.toggle_lock(1)
	Session.clear_unlocked()
	assert_eq(Session.slot_trainer_id(1), "")
	Session.set_slot(1, "cpu-1")
	assert_eq(Session.slot_trainer_id(1), "homura")
	var screen: Control = load("res://scenes/race_select.tscn").instantiate()
	add_child_autofree(screen)
	assert_eq((screen.get("_clear_button") as Button).text, "選択全解除")


func test_random_actions_preserve_locks_and_fill_only_selections() -> void:
	Session.set_slot_trainer(1, "kaede")
	Session.toggle_lock(1)
	for attempt in 20:
		Session.shuffle_gate_order()
		assert_eq(Session.slot_pururin_id(1), "cpu-1")
		assert_eq(Session.slot_trainer_id(1), "kaede")
		assert_true(Session.is_locked(1))
	Session.clear_slots()
	Session.set_slot(0, "player-1")
	Session.set_slot(1, "cpu-1")
	Session.set_slot_trainer(1, "kaede")
	Session.randomize_unlocked(true)
	assert_eq(Session.slot_pururin_id(0), "player-1")
	assert_eq(Session.slot_pururin_id(1), "cpu-1")
	var selected: Array[String] = []
	for slot in Session.SLOT_COUNT:
		assert_false(selected.has(Session.slot_pururin_id(slot)))
		selected.append(Session.slot_pururin_id(slot))
	var before := Session.slots_snapshot()
	Session.randomize_trainers_unlocked(true)
	assert_eq(Session.slots_snapshot(), before)
	Session.randomize_trainers_unlocked(false)
	assert_eq(Session.slots_snapshot()["trainers"][0], before["trainers"][0])
	for slot in range(1, Session.SLOT_COUNT):
		assert_false(Trainers.by_id(Session.slot_trainer_id(slot)).is_empty())

func test_selection_survives_character_change_and_snapshot_and_moves() -> void:
	assert_eq(Session.slot_trainer_id(1), "homura")
	assert_true(Session.set_slot_trainer(1, "kaede"))
	Session.set_slot(1, "cpu-8")
	assert_eq(Session.slot_trainer_id(1), "kaede")
	var saved := Session.slots_snapshot()
	Session.move_slot(1, 1)
	assert_eq(Session.slot_trainer_id(2), "kaede")
	Session.restore_slots(saved)
	assert_eq(Session.slot_trainer_id(1), "kaede")
	assert_eq(Session.field_entries()[1]["trainer_profile_id"], "draft")
	assert_false(Session.set_slot_trainer(0, "kaede"))
	Session.toggle_lock(1)
	assert_false(Session.set_slot_trainer(1, "ren"))

func test_selected_profile_is_received_by_real_cpu_runner() -> void:
	Session.set_slot_trainer(1, "kaede")
	var controller := Controller.instantiate()
	add_child_autofree(controller)
	var runners: Array = controller.get_runners_for_simulation()
	assert_eq(runners.size(), 2)
	assert_eq(runners[1].get("_cpu_trainer_profile")["id"], "draft")

func test_picker_selection_and_return_focus() -> void:
	var screen: Node = load("res://scenes/race_select.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	for button_name in ["RaceButton", "BackButton"]:
		var bottom_button: Control = screen.find_child(button_name, true, false)
		assert_lte(bottom_button.get_global_rect().end.y, screen.get_viewport_rect().size.y - 16.0, "下端に余白を確保：" + button_name)
	var controls: VBoxContainer = screen.find_child("SelectionControls", true, false)
	assert_eq(controls.get_theme_constant("separation"), 6)
	assert_eq(controls.get_parent().get_theme_constant("margin_top"), 6)
	Session.clear_slots()
	screen.call("_refresh_slots")
	screen.call("_refresh_detail")
	await get_tree().process_frame
	await get_tree().process_frame
	for button_name in ["RaceButton", "BackButton"]:
		var empty_button: Control = screen.find_child(button_name, true, false)
		assert_lte(empty_button.get_global_rect().end.y, screen.get_viewport_rect().size.y - 16.0, "空状態の下端余白：" + button_name)
	var panel: Control = screen.find_child("Panel", true, false)
	assert_true(Rect2(Vector2.ZERO, screen.get_viewport_rect().size).encloses(panel.get_global_rect()))
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-selection-empty-spaced.png"))
	Session.set_slot(0, "player-1")
	Session.set_slot(1, "cpu-1")
	screen.call("_refresh_slots")
	screen.call("_refresh_detail")
	await get_tree().process_frame
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-selection-spaced-controls.png"))
	screen.call("_on_trainer_requested", 1)
	var picker := screen.get_node("TrainerPicker")
	assert_true(picker.visible)
	assert_not_null(screen.find_child("ButtonNote1", true, false))
	assert_true(Session.is_default_trainer(1, "homura"))
	assert_false(Session.is_default_trainer(1, "yuu"))
	var row: Control = screen.find_child("Slot1", true, false)
	assert_eq(row.call("trainer_color"), Slot.COLOR_DEFAULT_TRAINER)
	for trainer: Dictionary in Trainers.values():
		picker.open(1, str(trainer["id"]))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_eq(picker.shown_trainer_id(), trainer["id"])
		assert_not_null(picker.find_child("TrainerPortrait", true, false).texture)
		var focused := get_viewport().gui_get_focus_owner()
		var scroll: ScrollContainer = picker.find_child("TrainerScroll", true, false)
		assert_true(scroll.get_global_rect().encloses(focused.get_parent().get_global_rect()), "選択枠の余白ごと表示される：%s" % trainer["id"])
	picker.open(1, "homura")
	await get_tree().process_frame
	await get_tree().process_frame
	var buttons: Array = picker.get("_buttons")
	for button: Button in buttons:
		var expected: Color = picker.DEFAULT_COLOR if button.name == "homura" else preload("res://scripts/menu/menu_style.gd").COLOR_TEXT
		assert_eq(button.get_theme_color("font_color"), expected)
		assert_eq(button.get_parent().get_theme_constant("margin_top"), 5)
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-trainer-profile-list.png"))
	picker.emit_signal("picked", "ibuki")
	assert_false(picker.visible)
	assert_eq(Session.slot_trainer_id(1), "ibuki")
	assert_ne(row.call("trainer_color"), Slot.COLOR_DEFAULT_TRAINER)

func test_pururin_picker_tiles_fit_inside_its_visible_scroll_area() -> void:
	var screen: Node = load("res://scenes/race_select.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.call("_on_slot_pick_requested", 1)
	var picker: Control = screen.get("_picker")
	var scroll: ScrollContainer = picker.find_child("Scroll", true, false)
	for tile: Button in picker.call("tiles"):
		tile.grab_focus()
		await get_tree().process_frame
		await get_tree().process_frame
		assert_true(scroll.get_global_rect().encloses(tile.get_parent().get_global_rect()), "黄色い枠を含めて一覧内に収まる：" + str(tile.call("pururin_id")))
	if OS.has_environment("PURURIN_CAPTURE_DIR"):
		await RenderingServer.frame_post_draw
		screen.get_viewport().get_texture().get_image().save_png(OS.get_environment("PURURIN_CAPTURE_DIR").path_join("pururin-picker-three-columns.png"))
