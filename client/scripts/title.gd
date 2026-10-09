extends Control
## タイトル画面。背景の画像（ゲーム名のロゴ入り）の上に、遊ぶモードのボタンを置く。

const CAMERA_EXPLORATION_SCENE_PATH := "res://scenes/camera_exploration.tscn"
const PAD_DIAGNOSTICS_SCENE_PATH := "res://scenes/pad_diagnostics.tscn"
const TRAINER_PROFILE_SCENE_PATH := "res://scenes/trainer_profile.tscn"
const BACKGROUND_IMAGE_PATH := "res://assets/ui/title_screen_background.png"
const MenuStyle := preload("res://scripts/menu/menu_style.gd")
## ボタンの下の余白と、ボタンの濃さ（1で不透明）。
const BUTTON_BOTTOM_MARGIN := 76.0
const BUTTON_HEIGHT := 64.0
const BUTTON_GAP := 12.0
const BUTTON_OPACITY := 0.7
const RaceControllerInput := preload("res://scripts/input/race_controller_input.gd")
const SCREEN_MODES := [DisplayServer.WINDOW_MODE_WINDOWED, DisplayServer.WINDOW_MODE_MAXIMIZED, DisplayServer.WINDOW_MODE_FULLSCREEN]
const SCREEN_MODE_LABELS := ["通常ウィンドウ", "最大化", "全画面"]

var _free_race_button: Button
var _camera_exploration_button: Button
var _pad_diagnostics_button: Button
var _screen_mode_label: Label
var _screen_mode_index := -1
var _screen_mode_row: HBoxContainer
var _screen_direction_down := {"ui_left": false, "ui_right": false}


