extends GutTest
## 起動からレースまでの画面の流れ：ロゴ → タイトル → レース選択 → レース。

const Logo := preload("res://scripts/logo.gd")
const LogoScene := preload("res://scenes/logo.tscn")
const TitleScene := preload("res://scenes/title.tscn")
const RaceSelect := preload("res://scripts/race_select.gd")
const RaceSelectScene := preload("res://scenes/race_select.tscn")
const RaceSession := preload("res://scripts/race_session.gd")
const PururinSlot := preload("res://scripts/menu/pururin_slot.gd")
const PururinDetail := preload("res://scripts/menu/pururin_detail.gd")
const PururinStatsConfig := preload("res://scripts/config/pururin_stats_config.gd")
const PururinRosterConfig := preload("res://scripts/config/pururin_roster_config.gd")


func before_each() -> void:
	RaceSession.select_distance(RaceSession.DEFAULT_DISTANCE_M)
	RaceSession.clear_slots()
	RaceSession.take_returning_from_race()


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


func _pad_button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func test_race_select_offers_every_supported_distance_and_remembers_the_choice() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var buttons: Array = screen.get("_distance_buttons")
	var distances := RaceSession.supported_distances_m()
	assert_eq(buttons.size(), distances.size())
	for index in buttons.size():
		assert_eq(buttons[index].button_pressed, is_equal_approx(float(distances[index]), RaceSession.selected_distance_m()))
	(buttons[0] as Button).button_pressed = true
	assert_eq(RaceSession.selected_distance_m(), float(distances[0]))
	screen.free()


func test_title_button_can_be_pressed_with_gamepad_a() -> void:
	var title := TitleScene.instantiate()
	add_child(title)
	var button: Button = title.get_node("FreeRaceButton")
	assert_eq(get_viewport().gui_get_focus_owner(), button)
	# 場面の切り替えは起こさず、ボタンが押されたことだけ確かめる。
	button.pressed.disconnect(title.go_to_race_select)
	watch_signals(button)
	title._unhandled_input(_pad_button(JOY_BUTTON_A))
	assert_signal_emitted(button, "pressed")
	title.free()


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_race_select_starts_with_every_slot_empty_and_the_race_button_disabled() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	assert_eq(slots.size(), RaceSession.SLOT_COUNT)
	for slot: Control in slots:
		assert_eq(slot.call("shown_text"), PururinSlot.EMPTY_TEXT)
	assert_true((screen.get_node("Panel/Content").find_child("RaceButton", true, false) as Button).disabled)
	assert_eq((screen.get("_hint_label") as Label).text, RaceSelect.START_PROBLEM_TEXT["no_player"])
	var focused := get_viewport().gui_get_focus_owner() as Button
	assert_true((screen.get("_distance_buttons") as Array).has(focused), "タイトルから来たときは、距離の段から")
	assert_true(focused.button_pressed, "今選ばれている距離のボタン")
	screen.free()


func test_left_and_right_on_a_slot_change_its_pururin_and_the_detail_follows() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var ids := RaceSession.roster_ids()
	var slots: Array = screen.get("_slots")
	var detail: Control = screen.get("_detail")
	var user_slot: Control = slots[RaceSession.user_slot()]
	user_slot.grab_focus()
	user_slot._gui_input(_action("ui_right"))
	assert_eq(RaceSession.selected_player_pururin_id(), ids[0])
	assert_eq(detail.call("shown_pururin_id"), ids[0])
	assert_true(str(user_slot.call("shown_text")).begins_with(str(PururinRosterConfig.pururin_by_id(ids[0])["display_name"])))
	assert_eq((screen.get("_hint_label") as Label).text, RaceSelect.START_PROBLEM_TEXT["no_opponent"])
	var first_opponent: Control = slots[1]
	first_opponent.grab_focus()
	assert_eq(detail.call("shown_pururin_id"), "", "空のスロットへ移ると、詳細は未選択")
	first_opponent._gui_input(_action("ui_left"))
	assert_eq(RaceSession.slot_pururin_id(1), ids[ids.size() - 1], "未選択の前は、一覧の最後")
	assert_false((screen.get("_race_button") as Button).disabled)
	assert_eq((screen.get("_hint_label") as Label).text, "")
	first_opponent._gui_input(_action("ui_right"))
	assert_eq(RaceSession.slot_pururin_id(1), RaceSession.EMPTY)
	assert_true((screen.get("_race_button") as Button).disabled)
	screen.free()


