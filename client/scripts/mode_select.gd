extends Control
## 遊び方と画質の選択。

const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const MENU_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const ONLINE_LOBBY_SCENE_PATH := "res://scenes/online_lobby.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const ControlGuide := preload("res://scripts/presentation/control_guide.gd")
const CAMERA_EXPLORATION_SCENE_PATH := "res://scenes/camera_exploration.tscn"
const BUTTON_OPACITY := 0.92
const SCREEN_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
const SCREEN_MODE_LABELS := ["通常ウィンドウ", "最大化", "全画面"]
const BUTTON_WIDTH := 460.0
const BUTTON_HEIGHT := 58.0

var _offline_button: Button
var _online_button: Button
var _friend_button: Button
var _guide_button: Button
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
	var background := TextureRect.new()
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.45, 0.45, 0.5, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.add_theme_stylebox_override("panel", MenuStyle.box(MenuStyle.COLOR_PANEL, 18, 28.0, 22.0))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -280.0
	panel.offset_right = 280.0
	panel.offset_top = -316.0
	panel.offset_bottom = 316.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := MenuStyle.label("ゲームモード設定", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_offline_button = _choice_button("オフラインフリー対戦", "OfflineFreeRaceButton")
	_offline_button.pressed.connect(go_to_race_select)
	UIAudio.bind_button_sound(_offline_button, "confirmation")
	column.add_child(_offline_button)
	_online_button = _choice_button("オンラインフリー対戦（未実装）", "OnlineFreeRaceButton")
	_online_button.disabled = true
	column.add_child(_online_button)
	_friend_button = _choice_button("ともだち対戦", "FriendRaceButton")
	_friend_button.pressed.connect(go_to_online_lobby)
	UIAudio.bind_button_sound(_friend_button, "confirmation")
	column.add_child(_friend_button)
	_guide_button = _choice_button("操作ガイド", "ControlGuideButton", MenuStyle.COLOR_BUTTON_QUIET)
	_guide_button.pressed.connect(_open_control_guide)
	UIAudio.bind_button_sound(_guide_button, "confirmation")
	column.add_child(_guide_button)
	var exploration := _choice_button("カメラで探検", "CameraExplorationButton", MenuStyle.COLOR_BUTTON_QUIET)
	exploration.pressed.connect(go_to_camera_exploration)
	UIAudio.bind_button_sound(exploration, "confirmation")
	column.add_child(exploration)
	_build_quality_selector(column)
	_build_screen_mode_selector(column)
	var quit_button := _choice_button("ゲームを終了", "QuitButton", MenuStyle.COLOR_BUTTON_QUIET)
	quit_button.pressed.connect(func(): get_tree().quit())
	UIAudio.bind_button_sound(quit_button, "confirmation")
	column.add_child(quit_button)
	_back_button = _choice_button("戻る", "BackButton", MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.pressed.connect(go_to_menu)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	column.add_child(_back_button)
	_offline_button.focus_neighbor_bottom = _offline_button.get_path_to(_friend_button)
	_friend_button.focus_neighbor_top = _friend_button.get_path_to(_offline_button)
	_friend_button.focus_neighbor_bottom = _friend_button.get_path_to(_guide_button)
	_guide_button.focus_neighbor_top = _guide_button.get_path_to(_friend_button)
	_guide_button.focus_neighbor_bottom = _guide_button.get_path_to(exploration)
	exploration.focus_neighbor_top = exploration.get_path_to(_guide_button)
	exploration.focus_neighbor_bottom = exploration.get_path_to(_quality_button)
	_quality_button.focus_neighbor_top = _quality_button.get_path_to(exploration)
	_quality_button.focus_neighbor_bottom = _quality_button.get_path_to(_screen_mode_row)
	_screen_mode_row.focus_neighbor_top = _screen_mode_row.get_path_to(_quality_button)
	_screen_mode_row.focus_neighbor_bottom = _screen_mode_row.get_path_to(quit_button)
	quit_button.focus_neighbor_top = quit_button.get_path_to(_screen_mode_row)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(_back_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(quit_button)
	_offline_button.grab_focus()


func _choice_button(text: String, node_name: String, color: Color = MenuStyle.COLOR_BUTTON) -> Button:
	var button := MenuStyle.button(text, 22, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	return button


## ともだち対戦：部屋の画面へ（今は、合言葉の部屋に集まる所まで）。
func go_to_online_lobby() -> void:
	get_tree().change_scene_to_file(ONLINE_LOBBY_SCENE_PATH)


func go_to_camera_exploration() -> void:
	get_tree().change_scene_to_file(CAMERA_EXPLORATION_SCENE_PATH)


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_SCENE_PATH)


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
	row.custom_minimum_size = Vector2(364, 30)
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
	var caption := MenuStyle.label("画質", 14)
	caption.custom_minimum_size.x = 128
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousQualityButton", -1, true))
	_quality_label = MenuStyle.label("", 14)
	_quality_label.name = "QualityLabel"
	_quality_label.custom_minimum_size.x = 140
	_quality_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quality_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quality_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_quality_label)
	row.add_child(_screen_mode_button("▶", "NextQualityButton", 1, true))
	_update_quality_text()


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
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
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
	row.custom_minimum_size = Vector2(364.0, 30.0)
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
	var caption := MenuStyle.label("ウィンドウサイズ", 14)
	caption.name = "ModeCaption"
	caption.custom_minimum_size.x = 128
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	row.add_child(_screen_mode_button("◀", "PreviousModeButton", -1))
	_screen_mode_label = MenuStyle.label("通常ウィンドウ", 14)
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
	var button := MenuStyle.button(text, 14, Color(MenuStyle.COLOR_BUTTON_QUIET, BUTTON_OPACITY))
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36, 30)
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