func _ready() -> void:
	# 画面の比率が画像と違うときは、暗くした同じ画像で、すき間を埋める。
	var filler := TextureRect.new()
	filler.name = "BackgroundFiller"
	filler.texture = load(BACKGROUND_IMAGE_PATH)
	filler.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	filler.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	filler.modulate = Color(0.35, 0.35, 0.4, 1.0)
	filler.set_anchors_preset(Control.PRESET_FULL_RECT)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(filler)
	var background := TextureRect.new()
	background.name = "Background"
	background.texture = load(BACKGROUND_IMAGE_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	# ボタンは少し透けさせて、背景の絵が見えるようにする。
	_free_race_button = MenuStyle.button("ゲーム開始", 28, Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_free_race_button.name = "FreeRaceButton"
	_free_race_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_free_race_button.offset_left = -182.0
	_free_race_button.offset_right = 182.0
	_free_race_button.offset_top = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT * 3.0 - BUTTON_GAP * 2.0
	_free_race_button.offset_bottom = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT * 2.0 - BUTTON_GAP * 2.0
	_free_race_button.pressed.connect(go_to_race_select)
	add_child(_free_race_button)
	_camera_exploration_button = MenuStyle.button("カメラで探検", 28, Color(MenuStyle.COLOR_BUTTON, BUTTON_OPACITY))
	_camera_exploration_button.name = "CameraExplorationButton"
	_camera_exploration_button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_camera_exploration_button.offset_left = -182.0
	_camera_exploration_button.offset_right = 182.0
	_camera_exploration_button.offset_top = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT * 2.0 - BUTTON_GAP
	_camera_exploration_button.offset_bottom = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT - BUTTON_GAP
	_camera_exploration_button.pressed.connect(go_to_camera_exploration)
	add_child(_camera_exploration_button)
	_free_race_button.focus_neighbor_bottom = _free_race_button.get_path_to(_camera_exploration_button)
	_camera_exploration_button.focus_neighbor_top = _camera_exploration_button.get_path_to(_free_race_button)
	var diagnostics := MenuStyle.button("ゲームパッド設定・入力確認", 18, MenuStyle.COLOR_BUTTON_QUIET)
	_pad_diagnostics_button = diagnostics
	diagnostics.name = "PadDiagnosticsButton"
	diagnostics.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	diagnostics.offset_left = -182.0
	diagnostics.offset_right = 182.0
	diagnostics.offset_top = -BUTTON_BOTTOM_MARGIN - BUTTON_HEIGHT
	diagnostics.offset_bottom = -BUTTON_BOTTOM_MARGIN
	diagnostics.pressed.connect(go_to_pad_diagnostics)
	add_child(diagnostics)
	_camera_exploration_button.focus_neighbor_bottom = _camera_exploration_button.get_path_to(diagnostics)
	diagnostics.focus_neighbor_top = diagnostics.get_path_to(_camera_exploration_button)
	_build_screen_mode_selector()
	_free_race_button.grab_focus()


func _build_screen_mode_selector() -> void:
	var row := HBoxContainer.new()
	row.name = "ScreenModeSelector"
	_screen_mode_row = row
	row.focus_mode = Control.FOCUS_ALL
	row.gui_input.connect(_screen_mode_gui_input)
	row.focus_entered.connect(row.queue_redraw)
	row.focus_exited.connect(row.queue_redraw)
	row.focus_exited.connect(func(): _screen_direction_down = {"ui_left": false, "ui_right": false})
	row.draw.connect(func():
		if row.has_focus():
			row.draw_style_box(MenuStyle.focus_box(), Rect2(Vector2.ZERO, row.size))
	)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.offset_left = -182.0
	row.offset_right = 182.0
	row.offset_top = -64.0
	row.offset_bottom = -24.0
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var caption := MenuStyle.label("ウィンドウサイズ", 16)
	caption.name = "ModeCaption"
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	var previous := _screen_mode_button("◀", "PreviousModeButton", -1)
	row.add_child(previous)
	_screen_mode_label = MenuStyle.label("通常ウィンドウ", 16)
	_screen_mode_label.name = "ModeLabel"
	_screen_mode_label.custom_minimum_size.x = 140.0
	_screen_mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen_mode_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_screen_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_screen_mode_label)
	var next := _screen_mode_button("▶", "NextModeButton", 1)
	row.add_child(next)
	row.focus_neighbor_top = row.get_path_to(_pad_diagnostics_button)
	_pad_diagnostics_button.focus_neighbor_bottom = _pad_diagnostics_button.get_path_to(row)
	_sync_screen_mode()


func _screen_mode_button(text: String, node_name: String, direction: int) -> Button:
	var button := MenuStyle.button(text, 16, Color(MenuStyle.COLOR_BUTTON_QUIET, BUTTON_OPACITY))
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(36, 40)
	# 通常のメニューボタンより薄い、画面最下部の操作行。
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 8.0
		style.content_margin_right = 8.0
		style.content_margin_top = 3.0
		style.content_margin_bottom = 3.0
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(_cycle_screen_mode.bind(direction))
	return button


## 行全体を選んで左右で切り替える。軸の連続イベントやキーリピートは数えない。
func _screen_mode_gui_input(event: InputEvent) -> void:
	if not _screen_mode_row.has_focus():
		return
	for action in ["ui_left", "ui_right"]:
		if not event.is_action(action):
			continue
		var down := event.is_action_pressed(action, true, true)
		if down and not _screen_direction_down[action] and not event.is_echo():
			_cycle_screen_mode(-1 if action == "ui_left" else 1)
		_screen_direction_down[action] = down
		_screen_mode_row.accept_event()


## タイトル再入場やOSの最大化・復元にも表示を合わせる。
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


static func cycled_screen_mode(mode: int, direction: int) -> int:
	return SCREEN_MODES[posmod(screen_mode_index(mode) + direction, SCREEN_MODES.size())]


func _cycle_screen_mode(direction: int) -> void:
	DisplayServer.window_set_mode(cycled_screen_mode(DisplayServer.window_get_mode(), direction))
	_sync_screen_mode()


## ゲームパッドの決定（A）で、選んでいるボタンを押す（Godotの標準では、ゲームパッドのボタンは「決定」に割り当てられていない）。
func _unhandled_input(event: InputEvent) -> void:
	if not RaceControllerInput.is_accept_pressed(event):
		return
	# ボタンを押すと場面が変わることがあるので、画面は先に取っておく。
	var viewport := get_viewport()
	if RaceControllerInput.activate_focused_control(viewport):
		viewport.set_input_as_handled()


## ゲーム開始の次は、トレーナーの画面（そこから、レース選択へ進む）。
func next_scene_path() -> String:
	return TRAINER_PROFILE_SCENE_PATH


func camera_exploration_scene_path() -> String:
	return CAMERA_EXPLORATION_SCENE_PATH


func go_to_race_select() -> void:
	get_tree().change_scene_to_file(next_scene_path())


func go_to_camera_exploration() -> void:
	get_tree().change_scene_to_file(camera_exploration_scene_path())

func pad_diagnostics_scene_path() -> String:
	return PAD_DIAGNOSTICS_SCENE_PATH


func go_to_pad_diagnostics() -> void:
	get_tree().change_scene_to_file(pad_diagnostics_scene_path())