func test_a_pururin_used_elsewhere_is_only_shown_as_taken_and_leaving_resets_the_slot() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(RaceSession.user_slot(), ids[0])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	var detail: Control = screen.get("_detail")
	var opponent: Control = slots[1]
	opponent.grab_focus()
	# 未選択の次は一覧の1番目。ユーザーが使っているので、「選択済み」として見せるだけ。
	opponent._gui_input(_action("ui_right"))
	assert_true(opponent.call("is_taken"))
	assert_eq(opponent.call("pururin_id"), ids[0])
	assert_eq(RaceSession.slot_pururin_id(1), RaceSession.EMPTY, "中身は空のまま")
	assert_eq(RaceSession.selected_player_pururin_id(), ids[0], "先に使っているスロットは、そのまま")
	assert_true(detail.call("is_showing_taken"))
	assert_eq(detail.call("shown_pururin_id"), ids[0])
	# そのまま別のスロットへ移ると、未選択に戻る。
	slots[2].grab_focus()
	assert_false(opponent.call("is_taken"))
	assert_eq(opponent.call("shown_text"), PururinSlot.EMPTY_TEXT)
	assert_false(detail.call("is_showing_taken"))
	# もう1つ右へ進めば、空いている2番目の個体で決まる。
	opponent.grab_focus()
	opponent._gui_input(_action("ui_right"))
	opponent._gui_input(_action("ui_right"))
	assert_false(opponent.call("is_taken"))
	assert_eq(RaceSession.slot_pururin_id(1), ids[1])
	screen.free()


func test_y_takes_the_shown_pururin_from_the_slot_that_held_it() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(RaceSession.user_slot(), ids[0])
	RaceSession.set_slot(3, ids[1])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	var opponent: Control = slots[1]
	opponent.grab_focus()
	opponent._gui_input(_action("ui_right"))
	opponent._gui_input(_action("ui_right"))
	assert_true(opponent.call("is_taken"), "4枠が使っている2番目の個体")
	opponent._gui_input(_pad_button(JOY_BUTTON_Y))
	assert_eq(RaceSession.slot_pururin_id(1), ids[1])
	assert_eq(RaceSession.slot_pururin_id(3), RaceSession.EMPTY)
	assert_false(opponent.call("is_taken"))
	assert_eq(slots[3].call("shown_text"), PururinSlot.EMPTY_TEXT)
	# 右側の「強制選択」ボタンでも奪える（ユーザーから奪うと、レースは始められなくなる）。
	opponent._gui_input(_action("ui_left"))
	assert_true(opponent.call("is_taken"), "ユーザーが使っている1番目の個体")
	(screen.get("_detail").find_child("ForceButton", true, false) as Button).pressed.emit()
	assert_eq(RaceSession.slot_pururin_id(1), ids[0])
	assert_eq(RaceSession.selected_player_pururin_id(), RaceSession.EMPTY)
	assert_true((screen.get("_race_button") as Button).disabled)
	screen.free()


func test_race_select_keeps_the_previous_choices_when_reopened() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(RaceSession.user_slot(), ids[1])
	RaceSession.set_slot(4, ids[6])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	assert_eq(slots[RaceSession.user_slot()].call("pururin_id"), ids[1])
	assert_eq(slots[4].call("pururin_id"), ids[6])
	assert_true((screen.get("_distance_buttons") as Array).has(get_viewport().gui_get_focus_owner()), "タイトルから来たときは、選び終わっていても、距離の段から")
	screen.free()
	# レースから戻ったときは、レース開始ボタンから。印は1回で消える。
	RaceSession.mark_returning_from_race()
	var returned := RaceSelectScene.instantiate()
	add_child(returned)
	assert_eq(get_viewport().gui_get_focus_owner(), returned.get("_race_button"))
	assert_false(RaceSession.take_returning_from_race())
	returned.free()


func test_moving_onto_a_distance_button_selects_it_and_up_from_the_user_slot_returns_to_it() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var distances := RaceSession.supported_distances_m()
	var distance_buttons: Array = screen.get("_distance_buttons")
	var last: Button = distance_buttons[distances.size() - 1]
	last.grab_focus()
	assert_eq(RaceSession.selected_distance_m(), float(distances[distances.size() - 1]))
	var user_slot: Control = (screen.get("_slots") as Array)[RaceSession.user_slot()]
	assert_eq(user_slot.get_node(user_slot.focus_neighbor_top), last)
	for button: Button in distance_buttons:
		assert_eq(button.get_node(button.focus_neighbor_bottom), user_slot)
	screen.free()


