extends Control
## 遊び方の選択。オフラインフリー対戦はレース選択へ進む。オンラインは、まだ進まない。

const RACE_SELECT_SCENE_PATH := "res://scenes/race_select.tscn"
const MENU_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const ONLINE_LOBBY_SCENE_PATH := "res://scenes/online_lobby.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/trainer_background.jpg"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const RaceSession := preload("res://scripts/race_session.gd")
const BUTTON_WIDTH := 460.0
const BUTTON_HEIGHT := 58.0

var _offline_button: Button
var _online_button: Button
var _web_test_button: Button
var _back_button: Button


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
	panel.offset_top = -180.0
	panel.offset_bottom = 180.0
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := MenuStyle.label("ゲーム開始", 30)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	_offline_button = _choice_button("オフラインフリー対戦", "OfflineFreeRaceButton")
	_offline_button.pressed.connect(go_to_race_select)
	UIAudio.bind_button_sound(_offline_button, "confirmation")
	column.add_child(_offline_button)
	_web_test_button = _choice_button("ウェブ版オフラインテスト", "WebOfflineTestButton")
	_web_test_button.pressed.connect(go_to_web_test)
	UIAudio.bind_button_sound(_web_test_button, "confirmation")
	column.add_child(_web_test_button)
	_online_button = _choice_button("📡オンラインフリー対戦（作成中）", "OnlineFreeRaceButton")
	_online_button.pressed.connect(go_to_online_lobby)
	UIAudio.bind_button_sound(_online_button, "confirmation")
	column.add_child(_online_button)
	_back_button = _choice_button("戻る", "BackButton", MenuStyle.COLOR_BUTTON_QUIET)
	_back_button.pressed.connect(go_to_menu)
	UIAudio.bind_button_sound(_back_button, "back")
	MenuStyle.add_mark(_back_button, "B")
	column.add_child(_back_button)
	_offline_button.focus_neighbor_bottom = _offline_button.get_path_to(_web_test_button)
	_web_test_button.focus_neighbor_top = _web_test_button.get_path_to(_offline_button)
	_web_test_button.focus_neighbor_bottom = _web_test_button.get_path_to(_online_button)
	_online_button.focus_neighbor_top = _online_button.get_path_to(_web_test_button)
	_online_button.focus_neighbor_bottom = _online_button.get_path_to(_back_button)
	_back_button.focus_neighbor_top = _back_button.get_path_to(_online_button)
	_offline_button.grab_focus()


func _choice_button(text: String, node_name: String, color: Color = MenuStyle.COLOR_BUTTON) -> Button:
	var button := MenuStyle.button(text, 22, color)
	button.name = node_name
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	return button


## オンラインフリー対戦：部屋の画面へ（今は、合言葉の部屋に集まる所まで）。
func go_to_online_lobby() -> void:
	get_tree().change_scene_to_file(ONLINE_LOBBY_SCENE_PATH)


func go_to_race_select() -> void:
	RaceSession.set_course_only(false)
	get_tree().change_scene_to_file(RACE_SELECT_SCENE_PATH)


## ウェブ版オフラインテスト：オフラインフリー対戦と同じ。景色だけ、コースまわりだけにする（軽くするため）。
func go_to_web_test() -> void:
	RaceSession.set_course_only(true)
	get_tree().change_scene_to_file(RACE_SELECT_SCENE_PATH)


func go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel") or RaceControllerInput.is_cancel_pressed(event):
		UIAudio.play_back()
		viewport.set_input_as_handled()
		go_to_menu()
	elif RaceControllerInput.is_accept_pressed(event) and RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()
