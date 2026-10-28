extends Control
## オプション設定。画質・画面モード・操作ガイド。トレーナー画面の次、ゲームモード選択の前。

const MODE_SELECT_SCENE_PATH := "res://scenes/mode_select.tscn"
const MENU_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const ControlGuide := preload("res://scripts/presentation/control_guide.gd")
const TrainerProfile := preload("res://scripts/config/trainer_profile.gd")
const SCREEN_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
const SCREEN_MODE_LABELS := ["通常ウィンドウ", "最大化", "全画面"]
const PANEL_WIDTH := 620.0
const PANEL_HEIGHT := 420.0
const BUTTON_HEIGHT := 56.0

var _guide_button: Button
var _next_button: Button
var _back_button: Button
var _guide_overlay: Control
var _screen_mode_label: Label
var _screen_mode_index := -1
var _screen_mode_row: HBoxContainer
var _screen_direction_down := {"ui_left": false, "ui_right": false}
var _quality_button: HBoxContainer
var _quality_label: Label
var _quality_direction_down := {"ui_left": false, "ui_right": false}


func _ready() -> void:
	MenuStyle.background(self, BACKGROUND_IMAGE_PATH)
	MenuStyle.top_bar(self, "オプション設定", TrainerProfile.trainer_name())
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.panel_box(28.0, 22.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_WIDTH * 0.5
	panel.offset_right = PANEL_WIDTH * 0.5
	panel.offset_top = -PANEL_HEIGHT * 0.5
	panel.offset_bottom = PANEL_HEIGHT * 0.5
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(MenuStyle.section_title("画面"))
	var note := MenuStyle.label("画質と画面の大きさを選べます（←→で変える）。操作が分からないときは、操作ガイドを見てください。", 14, MenuStyle.COLOR_BAR_DIM)
	note.add_theme_constant_override("outline_size", 0)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_build_quality_selector(column)
	_build_screen_mode_selector(column)
	column.add_child(MenuStyle.section_title("操作"))
	_guide_button = MenuStyle.pill_button("操作ガイドを見る", "secondary", 18)
	_guide_button.name = "ControlGuideButton"
	_guide_button.custom_minimum_size = Vector2(0.0, 44.0)
	_guide_button.pressed.connect(_open_control_guide)
	UIAudio.bind_button_sound(_guide_button, "confirmation")
	column.add_child(_guide_button)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_next_button = MenuStyle.pill_button("次へ（ゲームモード選択）", "primary", 22)
	_next_button.name = "NextButton"
	_next_button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	_next_button.pressed.connect(go_to_mode_select)
	UIAudio.bind_button_sound(_next_button, "confirmation")
	MenuStyle.add_mark(_next_button, "START")
	column.add_child(_next_button)
	var guide := MenuStyle.guide_bar(self)
	MenuStyle.guide_item(guide, "A", "決定")
	_back_button = MenuStyle.guide_button(guide, "B", "戻る")
	_back_button.name = "BackButton"
	_back_button.pressed.connect(go_to_menu)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.guide_item(guide, "START", "次へ")
	_quality_button.focus_neighbor_bottom = _quality_button.get_path_to(_screen_mode_row)
	_screen_mode_row.focus_neighbor_top = _screen_mode_row.get_path_to(_quality_button)
	_screen_mode_row.focus_neighbor_bottom = _screen_mode_row.get_path_to(_guide_button)
	_guide_button.focus_neighbor_top = _guide_button.get_path_to(_screen_mode_row)
	_guide_button.focus_neighbor_bottom = _guide_button.get_path_to(_next_button)
	_next_button.focus_neighbor_top = _next_button.get_path_to(_guide_button)
	_next_button.focus_neighbor_bottom = _next_button.get_path_to(_next_button)
	_next_button.grab_focus()


func step_quality() -> void:
	RaceSession.set_course_only(not RaceSession.is_course_only())
	_update_quality_text()


func _update_quality_text() -> void:
	_quality_label.text = "軽量" if RaceSession.is_course_only() else "標準"


func _quality_input(event: InputEvent) -> void:
	if not _quality_button.has_focus():
		return
	for action in ["ui_left", "ui_right"]:
		if event.is_action(action):
			var down := event.is_action_pressed(action, true, true)
			if down and not _quality_direction_down[action] and not event.is_echo():
				step_quality()
				UIAudio.play_selection_cycle()
			_quality_direction_down[action] = down
			_quality_button.accept_event()


func _build_quality_selector(column: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "QualityButton"
	_quality_button = row
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(364, 40)
	row.add_theme_constant_override("separation", 4)
	row.gui_input.connect(_quality_input)
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	row.focus_exited.connect(func(): _quality_direction_down = {"ui_left": false, "ui_right": false})
	row.draw.connect(func():
		if row.has_focus():
			row.draw_style_box(MenuStyle.focus_box(), Rect2(Vector2.ZERO, row.size))
	)
	column.add_child(row)
	var caption := MenuStyle.label("画質", 16, MenuStyle.COLOR_BAR_DIM)
	caption.custom_minimum_size.x = 150
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousQualityButton", -1, true))
	_quality_label = MenuStyle.bold_label("", 18)
	_quality_label.name = "QualityLabel"
	_quality_label.custom_minimum_size.x = 140
	_quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_quality_label)
	row.add_child(_screen_mode_button("▶", "NextQualityButton", 1, true))
	_update_quality_text()


func go_to_mode_select() -> void:
	get_tree().change_scene_to_file(MODE_SELECT_SCENE_PATH)


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _open_control_guide() -> void:
	if is_instance_valid(_guide_overlay):
		return
	var guide := ControlGuide.new()
	_guide_overlay = guide
	add_child(guide)
	guide.closed.connect(_on_control_guide_closed)


func _on_control_guide_closed() -> void:
	_guide_overlay = null
	if is_instance_valid(_guide_button):
		_guide_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if is_instance_valid(_guide_overlay):
		if RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
			viewport.set_input_as_handled()
		return
	if RaceControllerInput.is_menu_pressed(event):
		# 「次へ」に付けた START の目印のとおり、Start で次へ進む。
		viewport.set_input_as_handled()
		RaceControllerInput.activate_control(_next_button)
	elif event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_to_menu()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()


func _build_screen_mode_selector(menu: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "ScreenModeSelector"
	_screen_mode_row = row
	row.focus_mode = Control.FOCUS_ALL
	row.custom_minimum_size = Vector2(364.0, 40.0)
	row.gui_input.connect(_screen_mode_gui_input)
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	row.focus_exited.connect(func(): _screen_direction_down = {"ui_left": false, "ui_right": false})
	row.draw.connect(func():
		if row.has_focus():
			row.draw_style_box(MenuStyle.focus_box(), Rect2(Vector2.ZERO, row.size))
	)
	row.add_theme_constant_override("separation", 4)
	menu.add_child(row)
	var caption := MenuStyle.label("ウィンドウサイズ", 16, MenuStyle.COLOR_BAR_DIM)
	caption.name = "ModeCaption"
	caption.custom_minimum_size.x = 150
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousModeButton", -1))
	_screen_mode_label = MenuStyle.bold_label("通常ウィンドウ", 18)
	_screen_mode_label.name = "ModeLabel"
	_screen_mode_label.custom_minimum_size.x = 140.0
	_screen_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_screen_mode_label)
	row.add_child(_screen_mode_button("▶", "NextModeButton", 1))
	_sync_screen_mode()


func _screen_mode_button(text: String, node_name: String, direction: int, quality: bool = false) -> Button:
	var button := MenuStyle.pill_button(text, "secondary", 14)
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(44, 34)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func() -> void:
		if quality:
			step_quality()
			UIAudio.play_arrow_click()
			return
		var previous := _screen_mode_index
		_cycle_screen_mode(direction)
		if _screen_mode_index != previous:
			UIAudio.play_arrow_click())
	return button