func test_detail_preview_uses_attribute_adjusted_pre_race_stats() -> void:
	var preview := PururinDetail.preview_for("cpu-1")
	assert_eq(preview["id"], "cpu-1")
	assert_eq(preview["display_name"], "アカネ")
	assert_eq(preview["attribute"], "火")
	assert_eq(preview["running_style"], "逃げ")
	assert_eq(preview["pre_race_stats"]["acceleration"], 9)
	assert_eq(preview["pre_race_stats"]["cardio"], 8)
	assert_eq(preview["pre_race_stats"]["top_speed"], 5)
	assert_eq(PururinDetail.preview_for("unknown"), {})


func test_stat_bars_have_one_step_per_point_up_to_the_pre_race_maximum() -> void:
	var config := PururinStatsConfig.values()
	var maximum := int(config["attribute_stat_max"])
	assert_eq(PururinDetail.bar_segment_count(), maximum)
	assert_eq(PururinDetail.bar_filled_segments(maximum), maximum)
	assert_eq(PururinDetail.bar_filled_segments(5), 5)
	assert_eq(PururinDetail.bar_filled_segments(0), 0)
	for stat_id: String in config["stat_ids"]:
		assert_true(PururinDetail.STAT_LABELS.has(stat_id), stat_id)


func test_detail_preview_carries_the_attribute_and_style_for_their_marks() -> void:
	var config := PururinStatsConfig.values()
	for identifier in RaceSession.roster_ids():
		var preview := PururinDetail.preview_for(identifier)
		assert_true(config["attributes"].has(preview["attribute_id"]))
		assert_true(config["running_styles"].has(preview["style_id"]))
		assert_true(preview["attribute_color"] is Color)


func test_l1_and_r1_move_the_distance_one_step_and_stop_at_the_ends() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var distances := RaceSession.supported_distances_m()
	var start := distances.find(RaceSession.selected_distance_m())
	screen._unhandled_input(_pad_button(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[start + 1]))
	screen._unhandled_input(_pad_button(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[start]))
	for _step in distances.size() + 2:
		screen._unhandled_input(_pad_button(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[0]), "左の端で止まる")
	for _step in distances.size() + 2:
		screen._unhandled_input(_pad_button(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[distances.size() - 1]), "右の端で止まる")
	# 画面のボタンでも同じ。マークは L1 と R1。
	var previous: Button = screen.find_child("DistancePrev", true, false)
	var next: Button = screen.find_child("DistanceNext", true, false)
	assert_eq(previous.get_node("ButtonMark").get("kind"), "L1")
	assert_eq(next.get_node("ButtonMark").get("kind"), "R1")
	previous.pressed.emit()
	assert_eq(RaceSession.selected_distance_m(), float(distances[distances.size() - 2]))
	screen.free()


