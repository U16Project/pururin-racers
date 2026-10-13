extends GutTest

const ControlGuide := preload("res://scripts/presentation/control_guide.gd")
const ModeSelectScene := preload("res://scenes/mode_select.tscn")
const LocalRaceScene := preload("res://scenes/local_race.tscn")
const RaceSession := preload("res://scripts/race_session.gd")


func before_each() -> void:
	RaceSession.select_full_field(RaceSession.default_player_pururin_id())


func test_device_tabs_show_only_the_selected_controls_and_reset_scroll() -> void:
	var guide := ControlGuide.new()
	add_child(guide)
	await get_tree().process_frame
	var labels := _all_label_text(guide)
	assert_true(labels.contains("レース操作ガイド"))
	assert_true(labels.contains("ノッチ0〜6"))
	assert_true(labels.contains("A または LT"))
	assert_false(labels.contains("C を1回押す"))
	assert_true(labels.contains("オンライン対戦での一時停止") or labels.contains("オンライン対戦"))
	var diagram := guide.find_child("GuideDiagram", true, false) as TextureRect
	assert_not_null(diagram)
	assert_not_null(diagram.texture)
	var pad_texture := diagram.texture
	var keyboard_tab := guide.find_child("DeviceTab1", true, false) as Button
	keyboard_tab.pressed.emit()
	await get_tree().process_frame
	labels = _all_label_text(guide)
	assert_true(labels.contains("C を1回押す"))
	assert_false(labels.contains("A または LT"))
	diagram = guide.find_child("GuideDiagram", true, false) as TextureRect
	assert_ne(diagram.texture, pad_texture)
	var scroll := guide.find_child("GuideScroll", true, false) as ScrollContainer
	scroll.scroll_vertical = 250
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	guide._input(right)
	await get_tree().process_frame
	labels = _all_label_text(guide)
	assert_true(labels.contains("左クリック"))
	assert_eq(scroll.scroll_vertical, 0)
	guide.close_guide()


func test_guide_panel_stays_in_648px_viewport_and_footer_remains_visible() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var guide := ControlGuide.new()
	viewport.add_child(guide)
	for frame in 4:
		await get_tree().process_frame

	var panel := guide.get("_panel") as PanelContainer
	var panel_rect := Rect2(panel.position, panel.size)
	assert_true(panel_rect.position.x >= 0.0)
	assert_true(panel_rect.position.y >= 0.0)
	assert_true(panel_rect.end.x <= float(viewport.size.x))
	assert_true(panel_rect.end.y <= float(viewport.size.y))
	var scroll := guide.get("_scroll") as ScrollContainer
	assert_true(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page)
	var diagram := guide.find_child("GuideDiagram", true, false) as TextureRect
	assert_not_null(diagram)
	var scroll_rect := scroll.get_global_rect()
	var diagram_rect := diagram.get_global_rect()
	assert_true(diagram_rect.position.y >= scroll_rect.position.y)
	assert_true(diagram_rect.end.y <= scroll_rect.end.y)
	var footer := guide.find_child("GuideFooter", true, false) as Label
	assert_not_null(footer)
	assert_true(footer.is_visible_in_tree())
	assert_true(footer.get_global_rect().end.y <= panel_rect.end.y)
	guide.queue_free()
	viewport.queue_free()
	await get_tree().process_frame


func test_mode_select_opens_the_guide_and_returns_focus_when_closed() -> void:
	var screen := ModeSelectScene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var button := screen.find_child("ControlGuideButton", true, false) as Button
	assert_not_null(button)
	button.pressed.emit()
	await get_tree().process_frame
	var guide := screen.get_node_or_null("ControlGuideOverlay")
	assert_not_null(guide)
	assert_true(guide.is_visible_in_tree())
	guide.call("close_guide")
	assert_eq(get_viewport().gui_get_focus_owner(), button)
	screen.free()


func test_pause_guide_returns_to_the_pause_panel_without_resuming_race() -> void:
	var race := LocalRaceScene.instantiate()
	add_child(race)
	await get_tree().process_frame
	race.call("_set_paused", true)
	var button := race.find_child("PauseControlGuideButton", true, false) as Button
	assert_not_null(button)
	var touch_controls := race.get("_touch_controls") as Control
	for initially_shown in [true, false]:
		touch_controls.call("set_pad_shown", initially_shown)
		assert_eq(touch_controls.call("is_pad_shown"), initially_shown)
		button.pressed.emit()
		await get_tree().process_frame
		var guide := race.get_node_or_null("UI/ControlGuideOverlay")
		assert_not_null(guide)
		assert_false(touch_controls.call("is_pad_shown"))
		assert_false(touch_controls.is_processing_input())
		assert_true(bool(race.get("_paused")))
		assert_false(race.get_node("UI/PausePanel").visible)
		guide.call("close_guide")
		await get_tree().process_frame
		assert_true(touch_controls.is_processing_input())
		assert_eq(touch_controls.call("is_pad_shown"), initially_shown)
		assert_true(bool(race.get("_paused")))
		assert_true(race.get_node("UI/PausePanel").visible)
	assert_eq(get_viewport().gui_get_focus_owner(), button)
	race.free()


func _all_label_text(root: Node) -> String:
	var result := ""
	for label: Label in root.find_children("*", "Label", true, false):
		result += label.text + "\n"
	return result