func _screen_mode_gui_input(event: InputEvent) -> void:
	if not _screen_mode_row.has_focus():
		return
	for action in ["ui_left", "ui_right"]:
		if not event.is_action(action):
			continue
		var down := event.is_action_pressed(action, true, true)
		if down and not _screen_direction_down[action] and not event.is_echo():
			var previous := _screen_mode_index
			_cycle_screen_mode(-1 if action == "ui_left" else 1)
			var sound_key := screen_mode_sound_key(event is InputEventJoypadButton or event is InputEventJoypadMotion, _screen_mode_index != previous)
			if sound_key == "selection_cycle":
				UIAudio.play_selection_cycle()
		_screen_direction_down[action] = down
		_screen_mode_row.accept_event()


func _process(_delta: float) -> void:
	_sync_screen_mode()


func _sync_screen_mode() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		return
	var index := screen_mode_index(mode)
	if index != _screen_mode_index:
		_screen_mode_index = index
		_screen_mode_label.text = SCREEN_MODE_LABELS[index]


static func screen_mode_index(mode: int) -> int:
	if mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return 2
	var index := SCREEN_MODES.find(mode)
	return maxi(index, 0)


static func screen_mode_sound_key(is_gamepad: bool, changed: bool) -> String:
	return "selection_cycle" if is_gamepad and changed else ""


static func cycled_screen_mode(mode: int, direction: int) -> int:
	return SCREEN_MODES[posmod(screen_mode_index(mode) + direction, SCREEN_MODES.size())]


func _cycle_screen_mode(direction: int) -> void:
	DisplayServer.window_set_mode(cycled_screen_mode(DisplayServer.window_get_mode(), direction))
	_sync_screen_mode()