func _trigger(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func test_x_clears_the_focused_slot_and_the_three_buttons_work_on_unlocked_slots() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.select_full_field(ids[0])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	slots[2].grab_focus()
	slots[2]._gui_input(_pad_button(JOY_BUTTON_X))
	assert_eq(RaceSession.slot_pururin_id(2), RaceSession.EMPTY)
	assert_eq(slots[2].call("shown_text"), PururinSlot.EMPTY_TEXT)
	# 4枠を施錠してから、キャラ選択全解除：施錠中だけ残る（ユーザーも解除される）。
	slots[3].grab_focus()
	slots[3]._gui_input(_pad_button(JOY_BUTTON_BACK))
	assert_true(RaceSession.is_locked(3))
	assert_true(slots[3].call("is_locked"))
	var kept := RaceSession.slot_pururin_id(3)
	(screen.get("_clear_button") as Button).pressed.emit()
	for slot in RaceSession.SLOT_COUNT:
		assert_eq(slots[slot].call("pururin_id"), kept if slot == 3 else "")
	# キャラ選択ランダム：施錠中は変わらず、ほかは全部埋まる。
	(screen.get("_random_button") as Button).pressed.emit()
	assert_eq(RaceSession.slot_pururin_id(3), kept)
	for slot in RaceSession.SLOT_COUNT:
		assert_ne(slots[slot].call("shown_text"), PururinSlot.EMPTY_TEXT)
	assert_false((screen.get("_race_button") as Button).disabled)
	# 枠順ランダム：ユーザーの札は、ユーザーのスロットがある枠に付く。
	(screen.get("_order_button") as Button).pressed.emit()
	for slot in RaceSession.SLOT_COUNT:
		assert_eq(slots[slot].call("is_user"), RaceSession.is_user_slot(slot))
		assert_eq(slots[slot].call("is_locked"), RaceSession.is_locked(slot))
		assert_eq(slots[slot].call("pururin_id"), RaceSession.slot_pururin_id(slot))
	screen.free()


func test_a_locked_slot_ignores_left_right_and_x_and_cannot_be_robbed() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(0, ids[0])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	slots[0].grab_focus()
	slots[0]._gui_input(_pad_button(JOY_BUTTON_BACK))
	slots[0]._gui_input(_action("ui_right"))
	slots[0]._gui_input(_pad_button(JOY_BUTTON_X))
	assert_eq(RaceSession.slot_pururin_id(0), ids[0])
	# 別のスロットで同じ個体を出すと「選択済み」。施錠中なので、Yでも、ボタンでも奪えない。
	slots[1].grab_focus()
	slots[1]._gui_input(_action("ui_right"))
	assert_true(slots[1].call("is_taken"))
	var force_button: Button = screen.get("_detail").find_child("ForceButton", true, false)
	assert_true(force_button.disabled)
	assert_eq(force_button.text, PururinDetail.FORCE_LOCKED_TEXT)
	slots[1]._gui_input(_pad_button(JOY_BUTTON_Y))
	assert_eq(RaceSession.slot_pururin_id(0), ids[0])
	assert_eq(RaceSession.slot_pururin_id(1), RaceSession.EMPTY)
	screen.free()


func test_l2_and_r2_move_the_focused_slot_between_gates_and_focus_follows() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(0, ids[0])
	RaceSession.set_slot(1, ids[1])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	slots[0].grab_focus()
	# R2 を引いた瞬間に、下の枠へ。引いたままでは、もう動かない。
	slots[0]._gui_input(_trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(RaceSession.user_slot(), 1)
	assert_eq(get_viewport().gui_get_focus_owner(), slots[1], "選択の枠は、動かしたスロットに付いていく")
	slots[1]._gui_input(_trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	assert_eq(RaceSession.user_slot(), 1)
	slots[1]._gui_input(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	assert_true(slots[1].call("is_user"))
	assert_false(slots[0].call("is_user"))
	assert_eq(slots[0].call("pururin_id"), ids[1])
	assert_eq(slots[1].call("pururin_id"), ids[0])
	# L2 で上の枠へ戻る。1枠では、それ以上動かない。
	slots[1]._gui_input(_trigger(JOY_AXIS_TRIGGER_LEFT, 1.0))
	slots[0]._gui_input(_trigger(JOY_AXIS_TRIGGER_LEFT, 0.0))
	assert_eq(RaceSession.user_slot(), 0)
	slots[0]._gui_input(_trigger(JOY_AXIS_TRIGGER_LEFT, 1.0))
	slots[0]._gui_input(_trigger(JOY_AXIS_TRIGGER_LEFT, 0.0))
	assert_eq(RaceSession.user_slot(), 0)
	assert_eq(get_viewport().gui_get_focus_owner(), slots[0])
	screen.free()


func test_buttons_with_a_fixed_gamepad_button_show_its_mark() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	assert_eq((screen.get("_back_button") as Button).get_node("ButtonMark").get("kind"), "B")
	assert_eq((screen.get("_race_button") as Button).get_node("ButtonMark").get("kind"), "START")
	assert_eq((screen.get("_detail").find_child("ForceButton", true, false) as Button).get_node("ButtonMark").get("kind"), "Y")
	var first_note: Node = screen.find_child("ButtonNote1", true, false)
	assert_eq(first_note.get_child(0).get("kind"), "X")
	assert_eq(first_note.get_child(2).get("kind"), "SELECT")
	var second_note: Node = screen.find_child("ButtonNote2", true, false)
	assert_eq(second_note.get_child(0).get("kind"), "L2")
	assert_eq(second_note.get_child(2).get("kind"), "R2")
	screen.free()


func test_moving_a_slot_that_only_shows_a_taken_pururin_resets_it_to_empty() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(0, ids[0])
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	slots[1].grab_focus()
	slots[1]._gui_input(_action("ui_right"))
	assert_true(slots[1].call("is_taken"))
	slots[1]._gui_input(_trigger(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	slots[2]._gui_input(_trigger(JOY_AXIS_TRIGGER_RIGHT, 0.0))
	assert_eq(get_viewport().gui_get_focus_owner(), slots[2])
	for slot in [1, 2]:
		assert_false(slots[slot].call("is_taken"))
		assert_eq(slots[slot].call("shown_text"), PururinSlot.EMPTY_TEXT)
	assert_false(screen.get("_detail").call("is_showing_taken"))
	assert_eq(RaceSession.slot_pururin_id(0), ids[0])
	screen.free()


func test_force_button_and_its_mark_are_dimmed_when_the_holder_is_locked() -> void:
	var ids := RaceSession.roster_ids()
	RaceSession.set_slot(0, ids[0])
	RaceSession.toggle_lock(0)
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var slots: Array = screen.get("_slots")
	slots[1].grab_focus()
	slots[1]._gui_input(_action("ui_right"))
	var force_button: Button = screen.get("_detail").find_child("ForceButton", true, false)
	var mark: Control = force_button.get_node("ButtonMark")
	assert_true(force_button.disabled)
	assert_lt(mark.modulate.a, 1.0)
	# 施錠していない個体なら、ふつうの明るさ。
	RaceSession.toggle_lock(0)
	slots[1]._gui_input(_action("ui_left"))
	slots[1]._gui_input(_action("ui_right"))
	assert_false(force_button.disabled)
	assert_eq(mark.modulate, Color.WHITE)
	screen.free()


func test_l1_r1_carry_the_focus_frame_along_when_the_distance_row_is_focused() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var distances := RaceSession.supported_distances_m()
	var buttons: Array = screen.get("_distance_buttons")
	var last := distances.size() - 1
	(buttons[last] as Button).grab_focus()
	screen._unhandled_input(_pad_button(JOY_BUTTON_LEFT_SHOULDER))
	screen._unhandled_input(_pad_button(JOY_BUTTON_LEFT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[last - 2]))
	assert_eq(get_viewport().gui_get_focus_owner(), buttons[last - 2], "選択の枠も、選ばれている距離に付いていく")
	# 距離の段を選んでいないときは、選択の枠はそのまま。上の段へ移るときの行き先だけが変わる。
	var slots: Array = screen.get("_slots")
	slots[0].grab_focus()
	screen._unhandled_input(_pad_button(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(RaceSession.selected_distance_m(), float(distances[last - 1]))
	assert_eq(get_viewport().gui_get_focus_owner(), slots[0])
	assert_eq(slots[0].get_node(slots[0].focus_neighbor_top), buttons[last - 1])
	screen.free()


func test_every_focusable_part_has_explicit_neighbours_so_left_and_right_never_jump_rows() -> void:
	var screen := RaceSelectScene.instantiate()
	add_child(screen)
	var buttons: Array = screen.get("_distance_buttons")
	for index in buttons.size():
		var button: Button = buttons[index]
		assert_eq(button.get_node(button.focus_neighbor_left), buttons[maxi(index - 1, 0)])
		assert_eq(button.get_node(button.focus_neighbor_right), buttons[mini(index + 1, buttons.size() - 1)])
	var slots: Array = screen.get("_slots")
	for index in slots.size():
		var slot: Control = slots[index]
		assert_eq(slot.get_node(slot.focus_neighbor_left), slot)
		assert_eq(slot.get_node(slot.focus_neighbor_right), slot)
		if index > 0:
			assert_eq(slot.get_node(slot.focus_neighbor_top), slots[index - 1])
		if index < slots.size() - 1:
			assert_eq(slot.get_node(slot.focus_neighbor_bottom), slots[index + 1])
	var back: Button = screen.get("_back_button")
	var race: Button = screen.get("_race_button")
	assert_eq(back.get_node(back.focus_neighbor_right), race)
	assert_eq(race.get_node(race.focus_neighbor_left), back)
	# 行き先が決まっていない向きが、1つも無いこと。
	for node: Control in buttons + slots + [back, race, screen.get("_order_button"), screen.get("_random_button"), screen.get("_clear_button")]:
		for path: NodePath in [node.focus_neighbor_left, node.focus_neighbor_right, node.focus_neighbor_top, node.focus_neighbor_bottom]:
			assert_false(path.is_empty(), str(node.name))
	screen.free()
